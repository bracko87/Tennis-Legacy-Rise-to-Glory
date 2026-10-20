// Pure, read-only analysis of recorded training. No writes or fictional forecasts.
export const OPTIMIZATION_SKILLS = [
  'serve', 'forehand', 'backhand', 'return_skill', 'volley', 'slice', 'drop_shot',
  'lob', 'smash', 'fitness', 'stamina', 'recovery', 'movement',
] as const

export type OptimizationSkill = typeof OPTIMIZATION_SKILLS[number]
export type SkillScores = Partial<Record<OptimizationSkill, number>> & { fatigue?: number }
export type OptimizationEvent = {
  source: 'regular' | 'camp'
  activity: string
  focus_attribute: string | null
  season: number
  game_week: number
  efficiency: number | null
  gains: Record<string, number>
}

export type FocusEvidence = {
  focus: OptimizationSkill
  count: number
  targetGain: number
  totalGain: number
  efficiency: number | null
}

const isSkill = (key: string | null): key is OptimizationSkill =>
  key !== null && (OPTIMIZATION_SKILLS as readonly string[]).includes(key)

const positive = (value: unknown) =>
  typeof value === 'number' && Number.isFinite(value) ? Math.max(0, value) : 0

const mean = (items: number[]) =>
  items.length ? items.reduce((sum, value) => sum + value, 0) / items.length : 0

const measured = (keys: readonly OptimizationSkill[], scores: SkillScores) => {
  const known = keys.filter(key => typeof scores[key] === 'number' && Number.isFinite(scores[key]))
  return known.length ? known : [...keys]
}

export function weakestSkill(scores: SkillScores): OptimizationSkill {
  return measured(OPTIMIZATION_SKILLS, scores).reduce((weakest, key) =>
    positive(scores[key]) < positive(scores[weakest]) ? key : weakest)
}

export function complementarySkill(goal: OptimizationSkill, scores: SkillScores): OptimizationSkill {
  const technical = OPTIMIZATION_SKILLS.slice(0, 9) as readonly OptimizationSkill[]
  const physical = OPTIMIZATION_SKILLS.slice(9) as readonly OptimizationSkill[]
  const opposite = technical.includes(goal) ? physical : technical
  return measured(opposite, scores).reduce((weakest, key) =>
    positive(scores[key]) < positive(scores[weakest]) ? key : weakest)
}

/** Each row is a descriptive cohort of regular sessions focusing on that attribute.
 * Camp days are excluded because they are not a comparable player-set plan.
 */
export function analyzeTrainingChoices(
  events: OptimizationEvent[],
  goal: OptimizationSkill,
): {
  cohorts: FocusEvidence[]
  goalFocusedCount: number
  compared: boolean
  recentTrend: { recent: number; previous: number } | null
  regularCount: number
} {
  const regular = events.filter(event =>
    event.source === 'regular' && isSkill(event.focus_attribute) &&
    (event.activity === 'technical' || event.activity === 'physical'))
  const cohorts = OPTIMIZATION_SKILLS.flatMap(focus => {
    const matching = regular.filter(event => event.focus_attribute === focus)
    if (!matching.length) return []
    const validEfficiency = matching
      .map(event => event.efficiency)
      .filter((n): n is number => typeof n === 'number' && Number.isFinite(n) && n >= 0)
    return [{
      focus,
      count: matching.length,
      targetGain: mean(matching.map(event => positive(event.gains?.[goal]))),
      totalGain: mean(matching.map(event =>
        Object.values(event.gains ?? {}).reduce((sum, n) => sum + positive(n), 0))),
      efficiency: validEfficiency.length ? mean(validEfficiency) : null,
    }]
  })
  cohorts.sort((a, b) =>
    Number(b.count >= 3) - Number(a.count >= 3) ||
    b.targetGain - a.targetGain || b.count - a.count || a.focus.localeCompare(b.focus))

  // Report events arrive latest-first. Trend needs two equal-sized samples
  // covering at least three distinct game weeks and does not assert causation.
  const sampled = regular.slice(0, 12)
  const distinctWeeks = new Set(sampled.map(row => `${row.season}:${row.game_week}`))
  const recentTrend = sampled.length === 12 && distinctWeeks.size >= 3
    ? {
      recent: mean(sampled.slice(0, 6).map(row => positive(row.gains?.[goal]))),
      previous: mean(sampled.slice(6).map(row => positive(row.gains?.[goal]))),
    }
    : null

  return {
    cohorts,
    goalFocusedCount: cohorts.find(row => row.focus === goal)?.count ?? 0,
    compared: cohorts.filter(row => row.count >= 3).length >= 2,
    recentTrend,
    regularCount: regular.length,
  }
}

/** Advice only; the calendar and game engine decide actual trainable days. */
export function suggestedFocusRotation(
  goal: OptimizationSkill,
  complementary: OptimizationSkill,
  sessions: number,
  mode: 'focused' | 'balanced',
): OptimizationSkill[] {
  const count = Math.min(4, Math.max(1, Math.floor(sessions)))
  return Array.from({ length: count }, (_, index) =>
    mode === 'focused' ? (index % 4 === 3 ? complementary : goal)
      : (index % 2 === 1 ? complementary : goal))
}
