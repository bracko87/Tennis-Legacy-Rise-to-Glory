import type { FormEvent } from 'react'
import { useState } from 'react'
import { ArrowLeft, CheckCircle2, Eye, EyeOff, LockKeyhole } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { Link, useNavigate } from 'react-router'

import AppButton from '../../components/common/AppButton'
import FormField from '../../components/common/FormField'
import { supabase } from '../../lib/supabase'

export default function ResetPasswordPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const passwordValid = password.length >= 8 && /[A-Za-z]/.test(password) && /\d/.test(password)
  const confirmValid = password.length > 0 && password === confirmPassword

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setErrorMessage(null)

    if (!passwordValid || !confirmValid || loading) return

    setLoading(true)
    const { error } = await supabase.auth.updateUser({ password })

    if (error) {
      setLoading(false)
      setErrorMessage(mapPasswordError(error.message, t))
      return
    }

    await supabase.auth.signOut()
    setLoading(false)
    navigate('/login?password=updated', { replace: true })
  }

  return (
    <div className="tlg-auth-page">
      <div className="tlg-auth-background" aria-hidden="true">
        <div className="tlg-auth-background-grid" />
        <div className="tlg-auth-background-glow-one" />
        <div className="tlg-auth-background-glow-two" />
        <div className="tlg-auth-background-court" />
      </div>

      <header className="tlg-auth-topbar">
        <Link to="/" className="tlg-auth-brand">
          <span className="tlg-auth-brand-copy"><strong>Tennis Legacy</strong><small>{t('authPages.brandSubtitle')}</small></span>
        </Link>
        <Link to="/login" className="tlg-auth-home-link"><ArrowLeft size={16} /> {t('authPages.reset.signIn')}</Link>
      </header>

      <main className="tlg-auth-main">
        <section className="tlg-auth-showcase">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">{t('authPages.reset.eyebrow')}</span>
            <h1>{t('authPages.reset.heading')}<strong>{t('authPages.reset.headingAccent')}</strong></h1>
            <p>
              {t('authPages.reset.intro')}
            </p>
          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><LockKeyhole size={21} /></span>
              <div><span>{t('authPages.reset.secureAccess')}</span><h2>{t('authPages.reset.title')}</h2></div>
            </div>

            <p className="tlg-auth-card-description">{t('authPages.reset.cardBody')}</p>

            <form className="tlg-auth-form" onSubmit={handleSubmit} noValidate>
              <FormField id="reset-password" label={t('auth.newPassword')} required hint={t('authPages.reset.hint')} error={submitted && !passwordValid ? t('authPages.reset.weak') : undefined}>
                <div className="tlg-input-shell">
                  <LockKeyhole className="tlg-input-leading-icon" size={18} />
                  <input id="reset-password" type={showPassword ? 'text' : 'password'} value={password} onChange={(event) => { setPassword(event.target.value); setErrorMessage(null) }} className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !passwordValid ? 'tlg-input-error' : ''}`} autoComplete="new-password" placeholder={t('authPages.reset.placeholder')} />
                  <button type="button" className="tlg-input-action" aria-label={showPassword ? t('authPages.reset.hide') : t('authPages.reset.show')} onClick={() => setShowPassword((current) => !current)}>{showPassword ? <EyeOff size={18} /> : <Eye size={18} />}</button>
                </div>
              </FormField>

              <FormField id="reset-password-confirm" label={t('authPages.reset.confirm')} required error={submitted && !confirmValid ? t('authPages.reset.mismatch') : undefined} success={confirmValid ? t('authPages.reset.match') : undefined}>
                <div className="tlg-input-shell">
                  <LockKeyhole className="tlg-input-leading-icon" size={18} />
                  <input id="reset-password-confirm" type={showConfirmPassword ? 'text' : 'password'} value={confirmPassword} onChange={(event) => { setConfirmPassword(event.target.value); setErrorMessage(null) }} className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !confirmValid ? 'tlg-input-error' : ''} ${confirmValid ? 'tlg-input-success' : ''}`} autoComplete="new-password" placeholder={t('authPages.reset.confirmPlaceholder')} />
                  <button type="button" className="tlg-input-action" aria-label={showConfirmPassword ? t('authPages.reset.hide') : t('authPages.reset.show')} onClick={() => setShowConfirmPassword((current) => !current)}>{showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}</button>
                </div>
              </FormField>

              {errorMessage && <div className="tlg-auth-status tlg-auth-status-information" role="alert"><span>{errorMessage}</span></div>}

              <AppButton type="submit" variant="primary" size="large" fullWidth loading={loading} rightIcon={<CheckCircle2 size={18} />}>
                {loading ? t('authPages.reset.updating') : t('authPages.reset.update')}
              </AppButton>
            </form>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer"><span>Tennis Legacy: Rise to Glory</span><span>{t('authPages.reset.footer')}</span></footer>
    </div>
  )
}

function mapPasswordError(message: string, t: ReturnType<typeof useTranslation>['t']) {
  const normalized = message.toLowerCase()
  if (normalized.includes('weak') || normalized.includes('easy to guess') || normalized.includes('pwned') || normalized.includes('leaked')) {
    return t('authPages.reset.leaked')
  }
  if (normalized.includes('same password') || normalized.includes('different from')) {
    return t('authPages.reset.same')
  }
  return t('authPages.reset.expired')
}
