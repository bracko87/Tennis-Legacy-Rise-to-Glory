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
export default function TryAsGuestPage({ previewOnly = false }: { readonly previewOnly?: boolean }) {
  const available = useTennisGuestAvailability()
  const { user, player, authLoading, playerLoading } = useAuth()
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
    if (previewOnly || (!available && !user?.is_anonymous) || busy || authLoading || playerLoading) return
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
      if (trialError || !data) throw trialError ?? new Error('Could not enroll guest player')
      if (data.state === 'expired') {
        setError('This guest trial has ended. Please register to save your existing progress.')
        return
      }
      if (data.state !== 'active') throw new Error('Guest session not active')
      navigate(player ? '/game/overview' : '/create-player', { replace: true })
    } catch (reason) {
      const message = reason instanceof Error ? reason.message : 'Unable to create your guest player.'
      setError(/anonymous sign-ins are disabled/i.test(message) ? 'Guest sign-in is temporarily unavailable. Please try again later or create a permanent account.' : message)
    } finally {
      setBusy(false)
    }
  }

  if (!previewOnly && !authLoading && user && !user.is_anonymous) {
    return <Navigate to={player ? '/game/overview' : '/create-player'} replace />
  }

  return (
    <main className="tlg-guest-entry">
      <section className="tlg-guest-entry-card">
        <span className="tlg-guest-entry-label"><UserRound size={18}/> Tennis Legacy · Guest Player</span>
        <h1>Try Tennis Legacy without registering</h1>
        <p>Create your own tennis player with a name, country and appearance. No email, password, city or birthday is needed to begin.</p>
        <div className="tlg-guest-entry-facts">
          <span>14 days of guest access</span>
          <span>7 days of Premium after eligibility checks</span>
          <span>Register later to keep your player</span>
        </div>
        <p className="tlg-guest-entry-warning">
          <ShieldCheck size={17}/>
          Your guest progress is stored with this browser session. Clearing browser data, signing out, or switching devices before registering may make your player unrecoverable.
        </p>
        {error && <p role="alert" className="tlg-auth-status tlg-auth-status-information">{error}</p>}
        {previewOnly && <p role="status" className="tlg-auth-status tlg-auth-status-information">Admin UI preview only — no account is created, no trial starts and no data is saved.</p>}
        {!previewOnly && checked && !available && (
          <p role="status">Guest Player access is not available yet. You can still register a permanent account.</p>
        )}
        <div className="tlg-guest-entry-actions">
          <button
            className="tlg-btn tlg-btn-primary tlg-btn-large"
            type="button"
            onClick={() => void begin()}
            disabled={previewOnly || (!available && !user?.is_anonymous) || busy || authLoading || playerLoading}
          >
            {previewOnly ? 'Create Guest Player (Preview Only)' : busy ? 'Checking your guest session…' : user?.is_anonymous ? 'Continue as Guest' : 'Create Guest Player'}
            <ArrowRight size={17}/>
          </button>
          {previewOnly ? <span className="tlg-btn tlg-btn-secondary tlg-btn-large" aria-disabled="true">Create a Permanent Account</span> : <Link to={user?.is_anonymous ? "/guest/register" : "/register"} className="tlg-btn tlg-btn-secondary tlg-btn-large">Create a Permanent Account</Link>}
          {!previewOnly && <Link to="/">Back to Homepage</Link>}
        </div>
      </section>
    </main>
  )
}
