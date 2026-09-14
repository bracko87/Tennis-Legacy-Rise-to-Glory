import { useCallback, useEffect, useRef, useState } from 'react'

import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'

export type TrainingType = 'technical' | 'physical' | 'day_off'
export type TrainingIntensity = 'light' | 'standard' | 'hard'
export type DailyActivityType = 'home' | 'travel' | 'tournament' | 'training_camp' | 'injured'
export type TrainingSessionRole = 'planned_training' | 'active_recovery' | 'full_rest' | 'user_day_off'

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

export interface TrainingStaffEffects {
  technical_training_multiplier: number
  technical_camp_multiplier: number
  physical_training_multiplier: number
  physical_camp_multiplier: number
  training_fatigue_reduction: number
  active_recovery_multiplier: number
  recovery_multiplier: number
  morale_recovery_bonus_points: number
  confidence_recovery_bonus_points: number
  focus_recovery_bonus_points: number
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
  session_role?: TrainingSessionRole
  staff_effects_snapshot?: TrainingStaffEffects
  created_at: string
}

export interface TrainingDashboard {
  game_day: {
    season: number
    month: number
    day: number
    season_week?: number
    weekday_in_training_week?: number
    scheduled_role?: Exclude<TrainingSessionRole, 'user_day_off'>
  }
  activity_type: DailyActivityType
  eligible: boolean
  block_reason: string | null
  plan: TrainingPlan
  skills: TrainingSkills
  progress: TrainingProgress
  staff_effects: TrainingStaffEffects
  today_session: TrainingSession | null
  recent_sessions: TrainingSession[]
  rules: {
    focus_share: number
    other_share: number
    travel_fatigue_only: boolean
    regular_training_states: string[]
    blocked_states: string[]
    automatic_scheduler_enabled: boolean
    staff_effects_visible?: boolean
    weekly_rhythm?: {
      development_days: number
      active_recovery_days: number
      full_rest_days: number
    }
    camp_weekly_rhythm?: {
      development_days: number
      recovery_days: number
    }
    attribute_development_multiplier?: Record<string, number>
    age_modifier_used?: boolean
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
  session_role?: TrainingSessionRole
}

export function useTraining() {
  const { player } = useAuth()
  const [dashboard, setDashboard] = useState<TrainingDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const realtimeRefreshTimer = useRef<number | null>(null)

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
    if (!player?.id) {
      setDashboard(null)
      setLoading(false)
      return
    }

    void refresh()
  }, [player?.id, refresh])

  useEffect(() => {
    if (!player?.id) return

    const scheduleRefresh = () => {
      if (realtimeRefreshTimer.current !== null) {
        window.clearTimeout(realtimeRefreshTimer.current)
      }
      realtimeRefreshTimer.current = window.setTimeout(() => {
        realtimeRefreshTimer.current = null
        void refresh()
      }, 150)
    }

    const channel = supabase
      .channel(`training-account-sync:${player.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_training_plans', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_training_progress', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_training_sessions', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_daily_activity', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_skills', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .subscribe()

    return () => {
      if (realtimeRefreshTimer.current !== null) {
        window.clearTimeout(realtimeRefreshTimer.current)
        realtimeRefreshTimer.current = null
      }
      void supabase.removeChannel(channel)
    }
  }, [player?.id, refresh])

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
