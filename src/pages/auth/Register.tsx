/**
 * Register.tsx
 *
 * Premium manager registration connected to the Tennis Legacy Supabase Auth
 * project. Manager metadata is copied into public.profiles by the database
 * signup trigger.
 */

import type { FormEvent } from 'react'
import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Check,
  Eye,
  EyeOff,
  LockKeyhole,
  Mail,
  ShieldCheck,
  UserRound,
} from 'lucide-react'

import AppButton from '../../components/common/AppButton'
import FormField from '../../components/common/FormField'
import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import { clearStoredReferralCode, getReferralBrowserHash, getStoredReferralCode } from '../../lib/referrals'
import { supabase } from '../../lib/supabase'

const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

interface FormStatus {
  type: 'success' | 'error'
  message: string
}

type RegisterStep = 1 | 2 | 3

const REGISTER_STEPS: Array<{ id: RegisterStep; title: string; subtitle: string }> = [
  { id: 1, title: 'Account Details', subtitle: 'Username & email' },
  { id: 2, title: 'Security', subtitle: 'Password' },
  { id: 3, title: 'Date of Birth', subtitle: 'Month & day' },
]

export default function RegisterPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [username, setUsername] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [month, setMonth] = useState('')
  const [day, setDay] = useState('')
  const [year, setYear] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [status, setStatus] = useState<FormStatus | null>(null)
  const [registrationComplete, setRegistrationComplete] = useState(false)
  const [inviteEmail, setInviteEmail] = useState<string | null>(null)
  const [inviteBonusCoins, setInviteBonusCoins] = useState<number | null>(null)
  const [inviteLoading, setInviteLoading] = useState(false)
  const [registerStep, setRegisterStep] = useState<RegisterStep>(1)
  const [attemptedStep, setAttemptedStep] = useState<RegisterStep | null>(null)

  const inviteToken = searchParams.get('invite')?.trim() ?? ''

  useEffect(() => {
    let active = true

    async function loadInvite() {
      if (!inviteToken) return

      setInviteLoading(true)
      const { data, error } = await supabase.rpc('get_registration_invite_v1', {
        p_token: inviteToken,
      })

      if (!active) return
      setInviteLoading(false)

      if (error) {
        setStatus({
          type: 'error',
          message: 'This registration invitation could not be validated.',
        })
        return
      }

      const row = Array.isArray(data) ? data[0] : null
      const invitedEmail = typeof row?.email === 'string' ? row.email.trim().toLowerCase() : ''
      const bonusCoins = Number(row?.bonus_coins ?? 0)

      if (!invitedEmail) {
        setStatus({
          type: 'error',
          message: 'This registration invitation is invalid or has expired.',
        })
        return
      }

      setInviteEmail(invitedEmail)
      setInviteBonusCoins(Number.isFinite(bonusCoins) ? bonusCoins : 0)
      setEmail(invitedEmail)
      setStatus(null)
    }

    void loadInvite()
    return () => {
      active = false
    }
  }, [inviteToken])

  const currentYear = new Date().getFullYear()
  const usernameValid = /^[A-Za-z0-9_.-]{3,24}$/.test(username.trim())
  const emailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
  const passwordChecks = {
    length: password.length >= 8,
    letter: /[A-Za-z]/.test(password),
    number: /\d/.test(password),
  }
  const passwordValid = passwordChecks.length && passwordChecks.letter && passwordChecks.number
  const confirmPasswordValid = confirmPassword.length > 0 && password === confirmPassword
  const yearProvided = year.trim().length > 0
  const yearValid = !yearProvided || (/^\d{4}$/.test(year) && Number(year) >= 1900 && Number(year) <= currentYear)

  const availableDays = useMemo(() => createAvailableDays(month, year), [month, year])
  const birthdayDate = month && day && yearProvided && yearValid
    ? new Date(Number(year), Number(month) - 1, Number(day), 12, 0, 0, 0)
    : null
  const birthdayNotFuture = !yearProvided || (birthdayDate ? birthdayDate.getTime() <= Date.now() : false)
  const birthdayValid = month.length > 0
    && day.length > 0
    && Number(day) <= availableDays.length
    && yearValid
    && birthdayNotFuture

  const accountStepValid = usernameValid && emailValid
  const securityStepValid = passwordValid && confirmPasswordValid
  const formValid = accountStepValid && securityStepValid && birthdayValid
  const currentRegisterStep = REGISTER_STEPS.find((item) => item.id === registerStep) ?? REGISTER_STEPS[0]

  function clearStatus() {
    if (status) setStatus(null)
  }

  function goToNextRegistrationStep() {
    setAttemptedStep(registerStep)
    setStatus(null)

    if (registerStep === 1 && !accountStepValid) return
    if (registerStep === 2 && !securityStepValid) return
    if (registerStep >= 3) return

    setAttemptedStep(null)
    setRegisterStep((registerStep + 1) as RegisterStep)
  }

  function goToPreviousRegistrationStep() {
    if (registerStep <= 1 || loading) return
    setAttemptedStep(null)
    setStatus(null)
    setRegisterStep((registerStep - 1) as RegisterStep)
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setStatus(null)

    if (!formValid || loading) return
    setConfirmOpen(true)
  }

  async function createAccount() {
    if (!formValid || loading) return

    const normalizedEmail = email.trim().toLowerCase()
    const referralCode = getStoredReferralCode()
    const referralBrowserHash = referralCode ? await getReferralBrowserHash() : null
    const birthdayTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'

    setLoading(true)
    const { data, error } = await supabase.auth.signUp({
      email: normalizedEmail,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/create-player`,
        data: {
          username: username.trim(),
          birthday_month: Number(month),
          birthday_day: Number(day),
          birthday_year: yearProvided ? Number(year) : null,
          birthday_timezone: birthdayTimezone,
          ...(referralCode ? { referral_code: referralCode, referral_browser_hash: referralBrowserHash } : {}),
          ...(inviteToken ? { registration_invite_token: inviteToken } : {}),
        },
      },
    })
    setLoading(false)

    if (error) {
      setConfirmOpen(false)
      setStatus({ type: 'error', message: mapSignupError(error.message) })
      return
    }

    if (referralCode) clearStoredReferralCode()

    if (data.session) {
      navigate('/create-player', { replace: true })
      return
    }

    setConfirmOpen(false)
    setRegistrationComplete(true)
    setStatus({
      type: 'success',
      message: 'Account created. Check your inbox and confirm your email. After verification, Tennis Legacy will take you to Create Your Player.',
    })
  }

  return (
    <div className="tlg-auth-page tlg-auth-register-page tlg-auth-page-v2">
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

      <main className="tlg-auth-main tlg-auth-register-main">
        <section className="tlg-auth-showcase tlg-auth-showcase-compact">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">Create Account</span>
            <h1>Create your account.<strong> Your player comes next.</strong></h1>
            <p>
              First create the real account you use to sign in. After email verification, you will create the fictional tennis player for your career.
            </p>

          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card tlg-auth-register-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><UserRound size={21} /></span>
              <div><span>Account setup</span><h2>Create Account</h2></div>
            </div>

            <p className="tlg-auth-card-description">Your account is your login and ownership identity. Your tennis player is created separately after verification.</p>

            {registrationComplete ? (
              <div className="tlg-auth-verification-panel" role="status">
                <span className="tlg-auth-verification-icon"><Mail size={24} /></span>
                <span className="tlg-auth-eyebrow">Email verification</span>
                <h3>Check your email</h3>
                <p>
                  We sent a verification link to <strong>{email.trim().toLowerCase()}</strong>.
                  Open it to verify your account. Tennis Legacy will then take you directly to <strong>Create Your Player</strong>.
                </p>
                <div className="tlg-auth-verification-next">
                  <span>Next</span>
                  <strong>Create Your Player → Start Career</strong>
                </div>
                <Link to="/login" className="tlg-auth-inline-action">Already verified? Go to Sign In</Link>
              </div>
            ) : (
              <>
                <div className="tlg-register-stepper" aria-label="Create account progress">
                  {REGISTER_STEPS.map((item) => {
                    const active = item.id === registerStep
                    const complete = item.id < registerStep
                    return (
                      <div
                        key={item.id}
                        className={`tlg-register-step ${active ? 'active' : ''} ${complete ? 'complete' : ''}`}
                        aria-current={active ? 'step' : undefined}
                      >
                        <span className="tlg-register-step-number">{complete ? <Check size={14} /> : item.id}</span>
                        <span className="tlg-register-step-copy">
                          <strong>{item.title}</strong>
                          <small>{item.subtitle}</small>
                        </span>
                      </div>
                    )
                  })}
                </div>

                <form className="tlg-auth-form tlg-auth-register-form tlg-auth-register-wizard" onSubmit={handleSubmit} noValidate>
                  <section className="tlg-register-wizard-stage">
                    <header className="tlg-register-wizard-stage-head">
                      <div>
                        <span>Step {registerStep} of 3</span>
                        <h3>{currentRegisterStep.title}</h3>
                      </div>
                      <strong>{Math.round((registerStep / 3) * 100)}%</strong>
                    </header>

                    <div className="tlg-register-wizard-stage-body">
                      {registerStep === 1 && (
                        <div className="tlg-register-step-content">
                          <p className="tlg-register-step-intro">
                            Create the account identity you will use to sign in. Your tennis player will have a separate name and profile.
                          </p>

                          <div className="tlg-auth-form-grid">
                            <FormField
                              id="register-username"
                              label="Account username"
                              required
                              hint="This identifies your account. Your player will have a separate first and last name."
                              error={attemptedStep === 1 && !usernameValid ? 'Enter a valid 3–24 character username.' : undefined}
                            >
                              <div className="tlg-input-shell">
                                <UserRound className="tlg-input-leading-icon" size={18} />
                                <input
                                  id="register-username"
                                  value={username}
                                  onChange={(event) => { setUsername(event.target.value); clearStatus() }}
                                  className={`tlg-input tlg-input-with-leading-icon ${attemptedStep === 1 && !usernameValid ? 'tlg-input-error' : ''}`}
                                  placeholder="Choose a username"
                                  autoComplete="username"
                                  maxLength={24}
                                />
                              </div>
                            </FormField>

                            <FormField
                              id="register-email"
                              label="Email address"
                              required
                              hint="One Tennis Legacy account per email address."
                              error={attemptedStep === 1 && !emailValid ? 'Enter a valid email address.' : undefined}
                            >
                              <div className="tlg-input-shell">
                                <Mail className="tlg-input-leading-icon" size={18} />
                                <input
                                  id="register-email"
                                  type="email"
                                  value={email}
                                  onChange={(event) => {
                                    if (inviteEmail) return
                                    setEmail(event.target.value)
                                    clearStatus()
                                  }}
                                  className={`tlg-input tlg-input-with-leading-icon ${attemptedStep === 1 && !emailValid ? 'tlg-input-error' : ''}`}
                                  placeholder="you@example.com"
                                  autoComplete="email"
                                  readOnly={Boolean(inviteEmail)}
                                  aria-readonly={Boolean(inviteEmail)}
                                />
                              </div>
                            </FormField>
                          </div>

                          {inviteToken && (
                            <div className="tlg-auth-status tlg-auth-status-success" role="status">
                              <ShieldCheck size={18} />
                              <span>
                                {inviteLoading
                                  ? 'Validating registration invitation…'
                                  : inviteEmail
                                    ? `Registration invitation confirmed. ${inviteBonusCoins ?? 0} Coins will be added automatically when the account is created.`
                                    : 'Registration invitation could not be validated.'}
                              </span>
                            </div>
                          )}
                        </div>
                      )}

                      {registerStep === 2 && (
                        <div className="tlg-register-step-content">
                          <p className="tlg-register-step-intro">
                            Choose the password you will use to access this Tennis Legacy account.
                          </p>

                          <div className="tlg-auth-form-grid">
                            <FormField
                              id="register-password"
                              label="Password"
                              required
                              error={attemptedStep === 2 && !passwordValid ? 'Use at least 8 characters with a letter and number.' : undefined}
                            >
                              <div className="tlg-input-shell">
                                <LockKeyhole className="tlg-input-leading-icon" size={18} />
                                <input
                                  id="register-password"
                                  type={showPassword ? 'text' : 'password'}
                                  value={password}
                                  onChange={(event) => { setPassword(event.target.value); clearStatus() }}
                                  className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${attemptedStep === 2 && !passwordValid ? 'tlg-input-error' : ''}`}
                                  placeholder="Create a password"
                                  autoComplete="new-password"
                                />
                                <button type="button" className="tlg-input-action" onClick={() => setShowPassword((value) => !value)} aria-label={showPassword ? 'Hide password' : 'Show password'}>
                                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                                </button>
                              </div>
                            </FormField>

                            <FormField
                              id="register-confirm-password"
                              label="Confirm password"
                              required
                              error={attemptedStep === 2 && !confirmPasswordValid ? 'The passwords do not match.' : undefined}
                              success={confirmPasswordValid ? 'Passwords match.' : undefined}
                            >
                              <div className="tlg-input-shell">
                                <LockKeyhole className="tlg-input-leading-icon" size={18} />
                                <input
                                  id="register-confirm-password"
                                  type={showConfirmPassword ? 'text' : 'password'}
                                  value={confirmPassword}
                                  onChange={(event) => { setConfirmPassword(event.target.value); clearStatus() }}
                                  className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${attemptedStep === 2 && !confirmPasswordValid ? 'tlg-input-error' : ''} ${confirmPasswordValid ? 'tlg-input-success' : ''}`}
                                  placeholder="Repeat your password"
                                  autoComplete="new-password"
                                />
                                <button type="button" className="tlg-input-action" onClick={() => setShowConfirmPassword((value) => !value)} aria-label={showConfirmPassword ? 'Hide password' : 'Show password'}>
                                  {showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                                </button>
                              </div>
                            </FormField>
                          </div>

                          <div className="tlg-password-requirements tlg-password-requirements-v2">
                            <PasswordRequirement passed={passwordChecks.length} text="At least 8 characters" />
                            <PasswordRequirement passed={passwordChecks.letter} text="At least one letter" />
                            <PasswordRequirement passed={passwordChecks.number} text="At least one number" />
                          </div>
                        </div>
                      )}

                      {registerStep === 3 && (
                        <div className="tlg-register-step-content">
                          <p className="tlg-register-step-intro">
                            Month and day are required for the annual account birthday gift. The birth year is optional and is not used for your tennis player's age.
                          </p>

                          <div className="tlg-birthday-panel tlg-birthday-panel-v2 tlg-birthday-wizard-panel">
                            <div className="tlg-birthday-panel-heading">
                              <span><CalendarDays size={19} /></span>
                              <div>
                                <h3>Account holder date of birth</h3>
                                <p>This belongs to your account, not to your fictional tennis player.</p>
                              </div>
                            </div>

                            <p className="tlg-birthday-warning">
                              Month and day cannot be changed after registration. If you enter a year, check it carefully as well.
                            </p>

                            <FormField
                              id="birth-month"
                              label="Date of birth"
                              required
                              hint="Month and day are required. Year is optional."
                              error={submitted && !birthdayValid ? 'Enter a valid month and day. If you provide a year, it must be valid.' : undefined}
                            >
                              <div className="tlg-birthday-fields">
                                <select
                                  id="birth-month"
                                  value={month}
                                  onChange={(event) => {
                                    const value = event.target.value
                                    setMonth(value)
                                    if (day && Number(day) > createAvailableDays(value, year).length) setDay('')
                                    clearStatus()
                                  }}
                                  className={`tlg-input ${submitted && !birthdayValid ? 'tlg-input-error' : ''}`}
                                >
                                  <option value="">Month</option>
                                  {MONTHS.map((label, index) => <option key={label} value={String(index + 1)}>{label}</option>)}
                                </select>

                                <select
                                  value={day}
                                  onChange={(event) => { setDay(event.target.value); clearStatus() }}
                                  className={`tlg-input ${submitted && !birthdayValid ? 'tlg-input-error' : ''}`}
                                  aria-label="Birthday day"
                                >
                                  <option value="">Day</option>
                                  {availableDays.map((value) => <option key={value} value={String(value)}>{value}</option>)}
                                </select>

                                <div className="tlg-optional-year-field">
                                  <span>Optional</span>
                                  <input
                                    value={year}
                                    onChange={(event) => {
                                      const value = event.target.value.replace(/\D/g, '').slice(0, 4)
                                      setYear(value)
                                      if (day && Number(day) > createAvailableDays(month, value).length) setDay('')
                                      clearStatus()
                                    }}
                                    className={`tlg-input ${submitted && !yearValid ? 'tlg-input-error' : ''}`}
                                    placeholder="Year"
                                    inputMode="numeric"
                                    autoComplete="bday-year"
                                    aria-label="Birthday year, optional"
                                  />
                                </div>
                              </div>
                            </FormField>
                          </div>

                          {status && (
                            <div className={`tlg-auth-status ${status.type === 'success' ? 'tlg-auth-status-success' : 'tlg-auth-status-information'}`} role={status.type === 'error' ? 'alert' : 'status'}>
                              <ShieldCheck size={18} />
                              <span>{status.message}</span>
                            </div>
                          )}
                        </div>
                      )}
                    </div>

                    <footer className="tlg-register-wizard-nav">
                      <div>
                        {registerStep > 1 && (
                          <AppButton type="button" variant="secondary" size="large" onClick={goToPreviousRegistrationStep} disabled={loading}>
                            Back
                          </AppButton>
                        )}
                      </div>

                      <span className="tlg-register-wizard-nav-status">
                        {registerStep < 3 ? 'Complete this step to continue.' : 'Ready to create your account.'}
                      </span>

                      {registerStep < 3 ? (
                        <AppButton
                          type="button"
                          variant="primary"
                          size="large"
                          onClick={goToNextRegistrationStep}
                          rightIcon={<ArrowRight size={18} />}
                        >
                          Continue
                        </AppButton>
                      ) : (
                        <AppButton
                          type="submit"
                          variant="primary"
                          size="large"
                          loading={loading}
                          disabled={loading}
                          rightIcon={<ArrowRight size={18} />}
                        >
                          {loading ? 'Creating account…' : 'Create Account'}
                        </AppButton>
                      )}
                    </footer>
                  </section>
                </form>

                <div className="tlg-auth-divider"><span>Already have an account?</span></div>
                <Link to="/login" className="tlg-auth-outline-button">Sign In <ArrowRight size={17} /></Link>
              </>
            )}
            <p className="tlg-auth-supabase-note">Secure account authentication. Player and career data remain separate from your login details.</p>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer"><span>Tennis Legacy: Rise to Glory</span><span>Account → Verify → Player</span></footer>

      <GameConfirmDialog
        open={confirmOpen}
        eyebrow="Permanent account information"
        title="Confirm your account birthday"
        message={
          <span>
            You entered <strong>{day} {MONTHS[Math.max(0, Number(month) - 1)]}{yearProvided ? ` ${year}` : ''}</strong>.
            {yearProvided
              ? ' This account birthday cannot be changed after registration.'
              : ' You chose not to provide a birth year. Month and day cannot be changed after registration.'}
          </span>
        }
        detail="Please correct it now if anything is wrong. The annual 20-Coin Birthday Gift uses the month and day."
        confirmLabel="Confirm & Create Account"
        cancelLabel="Go back and edit"
        busy={loading}
        tone="warning"
        onConfirm={createAccount}
        onCancel={() => setConfirmOpen(false)}
      />
    </div>
  )
}

function mapSignupError(message: string) {
  const normalized = message.toLowerCase()
  if (normalized.includes('weak') || normalized.includes('easy to guess') || normalized.includes('pwned') || normalized.includes('leaked')) {
    return 'That password appears in known password-leak data or is too easy to guess. Choose a different, unique password.'
  }
  if (normalized.includes('already') || normalized.includes('duplicate') || normalized.includes('registered')) {
    return 'An account already exists with this email address or username. Sign in if this email belongs to you, or use another available username.'
  }
  if (normalized.includes('database error')) {
    return 'That username or email address is already unavailable. Choose another username or sign in if you already have an account.'
  }
  if (normalized.includes('rate') || normalized.includes('too many')) {
    return 'Too many registration attempts were made. Wait a moment and try again.'
  }
  return 'We could not create your account. Review the information and try again.'
}

function createAvailableDays(month: string, year: string) {
  const monthNumber = Number(month)
  if (!monthNumber) return Array.from({ length: 31 }, (_, index) => index + 1)
  if ([4, 6, 9, 11].includes(monthNumber)) return Array.from({ length: 30 }, (_, index) => index + 1)
  if (monthNumber === 2) {
    const length = year.length === 4 && !isLeapYear(Number(year)) ? 28 : 29
    return Array.from({ length }, (_, index) => index + 1)
  }
  return Array.from({ length: 31 }, (_, index) => index + 1)
}

function isLeapYear(year: number) {
  return year % 400 === 0 || (year % 4 === 0 && year % 100 !== 0)
}

function PasswordRequirement({ passed, text }: { passed: boolean; text: string }) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '5px',
        flex: '0 0 auto',
        whiteSpace: 'nowrap',
        padding: 0,
        margin: 0,
        border: 0,
        borderRadius: 0,
        background: 'transparent',
        boxShadow: 'none',
        color: passed ? '#1d6f9f' : '#547188',
        fontSize: '12px',
        fontWeight: 600,
      }}
    >
      <Check size={13} />
      {text}
    </span>
  )
}

function AuthBackground() {
  return <div className="tlg-auth-background" aria-hidden="true"><div className="tlg-auth-background-grid" /><div className="tlg-auth-background-glow-one" /><div className="tlg-auth-background-glow-two" /><div className="tlg-auth-background-court" /></div>
}
