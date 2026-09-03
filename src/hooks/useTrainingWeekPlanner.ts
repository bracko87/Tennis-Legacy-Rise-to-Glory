import { useCallback, useEffect, useRef, useState } from 'react'

import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'
import type { DailyActivityType, TrainingIntensity, TrainingSessionRole, TrainingType } from './useTraining'

export interface TrainingWeekDay {
  absolute_day: number
  weekday: number
  weekday_name: string
  season: number
  season_week: number
  month: number
  day: number
  activity_type: DailyActivityType
  activity_source: string | null
  activity_note: string | null
  activity_reference_id: string | null
  editable: boolean
  lock_reason: string | null
  plan_source: 'weekly_plan' | 'automatic_recovery' | 'default_plan' | 'processed_session'
  training_type: TrainingType
  focus_attribute: string | null
  intensity: TrainingIntensity
  session_role: TrainingSessionRole
  processed: boolean
  session_id: string | null
}

export interface TrainingWeekPlanner {
  season: number
  season_week: number
  week_offset: number
  week_start_absolute_day: number
  week_end_absolute_day: number
  current_absolute_day: number
  days: TrainingWeekDay[]
  rules: {
    editable_activity: 'home'
    calendar_override_states: DailyActivityType[]
    daily_plan_overrides_default_rhythm: boolean
    automatic_daily_processor_compatible: boolean
  }
}

export interface TrainingDaySaveDraft {
  absolute_day: number
  training_type: TrainingType
  focus_attribute: string | null
  intensity: TrainingIntensity
}

export function useTrainingWeekPlanner() {
  const { player } = useAuth()
  const [currentWeek, setCurrentWeek] = useState<TrainingWeekPlanner | null>(null)
  const [nextWeek, setNextWeek] = useState<TrainingWeekPlanner | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const refreshTimer = useRef<number | null>(null)

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    const [current, next] = await Promise.all([
      supabase.rpc('get_training_week_planner_v1', { p_week_offset: 0 }),
      supabase.rpc('get_training_week_planner_v1', { p_week_offset: 1 }),
    ])

    const rpcError = current.error ?? next.error
    if (rpcError) {
      setError(rpcError.message)
      setLoading(false)
      return false
    }

    setCurrentWeek(current.data as TrainingWeekPlanner)
    setNextWeek(next.data as TrainingWeekPlanner)
    setLoading(false)
    return true
  }, [])

  const saveDay = useCallback(async (
    absoluteDay: number,
    trainingType: TrainingType,
    focusAttribute: string | null,
    intensity: TrainingIntensity,
  ) => {
    setSaving(true)
    setError(null)
    const { error: rpcError } = await supabase.rpc('set_training_week_day_v1', {
      p_absolute_day: absoluteDay,
      p_training_type: trainingType,
      p_focus_attribute: trainingType === 'day_off' ? null : focusAttribute,
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

  const saveDays = useCallback(async (changes: TrainingDaySaveDraft[]) => {
    if (changes.length === 0) return { status: 'saved', saved_days: 0 }
    setSaving(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('set_training_week_days_v1', {
      p_days: changes.map((change) => ({
        absolute_day: change.absolute_day,
        training_type: change.training_type,
        focus_attribute: change.training_type === 'day_off' ? null : change.focus_attribute,
        intensity: change.intensity,
      })),
    })
    if (rpcError) {
      setError(rpcError.message)
      setSaving(false)
      return null
    }
    await refresh()
    setSaving(false)
    return data as { status: string; saved_days: number }
  }, [refresh])

  const applyWeek = useCallback(async (
    weekStartAbsoluteDay: number,
    trainingType: TrainingType,
    focusAttribute: string | null,
    intensity: TrainingIntensity,
  ) => {
    setSaving(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('set_training_week_plan_v1', {
      p_week_start_absolute_day: weekStartAbsoluteDay,
      p_training_type: trainingType,
      p_focus_attribute: trainingType === 'day_off' ? null : focusAttribute,
      p_intensity: intensity,
    })
    if (rpcError) {
      setError(rpcError.message)
      setSaving(false)
      return null
    }
    await refresh()
    setSaving(false)
    return data as { status: string; applied_days: number; skipped_days: number }
  }, [refresh])

  useEffect(() => {
    if (!player?.id) {
      setCurrentWeek(null)
      setNextWeek(null)
      setLoading(false)
      return
    }
    void refresh()
  }, [player?.id, refresh])

  useEffect(() => {
    if (!player?.id) return
    const scheduleRefresh = () => {
      if (refreshTimer.current !== null) window.clearTimeout(refreshTimer.current)
      refreshTimer.current = window.setTimeout(() => {
        refreshTimer.current = null
        void refresh()
      }, 120)
    }

    const channel = supabase
      .channel(`training-week-planner:${player.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_weekly_training_plan_days', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_daily_activity', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_training_sessions', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .subscribe()

    return () => {
      if (refreshTimer.current !== null) {
        window.clearTimeout(refreshTimer.current)
        refreshTimer.current = null
      }
      void supabase.removeChannel(channel)
    }
  }, [player?.id, refresh])

  return {
    currentWeek,
    nextWeek,
    loading,
    saving,
    error,
    refresh,
    saveDay,
    saveDays,
    applyWeek,
  }
}
