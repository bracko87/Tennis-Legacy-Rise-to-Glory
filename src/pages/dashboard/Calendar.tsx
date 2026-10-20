import { CalendarDays, ChevronLeft, ChevronRight, Plane, Star } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link, useSearchParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import TournamentPlanningIntelligence from '../../components/premium/TournamentPlanningIntelligence'
import PremiumSeasonPlanning from '../../components/premium/PremiumSeasonPlanning'
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
  isSeasonOpeningDay,
  monthDayFromDayOfSeason,
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
  activity_type: 'travel' | 'tournament' | 'national_team' | 'training_camp' | 'injured' | 'home'
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

function phaseLabel(phase: TournamentCalendarRow['phase'], t: TFunction) {
  if (phase === 'qualification') return t('calendarPage.tournament.phaseQualification')
  if (phase === 'main_draw') return t('calendarPage.tournament.phaseMainDraw')
  return null
}

function playerActivityLabel(activity: PlayerCalendarActivityRow['activity_type'], t: TFunction) {
  return t(`calendarPage.activities.${activity}`)
}

function monthNames(t: TFunction) {
  return t('calendarPage.months', { returnObjects: true }) as string[]
}

function weekdayNames(t: TFunction) {
  return t('calendarPage.weekdays', { returnObjects: true }) as string[]
}

function localizedMonthDay(monthIndex: number, day: number, t: TFunction) {
  const months = monthNames(t)
  return `${months[monthIndex] ?? MONTHS[monthIndex]?.name ?? ''} ${day}`
}

function localizedAbsoluteGameDay(absoluteDay: number, season: number, t: TFunction) {
  const seasonStart = (season - 1) * 366
  const value = monthDayFromDayOfSeason(absoluteDay - seasonStart + 1)
  return localizedMonthDay(value.monthIndex, value.day, t)
}

function localizedCompetitionWeekRange(seasonWeek: number, t: TFunction) {
  const range = competitionWeekRange(seasonWeek)
  if (range.start.monthIndex === range.end.monthIndex) {
    return `${monthNames(t)[range.start.monthIndex]} ${range.start.day}–${range.end.day}`
  }
  return `${localizedMonthDay(range.start.monthIndex, range.start.day, t)} – ${localizedMonthDay(range.end.monthIndex, range.end.day, t)}`
}

function surfaceLabel(value: TournamentCalendarRow['surface'], t: TFunction) {
  return t(`calendarPage.tournament.surface${value.charAt(0).toUpperCase()}${value.slice(1)}`)
}

function environmentLabel(value: TournamentCalendarRow['environment'], t: TFunction) {
  return t(`calendarPage.tournament.${value}`)
}

