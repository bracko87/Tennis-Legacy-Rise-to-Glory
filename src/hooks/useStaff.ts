import { useCallback, useEffect, useState } from 'react'

import { supabase } from '../lib/supabase'

export type StaffRole =
  | 'head_coach'
  | 'fitness_coach'
  | 'physiotherapist'
  | 'sports_psychologist'
  | 'performance_analyst'
  | 'agent_manager'

export type StaffQuality = 'developing' | 'professional' | 'advanced' | 'elite' | 'world_class'

export interface StaffCandidate {
  id: string
  role: StaffRole
  role_label: string
  first_name: string
  last_name: string
  country_code: string
  overall_rating: number
  quality_tier: StaffQuality
  quality_label: string
  specialty: string
  attributes: Record<string, number>
  base_weekly_salary: number
  signing_fee: number
  required_rank_position: number | null
}

export interface StaffContract {
  contract_id: string
  role: StaffRole
  role_label: string
  start_absolute_day: number
  end_absolute_day: number
  duration_weeks: 13 | 26 | 52
  weekly_salary: number
  signing_fee: number
  status: 'active'
  finance_status: 'pending' | 'posted'
  weeks_remaining: number
  staff: StaffCandidate
}

export interface StaffEffectSummary {
  label: string
  current_display: string
  maximum_display: string
  cadence: string
}

export interface StaffAttributeDefinition {
  key: string
  label: string
  description: string
}

export interface StaffRoleEffectDefinition {
  key: string
  label: string
  maximum: string
  cadence: string
  note?: string
}

export interface StaffRoleCatalogItem {
  role: StaffRole
  label: string
  main_responsibility: string
  systems: string[]
  max_positions: number
  effect_cadence: string
  vacancy_behavior: string
  stacking_rule: string
  facility_limited: boolean
  facility_limit_note: string
  attributes: StaffAttributeDefinition[]
  effects: StaffRoleEffectDefinition[]
  review_note: string | null
  sort_order: number
  occupied: boolean
  current_effects: StaffEffectSummary[]
}

export interface StaffEffects {
  technical_training_multiplier: number
  technical_camp_multiplier: number
  coach_match_preparation_multiplier: number
  physical_training_multiplier: number
  physical_camp_multiplier: number
  training_fatigue_reduction: number
  active_recovery_multiplier: number
  recovery_multiplier: number
  injury_prevention_reduction: number
  rehabilitation_duration_reduction: number
  return_to_play_duration_reduction: number
  rehabilitation_multiplier: number
  morale_recovery_bonus_points: number
  confidence_recovery_bonus_points: number
  focus_recovery_bonus_points: number
  morale_recovery_multiplier: number
  confidence_recovery_multiplier: number
  focus_recovery_multiplier: number
  pressure_bonus: number
  scouting_margin: number
  analyst_match_preparation_multiplier: number
  sponsorship_multiplier: number
  negotiation_multiplier: number
  match_staff_multiplier: number
  match_staff_cap: number
  facility_cap_applied: boolean
}

export interface StaffDashboard {
  current_absolute_day: number
  rank_position: number
  employed_count: number
  max_staff: number
  weekly_cost: number
  contracts_expiring_4_weeks: number
  contracts: StaffContract[]
  effects: StaffEffects
  roles: StaffRoleCatalogItem[]
  combined_effects: {
    technical_training_display: string
    physical_training_display: string
    active_recovery_display: string
    injury_risk_display: string
    match_support_display: string
    sponsor_value_display: string
  }
  finance: {
    is_live: boolean
    balance: number | null
    currency: 'USD'
  }
}

export interface StaffGameDate {
  season: number
  month: number
  day: number
  season_week: number
}

export interface StaffMemberProfile {
  staff: {
    id: string
    first_name: string
    last_name: string
    country_code: string
    age: number
    experience_years: number
    role: StaffRole
    role_label: string
    specialty: string
    overall_rating: number
    quality_tier: StaffQuality
    quality_label: string
    attributes: Record<string, number>
    education: string
    courses: string[]
    image_path: string | null
    status: string
  }
  contract: {
    id: string
    weekly_salary: number
    duration_weeks: number
    weeks_remaining: number
    start_absolute_day: number
    end_absolute_day: number
    start_game_day: StaffGameDate
    end_game_day: StaffGameDate
    status: string
    assignment: string
  }
  role: StaffRoleCatalogItem
  current_effects: StaffEffectSummary[]
  facility: {
    limited: boolean
    potential_equals_applied: boolean
    message: string
  }
  advisory: {
    available: boolean
    message: string
  }
  current_assignment: string
}

export interface StaffMarketResponse {
  total: number
  items: StaffCandidate[]
  offset: number
  limit: number
}

export interface StaffMarketFilters {
  role?: StaffRole | ''
  countryCode?: string
  qualityTier?: StaffQuality | ''
  maxWeeklySalary?: number | null
  specialty?: string
  offset?: number
  limit?: number
}

export interface StaffNegotiationQuote {
  available: boolean
  pending_confirmation?: boolean
  reason?: string
  negotiation_id?: string
  staff_id?: string
  quality_tier?: StaffQuality
  overall_rating?: number
  player_rank_position?: number
  duration_weeks?: 13 | 26 | 52
  round_number?: number
  max_rounds?: number
  base_contract_weekly_salary?: number
  salary_multiplier?: number
  offered_weekly_salary?: number
  minimum_next_multiplier?: number
  signing_fee?: number
  salary_total?: number
  total_commitment?: number
  acceptance_chance?: number
  chance_label?: string
  hard_refusal?: boolean
  explanation?: string
  cooldown_until_absolute_day?: number
  cooldown_days_remaining?: number
}

