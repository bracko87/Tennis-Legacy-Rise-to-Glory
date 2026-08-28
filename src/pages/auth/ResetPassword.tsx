import type { FormEvent } from 'react'
import { useState } from 'react'
import { ArrowLeft, CheckCircle2, Eye, EyeOff, LockKeyhole } from 'lucide-react'
import { Link, useNavigate } from 'react-router'

import AppButton from '../../components/common/AppButton'
import FormField from '../../components/common/FormField'
import { supabase } from '../../lib/supabase'

export default function ResetPasswordPage() {
  const navigate = useNavigate()
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const passwordValid =
    password.length >= 8 && /[A-Za-z]/.test(password) && /\d/.test(password)
  const confirmValid = password.length > 0 && password === confirmPassword

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setErrorMessage(null)

    if (!passwordValid || !confirmValid) return

    setLoading(true)
    const { error } = await supabase.auth.updateUser({ password })

    if (error) {
      setLoading(false)
      setErrorMessage(
        'This password reset session is invalid or has expired. Request a new reset link and try again.',
      )
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
          <span className="tlg-auth-brand-copy">
            <strong>Tennis Legacy</strong>
            <small>Rise to Glory</small>
          </span>
        </Link>
        <Link to="/login" className="tlg-auth-home-link">
          <ArrowLeft size={16} />
          Sign In
        </Link>
      </header>

      <main className="tlg-auth-main">
        <section className="tlg-auth-showcase">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">Password Recovery</span>
            <h1>
              Choose a new
              <strong> secure password.</strong>
            </h1>
            <p>
              Your reset link creates a short-lived authenticated recovery session. Once the password is changed, you will be signed out and returned to the normal sign-in page.
            </p>
          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><LockKeyhole size={21} /></span>
              <div>
                <span>Secure account access</span>
                <h2>Set new password</h2>
              </div>
            </div>

            <form className="tlg-auth-form" onSubmit={handleSubmit} noValidate>
              <FormField
                id="reset-password"
                label="New password"
                required
                hint="At least 8 characters with at least one letter and one number."
                error={submitted && !passwordValid ? 'Enter a stronger password.' : undefined}
              >
                <div className="tlg-input-shell">
                  <LockKeyhole className="tlg-input-leading-icon" size={18} aria-hidden="true" />
                  <input
                    id="reset-password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                    className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !passwordValid ? 'tlg-input-error' : ''}`}
                    autoComplete="new-password"
                    placeholder="Create a new password"
                  />
                  <button
                    type="button"
                    className="tlg-input-action"
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                    onClick={() => setShowPassword((current) => !current)}
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </FormField>

              <FormField
                id="reset-password-confirm"
                label="Confirm new password"
                required
                error={submitted && !confirmValid ? 'The passwords do not match.' : undefined}
              >
                <input
                  id="reset-password-confirm"
                  type="password"
                  value={confirmPassword}
                  onChange={(event) => setConfirmPassword(event.target.value)}
                  className={`tlg-input ${submitted && !confirmValid ? 'tlg-input-error' : ''}`}
                  autoComplete="new-password"
                  placeholder="Repeat the new password"
                />
              </FormField>

              {errorMessage && (
                <div className="tlg-auth-status tlg-auth-status-information" role="alert">
                  <span>{errorMessage}</span>
                </div>
              )}

              <AppButton
                type="submit"
                variant="primary"
                size="large"
                fullWidth
                disabled={loading}
                rightIcon={<CheckCircle2 size={18} />}
              >
                {loading ? 'Updating…' : 'Update Password'}
              </AppButton>
            </form>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer">
        <span>Tennis Legacy: Rise to Glory</span>
        <span>Secure password recovery</span>
      </footer>
    </div>
  )
}
