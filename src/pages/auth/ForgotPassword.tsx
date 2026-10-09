import type { FormEvent } from 'react'
import { useState } from 'react'
import { ArrowLeft, Mail, Send } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'

import AppButton from '../../components/common/AppButton'
import FormField from '../../components/common/FormField'
import { supabase } from '../../lib/supabase'

export default function ForgotPasswordPage() {
  const { t } = useTranslation()
  const [email, setEmail] = useState('')
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  const emailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setMessage(null)

    if (!emailValid) return

    setLoading(true)
    const redirectTo = `${window.location.origin}/reset-password`
    await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo })
    setLoading(false)

    // Always use the same response so this form does not reveal whether an account exists.
    setMessage(
      t('authPages.forgot.sent'),
    )
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
          <span className="tlg-auth-brand-copy">
            <strong>Tennis Legacy</strong>
            <small>{t('authPages.brandSubtitle')}</small>
          </span>
        </Link>
        <Link to="/login" className="tlg-auth-home-link">
          <ArrowLeft size={16} />
          {t('authPages.forgot.back')}
        </Link>
      </header>

      <main className="tlg-auth-main">
        <section className="tlg-auth-showcase">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">{t('authPages.forgot.eyebrow')}</span>
            <h1>
              {t('authPages.forgot.heading')}<strong>{t('authPages.forgot.headingAccent')}</strong>
            </h1>
            <p>
              {t('authPages.forgot.intro')}
            </p>
          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><Mail size={21} /></span>
              <div>
                <span>{t('authPages.forgot.secureRecovery')}</span>
                <h2>{t('authPages.forgot.title')}</h2>
              </div>
            </div>

            <p className="tlg-auth-card-description">
              {t('authPages.forgot.cardBody')}
            </p>

            <form className="tlg-auth-form" onSubmit={handleSubmit} noValidate>
              <FormField
                id="forgot-email"
                label={t('auth.email')}
                required
                error={submitted && !emailValid ? t('authPages.forgot.emailError') : undefined}
              >
                <div className="tlg-input-shell">
                  <Mail className="tlg-input-leading-icon" size={18} aria-hidden="true" />
                  <input
                    id="forgot-email"
                    type="email"
                    value={email}
                    onChange={(event) => {
                      setEmail(event.target.value)
                      setMessage(null)
                    }}
                    className={`tlg-input tlg-input-with-leading-icon ${submitted && !emailValid ? 'tlg-input-error' : ''}`}
                    placeholder="manager@example.com"
                    autoComplete="email"
                  />
                </div>
              </FormField>

              {message && (
                <div className="tlg-auth-status tlg-auth-status-success" role="status">
                  <span>{message}</span>
                </div>
              )}

              <AppButton
                type="submit"
                variant="primary"
                size="large"
                fullWidth
                disabled={loading}
                rightIcon={<Send size={18} />}
              >
                {loading ? t('auth.sending') : t('auth.sendResetLink')}
              </AppButton>
            </form>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer">
        <span>Tennis Legacy: Rise to Glory</span>
        <span>{t('authPages.forgot.footer')}</span>
      </footer>
    </div>
  )
}
