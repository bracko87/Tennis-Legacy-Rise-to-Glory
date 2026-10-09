/**
 * Login.tsx
 *
 * Premium production sign-in connected to Tennis Legacy Supabase Auth.
 */

import type { FormEvent, ReactNode } from 'react'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
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
  const { t } = useTranslation()
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
      setStatus({ type: 'success', message: t('authPages.login.passwordUpdated') })
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
          ? t('authPages.login.emailNotConfirmed')
          : t('authPages.login.invalidCredentials'),
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
      setStatus({ type: 'error', message: t('authPages.login.playerLoadError') })
      return
    }

    navigate(player ? '/game/overview' : '/create-player', { replace: true })
  }

  return (
    <div className="tlg-auth-page tlg-auth-page-v2">
      <AuthBackground />

      <header className="tlg-auth-topbar">
        <Link to="/" className="tlg-brand" aria-label={t('authPages.login.homepageAria')}>
          <span className="tlg-brand-mark" aria-hidden="true" />
          <span className="tlg-brand-copy">
            <strong className="tlg-brand-name">Tennis Legacy</strong>
            <span className="tlg-brand-subtitle">{t('authPages.brandSubtitle')}</span>
          </span>
        </Link>
        <Link to="/" className="tlg-auth-home-link"><ArrowLeft size={16} /> {t('authPages.home')}</Link>
      </header>

      <main className="tlg-auth-main">
        <section className="tlg-auth-showcase tlg-auth-showcase-compact">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">{t('authPages.login.welcome')}</span>
            <h1>{t('authPages.login.heading')}<strong>{t('authPages.login.headingAccent')}</strong></h1>
            <p>
              {t('authPages.login.intro')}
            </p>

            <div className="tlg-auth-feature-list">
              <AuthFeature icon={<Globe2 size={18} />} title={t('authPages.login.feature1Title')} description={t('authPages.login.feature1Body')} />
              <AuthFeature icon={<CalendarDays size={18} />} title={t('authPages.login.feature2Title')} description={t('authPages.login.feature2Body')} />
              <AuthFeature icon={<Trophy size={18} />} title={t('authPages.login.feature3Title')} description={t('authPages.login.feature3Body')} />
            </div>

          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><LockKeyhole size={21} /></span>
              <div><span>{t('authPages.login.accountAccess')}</span><h2>{t('authPages.login.signIn')}</h2></div>
            </div>

            <p className="tlg-auth-card-description">{t('authPages.login.cardBody')}</p>

            <form className="tlg-auth-form" onSubmit={handleSubmit} noValidate>
              <FormField id="login-email" label={t('auth.email')} required error={submitted && !emailValid ? t('authPages.login.emailError') : undefined}>
                <div className="tlg-input-shell">
                  <Mail className="tlg-input-leading-icon" size={18} />
                  <input id="login-email" type="email" value={email} onChange={(event) => { setEmail(event.target.value); setStatus(null) }} className={`tlg-input tlg-input-with-leading-icon ${submitted && !emailValid ? 'tlg-input-error' : ''}`} placeholder="you@example.com" autoComplete="email" />
                </div>
              </FormField>

              <FormField id="login-password" label={t('auth.password')} required labelAction={<Link className="tlg-auth-inline-action" to="/forgot-password">{t('auth.forgotPassword')}</Link>} error={submitted && !passwordValid ? t('authPages.login.passwordError') : undefined}>
                <div className="tlg-input-shell">
                  <LockKeyhole className="tlg-input-leading-icon" size={18} />
                  <input id="login-password" type={showPassword ? 'text' : 'password'} value={password} onChange={(event) => { setPassword(event.target.value); setStatus(null) }} className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !passwordValid ? 'tlg-input-error' : ''}`} placeholder={t('authPages.login.passwordPlaceholder')} autoComplete="current-password" />
                  <button type="button" className="tlg-input-action" onClick={() => setShowPassword((value) => !value)} aria-label={showPassword ? t('authPages.login.hidePassword') : t('authPages.login.showPassword')}>{showPassword ? <EyeOff size={18} /> : <Eye size={18} />}</button>
                </div>
              </FormField>

              {status && (
                <div className={`tlg-auth-status ${status.type === 'success' ? 'tlg-auth-status-success' : 'tlg-auth-status-information'}`} role={status.type === 'error' ? 'alert' : 'status'}>
                  <ShieldCheck size={18} /><span>{status.message}</span>
                </div>
              )}

              <AppButton type="submit" variant="primary" size="large" fullWidth loading={loading} rightIcon={<ArrowRight size={18} />}>
                {loading ? t('auth.signingIn') : t('authPages.login.signIn')}
              </AppButton>
            </form>

            <div className="tlg-auth-divider"><span>{t('authPages.login.newToGame')}</span></div>
            <button
              type="button"
              className="tlg-auth-outline-button tlg-auth-registration-disabled"
              disabled
              aria-disabled="true"
              title={t('authPages.login.registrationClosed')}
            >
              {t('authPages.login.createAccount')} <ArrowRight size={17} />
            </button>

            <p className="tlg-auth-supabase-note">{t('authPages.login.secureNote')}</p>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer"><span>Tennis Legacy: Rise to Glory</span><span>{t('authPages.login.footerFlow')}</span></footer>
    </div>
  )
}

function AuthFeature({ icon, title, description }: { icon: ReactNode; title: string; description: string }) {
  return <div className="tlg-auth-feature"><span className="tlg-auth-feature-icon">{icon}</span><div><strong>{title}</strong><p>{description}</p></div></div>
}

function AuthBackground() {
  return <div className="tlg-auth-background" aria-hidden="true"><div className="tlg-auth-background-grid" /><div className="tlg-auth-background-glow-one" /><div className="tlg-auth-background-glow-two" /><div className="tlg-auth-background-court" /></div>
}
