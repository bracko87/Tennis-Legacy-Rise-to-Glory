import { useEffect, useState } from 'react'
import { Link, Navigate, useNavigate } from 'react-router'
import { ArrowRight, ShieldCheck, UserRound } from 'lucide-react'
import { useAuth } from '../../auth/AuthContext'
import useTennisGuestAvailability from '../../hooks/useTennisGuestAvailability'
import { supabase } from '../../lib/supabase'
import '../../styles/guest-entry.css'

/**
 * Guest creation remains hidden and disabled server-side until conversion,
 * expiry enforcement in every gameplay path, ranking and Premium tests pass.
 * Anonymous Auth creates a new auth.users identity; do not replace a signed-in
 * permanent session or allow a repeat anonymous login to reset its clock.
 */
export default function TryAsGuestPage() {
  const available = useTennisGuestAvailability()
  const { user, player, authLoading } = useAuth()
  const navigate = useNavigate()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [checked, setChecked] = useState(false)

  // Distinguish an intentionally disabled rollout from an initial request.
  useEffect(() => {
    let mounted = true
    void supabase.rpc('get_public_tennis_guest_test_status_v1')
      .then(() => { if (mounted) setChecked(true) })
      .catch(() => { if (mounted) setChecked(true) })
    return () => { mounted = false }
  }, [])

  async function begin() {
    if (!available || busy || authLoading) return
    setError(null)
    setBusy(true)
    try {
      if (user && !user.is_anonymous) {
        navigate(player ? '/game/overview' : '/create-player', { replace: true })
        return
      }

      if (!user) {
        const { error: anonymousError } = await supabase.auth.signInAnonymously()
        if (anonymousError) throw anonymousError
      }

      // Enroll the current authenticated anonymous user only; repeated calls
      // cannot extend its server-issued 14-day deadline.
      const { data, error: trialError } = await supabase.rpc('enroll_my_tennis_guest_trial_v1')
      if (trialError || !data) throw trialError ?? new Error('Could not enroll test player')
      if (data.state === 'expired') {
        setError('This test period has ended. Please register to save your existing progress.')
        return
      }
      if (data.state !== 'active') throw new Error('Guest session not active')
      navigate('/create-player', { replace: true })
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to create your test player.')
    } finally {
      setBusy(false)
    }
  }

  if (!authLoading && user && !user.is_anonymous) {
    return <Navigate to={player ? '/game/overview' : '/create-player'} replace />
  }

  return (
    <main className="tlg-guest-entry">
      <section className="tlg-guest-entry-card">
        <span className="tlg-guest-entry-label"><UserRound size={18}/> Tennis Legacy · Test Player</span>
        <h1>Try Tennis Legacy without registering</h1>
        <p>Create your own tennis player with a name, country and appearance. No email, password, city or birthday is needed to begin.</p>
        <div className="tlg-guest-entry-facts">
          <span>14 days to test the game</span>
          <span>7 days of Premium after eligibility checks</span>
          <span>Register later to keep your player</span>
        </div>
        <p className="tlg-guest-entry-warning">
          <ShieldCheck size={17}/>
          Your guest progress is stored with this browser session. Clearing browser data, signing out, or switching devices before registering may make your player unrecoverable.
        </p>
        {error && <p role="alert" className="tlg-auth-status tlg-auth-status-information">{error}</p>}
        {checked && !available && (
          <p role="status">Test Player access is not available yet. You can still register a permanent account.</p>
        )}
        <div className="tlg-guest-entry-actions">
          <button
            className="tlg-btn tlg-btn-primary tlg-btn-large"
            type="button"
            onClick={() => void begin()}
            disabled={!available || busy || authLoading}
          >
            {busy ? 'Creating your test session…' : 'Create Test Player'}
            <ArrowRight size={17}/>
          </button>
          <Link to="/register" className="tlg-btn tlg-btn-secondary tlg-btn-large">Create a Permanent Account</Link>
          <Link to="/">Back to Homepage</Link>
        </div>
      </section>
    </main>
  )
}
