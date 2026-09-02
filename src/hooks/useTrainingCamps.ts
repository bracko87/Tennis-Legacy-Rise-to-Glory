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
  cost_index: number
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

export interface TrainingCampAccommodationTier {
  id: string
  slug: string
  name: string
  star_rating: number
  base_weekly_cost: number
  rest_quality: number
  fatigue_mitigation: number
  weekly_morale_bonus: number
  weekly_focus_bonus: number
  description: string
  sort_order: number
}

export interface TrainingCampQuote {
  program_id: string
  camp_name: string
  training_quality: {
    tier: TrainingCampQuality
    multiplier: number
  }
  quality_tier: TrainingCampQuality
  facility_rating?: number
  quality_multiplier: number
  start_season: number
  start_week: number
  start_absolute_day: number
  end_absolute_day: number
  start: { season: number; month: number; day: number }
  end: { season: number; month: number; day: number }
  duration_weeks: number
  origin: {
    city: string
    country_code: string
    continent: string | null
    precision: 'city' | 'city_label' | 'country' | 'country_estimate'
  }
  destination: {
    city: string
    country: string
    country_code: string
    continent: string
    cost_index: number
  }
  training_fee_weekly: number
  training_fee_total: number
  accommodation: {
    id: string
    slug: string
    name: string
    stars: number
    base_weekly_cost: number
    destination_cost_index: number
    weekly_cost: number
    total: number
    rest_quality: number
    fatigue_mitigation: number
    weekly_morale_bonus: number
    weekly_focus_bonus: number
    description: string
  }
  travel: {
    cost: number
    one_way_km: number | null
    round_trip_km: number | null
    band: 'same_city' | 'domestic' | 'regional' | 'intercontinental'
    basis: 'exact_city_match' | 'same_country_estimate' | 'country_centroid_distance' | 'continent_fallback'
    arrival_fatigue: number
    formula: string
  }
  travel_cost: number
  travel_type: string
  staff_count: number
  staff_cost: number
  grand_total: number
}

export interface TrainingCampBooking {
  id: string
  player_id: string
  program_id: string
  start_absolute_day: number
  end_absolute_day: number
  start_season: number
  start_season_week: number | null
  start_month: number
  start_day: number
  end_season: number
  end_month: number
  end_day: number
  duration_weeks: number
  weekly_cost: number
  total_cost: number
  training_fee_total: number
  accommodation_weekly_cost: number
  accommodation_total: number
  travel_cost: number
  travel_distance_km: number | null
  travel_round_trip_km: number | null
  travel_band: string | null
  travel_basis: string | null
  travel_arrival_fatigue: number | null
  staff_count: number
  staff_total_cost: number
  origin_city: string | null
  origin_country_code: string | null
  origin_continent: string | null
  status: 'booked' | 'active' | 'completed' | 'cancelled'
  booked_at: string
  started_at: string | null
  completed_at: string | null
  accommodation: TrainingCampAccommodationTier | null
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
  quote?: TrainingCampQuote
}

export function useTrainingCamps() {
  const { player } = useAuth()
  const [programs, setPrograms] = useState<TrainingCampProgram[]>([])
  const [accommodations, setAccommodations] = useState<TrainingCampAccommodationTier[]>([])
  const [bookings, setBookings] = useState<TrainingCampBooking[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const refreshTimer = useRef<number | null>(null)

  const refresh = useCallback(async () => {
    if (!player?.id) {
      setPrograms([])
      setAccommodations([])
      setBookings([])
      setLoading(false)
      return
    }

    setLoading(true)
    setError(null)

    const [programResult, accommodationResult, bookingResult] = await Promise.all([
      supabase
        .from('training_camp_programs')
        .select(`
          id, slug, name, category, surface, quality_tier, quality_multiplier,
          weekly_cost, rating, development_profile, condition_profile,
          benefit_summary, description,
          location:training_camp_locations!inner(
            id, slug, city, country, country_code, continent,
            image_url, thumbnail_url, description, cost_index, sort_order
          )
        `)
        .eq('is_active', true),
      supabase
        .from('training_camp_accommodation_tiers')
        .select('id, slug, name, star_rating, base_weekly_cost, rest_quality, fatigue_mitigation, weekly_morale_bonus, weekly_focus_bonus, description, sort_order')
        .eq('is_active', true)
        .order('sort_order', { ascending: true }),
      supabase
        .from('player_training_camp_bookings')
        .select(`
          id, player_id, program_id, start_absolute_day, end_absolute_day,
          start_season, start_season_week, start_month, start_day, end_season, end_month, end_day,
          duration_weeks, weekly_cost, total_cost, training_fee_total,
          accommodation_weekly_cost, accommodation_total, travel_cost,
          travel_distance_km, travel_round_trip_km, travel_band, travel_basis, travel_arrival_fatigue,
          staff_count, staff_total_cost, origin_city, origin_country_code, origin_continent,
          status, booked_at, started_at, completed_at,
          accommodation:training_camp_accommodation_tiers(
            id, slug, name, star_rating, base_weekly_cost, rest_quality,
            fatigue_mitigation, weekly_morale_bonus, weekly_focus_bonus, description, sort_order
          ),
          program:training_camp_programs!inner(
            id, slug, name, category, surface, quality_tier, quality_multiplier,
            weekly_cost, rating, development_profile, condition_profile,
            benefit_summary, description,
            location:training_camp_locations!inner(
              id, slug, city, country, country_code, continent,
              image_url, thumbnail_url, description, cost_index, sort_order
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

    if (accommodationResult.error) {
      setError((current) => current ?? accommodationResult.error?.message ?? 'Unable to load accommodation options.')
      setAccommodations([])
    } else {
      setAccommodations((accommodationResult.data ?? []) as unknown as TrainingCampAccommodationTier[])
    }

    if (bookingResult.error) {
      setError((current) => current ?? bookingResult.error?.message ?? 'Unable to load training camp bookings.')
      setBookings([])
    } else {
      setBookings((bookingResult.data ?? []) as unknown as TrainingCampBooking[])
    }

    setLoading(false)
  }, [player?.id])

  const quoteCamp = useCallback(async (
    programId: string,
    startSeason: number,
    startWeek: number,
    durationWeeks: number,
    accommodationSlug: string,
  ) => {
    const { data, error: rpcError } = await supabase.rpc('quote_training_camp_v2', {
      p_program_id: programId,
      p_start_season: startSeason,
      p_start_week: startWeek,
      p_duration_weeks: durationWeeks,
      p_accommodation_slug: accommodationSlug,
    })
    if (rpcError) return { quote: null, error: rpcError.message }
    return { quote: data as TrainingCampQuote, error: null }
  }, [])

  const bookCamp = useCallback(async (
    programId: string,
    startSeason: number,
    startWeek: number,
    durationWeeks: number,
    accommodationSlug: string,
  ) => {
    setSaving(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc('book_training_camp_v2', {
      p_program_id: programId,
      p_start_season: startSeason,
      p_start_week: startWeek,
      p_duration_weeks: durationWeeks,
      p_accommodation_slug: accommodationSlug,
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
    accommodations,
    bookings,
    loading,
    saving,
    processing,
    error,
    refresh,
    quoteCamp,
    bookCamp,
    cancelCamp,
    processToday,
  }
}
