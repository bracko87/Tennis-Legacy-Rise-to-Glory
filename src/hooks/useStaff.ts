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

export interface StaffEffects {
  technical_training_multiplier: number
  technical_camp_multiplier: number
  coach_match_preparation_multiplier: number
  physical_training_multiplier: number
  physical_camp_multiplier: number
  training_fatigue_reduction: number
  recovery_multiplier: number
  injury_prevention_reduction: number
  rehabilitation_multiplier: number
  morale_recovery_multiplier: number
  confidence_recovery_multiplier: number
  focus_recovery_multiplier: number
  pressure_bonus: number
  scouting_margin: number
  analyst_match_preparation_multiplier: number
  sponsorship_multiplier: number
  negotiation_multiplier: number
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
  finance: {
    is_live: boolean
    balance: number | null
    currency: 'USD'
  }
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
  reason?: string
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
  acceptance_chance?: number
  chance_label?: string
  hard_refusal?: boolean
  explanation?: string
  cooldown_until_absolute_day?: number
  cooldown_days_remaining?: number
}

export interface StaffNegotiationResult {
  status: 'accepted' | 'rejected'
  accepted: boolean
  staff_id: string
  round_number: number
  acceptance_chance: number
  weekly_salary?: number
  offered_weekly_salary?: number
  salary_multiplier: number
  signing_fee?: number
  duration_weeks?: 13 | 26 | 52
  contract_id?: string
  remaining_rounds?: number
  minimum_next_multiplier?: number | null
  cooldown_until_absolute_day?: number | null
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
    const { data, error: rpcError } = await supabase.rpc('get_staff_dashboard_v1')
    if (rpcError) {
      setDashboard(null)
      setError(rpcError.message)
    } else {
      setDashboard(data as StaffDashboard)
    }
    setLoading(false)
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
    const result = data as StaffNegotiationResult
    if (result.accepted) await refreshDashboard()
    setSaving(false)
    return result
  }, [refreshDashboard])

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
    loadMarket,
    quoteNegotiation,
    negotiateStaff,
    terminateContract,
  }
}
