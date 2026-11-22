import { useEffect, useState } from 'react'
import { useLocation, useNavigate } from 'react-router'
import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'
import '../../styles/converted-guest-profile.css'

type CompletionStatus = {
  eligible: boolean
  username_confirmed?: boolean
  birthday_set?: boolean
  home_city?: string | null
  dismissed?: boolean
}

/** Non-blocking post-conversion reminder; never interrupts active guest sessions. */
export default function ConvertedGuestProfileReminder() {
  const { user, player, refreshPlayer } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()
  const [status, setStatus] = useState<CompletionStatus | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const isOverview = location.pathname === '/game/overview'
  const sessionKey = user?.id ? `tlg:converted-profile-reminder:${user.id}` : ''

  useEffect(() => {
    if (!isOverview || !user || user.is_anonymous || !player || (sessionKey && sessionStorage.getItem(sessionKey))) {
      setStatus(null)
      return
    }
    let mounted = true
    void supabase.rpc('get_my_tennis_converted_profile_completion_v1').then(({ data, error: rpcError }) => {
      if (!mounted || rpcError) return
      const result = data as CompletionStatus | null
      setStatus(result?.eligible && !result.dismissed &&
        (!result.username_confirmed || !result.birthday_set || !result.home_city) ? result : null)
    }).catch(() => {
      // Reminder is advisory only; network failure must never block gameplay.
    })
    return () => { mounted = false }
  }, [isOverview, user?.id, user?.is_anonymous, player?.id, sessionKey])

  if (!isOverview || !status) return null

  const openAccount = () => {
    if (sessionKey) sessionStorage.setItem(sessionKey, 'seen')
    setStatus(null)
    navigate('/game/player-account#profile-completion')
  }

  const remindLater = async () => {
    if (busy) return
    setBusy(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('dismiss_my_tennis_converted_profile_reminder_v1')
    if (rpcError) {
      setError(rpcError.message)
      setBusy(false)
      return
    }
    const cityStatus = (data as { city?: { status?: string } } | null)?.city?.status
    if (cityStatus === 'no_available_city') {
      setError('No supported home city was found for your country. Please choose one from Player & Account when available.')
    }
    if (sessionKey) sessionStorage.setItem(sessionKey, 'seen')
    setStatus(null)
    await refreshPlayer()
    setBusy(false)
  }

  return (
    <div className="tlg-converted-profile-backdrop">
      <section className="tlg-converted-profile-modal" role="dialog" aria-modal="true"
        aria-labelledby="tlg-converted-profile-title" aria-describedby="tlg-converted-profile-description">
        <span className="tlg-converted-profile-eyebrow">Your guest career is now a permanent account</span>
        <h2 id="tlg-converted-profile-title">Complete your account details</h2>
        <p id="tlg-converted-profile-description">
          Your player, results, equipment and progress are already saved. Some optional information was not collected during guest registration.
        </p>
        <ul>
          {!status.username_confirmed && <li><strong>Account username</strong> — confirm or replace your automatically assigned username.</li>}
          {!status.birthday_set && <li><strong>Birthday (optional)</strong> — add it once to qualify for the annual Birthday Gift. Once saved, it cannot be changed.</li>}
          {!status.home_city && <li><strong>Player home city</strong> — choose a city in your player's country, or let the game assign one automatically.</li>}
        </ul>
        <div className="tlg-converted-profile-actions">
          <button type="button" onClick={openAccount}>Open Player & Account</button>
          <button type="button" className="secondary" disabled={busy} onClick={() => void remindLater()}>
            {busy ? 'Saving…' : 'Maybe later'}
          </button>
        </div>
        <small>You can continue playing without completing these details. If you choose later, an available city will be assigned automatically.</small>
        {error && <p role="alert">{error}</p>}
      </section>
    </div>
  )
}
