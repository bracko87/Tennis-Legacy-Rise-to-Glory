import { useCallback, useEffect, useState } from 'react'
import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'

export type TennisClubAlerts = {
  invitations: number
  messages: number
  applications: number
  total: number
}
const empty: TennisClubAlerts = { invitations: 0, messages: 0, applications: 0, total: 0 }

// Shared signal for club pages, sidebar and related actions. Counts are sourced
// from authenticated server queries and refresh while the player is online.
export function notifyTennisClubAlertsChanged() {
  window.dispatchEvent(new Event('tlg:tennis-club-alerts-changed'))
}

export function useTennisClubAlerts() {
  const { user } = useAuth()
  const [alerts, setAlerts] = useState<TennisClubAlerts>(empty)

  const refresh = useCallback(async () => {
    if (!user?.id) {
      setAlerts(empty)
      return
    }
    const { data, error } = await supabase.rpc('get_tennis_club_alert_counts_v1')
    if (error || !data) return
    const raw = data as Partial<TennisClubAlerts>
    setAlerts({
      invitations: Math.max(0, Number(raw.invitations) || 0),
      messages: Math.max(0, Number(raw.messages) || 0),
      applications: Math.max(0, Number(raw.applications) || 0),
      total: Math.max(0, Number(raw.total) || 0),
    })
  }, [user?.id])

  useEffect(() => {
    void refresh()
    const timer = window.setInterval(() => { void refresh() }, 20_000)
    const onVisible = () => {
      if (document.visibilityState === 'visible') void refresh()
    }
    const onChanged = () => { void refresh() }
    document.addEventListener('visibilitychange', onVisible)
    window.addEventListener('tlg:tennis-club-alerts-changed', onChanged)
    return () => {
      window.clearInterval(timer)
      document.removeEventListener('visibilitychange', onVisible)
      window.removeEventListener('tlg:tennis-club-alerts-changed', onChanged)
    }
  }, [refresh])

  return { alerts, refresh }
}
