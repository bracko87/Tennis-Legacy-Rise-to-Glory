import { useCallback, useEffect, useMemo, useState } from 'react'

import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'

export interface UserWalletRecord {
  user_id: string
  coins_balance: number
  lifetime_coins_earned: number
  lifetime_coins_spent: number
}

export interface PremiumMembershipRecord {
  user_id: string
  plan_code: 'free' | 'premium'
  status: 'active' | 'past_due' | 'canceled' | 'incomplete'
  started_at: string
  current_period_start: string | null
  current_period_end: string | null
  cancel_at_period_end: boolean
  monthly_price_eur_cents: number
  monthly_coin_reward: number
  billing_plan_code: 'premium_monthly' | 'premium_quarterly' | 'premium_yearly' | null
  billing_period_months: number | null
  billing_amount_eur_cents: number | null
  coins_per_payment: number | null
  stripe_price_id: string | null
}

export interface PremiumTrialRecord {
  state: 'active' | 'expired' | 'subscribed' | 'ineligible' | 'not_ready'
  trial_started?: boolean
  started_at?: string
  expires_at?: string
  seconds_left?: number
  show_welcome?: boolean
  show_expired?: boolean
}

export function useCommerce() {
  const { user } = useAuth()
  const [wallet, setWallet] = useState<UserWalletRecord | null>(null)
  const [membership, setMembership] = useState<PremiumMembershipRecord | null>(null)
  const [trial, setTrial] = useState<PremiumTrialRecord | null>(null)
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async (background = true) => {
    if (!user) {
      setWallet(null)
      setMembership(null)
      setTrial(null)
      setLoading(false)
      setRefreshing(false)
      setError(null)
      return
    }

    if (background) setRefreshing(true)
    else setLoading(true)
    setError(null)

    const [walletResult, membershipResult, trialResult] = await Promise.all([
      supabase
        .from('user_wallets')
        .select('user_id, coins_balance, lifetime_coins_earned, lifetime_coins_spent')
        .eq('user_id', user.id)
        .maybeSingle(),
      supabase
        .from('premium_memberships')
        .select('user_id, plan_code, status, started_at, current_period_start, current_period_end, cancel_at_period_end, monthly_price_eur_cents, monthly_coin_reward, billing_plan_code, billing_period_months, billing_amount_eur_cents, coins_per_payment, stripe_price_id')
        .eq('user_id', user.id)
        .maybeSingle(),
      supabase.rpc('get_my_tennis_premium_trial_v1', { p_action: 'status' }),
    ])

    if (walletResult.error || membershipResult.error) {
      const message = walletResult.error?.message ?? membershipResult.error?.message ?? 'Unable to load commerce data.'
      setError(message)
    }

    setWallet((walletResult.data ?? null) as UserWalletRecord | null)
    setMembership((membershipResult.data ?? null) as PremiumMembershipRecord | null)
    if (!trialResult.error) setTrial((trialResult.data ?? null) as PremiumTrialRecord | null)
    if (background) setRefreshing(false)
    else setLoading(false)
  }, [user])

  useEffect(() => {
    void refresh(false)
  }, [refresh])

  useEffect(() => {
    const handleCoinChange = () => { void refresh() }
    window.addEventListener('tlg-coin-balance-changed', handleCoinChange)
    window.addEventListener('tlg-premium-status-changed', handleCoinChange)
    return () => {
      window.removeEventListener('tlg-coin-balance-changed', handleCoinChange)
      window.removeEventListener('tlg-premium-status-changed', handleCoinChange)
    }
  }, [refresh])

  const isPaidPremium = useMemo(() => {
    if (!membership || membership.plan_code !== 'premium' || membership.status !== 'active') return false
    if (!membership.current_period_end) return true
    return new Date(membership.current_period_end).getTime() > Date.now()
  }, [membership])

  const isTrial = !isPaidPremium && trial?.state === 'active'
    && Boolean(trial.expires_at && new Date(trial.expires_at).getTime() > Date.now())
  const isPremium = isPaidPremium || isTrial

  // Trial expiry must lock features without waiting for another page reload.
  useEffect(() => {
    if (trial?.state !== 'active' || !trial.expires_at) return
    const remaining = new Date(trial.expires_at).getTime() - Date.now()
    if (remaining <= 0) { void refresh(); return }
    const timer = window.setTimeout(() => { void refresh() }, Math.min(remaining + 250, 2_147_483_647))
    return () => window.clearTimeout(timer)
  }, [trial?.state, trial?.expires_at, refresh])

  useEffect(() => {
    if (!user?.id) return
    const visible = () => {
      if (document.visibilityState === 'visible') void refresh()
    }
    document.addEventListener('visibilitychange', visible)
    return () => document.removeEventListener('visibilitychange', visible)
  }, [user?.id, refresh])

  return {
    wallet,
    membership,
    trial,
    isTrial,
    isPaidPremium,
    coins: wallet?.coins_balance ?? 0,
    isPremium,
    loading,
    refreshing,
    error,
    refresh,
  }
}
