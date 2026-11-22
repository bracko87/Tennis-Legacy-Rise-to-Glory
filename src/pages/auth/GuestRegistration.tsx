import { useCallback, useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router'
import { ArrowRight, CheckCircle2, MailCheck, ShieldCheck } from 'lucide-react'
import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'
import useGoogleSignInAvailability from '../../hooks/useGoogleSignInAvailability'
import '../../styles/guest-conversion.css'

type ConversionStatus = {
  eligible: boolean
  is_anonymous: boolean
  email_verified?: boolean
  password_set?: boolean
  google_linked?: boolean
  expired?: boolean
  retired?: boolean
  can_convert?: boolean
  can_set_password?: boolean
}

export default function GuestRegistrationPage() {
  const { user, player, authLoading, signOut } = useAuth()
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const googleAvailable = useGoogleSignInAvailability()
  const [status, setStatus] = useState<ConversionStatus | null>(null)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [loading, setLoading] = useState(false)
  const [checking, setChecking] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [pendingEmail, setPendingEmail] = useState('')
  const [registeredNow, setRegisteredNow] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!user?.id) { setChecking(false); return }
    setChecking(true)
    try {
      // Refresh the signed-in identity after an email confirmation callback.
      // Never create a replacement user or reassign any player ownership.
      const { error: userError } = await supabase.auth.getUser()
      if (userError) throw userError
      const { data, error: rpcError } = await supabase.rpc('get_my_tennis_guest_conversion_status_v1')
      if (rpcError || !data) throw rpcError ?? new Error('Conversion status unavailable')
      setStatus(data as ConversionStatus)
      return data as ConversionStatus
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Cannot verify your guest session')
      setStatus(null)
      return null
    } finally {
      setChecking(false)
    }
  }, [user?.id])

  useEffect(() => { void refresh() }, [refresh])

  // OAuth errors return in URL query parameters; explain them instead of silently
  // dropping the player back onto the email-entry form.
  useEffect(() => {
    const code = searchParams.get('error_code') || searchParams.get('error')
    const description = searchParams.get('error_description') || ''
    if (!code && !description) return
    if (/identity_already_exists|already.linked|identity.*another/i.test(code + ' ' + description)) {
      setError('This Google account is already linked to another Tennis Legacy account. Your guest player was not transferred. Choose a different Google account or an unused email address.')
    } else {
      setError(description.replace(/\+/g, ' ') || 'The verification link could not be completed. Refresh your account status or request a new email.')
    }
    setSearchParams(previous => {
      const next = new URLSearchParams(previous)
      for (const key of ['error', 'error_code', 'error_description']) next.delete(key)
      return next
    }, { replace: true })
  }, [searchParams, setSearchParams])

  // Auth callbacks may return with updated identity in the same tab.
  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange(event => {
      if (event === 'SIGNED_IN' || event === 'USER_UPDATED') {
        window.setTimeout(() => { void refresh() }, 0)
      }
    })
    return () => subscription.unsubscribe()
  }, [refresh])

  useEffect(() => {
    if (!registeredNow) return
    const timer = window.setTimeout(() => navigate(player ? '/game/overview' : '/create-player', { replace: true }), 2500)
    return () => window.clearTimeout(timer)
  }, [registeredNow, navigate, player?.id])


  async function requestEmail(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!status?.eligible || !status.is_anonymous || status.retired || !status.can_convert || loading) return
    const address = email.trim().toLowerCase()
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(address)) {
      setError('Enter a valid email address.')
      return
    }
    setLoading(true)
    setError(null)
    setNotice(null)
    try {
      const { error: updateError } = await supabase.auth.updateUser(
        { email: address },
        { emailRedirectTo: new URL('/guest/register', window.location.origin).toString() }
      )
      if (updateError) throw updateError
      setNotice('Verification email requested. Open the link in this browser to link your guest player, then return here to set a password.')
      await refresh()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to send verification')
    } finally { setLoading(false) }
  }

  async function addPassword(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!status?.eligible || !status.can_set_password || status.password_set || loading) return
    if (password.length < 10 || !/[a-zA-Z]/.test(password) || !/[0-9]/.test(password) || password !== confirm) {
      setError('Use at least 10 characters with a letter and a number, and confirm the same password.')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password })
      if (updateError) throw updateError
      setPassword('')
      setConfirm('')
      setNotice('Your account now has an email and password. Your tennis player and progress remain attached to this account.')
      await refresh()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to set password')
    } finally { setLoading(false) }
  }

  async function linkGoogle() {
    if (!googleAvailable || !status?.eligible || !status.is_anonymous || status.retired || !status.can_convert || loading) return
    setLoading(true)
    setError(null)
    try {
      // Link to the CURRENT guest user, never signInWithOAuth (which can
      // silently replace the session with another account).
      const { error: linkError } = await supabase.auth.linkIdentity({
        provider: 'google',
        options: { redirectTo: new URL('/guest/register', window.location.origin).toString() },
      })
      if (linkError) throw linkError
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to link Google identity')
      setLoading(false)
    }
  }

  if (!authLoading && !user) return <Navigate to="/login" replace />

  const linked = status?.eligible && !status.is_anonymous
  const complete = linked && (status?.password_set || status?.google_linked)

  return (
    <main className="tlg-guest-convert">
      <section className="tlg-guest-convert-card">
        <span className="tlg-guest-convert-eyebrow"><ShieldCheck size={18}/> Tennis Legacy · Save Your Progress</span>
        <h1>Register and keep your tennis player</h1>
        <p>Register before your 14-day guest trial ends to keep your tennis player, ranking, equipment, staff, finances and Premium history.</p>
        <p className="tlg-guest-convert-identity"><strong>{player ? `${player.first_name} ${player.last_name}` : 'Your guest player'}</strong> · No player reset or second Premium trial</p>

        {(checking || authLoading) && <p role="status">Checking your account…</p>}
        {error && <p role="alert" className="tlg-guest-convert-error">{error}</p>}
        {notice && <p role="status" className="tlg-guest-convert-notice">{notice}</p>}

        {!checking && status && !status.eligible && (
          <p>This session is not a guest account. <Link to="/game/overview">Return to the game</Link>.</p>
        )}

        {!checking && status?.eligible && status.retired && (
          <section className="tlg-guest-convert-complete" role="status">
            <h2>Your guest player has left the game</h2>
            <p>The 14-day guest trial finished without permanent registration. Future tournament applications were withdrawn, and unstarted scheduled matches were resolved as walkovers where an opponent was available. This guest player can no longer be converted.</p>
            <button
              type="button"
              disabled={loading}
              onClick={() => void (async () => {
                setLoading(true)
                try {
                  await signOut()
                  navigate('/register', {replace:true})
                } catch (reason) {
                  setError(reason instanceof Error ? reason.message : 'Could not sign out')
                } finally { setLoading(false) }
              })()}
            >
              Create a New Permanent Account
            </button>
          </section>
        )}

        {!checking && status?.eligible && status.is_anonymous && !status.retired && status.can_convert && (
          <>
            {status.expired && <p className="tlg-guest-convert-notice">Your 14-day guest trial has ended. Register immediately if your account has not yet been automatically retired.</p>}
            {googleAvailable && (
              <button type="button" className="tlg-guest-convert-google" disabled={loading} onClick={() => void linkGoogle()}>
                <svg aria-hidden="true" width="20" height="20" viewBox="0 0 48 48" focusable="false"><path fill="#4285F4" d="M43.6 24.5c0-1.4-.1-2.8-.4-4.1H24v7.8h11a9.4 9.4 0 0 1-4.1 6.2v5.1h6.6c3.9-3.6 6.1-8.8 6.1-15z"/><path fill="#34A853" d="M24 44c5.5 0 10.1-1.8 13.5-4.5l-6.6-5.1c-1.8 1.2-4.1 2-6.9 2-5.3 0-9.8-3.6-11.4-8.4H5.8v5.3A20 20 0 0 0 24 44z"/><path fill="#FBBC05" d="M12.6 28a12 12 0 0 1 0-8V14.7H5.8a20 20 0 0 0 0 18.6z"/><path fill="#EA4335" d="M24 11.6c3 0 5.7 1 7.8 3.1l5.9-5.9A19.3 19.3 0 0 0 24 4 20 20 0 0 0 5.8 14.7l6.8 5.3A12 12 0 0 1 24 11.6z"/></svg>
                Continue with Google
              </button>
            )}
            {googleAvailable && <p className="tlg-guest-convert-help">Or continue with email</p>}

            <form onSubmit={event => void requestEmail(event)} className="tlg-guest-convert-form">
              <label htmlFor="guest-permanent-email">Your email address</label>
              <input
                id="guest-permanent-email" type="email" autoComplete="email"
                value={email} onChange={e => setEmail(e.target.value)} required
                placeholder="you@example.com"
              />
              <button type="submit" disabled={loading}>Verify Email &amp; Save My Progress <ArrowRight size={17}/></button>
            </form>
            <p className="tlg-guest-convert-help">Check your email before setting a password. Do not sign out or clear this browser's data while verification is pending.</p>
            <p className="tlg-guest-convert-help">If this email or Google account already belongs to a different Tennis Legacy account, linking may be refused. We will not merge or overwrite two players automatically.</p>
          </>
        )}

        {!checking && status?.eligible && !status.is_anonymous && !complete && status.can_set_password && (
          <form onSubmit={event => void addPassword(event)} className="tlg-guest-convert-form">
            <p><CheckCircle2 size={17}/> Email linked to this guest account. Add a password to finish registration.</p>
            <label htmlFor="guest-permanent-password">New password</label>
            <input
              id="guest-permanent-password" type="password" autoComplete="new-password"
              value={password} onChange={e => setPassword(e.target.value)} minLength={10} required
            />
            <label htmlFor="guest-confirm-password">Confirm password</label>
            <input
              id="guest-confirm-password" type="password" autoComplete="new-password"
              value={confirm} onChange={e => setConfirm(e.target.value)} minLength={10} required
            />
            <button type="submit" disabled={loading}>Save Password &amp; Complete Registration</button>
          </form>
        )}

        {!checking && linked && !complete && !status?.can_set_password && (
          <p role="status">Your email verification is still being processed. Once verified, you can set your account password.</p>
        )}

        {!checking && complete && (
          <div className="tlg-guest-convert-complete">
            <CheckCircle2 size={28}/>
            <h2>Progress saved to your permanent account</h2>
            <p>You can now sign in again using the method you linked. No second Premium trial has been created.</p>
          </div>
        )}

        <div className="tlg-guest-convert-footer">
          <button type="button" disabled={loading || checking} onClick={() => void refresh()}>Refresh account status</button>
          <Link to={player ? '/game/overview' : '/create-player'}>Back to your player</Link>
        </div>
      </section>
    </main>
  )
}
