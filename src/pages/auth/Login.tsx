/**
 * Login.tsx
 *
 * Premium production sign-in connected to Tennis Legacy Supabase Auth.
 */

import type { FormEvent, ReactNode } from 'react'
import { useEffect, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Eye,
  EyeOff,
  Globe2,
  LockKeyhole,
  Mail,
  ShieldCheck,
  Trophy,
} from 'lucide-react'

import AppButton from '../../components/common/AppButton'
import FormField from '../../components/common/FormField'
import { supabase } from '../../lib/supabase'

interface FormStatus {
  type: 'information' | 'success' | 'error'
  message: string
}

export default function LoginPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [status, setStatus] = useState<FormStatus | null>(null)

  useEffect(() => {
    if (searchParams.get('password') === 'updated') {
      setStatus({ type: 'success', message: 'Your password has been updated. Sign in with your new password.' })
    }
  }, [searchParams])

  const emailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
  const passwordValid = password.length >= 6

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setStatus(null)

    if (!emailValid || !passwordValid || loading) return

    setLoading(true)
    const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim(), password })

    if (error || !data.user) {
      setLoading(false)
      setStatus({
        type: 'error',
        message: error?.message.toLowerCase().includes('email not confirmed')
          ? 'Confirm your email address before signing in. Use the verification email sent after registration.'
          : 'Those sign-in details were not accepted. Check your email and password and try again.',
      })
      return
    }

    const { data: player, error: playerError } = await supabase
      .from('players')
      .select('id')
      .eq('owner_user_id', data.user.id)
      .maybeSingle()

    setLoading(false)

    if (playerError) {
      setStatus({ type: 'error', message: 'Your account is signed in, but your player profile could not be loaded. Try again.' })
      return
    }

    navigate(player ? '/game/overview' : '/create-player', { replace: true })
  }

  return (
    <div className="tlg-auth-page">
      <AuthBackground />

      <header className="tlg-auth-topbar">
        <Link to="/" className="tlg-brand" aria-label="Tennis Legacy homepage">
          <span className="tlg-brand-mark" aria-hidden="true" />
          <span className="tlg-brand-copy">
            <strong className="tlg-brand-name">Tennis Legacy</strong>
            <span className="tlg-brand-subtitle">Rise to Glory</span>
          </span>
        </Link>
        <Link to="/" className="tlg-auth-home-link"><ArrowLeft size={16} /> Home</Link>
      </header>

      <main className="tlg-auth-main">
        <section className="tlg-auth-showcase">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">Manager Access</span>
            <h1>Continue building<strong> your tennis legacy.</strong></h1>
            <p>
              Return to your professional career, manage the next decisions and continue competing in a persistent multiplayer tennis universe.
            </p>

            <div className="tlg-auth-feature-list">
              <AuthFeature icon={<Globe2 size={18} />} title="Persistent career world" description="Your professional identity remains connected across every game season." />
              <AuthFeature icon={<CalendarDays size={18} />} title="Manager operations" description="Prepare tournaments, training, travel, recovery and career decisions." />
              <AuthFeature icon={<Trophy size={18} />} title="Long-term legacy" description="Rankings, titles, records and milestones will build one continuous career history." />
            </div>

            <div className="tlg-auth-career-preview">
              <div className="tlg-auth-career-preview-header">
                <span><ShieldCheck size={15} /> Secure career access</span>
                <span className="tlg-auth-preview-status"><i /> Online</span>
              </div>
              <div className="tlg-auth-career-preview-body">
                <div><span>World</span><strong>ATP or WTA</strong></div>
                <div><span>Career</span><strong>Persistent</strong></div>
                <div><span>Session</span><strong>Protected</strong></div>
              </div>
            </div>
          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><LockKeyhole size={21} /></span>
              <div><span>Secure manager access</span><h2>Sign in</h2></div>
            </div>

            <p className="tlg-auth-card-description">Enter the credentials for your Tennis Legacy manager account.</p>

            <form className="tlg-auth-form" onSubmit={handleSubmit} noValidate>
              <FormField id="login-email" label="Email address" required error={submitted && !emailValid ? 'Enter a valid email address.' : undefined}>
                <div className="tlg-input-shell">
                  <Mail className="tlg-input-leading-icon" size={18} />
                  <input id="login-email" type="email" value={email} onChange={(event) => { setEmail(event.target.value); setStatus(null) }} className={`tlg-input tlg-input-with-leading-icon ${submitted && !emailValid ? 'tlg-input-error' : ''}`} placeholder="manager@example.com" autoComplete="email" />
                </div>
              </FormField>

              <FormField id="login-password" label="Password" required labelAction={<Link className="tlg-auth-inline-action" to="/forgot-password">Forgot password?</Link>} error={submitted && !passwordValid ? 'Enter your account password.' : undefined}>
                <div className="tlg-input-shell">
                  <LockKeyhole className="tlg-input-leading-icon" size={18} />
                  <input id="login-password" type={showPassword ? 'text' : 'password'} value={password} onChange={(event) => { setPassword(event.target.value); setStatus(null) }} className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !passwordValid ? 'tlg-input-error' : ''}`} placeholder="Enter your password" autoComplete="current-password" />
                  <button type="button" className="tlg-input-action" onClick={() => setShowPassword((value) => !value)} aria-label={showPassword ? 'Hide password' : 'Show password'}>{showPassword ? <EyeOff size={18} /> : <Eye size={18} />}</button>
                </div>
              </FormField>

              {status && (
                <div className={`tlg-auth-status ${status.type === 'success' ? 'tlg-auth-status-success' : 'tlg-auth-status-information'}`} role={status.type === 'error' ? 'alert' : 'status'}>
                  <ShieldCheck size={18} /><span>{status.message}</span>
                </div>
              )}

              <AppButton type="submit" variant="primary" size="large" fullWidth loading={loading} rightIcon={<ArrowRight size={18} />}>
                {loading ? 'Signing in…' : 'Enter manager center'}
              </AppButton>
            </form>

            <div className="tlg-auth-divider"><span>New to Tennis Legacy?</span></div>
            <Link to="/register" className="tlg-auth-outline-button">Create a manager account <ArrowRight size={17} /></Link>

            <p className="tlg-auth-supabase-note">Secure authentication · server-side career data · protected manager session</p>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer"><span>Tennis Legacy: Rise to Glory</span><span>Persistent multiplayer tennis management</span></footer>
    </div>
  )
}

function AuthFeature({ icon, title, description }: { icon: ReactNode; title: string; description: string }) {
  return <div className="tlg-auth-feature"><span className="tlg-auth-feature-icon">{icon}</span><div><strong>{title}</strong><p>{description}</p></div></div>
}

function AuthBackground() {
  return <div className="tlg-auth-background" aria-hidden="true"><div className="tlg-auth-background-grid" /><div className="tlg-auth-background-glow-one" /><div className="tlg-auth-background-glow-two" /><div className="tlg-auth-background-court" /></div>
}