export interface StaffNegotiationResult {
  status: 'accepted_pending_confirmation' | 'rejected'
  accepted: boolean
  pending_confirmation?: boolean
  negotiation_id?: string
  offer_id?: string
  staff_id: string
  round_number: number
  acceptance_chance: number
  weekly_salary?: number
  offered_weekly_salary?: number
  salary_multiplier: number
  signing_fee?: number
  duration_weeks?: 13 | 26 | 52
  salary_total?: number
  total_commitment?: number
  remaining_rounds?: number
  minimum_next_multiplier?: number | null
  cooldown_until_absolute_day?: number | null
}

export interface StaffHireConfirmationResult {
  status: 'confirmed' | 'already_confirmed'
  contract_id: string
  staff_id?: string
  weekly_salary?: number
  signing_fee?: number
  duration_weeks?: 13 | 26 | 52
  salary_total?: number
  total_commitment?: number
}

export interface StaffTerminationQuote {
  contract_id: string
  staff_id: string
  staff_name: string
  weekly_salary: number
  remaining_weeks: number
  remaining_salary: number
  termination_rate: number
  termination_fee: number
  balance: number | null
}

export function contractWeeklySalary(base: number, duration: 13 | 26 | 52) {
  const multiplier = duration === 13 ? 1 : duration === 26 ? 0.93 : 0.86
  return Math.max(100, Math.round((base * multiplier) / 10) * 10)
}

export function useStaff() {
  const [dashboard, setDashboard] = useState<StaffDashboard | null>(null)
  const [market, setMarket] = useState<StaffMarketResponse>({ total: 0, items: [], offset: 0, limit: 25 })
  const [loading, setLoading] = useState(true)
  const [marketLoading, setMarketLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refreshDashboard = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_staff_dashboard_v2')
    if (rpcError) {
      setDashboard(null)
      setError(rpcError.message)
    } else {
      setDashboard(data as StaffDashboard)
    }
    setLoading(false)
  }, [])

  const loadStaffProfile = useCallback(async (staffId: string) => {
    const { data, error: rpcError } = await supabase.rpc('get_staff_member_profile_v1', {
      p_staff_id: staffId,
    })
    if (rpcError) return { profile: null, error: rpcError.message }
    return { profile: data as StaffMemberProfile, error: null }
  }, [])

  const loadMarket = useCallback(async (filters: StaffMarketFilters = {}) => {
    setMarketLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_staff_market_v1', {
      p_role: filters.role || null,
      p_country_code: filters.countryCode?.trim() || null,
      p_quality_tier: filters.qualityTier || null,
      p_max_weekly_salary: filters.maxWeeklySalary ?? null,
      p_specialty: filters.specialty?.trim() || null,
      p_offset: filters.offset ?? 0,
      p_limit: filters.limit ?? 25,
    })
    if (rpcError) {
      setMarket({ total: 0, items: [], offset: filters.offset ?? 0, limit: filters.limit ?? 25 })
      setError(rpcError.message)
    } else {
      setMarket(data as StaffMarketResponse)
    }
    setMarketLoading(false)
  }, [])

  const quoteNegotiation = useCallback(async (
    staffId: string,
    durationWeeks: 13 | 26 | 52,
    salaryMultiplier: number,
  ) => {
    const { data, error: rpcError } = await supabase.rpc('quote_staff_negotiation_v1', {
      p_staff_id: staffId,
      p_duration_weeks: durationWeeks,
      p_salary_multiplier: salaryMultiplier,
    })
    if (rpcError) return { quote: null, error: rpcError.message }
    return { quote: data as StaffNegotiationQuote, error: null }
  }, [])

  const negotiateStaff = useCallback(async (
    staffId: string,
    durationWeeks: 13 | 26 | 52,
    salaryMultiplier: number,
  ) => {
    setSaving(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('negotiate_staff_offer_v1', {
      p_staff_id: staffId,
      p_duration_weeks: durationWeeks,
      p_salary_multiplier: salaryMultiplier,
    })
    if (rpcError) {
      setError(rpcError.message)
      setSaving(false)
      return null
    }
    setSaving(false)
    return data as StaffNegotiationResult
  }, [])

  const confirmStaffOffer = useCallback(async (negotiationId: string) => {
    setSaving(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('confirm_staff_offer_v1', {
      p_negotiation_id: negotiationId,
    })
    if (rpcError) {
      setError(rpcError.message)
      setSaving(false)
      return null
    }
    await refreshDashboard()
    setSaving(false)
    return data as StaffHireConfirmationResult
  }, [refreshDashboard])

  const quoteStaffTermination = useCallback(async (contractId: string) => {
    const { data, error: rpcError } = await supabase.rpc('quote_staff_termination_v1', {
      p_contract_id: contractId,
    })
    if (rpcError) return { quote: null, error: rpcError.message }
    return { quote: data as StaffTerminationQuote, error: null }
  }, [])

  const terminateContract = useCallback(async (contractId: string) => {
    setSaving(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('terminate_staff_contract_v1', {
      p_contract_id: contractId,
    })
    if (rpcError) {
      setError(rpcError.message)
      setSaving(false)
      return null
    }
    await refreshDashboard()
    setSaving(false)
    return data as Record<string, unknown>
  }, [refreshDashboard])

  useEffect(() => {
    void refreshDashboard()
  }, [refreshDashboard])

  return {
    dashboard,
    market,
    loading,
    marketLoading,
    saving,
    error,
    refreshDashboard,
    loadStaffProfile,
    loadMarket,
    quoteNegotiation,
    negotiateStaff,
    confirmStaffOffer,
    quoteStaffTermination,
    terminateContract,
  }
}
