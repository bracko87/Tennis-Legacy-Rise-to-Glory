export interface TournamentTactic {
  preset: string
  approach: string
  rally: string
  serve: string
  returnGame: string
  courtPosition: string
  target: string
  risk: string
}

export const TACTIC_OPTIONS = {
  approach: ['Defensive', 'Balanced', 'Aggressive'],
  rally: ['Shorten points', 'Balanced rallies', 'Extend rallies'],
  serve: ['Safe first serve', 'Balanced', 'Power serving', 'Serve + 1'],
  returnGame: ['Safe return', 'Balanced', 'Aggressive return', 'Attack second serve'],
  courtPosition: ['Deep baseline', 'Normal baseline', 'Inside baseline', 'Net attack'],
  target: ['Automatic', 'Backhand', 'Forehand', 'Movement', 'Stamina', 'Second serve'],
  risk: ['Safe', 'Balanced', 'Aggressive'],
} as const

export const TACTIC_PRESETS = ['Balanced', 'Attack', 'Counterpunch', 'Serve + 1', 'Defensive / Grind', 'Net Attack'] as const

export const BALANCED_TACTIC: TournamentTactic = {
  preset: 'Balanced',
  approach: 'Balanced',
  rally: 'Balanced rallies',
  serve: 'Balanced',
  returnGame: 'Balanced',
  courtPosition: 'Normal baseline',
  target: 'Automatic',
  risk: 'Balanced',
}

export function tacticFromPreset(preset: string): TournamentTactic {
  if (preset === 'Attack') {
    return { preset, approach: 'Aggressive', rally: 'Shorten points', serve: 'Serve + 1', returnGame: 'Aggressive return', courtPosition: 'Inside baseline', target: 'Automatic', risk: 'Aggressive' }
  }
  if (preset === 'Counterpunch') {
    return { preset, approach: 'Defensive', rally: 'Extend rallies', serve: 'Safe first serve', returnGame: 'Balanced', courtPosition: 'Deep baseline', target: 'Automatic', risk: 'Safe' }
  }
  if (preset === 'Serve + 1') {
    return { preset, approach: 'Aggressive', rally: 'Shorten points', serve: 'Serve + 1', returnGame: 'Attack second serve', courtPosition: 'Inside baseline', target: 'Automatic', risk: 'Aggressive' }
  }
  if (preset === 'Defensive / Grind') {
    return { preset, approach: 'Defensive', rally: 'Extend rallies', serve: 'Safe first serve', returnGame: 'Safe return', courtPosition: 'Deep baseline', target: 'Stamina', risk: 'Safe' }
  }
  if (preset === 'Net Attack') {
    return { preset, approach: 'Aggressive', rally: 'Shorten points', serve: 'Power serving', returnGame: 'Aggressive return', courtPosition: 'Net attack', target: 'Automatic', risk: 'Aggressive' }
  }
  return { ...BALANCED_TACTIC }
}
