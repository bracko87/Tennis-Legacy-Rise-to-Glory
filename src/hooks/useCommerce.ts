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

export function useCommerce() {
  const { user } = useAuth()
  const [wallet, setWallet] = useState<UserWalletRecord | null>(null)
  const [membership, setMembership] = useState<PremiumMembershipRecord | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!user) {
      setWallet(null)
      setMembership(null)
      setLoading(false)
      setError(null)
      return
    }

    setLoading(true)
    setError(null)

    const [walletResult, membershipResult] = await Promise.all([
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
    ])

    if (walletResult.error || membershipResult.error) {
      const message = walletResult.error?.message ?? membershipResult.error?.message ?? 'Unable to load commerce data.'
      setError(message)
    }

    setWallet((walletResult.data ?? null) as UserWalletRecord | null)
    setMembership((membershipResult.data ?? null) as PremiumMembershipRecord | null)
    setLoading(false)
  }, [user])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const isPremium = useMemo(() => {
    if (!membership || membership.plan_code !== 'premium' || membership.status !== 'active') return false
    if (!membership.current_period_end) return true
    return new Date(membership.current_period_end).getTime() > Date.now()
  }, [membership])

  return {
    wallet,
    membership,
    coins: wallet?.coins_balance ?? 0,
    isPremium,
    loading,
    error,
    refresh,
  }
}
