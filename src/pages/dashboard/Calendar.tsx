import { CalendarDays, ChevronLeft, ChevronRight } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import TabbedModulePage from '../../components/game/TabbedModulePage'
import { useGameClock } from '../../hooks/useGameClock'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-calendar.css'

const MONTHS = [
  { name: 'January', days: 31 },
  { name: 'February', days: 29 },
  { name: 'March', days: 31 },
  { name: 'April', days: 30 },
  { name: 'May', days: 31 },
  { name: 'June', days: 30 },
  { name: 'July', days: 31 },
  { name: 'August', days: 31 },
  { name: 'September', days: 30 },
  { name: 'October', days: 31 },
  { name: 'November', days: 30 },
  { name: 'December', days: 31 },
] as const

const WEEKDAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'] as const
const TOURNAMENT_WEEKS = [1, 2, 3, 4] as const
const DAYS_PER_SEASON = 366
const SEASON_ONE_JANUARY_ONE_WEEKDAY = 5 // Saturday in a Monday-first calendar.

interface TournamentCalendarRow {
  competition_id: string
  tournament_id: string
  edition_id: string
  schedule_slot_id: string
  world: 'ATP' | 'WTA'
  season_number: number
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
}

function daysBeforeMonth(monthIndex: number) {
  return MONTHS.slice(0, monthIndex).reduce((total, month) => total + month.days, 0)
}

function firstWeekdayIndex(season: number, monthIndex: number) {
  const elapsedDays = (season - 1) * DAYS_PER_SEASON + daysBeforeMonth(monthIndex)
  return (SEASON_ONE_JANUARY_ONE_WEEKDAY + elapsedDays) % 7
}

function weekdayForDate(season: number, monthIndex: number, day: number) {
  return WEEKDAYS[(firstWeekdayIndex(season, monthIndex) + day - 1) % 7]
}

function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function phaseLabel(phase: TournamentCalendarRow['phase']) {
  if (phase === 'qualification') return 'Qualification'
  if (phase === 'main_draw') return 'Main draw'
  return null
}

