export const MONTHS = [
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

export const WEEKDAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'] as const
export const DAYS_PER_SEASON = 366
export const SEASON_OPENING_DAYS = 2
export const COMPETITION_WEEKS_PER_SEASON = 52

const JANUARY_ONE_WEEKDAY_INDEX = 5 // Saturday in a Monday-first calendar.

export interface MonthDay {
  monthIndex: number
  day: number
}

export interface CompetitionWeekRange {
  seasonWeek: number
  start: MonthDay
  end: MonthDay
  displayMonthIndex: number
  monthWeek: number
}

export function daysBeforeMonth(monthIndex: number) {
  return MONTHS.slice(0, monthIndex).reduce((total, month) => total + month.days, 0)
}

export function dayOfSeason(monthIndex: number, day: number) {
  return daysBeforeMonth(monthIndex) + day
}

export function monthDayFromDayOfSeason(dayOfSeasonValue: number): MonthDay {
  let remaining = Math.max(1, Math.min(DAYS_PER_SEASON, dayOfSeasonValue))
  let monthIndex = 0

  while (monthIndex < MONTHS.length - 1 && remaining > MONTHS[monthIndex].days) {
    remaining -= MONTHS[monthIndex].days
    monthIndex += 1
  }

  return { monthIndex, day: remaining }
}

export function competitionWeekStartDayOfSeason(seasonWeek: number) {
  return SEASON_OPENING_DAYS + 1 + (seasonWeek - 1) * 7
}

export function competitionWeekRange(seasonWeek: number): CompetitionWeekRange {
  const safeWeek = Math.max(1, Math.min(COMPETITION_WEEKS_PER_SEASON, seasonWeek))
  const startDay = competitionWeekStartDayOfSeason(safeWeek)
  const start = monthDayFromDayOfSeason(startDay)
  const end = monthDayFromDayOfSeason(startDay + 6)
  const thursday = monthDayFromDayOfSeason(startDay + 3)
  const displayMonthIndex = thursday.monthIndex

  let monthWeek = 0
  for (let week = 1; week <= safeWeek; week += 1) {
    const candidateThursday = monthDayFromDayOfSeason(competitionWeekStartDayOfSeason(week) + 3)
    if (candidateThursday.monthIndex === displayMonthIndex) monthWeek += 1
  }

  return {
    seasonWeek: safeWeek,
    start,
    end,
    displayMonthIndex,
    monthWeek,
  }
}

export function competitionWeeksForMonth(monthIndex: number) {
  const result: CompetitionWeekRange[] = []

  for (let seasonWeek = 1; seasonWeek <= COMPETITION_WEEKS_PER_SEASON; seasonWeek += 1) {
    const range = competitionWeekRange(seasonWeek)
    if (range.displayMonthIndex === monthIndex) result.push(range)
  }

  return result
}

export function formatMonthDay(value: MonthDay) {
  return `${MONTHS[value.monthIndex].name} ${value.day}`
}

export function formatCompetitionWeekRange(seasonWeek: number) {
  const range = competitionWeekRange(seasonWeek)
  if (range.start.monthIndex === range.end.monthIndex) {
    return `${MONTHS[range.start.monthIndex].name} ${range.start.day}–${range.end.day}`
  }
  return `${formatMonthDay(range.start)} – ${formatMonthDay(range.end)}`
}

export function formatCompetitionWeekDay(seasonWeek: number, competitionDay: number) {
  const dayValue = competitionWeekStartDayOfSeason(seasonWeek) + competitionDay - 1
  return formatMonthDay(monthDayFromDayOfSeason(dayValue))
}

export function firstWeekdayIndex(monthIndex: number) {
  return (JANUARY_ONE_WEEKDAY_INDEX + daysBeforeMonth(monthIndex)) % 7
}

export function weekdayForDate(monthIndex: number, day: number) {
  return WEEKDAYS[(firstWeekdayIndex(monthIndex) + day - 1) % 7]
}

export function absoluteGameDay(season: number, monthIndex: number, day: number) {
  return (season - 1) * DAYS_PER_SEASON + daysBeforeMonth(monthIndex) + day - 1
}

export function competitionWeekAbsoluteStart(season: number, seasonWeek: number) {
  return (season - 1) * DAYS_PER_SEASON + competitionWeekStartDayOfSeason(seasonWeek) - 1
}

export function isSeasonOpeningDay(monthIndex: number, day: number) {
  return monthIndex === 0 && day <= SEASON_OPENING_DAYS
}
