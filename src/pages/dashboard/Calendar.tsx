import { CalendarDays, ChevronLeft, ChevronRight } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import TabbedModulePage from '../../components/game/TabbedModulePage'
import { useGameClock } from '../../hooks/useGameClock'

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
const DAYS_PER_SEASON = 366
const SEASON_ONE_JANUARY_ONE_WEEKDAY = 5 // Saturday in a Monday-first calendar.

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

  useEffect(() => {
    if (!clock.loading) setMonthIndex(clock.monthIndex)
  }, [clock.loading, clock.monthIndex])

  const month = MONTHS[monthIndex]
  const world = player?.world ?? 'ATP'

  return (
    <div className="tlg-tournament-calendar">
      <div className="tlg-tournament-calendar-head">
        <div>
          <h4>Season {clock.season} Tournament Calendar</h4>
          <p>
            Browse official {world} singles tournaments month by month. ATP and WTA tournament schedules remain completely separate.
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

      <div className="tlg-tournament-list">
        <div className="tlg-tournament-empty">
          <strong>No {world} tournaments published for {month.name} yet.</strong>
          <p>
            When the tournament database is populated, every event scheduled in {month.name} will appear here as a linked tournament row with dates, location, surface, category and entry status.
          </p>
        </div>
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
      intro="Use the Calendar for the complete Tennis Legacy season timeline. Tournament Calendar focuses only on official singles events belonging to your ATP or WTA world."
      icon={<CalendarDays size={18} />}
      sideTitle="Calendar engine pending"
      sideDescription="Calendar views use the global Tennis Legacy game clock and the fixed 366-day season structure. Tournament rows will be populated only from official server-backed event data."
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