function SeasonCalendarView() {
  const clock = useGameClock()
  const [monthIndex, setMonthIndex] = useState(0)

  useEffect(() => {
    if (!clock.loading) setMonthIndex(clock.monthIndex)
  }, [clock.loading, clock.monthIndex])

  const month = MONTHS[monthIndex]
  const leadingEmptyCells = firstWeekdayIndex(clock.season, monthIndex)

  const cells = useMemo(() => {
    const values: Array<number | null> = []
    for (let index = 0; index < leadingEmptyCells; index += 1) values.push(null)
    for (let day = 1; day <= month.days; day += 1) values.push(day)
    while (values.length % 7 !== 0) values.push(null)
    return values
  }, [leadingEmptyCells, month.days])

  const todayWeekday = weekdayForDate(clock.season, clock.monthIndex, clock.day)

  return (
    <div className="tlg-season-calendar">
      <div className="tlg-season-calendar-toolbar">
        <div className="tlg-season-calendar-copy">
          <h4>Season {clock.season} · {month.name}</h4>
          <p>
            Today: Season {clock.season} · {todayWeekday} · {clock.month} {clock.day}. Every Tennis Legacy season uses the same fixed month lengths.
          </p>
        </div>

        <div className="tlg-season-calendar-nav" aria-label="Calendar month navigation">
          <button
            type="button"
            disabled={monthIndex === 0}
            onClick={() => setMonthIndex((value) => Math.max(0, value - 1))}
          >
            <ChevronLeft size={14} /> Previous
          </button>
          <strong>{month.name}</strong>
          <button
            type="button"
            disabled={monthIndex === MONTHS.length - 1}
            onClick={() => setMonthIndex((value) => Math.min(MONTHS.length - 1, value + 1))}
          >
            Next <ChevronRight size={14} />
          </button>
        </div>
      </div>

      <div className="tlg-calendar-weekdays" aria-hidden="true">
        {WEEKDAYS.map((weekday) => <span key={weekday}>{weekday}</span>)}
      </div>

      <div className="tlg-calendar-grid">
        {cells.map((day, index) => {
          if (day === null) {
            return <div key={`empty-${index}`} className="tlg-calendar-day-empty" aria-hidden="true" />
          }

          const current = monthIndex === clock.monthIndex && day === clock.day

          return (
            <div
              key={`${month.name}-${day}`}
              className={current ? 'tlg-calendar-day tlg-calendar-day-current' : 'tlg-calendar-day'}
            >
              <span className="tlg-calendar-day-number">{month.name} {day}</span>
              {current && <span className="tlg-calendar-today-badge">Today</span>}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function TournamentCalendarView() {
  const { player } = useAuth()
  const clock = useGameClock()
  const [monthIndex, setMonthIndex] = useState(0)
  const [events, setEvents] = useState<TournamentCalendarRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!clock.loading) setMonthIndex(clock.monthIndex)
  }, [clock.loading, clock.monthIndex])

  const month = MONTHS[monthIndex]
  const world = player?.world ?? 'ATP'

  useEffect(() => {
    if (clock.loading) return

    let cancelled = false

    async function loadTournamentCalendar() {
      setLoading(true)
      setError(null)

      const { data, error: calendarError } = await supabase.rpc('get_tournament_calendar_v1', {
        p_season_number: clock.season,
        p_calendar_month: monthIndex + 1,
        p_world: world,
      })

      if (cancelled) return

      if (calendarError) {
        setEvents([])
        setError(calendarError.message)
        setLoading(false)
        return
      }

      setEvents((data ?? []) as TournamentCalendarRow[])
      setLoading(false)
    }

    void loadTournamentCalendar()

    return () => {
      cancelled = true
    }
  }, [clock.loading, clock.season, monthIndex, world])

  const uniqueTournamentCount = useMemo(
    () => new Set(events.map((event) => event.tournament_id)).size,
    [events],
  )

  return (
    <div className="tlg-tournament-calendar">
      <div className="tlg-tournament-calendar-head">
        <div>
          <h4>Season {clock.season} Tournament Calendar</h4>
          <p>
            ATP and WTA use the same tournament locations, weeks, categories and surfaces. You only see the separate {world} competition belonging to your player.
          </p>
        </div>
        <span className="tlg-tournament-world-chip">{world} singles</span>
      </div>

      <div className="tlg-tournament-month-tabs" role="tablist" aria-label="Tournament calendar months">
        {MONTHS.map((item, index) => (
          <button
            key={item.name}
            type="button"
            role="tab"
            aria-selected={index === monthIndex}
            className={index === monthIndex ? 'tlg-tournament-month-tab tlg-tournament-month-tab-active' : 'tlg-tournament-month-tab'}
            onClick={() => setMonthIndex(index)}
          >
            {item.name}
          </button>
        ))}
      </div>

      <div className="tlg-tournament-month-summary">
        <div>
          <span>{month.name}</span>
          <strong>{loading ? 'Loading tournaments…' : `${uniqueTournamentCount} tournaments`}</strong>
        </div>
        <p>Competition weeks are fixed to Week 1–4. A tournament remains assigned to its starting month even if its competition window later crosses into the next month.</p>
      </div>

      {error && (
        <div className="tlg-tournament-load-error">
          Unable to load the tournament calendar: {error}
        </div>
      )}

      <div className="tlg-tournament-weeks">
        {TOURNAMENT_WEEKS.map((week) => {
          const weekEvents = events.filter((event) => event.month_week === week)

          return (
            <section key={week} className="tlg-tournament-week">
              <header className="tlg-tournament-week-head">
                <div>
                  <span>{month.name}</span>
                  <h5>Week {week}</h5>
                </div>
                <strong>{loading ? '—' : `${weekEvents.length} calendar ${weekEvents.length === 1 ? 'entry' : 'entries'}`}</strong>
              </header>

              {loading ? (
                <div className="tlg-tournament-week-empty">Loading {month.name} Week {week}…</div>
              ) : weekEvents.length === 0 ? (
                <div className="tlg-tournament-week-empty">No {world} tournaments published for {month.name} Week {week} yet.</div>
              ) : (
                <div className="tlg-tournament-week-list">
                  <div className="tlg-tournament-row tlg-tournament-row-head" aria-hidden="true">
                    <span>Tournament</span>
                    <span>Location</span>
                    <span>Category</span>
                    <span>Surface</span>
                    <span>Draw / Points</span>
                  </div>

                  {weekEvents.map((event) => {
                    const currentPhaseLabel = phaseLabel(event.phase)

                    return (
                      <Link
                        key={event.schedule_slot_id}
                        to={`/game/tournaments/${event.competition_id}`}
                        className="tlg-tournament-row tlg-tournament-row-link"
                        aria-label={`Open ${event.tournament_name}`}
                      >
                        <div className="tlg-tournament-name-cell">
                          <strong>{event.tournament_name}</strong>
                          {currentPhaseLabel && <span className="tlg-tournament-phase-chip">{currentPhaseLabel}</span>}
                        </div>

                        <div className="tlg-tournament-location-cell">
                          <CountryFlag
                            countryCode={event.country_code}
                            countryName={event.country_name}
                            width={24}
                            height={16}
                          />
                          <div>
                            <strong>{event.city}</strong>
                            <small>{event.country_name}</small>
                          </div>
                        </div>

                        <div>
                          <span className="tlg-tournament-category-chip">{event.category_label}</span>
                        </div>

                        <div className="tlg-tournament-surface-cell">
                          <strong>{titleCase(event.surface)}</strong>
                          <small>{titleCase(event.environment)}</small>
                        </div>

                        <div className="tlg-tournament-draw-cell">
                          <strong>Main {event.main_draw_capacity}</strong>
                          <small>Qual. max {event.qualifying_capacity_max} · Winner {event.winner_points} pts</small>
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
    </div>
  )
}

export default function CalendarPage() {
  return (
    <TabbedModulePage
      title="Calendar"
      subtitle="Season calendar and tournament calendar"
      eyebrow="Competition planning"
      intro="Use the Calendar for the complete Tennis Legacy season timeline. Tournament Calendar shows the shared world schedule while keeping ATP and WTA entries, draws, matches, results and rankings completely separate."
      icon={<CalendarDays size={18} />}
      sideTitle="Calendar engine pending"
      sideDescription="Calendar views use the global Tennis Legacy game clock and fixed 366-day season structure. Tournament data is server-backed and separated into ATP and WTA competitions."
      wide
      tabs={[
        {
          id: 'season-calendar',
          label: 'Calendar',
          content: <SeasonCalendarView />,
        },
        {
          id: 'tournament-calendar',
          label: 'Tournament Calendar',
          content: <TournamentCalendarView />,
        },
      ]}
    />
  )
}
