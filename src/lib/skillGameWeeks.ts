import type { TFunction } from 'react-i18next'

// All Skills charts use recorded in-game season/week data, never wall-clock
// recorded_at for display or inferred game dates. Unknown historic weeks are
// intentionally omitted from the weekly series (not silently backdated).
export type GameWeekSnapshot = {
  recorded_at: string
  game_season?: number | null
  game_week?: number | null
}

export function weeklySkillSnapshots<T extends GameWeekSnapshot>(history: T[]): T[] {
  const weeks = new Map<string, T>()
  // The caller's history is chronologically ordered; if multiple state changes
  // occur in a game week, keep the LAST recorded state for that week.
  for (const row of history) {
    if (!Number.isInteger(row.game_season) || !Number.isInteger(row.game_week)) continue
    const season = row.game_season as number
    const week = row.game_week as number
    if (season < 1 || week < 0 || week > 52) continue
    weeks.set(`${season}:${week}`, row)
  }
  return [...weeks.values()].sort((a,b)=>
    (a.game_season as number)-(b.game_season as number) ||
    (a.game_week as number)-(b.game_week as number)
  )
}

export function gameWeekText(
  row: GameWeekSnapshot,
  translate: TFunction,
): string {
  if (!Number.isInteger(row.game_season) || !Number.isInteger(row.game_week)) return '—'
  return `${translate('statisticsPage.season',{season:row.game_season as number})} · ${translate('overviewPage.week',{week:row.game_week as number})}`
}
