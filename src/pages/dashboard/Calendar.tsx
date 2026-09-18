import { CalendarDays, ChevronLeft, ChevronRight, Plane, Star } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import TabbedModulePage from '../../components/game/TabbedModulePage'
import { useGameClock } from '../../hooks/useGameClock'
import {
  MONTHS,
  WEEKDAYS,
  absoluteGameDay,
  competitionWeekRange,
  competitionWeeksForMonth,
  dayOfSeason,
  firstWeekdayIndex,
  formatAbsoluteGameDay,
  formatCompetitionWeekRange,
  isSeasonOpeningDay,
  weekdayForDate,
} from '../../lib/competitionCalendar'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-calendar.css'
import '../../styles/calendar-player-activity.css'
import '../../styles/tournament-status.css'

const TOURNAMENT_RETURN_STORAGE_KEY = 'tlg-tournament-calendar-return'

interface TournamentCalendarRow {
  competition_id: string
  tournament_id: string
  edition_id: string
  schedule_slot_id: string
  world: 'ATP' | 'WTA'
  season_number: number
  season_week: number
  calendar_month: number
  month_week: number
  phase: 'full' | 'qualification' | 'main_draw'
  tournament_name: string
  city: string
  country_code: string
  country_name: string
  category_code: string
  category_label: string
  winner_points: number
  main_draw_capacity: number
  qualifying_capacity_max: number
  default_qualifier_slots: number
  surface: 'hard' | 'clay' | 'grass'
  environment: 'indoor' | 'outdoor'
  tournament_status: string
  tournament_status_label: string
  applications_open: boolean
  application_open_day: number
  application_close_day: number
  tournament_start_day: number
  tournament_end_day: number
  user_status: string
  user_status_label: string
  user_entry_projection: string | null
}

interface SponsorTournamentObjective {
  competition_id: string
  objective_id: string
  tournament_name: string | null
  requirement_label: string | null
  reward_amount: number
  status: 'upcoming' | 'active' | 'completed' | 'failed' | 'expired'
}

interface TournamentReturnPosition {
  month: number
  week: number
}

interface PlayerCalendarActivityRow {
  season: number
  month: number
  day: number
  activity_type: 'travel' | 'tournament' | 'training_camp' | 'injured' | 'home'
  source: string | null
  note: string | null
  reference_id: string | null
}

function parsePositiveInteger(value: string | null, minimum: number, maximum: number) {
  if (!value) return null
  const parsed = Number.parseInt(value, 10)
  return Number.isInteger(parsed) && parsed >= minimum && parsed <= maximum ? parsed : null
}

function saveTournamentReturnPosition(month: number, week: number) {
  try {
    window.sessionStorage.setItem(
      TOURNAMENT_RETURN_STORAGE_KEY,
      JSON.stringify({ month, week } satisfies TournamentReturnPosition),
    )
  } catch {
    // Browser storage can be unavailable in privacy-restricted contexts.
  }
}

