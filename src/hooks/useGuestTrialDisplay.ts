import { useCallback, useEffect, useState } from 'react'
import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'

export type GuestTrialDisplay = {
  state: 'active' | 'expired' | 'retired' | 'not_enrolled' | 'loading'
  expiresAt: string | null
  daysLeft: number
  pending: boolean
}

/**
 * Read-only display state. Database policies/RPCs enforce the actual deadline.
 * We never hide the register action when the guest status query fails.
 */
export function useGuestTrialDisplay(): GuestTrialDisplay {
  const { user } = useAuth()
  const guest = user?.is_anonymous === true
  const [state, setState] = useState<GuestTrialDisplay>({
    state: 'loading', expiresAt: null, daysLeft: 0, pending: true,
  })

  const refresh = useCallback(async () => {
    if (!guest) return
    try {
      const { data, error } = await supabase.rpc('get_my_tennis_guest_trial_v1')
      if (error || !data) throw error ?? new Error('Trial status unavailable')
      const end = typeof data.expires_at === 'string' ? data.expires_at : null
      const left = end ? Math.max(0, Math.ceil((new Date(end).getTime() - Date.now()) / 86400000)) : 0
      setState({
        state: data.state === 'retired' ? 'retired' : data.state === 'expired' ? 'expired' : data.state === 'active' ? 'active' : 'not_enrolled',
        expiresAt: end, daysLeft: left, pending: false,
      })
    } catch {
      setState({ state: 'not_enrolled', expiresAt: null, daysLeft: 0, pending: false })
    }
  }, [guest])

  useEffect(() => {
    if (!guest) return
    void refresh()
    const interval = window.setInterval(() => void refresh(), 60_000)
    const visibility = () => { if (document.visibilityState === 'visible') void refresh() }
    document.addEventListener('visibilitychange', visibility)
    return () => {
      window.clearInterval(interval)
      document.removeEventListener('visibilitychange', visibility)
    }
  }, [guest, refresh])

  if (!guest) return { state: 'not_enrolled', expiresAt: null, daysLeft: 0, pending: false }
  return state
}
