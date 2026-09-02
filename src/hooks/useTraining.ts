import { useCallback, useEffect, useState } from 'react'

import { supabase } from '../lib/supabase'

export type TrainingType = 'technical' | 'physical' | 'day_off'
export type TrainingIntensity = 'light' | 'standard' | 'hard'
export type DailyActivityType = 'home' | 'travel' | 'tournament' | 'training_camp' | 'injured'

export interface TrainingPlan {
  training_type: TrainingType
  focus_attribute: string | null
  intensity: TrainingIntensity
  focus_share: number
  is_active: boolean
  updated_at?: string
}

export interface TrainingSkills {
  serve: number
  forehand: number
  backhand: number
  return_skill: number
  volley: number
  slice: number
  drop_shot: number
  lob: number
  smash: number
  fitness: number
  stamina: number
  recovery: number
  movement: number
  fatigue: number
  sharpness: number
  morale: number
  confidence: number
  focus: number
}

export interface TrainingProgress {
  serve: number
  forehand: number
  backhand: number
  return_skill: number
  volley: number
  slice: number
  drop_shot: number
  lob: number
  smash: number
  fitness: number
  stamina: number
  recovery: number
  movement: number
}

export interface TrainingSession {
  id: string
  season?: number
  month?: number
  day?: number
  training_type: TrainingType
  focus_attribute: string | null
  intensity: TrainingIntensity
  efficiency: number
  development_gains?: Record<string, number>
  level_ups: Record<string, number>
  fatigue_before: number
  fatigue_after: number
  sharpness_before: number
  sharpness_after: number
  morale_before?: number
  morale_after?: number
  focus_before?: number
  focus_after?: number
  processed_by?: 'manual' | 'daily_engine'
  created_at: string
}

export interface TrainingDashboard {
  game_day: {
    season: number
    month: number
    day: number
  }
  activity_type: DailyActivityType
  eligible: boolean
  block_reason: string | null
  plan: TrainingPlan
  skills: TrainingSkills
  progress: TrainingProgress
  today_session: TrainingSession | null
  recent_sessions: TrainingSession[]
  rules: {
    focus_share: number
    other_share: number
    travel_fatigue_only: boolean
    travel_fatigue_cost?: number
    regular_training_states: string[]
    blocked_states: string[]
    automatic_scheduler_enabled: boolean
  }
}

interface TrainingActionResult {
  status: 'completed' | 'blocked' | 'already_processed' | string
  reason?: string
  session_id?: string
  training_type?: TrainingType
  focus_attribute?: string | null
  intensity?: TrainingIntensity
  efficiency?: number
  development_gains?: Record<string, number>
  level_ups?: Record<string, number>
}

export function useTraining() {
  const [dashboard, setDashboard] = useState<TrainingDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc('get_training_dashboard_v1')

    if (rpcError) {
      setDashboard(null)
      setError(rpcError.message)
      setLoading(false)
      return null
    }

    const next = data as TrainingDashboard
    setDashboard(next)
    setLoading(false)
    return next
  }, [])

  const savePlan = useCallback(async (
    trainingType: TrainingType,
    focusAttribute: string | null,
    intensity: TrainingIntensity,
  ) => {
    setSaving(true)
    setError(null)

    const { error: rpcError } = await supabase.rpc('set_regular_training_plan_v1', {
      p_training_type: trainingType,
      p_focus_attribute: focusAttribute,
      p_intensity: intensity,
    })

    if (rpcError) {
      setError(rpcError.message)
      setSaving(false)
      return false
    }

    await refresh()
    setSaving(false)
    return true
  }, [refresh])

  const completeToday = useCallback(async () => {
    setProcessing(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc('complete_regular_training_today_v1')

    if (rpcError) {
      setError(rpcError.message)
      setProcessing(false)
      return null
    }

    const result = data as TrainingActionResult
    await refresh()
    setProcessing(false)
    return result
  }, [refresh])

  useEffect(() => {
    void refresh()
  }, [refresh])

  return {
    dashboard,
    loading,
    saving,
    processing,
    error,
    refresh,
    savePlan,
    completeToday,
  }
}
