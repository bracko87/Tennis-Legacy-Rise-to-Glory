import type { FormEvent } from 'react'
import { useState } from 'react'
import { ArrowLeft, Mail, Send } from 'lucide-react'
import { Link } from 'react-router'

import AppButton from '../../components/common/AppButton'
import FormField from '../../components/common/FormField'
import { supabase } from '../../lib/supabase'

export default function ForgotPasswordPage() {
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
      'If an account exists for that email address, a password reset link has been sent. Check your inbox and spam folder.',
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
            <small>Rise to Glory</small>
          </span>
        </Link>
        <Link to="/login" className="tlg-auth-home-link">
          <ArrowLeft size={16} />
          Back to Sign In
        </Link>
      </header>

      <main className="tlg-auth-main">
        <section className="tlg-auth-showcase">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">Account Recovery</span>
            <h1>
              Reset access to
              <strong> your tennis career.</strong>
            </h1>
            <p>
              Enter the email address used for your Tennis Legacy manager account. We will send a secure recovery link when the account is eligible for password recovery.
            </p>
          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><Mail size={21} /></span>
              <div>
                <span>Secure recovery</span>
                <h2>Forgot password</h2>
              </div>
            </div>

            <p className="tlg-auth-card-description">
              We will send the reset link to your registered email address.
            </p>

            <form className="tlg-auth-form" onSubmit={handleSubmit} noValidate>
              <FormField
                id="forgot-email"
                label="Email address"
                required
                error={submitted && !emailValid ? 'Enter a valid email address.' : undefined}
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
                {loading ? 'Sending…' : 'Send Reset Link'}
              </AppButton>
            </form>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer">
        <span>Tennis Legacy: Rise to Glory</span>
        <span>Secure account recovery</span>
      </footer>
    </div>
  )
}
