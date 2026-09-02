import { useCallback, useEffect, useRef, useState } from 'react'

import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'

export type TrainingCampCategory = 'tennis_skills' | 'physical' | 'recovery_mindset'
export type TrainingCampSurface = 'hard' | 'clay' | 'grass' | null
export type TrainingCampQuality = 'standard' | 'advanced' | 'elite'

export interface TrainingCampLocation {
  id: string
  slug: string
  city: string
  country: string
  country_code: string
  continent: string
  image_url: string | null
  thumbnail_url: string | null
  description: string | null
  sort_order: number
}

export interface TrainingCampProgram {
  id: string
  slug: string
  name: string
  category: TrainingCampCategory
  surface: TrainingCampSurface
  quality_tier: TrainingCampQuality
  quality_multiplier: number
  weekly_cost: number
  rating: number
  development_profile: Record<string, number>
  condition_profile: Record<string, number>
  benefit_summary: string
  description: string
  location: TrainingCampLocation
}

export interface TrainingCampBooking {
  id: string
  player_id: string
  program_id: string
  start_absolute_day: number
  end_absolute_day: number
  start_season: number
  start_month: number
  start_day: number
  end_season: number
  end_month: number
  end_day: number
  duration_weeks: number
  weekly_cost: number
  total_cost: number
  status: 'booked' | 'active' | 'completed' | 'cancelled'
  booked_at: string
  started_at: string | null
  completed_at: string | null
  program: TrainingCampProgram
}

export interface TrainingCampActionResult {
  status: string
  reason?: string
  booking_id?: string
  camp_name?: string
  camp_day_number?: number
  camp_week?: number
  development_gains?: Record<string, number>
  level_ups?: Record<string, number>
  condition_changes?: Record<string, number>
}

export function useTrainingCamps() {
  const { player } = useAuth()
  const [programs, setPrograms] = useState<TrainingCampProgram[]>([])
  const [bookings, setBookings] = useState<TrainingCampBooking[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const refreshTimer = useRef<number | null>(null)

  const refresh = useCallback(async () => {
    if (!player?.id) {
      setPrograms([])
      setBookings([])
      setLoading(false)
      return
    }

    setLoading(true)
    setError(null)

    const [programResult, bookingResult] = await Promise.all([
      supabase
        .from('training_camp_programs')
        .select(`
          id, slug, name, category, surface, quality_tier, quality_multiplier,
          weekly_cost, rating, development_profile, condition_profile,
          benefit_summary, description,
          location:training_camp_locations!inner(
            id, slug, city, country, country_code, continent,
            image_url, thumbnail_url, description, sort_order
          )
        `)
        .eq('is_active', true),
      supabase
        .from('player_training_camp_bookings')
        .select(`
          id, player_id, program_id, start_absolute_day, end_absolute_day,
          start_season, start_month, start_day, end_season, end_month, end_day,
          duration_weeks, weekly_cost, total_cost, status, booked_at, started_at, completed_at,
          program:training_camp_programs!inner(
            id, slug, name, category, surface, quality_tier, quality_multiplier,
            weekly_cost, rating, development_profile, condition_profile,
            benefit_summary, description,
            location:training_camp_locations!inner(
              id, slug, city, country, country_code, continent,
              image_url, thumbnail_url, description, sort_order
            )
          )
        `)
        .in('status', ['booked', 'active'])
        .order('start_absolute_day', { ascending: true }),
    ])

    if (programResult.error) {
      setError(programResult.error.message)
      setPrograms([])
    } else {
      const next = (programResult.data ?? []) as unknown as TrainingCampProgram[]
      next.sort((a, b) => (a.location.sort_order - b.location.sort_order) || (a.weekly_cost - b.weekly_cost))
      setPrograms(next)
    }

    if (bookingResult.error) {
      setError((current) => current ?? bookingResult.error?.message ?? 'Unable to load training camp bookings.')
      setBookings([])
    } else {
      setBookings((bookingResult.data ?? []) as unknown as TrainingCampBooking[])
    }

    setLoading(false)
  }, [player?.id])

  const bookCamp = useCallback(async (
    programId: string,
    start: { season: number; month: number; day: number },
    durationWeeks: number,
  ) => {
    setSaving(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc('book_training_camp_v1', {
      p_program_id: programId,
      p_start_season: start.season,
      p_start_month: start.month,
      p_start_day: start.day,
      p_duration_weeks: durationWeeks,
    })

    if (rpcError) {
      setError(rpcError.message)
      setSaving(false)
      return null
    }

    await refresh()
    setSaving(false)
    return data as TrainingCampActionResult
  }, [refresh])

  const cancelCamp = useCallback(async (bookingId: string) => {
    setSaving(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('cancel_training_camp_v1', {
      p_booking_id: bookingId,
    })
    if (rpcError) {
      setError(rpcError.message)
      setSaving(false)
      return null
    }
    await refresh()
    setSaving(false)
    return data as TrainingCampActionResult
  }, [refresh])

  const processToday = useCallback(async () => {
    setProcessing(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('complete_training_camp_today_v1')
    if (rpcError) {
      setError(rpcError.message)
      setProcessing(false)
      return null
    }
    await refresh()
    setProcessing(false)
    return data as TrainingCampActionResult
  }, [refresh])

  useEffect(() => {
    void refresh()
  }, [refresh])

  useEffect(() => {
    if (!player?.id) return

    const scheduleRefresh = () => {
      if (refreshTimer.current !== null) window.clearTimeout(refreshTimer.current)
      refreshTimer.current = window.setTimeout(() => {
        refreshTimer.current = null
        void refresh()
      }, 160)
    }

    const channel = supabase
      .channel(`training-camps:${player.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_training_camp_bookings', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_training_camp_days', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_daily_activity', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_training_progress', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_skills', filter: `player_id=eq.${player.id}` }, scheduleRefresh)
      .subscribe()

    return () => {
      if (refreshTimer.current !== null) window.clearTimeout(refreshTimer.current)
      void supabase.removeChannel(channel)
    }
  }, [player?.id, refresh])

  return {
    programs,
    bookings,
    loading,
    saving,
    processing,
    error,
    refresh,
    bookCamp,
    cancelCamp,
    processToday,
  }
}