function consumeTournamentReturnPosition(): TournamentReturnPosition | null {
  try {
    const raw = window.sessionStorage.getItem(TOURNAMENT_RETURN_STORAGE_KEY)
    window.sessionStorage.removeItem(TOURNAMENT_RETURN_STORAGE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as Partial<TournamentReturnPosition>
    if (
      typeof parsed.month === 'number'
      && parsed.month >= 1
      && parsed.month <= 12
      && typeof parsed.week === 'number'
      && parsed.week >= 1
      && parsed.week <= 5
    ) return { month: parsed.month, week: parsed.week }
  } catch {
    // Invalid browser storage should not block Calendar.
  }
  return null
}

function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function phaseLabel(phase: TournamentCalendarRow['phase']) {
  if (phase === 'qualification') return 'Qualification'
  if (phase === 'main_draw') return 'Main draw'
  return null
}

function playerActivityLabel(activity: PlayerCalendarActivityRow['activity_type']) {
  if (activity === 'training_camp') return 'Training Camp'
  if (activity === 'tournament') return 'Tournament'
  if (activity === 'travel') return 'Travel'
  if (activity === 'injured') return 'Health / Recovery'
  return 'Home'
}

function playerActivityPriority(activity: PlayerCalendarActivityRow) {
  if (activity.activity_type === 'injured') return 1
  if (activity.activity_type === 'tournament' && activity.source === 'tournament_accepted') return 8
  if (activity.activity_type === 'tournament' && activity.source !== 'tournament_predicted') return 2
  if (activity.activity_type === 'travel') return 3
  if (activity.activity_type === 'training_camp') return 4
  if (activity.activity_type === 'tournament') return 9
  return 10
}

function activeTournamentWeekForDate(monthIndex: number, day: number) {
  const seasonDay = dayOfSeason(monthIndex, day)
  const seasonWeek = seasonDay <= 2
    ? 1
    : Math.max(1, Math.min(52, Math.floor((seasonDay - 3) / 7) + 1))
  return competitionWeekRange(seasonWeek)
}

function tournamentTimingLabel(event: TournamentCalendarRow) {
  if (event.tournament_status === 'applications_not_open') return `Opens ${formatAbsoluteGameDay(event.application_open_day, event.season_number)}`
  if (event.tournament_status === 'applications_open') return `Closes ${formatAbsoluteGameDay(event.application_close_day, event.season_number)}`
  if (event.tournament_status === 'applications_closed' || event.tournament_status === 'draw_published') return `Starts ${formatAbsoluteGameDay(event.tournament_start_day, event.season_number)}`
  if (event.tournament_status === 'in_progress') return `Ends ${formatAbsoluteGameDay(event.tournament_end_day, event.season_number)}`
  if (event.tournament_status === 'completed') return `Finished ${formatAbsoluteGameDay(event.tournament_end_day, event.season_number)}`
  return ''
}

function SeasonCalendarView() {
  const { player } = useAuth()
  const clock = useGameClock()
  const [monthIndex, setMonthIndex] = useState(0)
  const [activities, setActivities] = useState<PlayerCalendarActivityRow[]>([])
  const [activityError, setActivityError] = useState<string | null>(null)
  const [activityVersion, setActivityVersion] = useState(0)

  useEffect(() => {
    if (!clock.loading) setMonthIndex(clock.monthIndex)
  }, [clock.loading, clock.monthIndex])

  useEffect(() => {
    if (!player?.id || clock.loading) {
      setActivities([])
      return
    }
    let cancelled = false
    async function loadPlayerActivity() {
      const { data, error } = await supabase.rpc('get_player_calendar_activity_v1', {
        p_season: clock.season,
        p_month: monthIndex + 1,
      })
      if (cancelled) return
      if (error) {
        setActivities([])
        setActivityError(error.message)
        return
      }
      setActivityError(null)
      setActivities((data ?? []) as PlayerCalendarActivityRow[])
    }
    void loadPlayerActivity()
    return () => { cancelled = true }
  }, [player?.id, clock.loading, clock.season, monthIndex, activityVersion])

  useEffect(() => {
    if (!player?.id) return
    const refresh = () => setActivityVersion((value) => value + 1)
    const channel = supabase
      .channel(`season-calendar-activity:${player.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_daily_activity', filter: `player_id=eq.${player.id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_entries', filter: `player_id=eq.${player.id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_travel_legs', filter: `player_id=eq.${player.id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_matches' }, refresh)
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [player?.id])

  const month = MONTHS[monthIndex]
  const leadingEmptyCells = firstWeekdayIndex(monthIndex)
  const cells = useMemo(() => {
    const values: Array<number | null> = []
    for (let index = 0; index < leadingEmptyCells; index += 1) values.push(null)
    for (let day = 1; day <= month.days; day += 1) values.push(day)
    while (values.length % 7 !== 0) values.push(null)
    return values
  }, [leadingEmptyCells, month.days])
  const activityByDay = useMemo(() => {
    const grouped = new Map<number, PlayerCalendarActivityRow>()
    for (const activity of activities) {
      const current = grouped.get(activity.day)
      if (!current || playerActivityPriority(activity) < playerActivityPriority(current)) grouped.set(activity.day, activity)
    }
    return grouped
  }, [activities])
  const todayWeekday = weekdayForDate(clock.monthIndex, clock.day)
  const todayAbsoluteDay = absoluteGameDay(clock.season, clock.monthIndex, clock.day)

  const monthNavigation = (label: string) => (
    <div className="tlg-season-calendar-nav" aria-label={label}>
      <button type="button" disabled={monthIndex === 0} onClick={() => setMonthIndex((value) => Math.max(0, value - 1))}><ChevronLeft size={14} /> Previous</button>
      <strong>{month.name}</strong>
      <button type="button" disabled={monthIndex === MONTHS.length - 1} onClick={() => setMonthIndex((value) => Math.min(MONTHS.length - 1, value + 1))}>Next <ChevronRight size={14} /></button>
    </div>
  )

  return (
    <div className="tlg-season-calendar">
      <div className="tlg-season-calendar-toolbar">
        <div className="tlg-season-calendar-copy">
          <h4>Season {clock.season} · {month.name}</h4>
          <p>Today: Season {clock.season} · {todayWeekday} · {clock.month} {clock.day}. Accepted main-draw weeks are reserved with a light overlay until your first match schedule is known. Confirmed match days are secured; predicted tournament days remain planning days until progression makes them certain.</p>
        </div>
        {monthNavigation('Calendar month navigation')}
      </div>

      {activityError && <div className="tlg-calendar-player-activity-error">Unable to load your player schedule: {activityError}</div>}
      <div className="tlg-calendar-weekdays" aria-hidden="true">{WEEKDAYS.map((weekday) => <span key={weekday}>{weekday}</span>)}</div>
      <div className="tlg-calendar-grid">
        {cells.map((day, index) => {
          if (day === null) return <div key={`empty-${index}`} className="tlg-calendar-day-empty" aria-hidden="true" />
          const current = monthIndex === clock.monthIndex && day === clock.day
          const openingDay = isSeasonOpeningDay(monthIndex, day)
          const activity = activityByDay.get(day)
          const activityAbsoluteDay = activity ? absoluteGameDay(activity.season, activity.month - 1, activity.day) : null
          const tournamentCompleted = activity?.activity_type === 'tournament'
            && (activity.source === 'tournament_completed' || (activityAbsoluteDay !== null && activityAbsoluteDay < todayAbsoluteDay))
          const tournamentAccepted = activity?.activity_type === 'tournament' && activity.source === 'tournament_accepted'
          const tournamentPredicted = activity?.activity_type === 'tournament' && activity.source === 'tournament_predicted'
          const tournamentConfirmed = activity?.activity_type === 'tournament' && !tournamentCompleted && !tournamentAccepted && !tournamentPredicted
          const tournamentState = tournamentCompleted ? 'completed' : tournamentAccepted ? 'accepted' : tournamentPredicted ? 'predicted' : tournamentConfirmed ? 'confirmed' : ''
          const classes = ['tlg-calendar-day']
          if (current) classes.push('tlg-calendar-day-current')
          if (activity) classes.push(`tlg-calendar-day-${activity.activity_type}`)
          if (tournamentState) classes.push(`tlg-calendar-day-tournament-${tournamentState}`)

          return (
            <div key={`${month.name}-${day}`} className={classes.join(' ')}>
              <span className="tlg-calendar-day-number">{month.name} {day}</span>
              {current && <span className="tlg-calendar-today-badge">Today</span>}
              {openingDay && !current && <span className="tlg-calendar-today-badge">Season opening</span>}
              {activity && (
                <div className="tlg-calendar-player-activities">
                  <div className={`tlg-calendar-player-activity ${activity.activity_type}${tournamentState ? ` ${tournamentState}` : ''}`}>
                    {activity.activity_type === 'travel' && <Plane size={13} className="tlg-calendar-travel-icon" aria-hidden="true" />}
                    <span>{activity.activity_type === 'tournament'
                      ? `Tournament · ${tournamentCompleted ? 'Played' : tournamentAccepted ? 'Accepted' : tournamentPredicted ? 'Predicted' : 'Confirmed'}`
                      : playerActivityLabel(activity.activity_type)}</span>
                    <strong>{activity.note || playerActivityLabel(activity.activity_type)}</strong>
                  </div>
                </div>
              )}
            </div>
          )
        })}
      </div>

      <div className="tlg-season-calendar-bottom-nav">
        {monthNavigation('Calendar month navigation bottom')}
      </div>
    </div>
  )
}

function TournamentCalendarView({ initialMonth, initialWeek }: { initialMonth?: number; initialWeek?: number }) {
  const { player } = useAuth()
  const clock = useGameClock()
  const [, setSearchParams] = useSearchParams()
  const initialSeasonWeek = initialMonth && initialWeek
    ? competitionWeeksForMonth(initialMonth - 1).find((week) => week.monthWeek === initialWeek)?.seasonWeek ?? null
    : null
  const [monthIndex, setMonthIndex] = useState(() => initialMonth ? initialMonth - 1 : 0)
  const [restoreWeek, setRestoreWeek] = useState<number | null>(initialWeek ?? null)
  const [focusedSeasonWeek, setFocusedSeasonWeek] = useState<number | null>(initialSeasonWeek)
  const [events, setEvents] = useState<TournamentCalendarRow[]>([])
  const [sponsorObjectives, setSponsorObjectives] = useState<SponsorTournamentObjective[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (clock.loading || initialMonth) return
    const activeWeek = activeTournamentWeekForDate(clock.monthIndex, clock.day)
    setMonthIndex(activeWeek.displayMonthIndex)
    setFocusedSeasonWeek(activeWeek.seasonWeek)
    setRestoreWeek(activeWeek.monthWeek)
  }, [clock.loading, clock.monthIndex, clock.day, initialMonth])

  const month = MONTHS[monthIndex]
  const world = player?.world ?? 'ATP'
  const monthCompetitionWeeks = useMemo(() => competitionWeeksForMonth(monthIndex), [monthIndex])

  useEffect(() => {
    if (clock.loading) return
    let cancelled = false
    async function loadTournamentCalendar() {
      setLoading(true)
      setError(null)
      const { data, error: calendarError } = await supabase.rpc('get_tournament_calendar_v2', {
        p_season_number: clock.season,
        p_calendar_month: monthIndex + 1,
        p_world: world,
      })
      if (cancelled) return
      if (calendarError) {
        setEvents([])
        setError(calendarError.message)
      } else {
        setEvents((data ?? []) as TournamentCalendarRow[])
      }
      setLoading(false)
    }
    void loadTournamentCalendar()
    return () => { cancelled = true }
  }, [clock.loading, clock.season, clock.day, clock.monthIndex, monthIndex, world])

  useEffect(() => {
    if (!player?.id || clock.loading) {
      setSponsorObjectives([])
      return
    }

    let cancelled = false
    async function loadSponsorObjectives() {
      const { data, error: sponsorObjectiveError } = await supabase.rpc('get_my_sponsor_tournament_objectives_v1', {
        p_season: clock.season,
      })
      if (cancelled) return
      if (sponsorObjectiveError) {
        setSponsorObjectives([])
        return
      }
      setSponsorObjectives((data ?? []) as SponsorTournamentObjective[])
    }

    void loadSponsorObjectives()
    return () => { cancelled = true }
  }, [player?.id, clock.loading, clock.season])

  const sponsorObjectivesByCompetition = useMemo(() => {
    const grouped = new Map<string, SponsorTournamentObjective[]>()
    for (const objective of sponsorObjectives) {
      const current = grouped.get(objective.competition_id) ?? []
      current.push(objective)
      grouped.set(objective.competition_id, current)
    }
    return grouped
  }, [sponsorObjectives])

  useEffect(() => {
    if (loading || !restoreWeek) return
    const target = document.getElementById(`tournament-week-${restoreWeek}`)
    if (!target) return
    window.requestAnimationFrame(() => {
      target.scrollIntoView({ block: 'start', behavior: 'auto' })
      setRestoreWeek(null)
    })
  }, [loading, restoreWeek, events])

  const uniqueTournamentCount = useMemo(() => new Set(events.map((event) => event.tournament_id)).size, [events])

  function selectMonth(index: number) {
    const firstWeek = competitionWeeksForMonth(index)[0]
    setMonthIndex(index)
    setFocusedSeasonWeek(firstWeek?.seasonWeek ?? null)
    setRestoreWeek(firstWeek?.monthWeek ?? null)
    const params: Record<string, string> = { tab: 'tournament-calendar', month: String(index + 1) }
    if (firstWeek) params.week = String(firstWeek.monthWeek)
    setSearchParams(params, { replace: true })
  }

  function navigateWeek(direction: -1 | 1) {
    const fallback = monthCompetitionWeeks[0]?.seasonWeek ?? 1
    const targetSeasonWeek = Math.max(1, Math.min(52, (focusedSeasonWeek ?? fallback) + direction))
    const target = competitionWeekRange(targetSeasonWeek)
    setMonthIndex(target.displayMonthIndex)
    setFocusedSeasonWeek(target.seasonWeek)
    setRestoreWeek(target.monthWeek)
    setSearchParams({
      tab: 'tournament-calendar',
      month: String(target.displayMonthIndex + 1),
      week: String(target.monthWeek),
    }, { replace: true })
  }

  const weekNavigation = (label: string) => (
    <div className="tlg-tournament-week-nav" aria-label={label}>
      <button type="button" disabled={(focusedSeasonWeek ?? 1) <= 1} onClick={() => navigateWeek(-1)}><ChevronLeft size={14} /> Previous week</button>
      <strong>{focusedSeasonWeek ? `Season Week ${focusedSeasonWeek}` : month.name}</strong>
      <button type="button" disabled={(focusedSeasonWeek ?? 52) >= 52} onClick={() => navigateWeek(1)}>Next week <ChevronRight size={14} /></button>
    </div>
  )

  return (
    <div className="tlg-tournament-calendar">
      <div className="tlg-tournament-calendar-head">
        <div>
          <h4>Season {clock.season} Tournament Calendar</h4>
          <p>Competition weeks run Monday to Sunday. Opening this tab now focuses the active in-game week automatically; you can still browse any previous or future week.</p>
        </div>
        <span className="tlg-tournament-world-chip">{world} singles</span>
      </div>

      {weekNavigation('Tournament calendar week navigation top')}

      <div className="tlg-tournament-month-tabs" role="tablist" aria-label="Tournament calendar months">
        {MONTHS.map((item, index) => (
          <button key={item.name} type="button" role="tab" aria-selected={index === monthIndex} className={index === monthIndex ? 'tlg-tournament-month-tab tlg-tournament-month-tab-active' : 'tlg-tournament-month-tab'} onClick={() => selectMonth(index)}>{item.name}</button>
        ))}
      </div>

      <div className="tlg-tournament-month-summary">
        <div><span>{month.name}</span><strong>{loading ? 'Loading tournaments…' : `${uniqueTournamentCount} tournaments`}</strong></div>
        <p>{monthCompetitionWeeks.length} Monday–Sunday competition weeks are assigned to {month.name}. A cross-month week belongs to the month containing at least four of its seven days.</p>
      </div>

      {monthIndex === 0 && (
        <div className="tlg-tournament-month-summary">
          <div><span>Season opening</span><strong>January 1–2</strong></div>
          <p>No tournament week runs on these opening days. They are reserved for applications, travel, training and preparation before Week 1 begins Monday, January 3.</p>
        </div>
      )}

      {error && <div className="tlg-tournament-load-error">Unable to load the tournament calendar: {error}</div>}

      <div className="tlg-tournament-weeks">
        {monthCompetitionWeeks.map((weekInfo) => {
          const week = weekInfo.monthWeek
          const weekEvents = events.filter((event) => event.season_week === weekInfo.seasonWeek)
          const focused = focusedSeasonWeek === weekInfo.seasonWeek
          return (
            <section key={weekInfo.seasonWeek} id={`tournament-week-${week}`} className={`tlg-tournament-week${focused ? ' tlg-tournament-week-active' : ''}`}>
              <header className="tlg-tournament-week-head">
                <div><span>{month.name} · Season Week {weekInfo.seasonWeek}</span><h5>Week {week} · {formatCompetitionWeekRange(weekInfo.seasonWeek)}</h5></div>
                <strong>{loading ? '—' : `${weekEvents.length} calendar ${weekEvents.length === 1 ? 'entry' : 'entries'}`}</strong>
              </header>

              {loading ? (
                <div className="tlg-tournament-week-empty">Loading {month.name} Week {week}…</div>
              ) : weekEvents.length === 0 ? (
                <div className="tlg-tournament-week-empty">No {world} tournaments published for {month.name} Week {week} yet.</div>
              ) : (
                <div className="tlg-tournament-week-list">
                  <div className="tlg-tournament-row tlg-tournament-row-head" aria-hidden="true">
                    <span>Tournament</span><span>Location</span><span>Category</span><span>Surface</span><span>Draw / Points</span><span>Status</span>
                  </div>

                  {weekEvents.map((event) => {
                    const currentPhaseLabel = phaseLabel(event.phase)
                    const sponsorObjectiveList = sponsorObjectivesByCompetition.get(event.competition_id) ?? []
                    const sponsorObjectiveTitle = sponsorObjectiveList
                      .map((objective) => `${objective.requirement_label ?? 'Sponsor objective'} · ${Math.max(0, Number(objective.reward_amount) || 0).toLocaleString()}`)
                      .join(' | ')
                    const returnQuery = `tab=tournament-calendar&month=${monthIndex + 1}&week=${week}`
                    return (
                      <Link
                        key={event.schedule_slot_id}
                        to={`/game/tournaments/${event.competition_id}?fromMonth=${monthIndex + 1}&fromWeek=${week}`}
                        onClick={() => saveTournamentReturnPosition(monthIndex + 1, week)}
                        className="tlg-tournament-row tlg-tournament-row-link"
                        aria-label={`Open ${event.tournament_name}`}
                        state={{ tournamentCalendarReturn: `/game/calendar?${returnQuery}#tournament-week-${week}` }}
                      >
                        <div className="tlg-tournament-name-cell">
                          <strong>{event.tournament_name}</strong>
                          {currentPhaseLabel && <span className="tlg-tournament-phase-chip">{currentPhaseLabel}</span>}
                          {sponsorObjectiveList.length > 0 && (
                            <span
                              className="tlg-tournament-sponsor-objective-chip"
                              title={sponsorObjectiveTitle || 'Sponsor objective'}
                              aria-label={sponsorObjectiveTitle || 'Sponsor objective'}
                            >
                              <Star size={11} aria-hidden="true" />
                              Sponsor objective
                            </span>
                          )}
                        </div>
                        <div className="tlg-tournament-location-cell">
                          <CountryFlag countryCode={event.country_code} countryName={event.country_name} width={24} height={16} />
                          <div><strong>{event.city}</strong><small>{event.country_name}</small></div>
                        </div>
                        <div><span className="tlg-tournament-category-chip">{event.category_label}</span></div>
                        <div className="tlg-tournament-surface-cell"><strong>{titleCase(event.surface)}</strong><small>{titleCase(event.environment)}</small></div>
                        <div className="tlg-tournament-draw-cell"><strong>Main {event.main_draw_capacity}</strong><small>Qual. max {event.qualifying_capacity_max} · Winner {event.winner_points} pts</small></div>
                        <div className="tlg-tournament-status-cell">
                          <span className={`tlg-status-chip tournament ${event.tournament_status}`}>{event.tournament_status_label}</span>
                          <small>{tournamentTimingLabel(event)}</small>
                          <span className={`tlg-status-chip player ${event.user_status}`}>{event.user_status_label}</span>
                        </div>
                      </Link>
                    )
                  })}
                </div>
              )}
            </section>
          )
        })}
      </div>

      {weekNavigation('Tournament calendar week navigation bottom')}
    </div>
  )
}