function playerActivityPriority(activity: PlayerCalendarActivityRow) {
  if (activity.activity_type === 'injured') return 1
  if (activity.activity_type === 'national_team') return 2
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

function tournamentTimingLabel(event: TournamentCalendarRow, t: TFunction) {
  if (event.tournament_status === 'applications_not_open') return t('calendarPage.tournament.timingOpens', { date: localizedAbsoluteGameDay(event.application_open_day, event.season_number, t) })
  if (event.tournament_status === 'applications_open') return t('calendarPage.tournament.timingCloses', { date: localizedAbsoluteGameDay(event.application_close_day, event.season_number, t) })
  if (event.tournament_status === 'applications_closed' || event.tournament_status === 'draw_published') return t('calendarPage.tournament.timingStarts', { date: localizedAbsoluteGameDay(event.tournament_start_day, event.season_number, t) })
  if (event.tournament_status === 'in_progress') return t('calendarPage.tournament.timingEnds', { date: localizedAbsoluteGameDay(event.tournament_end_day, event.season_number, t) })
  if (event.tournament_status === 'completed') return t('calendarPage.tournament.timingFinished', { date: localizedAbsoluteGameDay(event.tournament_end_day, event.season_number, t) })
  return ''
}

function SeasonCalendarView() {
  const { t } = useTranslation()
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
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_calendar_commitments', filter: `player_id=eq.${player.id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'national_team_callups', filter: `player_id=eq.${player.id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_matches' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_doubles_teams' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_doubles_matches' }, refresh)
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
    const grouped = new Map<number, PlayerCalendarActivityRow[]>()
    for (const activity of activities) {
      const current = grouped.get(activity.day) ?? []
      current.push(activity)
      grouped.set(activity.day, current)
    }
    for (const rows of grouped.values()) {
      rows.sort((a, b) => playerActivityPriority(a) - playerActivityPriority(b) || (a.source ?? '').localeCompare(b.source ?? ''))
    }
    return grouped
  }, [activities])
  const rawTodayWeekday = weekdayForDate(clock.monthIndex, clock.day)
  const todayWeekday = weekdayNames(t)[WEEKDAYS.indexOf(rawTodayWeekday)] ?? rawTodayWeekday
  const localizedMonths = monthNames(t)
  const monthName = localizedMonths[monthIndex] ?? month.name
  const currentMonthName = localizedMonths[clock.monthIndex] ?? clock.month
  const todayAbsoluteDay = absoluteGameDay(clock.season, clock.monthIndex, clock.day)

  const monthNavigation = (label: string) => (
    <div className="tlg-season-calendar-nav" aria-label={label}>
      <button type="button" disabled={monthIndex === 0} onClick={() => setMonthIndex((value) => Math.max(0, value - 1))}><ChevronLeft size={14} /> {t('calendarPage.previous')}</button>
      <strong>{monthName}</strong>
      <button type="button" disabled={monthIndex === MONTHS.length - 1} onClick={() => setMonthIndex((value) => Math.min(MONTHS.length - 1, value + 1))}>{t('calendarPage.next')} <ChevronRight size={14} /></button>
    </div>
  )

  return (
    <div className="tlg-season-calendar">
      <div className="tlg-season-calendar-toolbar">
        <div className="tlg-season-calendar-copy">
          <h4>{t('calendarPage.seasonMonth', { season: clock.season, month: monthName })}</h4>
          <p>{t('calendarPage.todaySummary', { season: clock.season, weekday: todayWeekday, month: currentMonthName, day: clock.day })}</p>
        </div>
        {monthNavigation(t('calendarPage.calendarNav'))}
      </div>

      {activityError && <div className="tlg-calendar-player-activity-error">{t('calendarPage.scheduleLoadError', { error: activityError })}</div>}
      <div className="tlg-calendar-weekdays" aria-hidden="true">{weekdayNames(t).map((weekday) => <span key={weekday}>{weekday}</span>)}</div>
      <div className="tlg-calendar-grid">
        {cells.map((day, index) => {
          if (day === null) return <div key={`empty-${index}`} className="tlg-calendar-day-empty" aria-hidden="true" />
          const current = monthIndex === clock.monthIndex && day === clock.day
          const openingDay = isSeasonOpeningDay(monthIndex, day)
          const dayActivities = activityByDay.get(day) ?? []
          const primaryActivity = dayActivities[0] ?? null
          const primaryAbsoluteDay = primaryActivity
            ? absoluteGameDay(primaryActivity.season, primaryActivity.month - 1, primaryActivity.day)
            : null
          const primaryCompleted = primaryActivity?.activity_type === 'tournament'
            && (
              primaryActivity.source === 'tournament_completed'
              || primaryActivity.source === 'doubles_tournament_completed'
              || (primaryAbsoluteDay !== null && primaryAbsoluteDay < todayAbsoluteDay)
            )
          const primaryAccepted = primaryActivity?.activity_type === 'tournament'
            && (primaryActivity.source === 'tournament_accepted' || primaryActivity.source === 'doubles_tournament_accepted')
          const primaryPredicted = primaryActivity?.activity_type === 'tournament'
            && (primaryActivity.source === 'tournament_predicted' || primaryActivity.source === 'doubles_tournament_predicted')
          const primaryConfirmed = primaryActivity?.activity_type === 'tournament'
            && !primaryCompleted && !primaryAccepted && !primaryPredicted
          const primaryTournamentState = primaryCompleted
            ? 'completed'
            : primaryAccepted
              ? 'accepted'
              : primaryPredicted
                ? 'predicted'
                : primaryConfirmed
                  ? 'confirmed'
                  : ''
          const primaryNationalTeam = primaryActivity?.activity_type === 'national_team'
          const primaryNationalTeamState = primaryNationalTeam
            ? (primaryAbsoluteDay !== null && primaryAbsoluteDay < todayAbsoluteDay ? 'completed' : 'confirmed')
            : ''

          const classes = ['tlg-calendar-day']
          if (current) classes.push('tlg-calendar-day-current')
          if (primaryActivity) classes.push(`tlg-calendar-day-${primaryActivity.activity_type}`)
          if (primaryTournamentState) classes.push(`tlg-calendar-day-tournament-${primaryTournamentState}`)
          if (primaryNationalTeamState) classes.push(`tlg-calendar-day-national-team-${primaryNationalTeamState}`)

          return (
            <div key={`${month.name}-${day}`} className={classes.join(' ')}>
              <span className="tlg-calendar-day-number">{monthName} {day}</span>
              {current && <span className="tlg-calendar-today-badge">{t('calendarPage.today')}</span>}
              {openingDay && !current && <span className="tlg-calendar-today-badge">{t('calendarPage.seasonOpening')}</span>}
              {dayActivities.length > 0 && (
                <div className="tlg-calendar-player-activities">
                  {dayActivities.slice(0, 4).map((activity, activityIndex) => {
                    const activityAbsoluteDay = absoluteGameDay(activity.season, activity.month - 1, activity.day)
                    const isDoubles = activity.source?.startsWith('doubles_') ?? false
                    const tournamentCompleted = activity.activity_type === 'tournament'
                      && (
                        activity.source === 'tournament_completed'
                        || activity.source === 'doubles_tournament_completed'
                        || activityAbsoluteDay < todayAbsoluteDay
                      )
                    const tournamentAccepted = activity.activity_type === 'tournament'
                      && (activity.source === 'tournament_accepted' || activity.source === 'doubles_tournament_accepted')
                    const tournamentPredicted = activity.activity_type === 'tournament'
                      && (activity.source === 'tournament_predicted' || activity.source === 'doubles_tournament_predicted')
                    const tournamentConfirmed = activity.activity_type === 'tournament'
                      && !tournamentCompleted && !tournamentAccepted && !tournamentPredicted
                    const tournamentState = tournamentCompleted
                      ? 'completed'
                      : tournamentAccepted
                        ? 'accepted'
                        : tournamentPredicted
                          ? 'predicted'
                          : tournamentConfirmed
                            ? 'confirmed'
                            : ''
                    const nationalTeamCompleted = activity.activity_type === 'national_team'
                      && activityAbsoluteDay < todayAbsoluteDay
                    const nationalTeamState = activity.activity_type === 'national_team'
                      ? (nationalTeamCompleted ? 'completed' : 'confirmed')
                      : ''
                    const visualState = tournamentState || nationalTeamState

                    return (
                      <div
                        key={`${activity.source ?? activity.activity_type}-${activity.reference_id ?? activityIndex}-${activityIndex}`}
                        className={`tlg-calendar-player-activity ${activity.activity_type}${visualState ? ` ${visualState}` : ''}`}
                      >
                        {activity.activity_type === 'travel' && <Plane size={13} className="tlg-calendar-travel-icon" aria-hidden="true" />}
                        <span>{activity.activity_type === 'tournament'
                          ? t('calendarPage.activities.tournamentState', {
                              discipline: t(`calendarPage.activities.${isDoubles ? 'doublesShort' : 'singlesShort'}`),
                              state: t(`calendarPage.activities.${tournamentCompleted ? 'played' : tournamentAccepted ? 'accepted' : tournamentPredicted ? 'predicted' : 'confirmed'}`),
                            })
                          : activity.activity_type === 'national_team'
                            ? t('calendarPage.activities.nationalState', { state: t(`calendarPage.activities.${nationalTeamCompleted ? 'played' : 'confirmed'}`) })
                            : playerActivityLabel(activity.activity_type, t)}</span>
                        <strong>{activity.activity_type === 'national_team'
                          ? t('calendarPage.activities.national_team')
                          : activity.note || playerActivityLabel(activity.activity_type, t)}</strong>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          )
        })}
      </div>

      <div className="tlg-season-calendar-bottom-nav">
        {monthNavigation(t('calendarPage.calendarNavBottom'))}
      </div>

      <PremiumSeasonPlanning
        playerId={player?.id ?? null}
        season={clock.season}
        clockLoading={clock.loading}
      />
    </div>
  )
}

function TournamentCalendarView({ initialMonth, initialWeek }: { initialMonth?: number; initialWeek?: number }) {
  const { t } = useTranslation()
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
  const localizedMonths = monthNames(t)
  const monthName = localizedMonths[monthIndex] ?? month.name
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
      <button type="button" disabled={(focusedSeasonWeek ?? 1) <= 1} onClick={() => navigateWeek(-1)}><ChevronLeft size={14} /> {t('calendarPage.previousWeek')}</button>
      <strong>{focusedSeasonWeek ? t('calendarPage.seasonWeek', { week: focusedSeasonWeek }) : monthName}</strong>
      <button type="button" disabled={(focusedSeasonWeek ?? 52) >= 52} onClick={() => navigateWeek(1)}>{t('calendarPage.nextWeek')} <ChevronRight size={14} /></button>
    </div>
  )

  return (
    <div className="tlg-tournament-calendar">
      <div className="tlg-tournament-calendar-head">
        <div>
          <h4>{t('calendarPage.tournament.heading', { season: clock.season })}</h4>
          <p>{t('calendarPage.tournament.intro')}</p>
        </div>
        <span className="tlg-tournament-world-chip">{t('calendarPage.tournament.singles', { world })}</span>
      </div>

      {weekNavigation(t('calendarPage.tournament.weekNavTop'))}

      <div className="tlg-tournament-month-tabs" role="tablist" aria-label={t('calendarPage.tournament.monthsAria')}>
        {MONTHS.map((item, index) => (
          <button key={item.name} type="button" role="tab" aria-selected={index === monthIndex} className={index === monthIndex ? 'tlg-tournament-month-tab tlg-tournament-month-tab-active' : 'tlg-tournament-month-tab'} onClick={() => selectMonth(index)}>{localizedMonths[index] ?? item.name}</button>
        ))}
      </div>

      <div className="tlg-tournament-month-summary">
        <div><span>{monthName}</span><strong>{loading ? t('calendarPage.tournament.loadingTournaments') : t('calendarPage.tournament.tournamentCount', { count: uniqueTournamentCount })}</strong></div>
        <p>{t('calendarPage.tournament.monthSummary', { count: monthCompetitionWeeks.length, month: monthName })}</p>
      </div>

      <TournamentPlanningIntelligence
        playerId={player?.id ?? null}
        season={clock.season}
        month={monthIndex + 1}
        clockLoading={clock.loading}
      />

      {monthIndex === 0 && (
        <div className="tlg-tournament-month-summary">
          <div><span>{t('calendarPage.seasonOpening')}</span><strong>{t('calendarPage.tournament.openingDates')}</strong></div>
          <p>{t('calendarPage.tournament.openingBody')}</p>
        </div>
      )}

      {error && <div className="tlg-tournament-load-error">{t('calendarPage.tournament.loadError', { error })}</div>}

      <div className="tlg-tournament-weeks">
        {monthCompetitionWeeks.map((weekInfo) => {
          const week = weekInfo.monthWeek
          const weekEvents = events.filter((event) => event.season_week === weekInfo.seasonWeek)
          const focused = focusedSeasonWeek === weekInfo.seasonWeek
          return (
            <section key={weekInfo.seasonWeek} id={`tournament-week-${week}`} className={`tlg-tournament-week${focused ? ' tlg-tournament-week-active' : ''}`}>
              <header className="tlg-tournament-week-head">
                <div><span>{t('calendarPage.tournament.weekHeading', { month: monthName, week: weekInfo.seasonWeek })}</span><h5>{t('calendarPage.tournament.weekRange', { monthWeek: week, range: localizedCompetitionWeekRange(weekInfo.seasonWeek, t) })}</h5></div>
                <strong>{loading ? '—' : t('calendarPage.tournament.entries', { count: weekEvents.length })}</strong>
              </header>

              {loading ? (
                <div className="tlg-tournament-week-empty">{t('calendarPage.tournament.loadingWeek', { month: monthName, week })}</div>
              ) : weekEvents.length === 0 ? (
                <div className="tlg-tournament-week-empty">{t('calendarPage.tournament.noEvents', { world, month: monthName, week })}</div>
              ) : (
                <div className="tlg-tournament-week-list">
                  <div className="tlg-tournament-row tlg-tournament-row-head" aria-hidden="true">
                    <span>{t('calendarPage.tournament.columns.tournament')}</span><span>{t('calendarPage.tournament.columns.location')}</span><span>{t('calendarPage.tournament.columns.category')}</span><span>{t('calendarPage.tournament.columns.surface')}</span><span>{t('calendarPage.tournament.columns.drawPoints')}</span><span>{t('calendarPage.tournament.columns.status')}</span>
                  </div>

                  {weekEvents.map((event) => {
                    const currentPhaseLabel = phaseLabel(event.phase, t)
                    const sponsorObjectiveList = sponsorObjectivesByCompetition.get(event.competition_id) ?? []
                    const sponsorObjectiveTitle = sponsorObjectiveList
                      .map((objective) => `${objective.requirement_label ?? t('calendarPage.tournament.sponsorObjective')} · ${Math.max(0, Number(objective.reward_amount) || 0).toLocaleString()}`)
                      .join(' | ')
                    const returnQuery = `tab=tournament-calendar&month=${monthIndex + 1}&week=${week}`
                    return (
                      <Link
                        key={event.schedule_slot_id}
                        to={`/game/tournaments/${event.competition_id}?fromMonth=${monthIndex + 1}&fromWeek=${week}`}
                        onClick={() => saveTournamentReturnPosition(monthIndex + 1, week)}
                        className="tlg-tournament-row tlg-tournament-row-link"
                        aria-label={t('calendarPage.tournament.openAria', { name: event.tournament_name })}
                        state={{ tournamentCalendarReturn: `/game/calendar?${returnQuery}#tournament-week-${week}` }}
                      >
                        <div className="tlg-tournament-name-cell">
                          <strong>{event.tournament_name}</strong>
                          {currentPhaseLabel && <span className="tlg-tournament-phase-chip">{currentPhaseLabel}</span>}
                          {sponsorObjectiveList.length > 0 && (
                            <span
                              className="tlg-tournament-sponsor-objective-chip"
                              title={sponsorObjectiveTitle || 'Sponsor objective'}
                              aria-label={sponsorObjectiveTitle || t('calendarPage.tournament.sponsorObjective')}
                            >
                              <Star size={11} aria-hidden="true" />
                              {t('calendarPage.tournament.sponsorObjective')}
                            </span>
                          )}
                        </div>
                        <div className="tlg-tournament-location-cell">
                          <CountryFlag countryCode={event.country_code} countryName={event.country_name} width={24} height={16} />
                          <div><strong>{event.city}</strong><small>{event.country_name}</small></div>
                        </div>
                        <div><span className="tlg-tournament-category-chip">{event.category_label}</span></div>
                        <div className="tlg-tournament-surface-cell"><strong>{surfaceLabel(event.surface, t)}</strong><small>{environmentLabel(event.environment, t)}</small></div>
                        <div className="tlg-tournament-draw-cell"><strong>{t('calendarPage.tournament.mainDraw', { count: event.main_draw_capacity })}</strong><small>{t('calendarPage.tournament.qualifying', { count: event.qualifying_capacity_max, points: event.winner_points })}</small></div>
                        <div className="tlg-tournament-status-cell">
                          <span className={`tlg-status-chip tournament ${event.tournament_status}`}>{t(`calendarPage.tournament.status.${event.tournament_status}`, { defaultValue: event.tournament_status_label })}</span>
                          <small>{tournamentTimingLabel(event, t)}</small>
                          <span className={`tlg-status-chip player ${event.user_status}`}>{t(`calendarPage.tournament.userStatus.${event.user_status}`, { defaultValue: event.user_status_label })}</span>
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

      {weekNavigation(t('calendarPage.tournament.weekNavBottom'))}
    </div>
  )
}

export default function CalendarPage() {
  const { t } = useTranslation()
  const [searchParams] = useSearchParams()
  const requestedMonth = parsePositiveInteger(searchParams.get('month'), 1, 12)
  const requestedWeek = parsePositiveInteger(searchParams.get('week'), 1, 5)
  const [savedReturn] = useState<TournamentReturnPosition | null>(() => consumeTournamentReturnPosition())
  const initialMonth = requestedMonth ?? savedReturn?.month
  const initialWeek = requestedWeek ?? (savedReturn && savedReturn.month === initialMonth ? savedReturn.week : undefined)
  const initialTabId = searchParams.get('tab') === 'tournament-calendar' || initialMonth ? 'tournament-calendar' : 'season-calendar'

  return (
    <TabbedModulePage
      title={t('calendarPage.title')}
      subtitle={t('calendarPage.subtitle')}
      eyebrow={t('calendarPage.eyebrow')}
      intro={t('calendarPage.intro')}
      icon={<CalendarDays size={18} />}
      sideTitle={t('calendarPage.sideTitle')}
      sideDescription={t('calendarPage.sideDescription')}
      wide
      initialTabId={initialTabId}
      tabs={[
        { id: 'season-calendar', label: t('calendarPage.tabs.calendar'), content: <SeasonCalendarView /> },
        { id: 'tournament-calendar', label: t('calendarPage.tabs.tournamentCalendar'), content: <TournamentCalendarView initialMonth={initialMonth} initialWeek={initialWeek} /> },
      ]}
    />
  )
}