export default function CalendarPage() {
  const [searchParams] = useSearchParams()
  const requestedMonth = parsePositiveInteger(searchParams.get('month'), 1, 12)
  const requestedWeek = parsePositiveInteger(searchParams.get('week'), 1, 5)
  const [savedReturn] = useState<TournamentReturnPosition | null>(() => consumeTournamentReturnPosition())
  const initialMonth = requestedMonth ?? savedReturn?.month
  const initialWeek = requestedWeek ?? (savedReturn && savedReturn.month === initialMonth ? savedReturn.week : undefined)
  const initialTabId = searchParams.get('tab') === 'tournament-calendar' || initialMonth ? 'tournament-calendar' : 'season-calendar'

  return (
    <TabbedModulePage
      title="Calendar"
      subtitle="Season calendar and tournament calendar"
      eyebrow="Competition planning"
      intro="Use the Calendar for the complete Tennis Legacy season timeline. Confirmed tournament match days, predicted progression days and travel are synchronized with the real draw and schedule."
      icon={<CalendarDays size={18} />}
      sideTitle="Player calendar synchronization"
      sideDescription="Only secured match days and actual travel block planning. Predicted tournament progression remains visible without unnecessarily locking free days."
      wide
      initialTabId={initialTabId}
      tabs={[
        { id: 'season-calendar', label: 'Calendar', content: <SeasonCalendarView /> },
        { id: 'tournament-calendar', label: 'Tournament Calendar', content: <TournamentCalendarView initialMonth={initialMonth} initialWeek={initialWeek} /> },
      ]}
    />
  )
}
