/**
 * Register.tsx
 *
 * Premium manager registration connected to the Tennis Legacy Supabase Auth
 * project. Manager metadata is copied into public.profiles by the database
 * signup trigger.
 */

import type { FormEvent, ReactNode } from 'react'
import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Check,
  Eye,
  EyeOff,
  Globe2,
  LockKeyhole,
  Mail,
  ShieldCheck,
  Trophy,
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
  const [inviteEmail, setInviteEmail] = useState<string | null>(null)
  const [inviteBonusCoins, setInviteBonusCoins] = useState<number | null>(null)
  const [inviteLoading, setInviteLoading] = useState(false)

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
  const yearValid = /^\d{4}$/.test(year) && Number(year) >= 1900 && Number(year) <= currentYear

  const availableDays = useMemo(() => createAvailableDays(month, year), [month, year])
  const birthdayDate = month && day && yearValid ? new Date(Number(year), Number(month) - 1, Number(day), 12, 0, 0, 0) : null
  const birthdayNotFuture = birthdayDate ? birthdayDate.getTime() <= Date.now() : false
  const birthdayValid = month.length > 0 && day.length > 0 && Number(day) <= availableDays.length && yearValid && birthdayNotFuture
  const formValid = usernameValid && emailValid && passwordValid && confirmPasswordValid && birthdayValid

  function clearStatus() {
    if (status) setStatus(null)
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
          birthday_year: Number(year),
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
    setStatus({
      type: 'success',
      message: 'Account created. Check your inbox and confirm your email address to continue to player creation.',
    })
  }

  return (
    <div className="tlg-auth-page tlg-auth-register-page">
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
        <section className="tlg-auth-showcase">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">Start Your Journey</span>
            <h1>Create the manager behind<strong> a future champion.</strong></h1>
            <p>
              Register your manager account, verify your email and create the ATP or WTA professional who will represent your career in the persistent Tennis Legacy world.
            </p>

            <div className="tlg-auth-feature-list">
              <AuthFeature icon={<UserRound size={18} />} title="Own one professional career" description="Create a realistic identity and build it season after season." />
              <AuthFeature icon={<Globe2 size={18} />} title="Join a shared universe" description="Your player lives in the same competitive ecosystem as other managers." />
              <AuthFeature icon={<Trophy size={18} />} title="Build a legacy" description="Rankings, titles, records and career history will persist across seasons." />
            </div>
          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card tlg-auth-register-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><UserRound size={21} /></span>
              <div><span>Manager registration</span><h2>Create account</h2></div>
            </div>

            <p className="tlg-auth-card-description">Create your secure manager identity before building your professional player.</p>

            <form className="tlg-auth-form" onSubmit={handleSubmit} noValidate>
              <div className="tlg-auth-form-grid">
                <FormField id="register-username" label="Username" required hint={!submitted ? '3–24 characters · letters, numbers, dots, dashes and underscores.' : undefined} error={submitted && !usernameValid ? 'Enter a valid 3–24 character username.' : undefined}>
                  <div className="tlg-input-shell">
                    <UserRound className="tlg-input-leading-icon" size={18} />
                    <input id="register-username" value={username} onChange={(event) => { setUsername(event.target.value); clearStatus() }} className={`tlg-input tlg-input-with-leading-icon ${submitted && !usernameValid ? 'tlg-input-error' : ''}`} placeholder="Choose a username" autoComplete="username" maxLength={24} />
                  </div>
                </FormField>

                <FormField id="register-email" label="Email address" required hint={!submitted ? 'One manager account per email address.' : undefined} error={submitted && !emailValid ? 'Enter a valid email address.' : undefined}>
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
                      className={`tlg-input tlg-input-with-leading-icon ${submitted && !emailValid ? 'tlg-input-error' : ''}`}
                      placeholder="manager@example.com"
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

              <div className="tlg-auth-form-grid">
                <FormField id="register-password" label="Password" required error={submitted && !passwordValid ? 'Use at least 8 characters with a letter and number.' : undefined}>
                  <div className="tlg-input-shell">
                    <LockKeyhole className="tlg-input-leading-icon" size={18} />
                    <input id="register-password" type={showPassword ? 'text' : 'password'} value={password} onChange={(event) => { setPassword(event.target.value); clearStatus() }} className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !passwordValid ? 'tlg-input-error' : ''}`} placeholder="Create a password" autoComplete="new-password" />
                    <button type="button" className="tlg-input-action" onClick={() => setShowPassword((value) => !value)} aria-label={showPassword ? 'Hide password' : 'Show password'}>{showPassword ? <EyeOff size={18} /> : <Eye size={18} />}</button>
                  </div>
                </FormField>

                <FormField id="register-confirm-password" label="Confirm password" required error={submitted && !confirmPasswordValid ? 'The passwords do not match.' : undefined} success={confirmPasswordValid ? 'Passwords match.' : undefined}>
                  <div className="tlg-input-shell">
                    <LockKeyhole className="tlg-input-leading-icon" size={18} />
                    <input id="register-confirm-password" type={showConfirmPassword ? 'text' : 'password'} value={confirmPassword} onChange={(event) => { setConfirmPassword(event.target.value); clearStatus() }} className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !confirmPasswordValid ? 'tlg-input-error' : ''} ${confirmPasswordValid ? 'tlg-input-success' : ''}`} placeholder="Repeat your password" autoComplete="new-password" />
                    <button type="button" className="tlg-input-action" onClick={() => setShowConfirmPassword((value) => !value)} aria-label={showConfirmPassword ? 'Hide password' : 'Show password'}>{showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}</button>
                  </div>
                </FormField>
              </div>

              <div
                className="tlg-password-requirements"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  flexWrap: 'nowrap',
                  gap: '18px',
                  width: '100%',
                  background: 'transparent',
                  border: 0,
                  padding: 0,
                  boxShadow: 'none',
                }}
              >
                <PasswordRequirement passed={passwordChecks.length} text="At least 8 characters" />
                <PasswordRequirement passed={passwordChecks.letter} text="At least one letter" />
                <PasswordRequirement passed={passwordChecks.number} text="At least one number" />
              </div>

              <div className="tlg-birthday-panel">
                <div className="tlg-birthday-panel-heading">
                  <span><CalendarDays size={19} /></span>
                  <div>
                    <h3>Birthday</h3>
                    <p>Used for your annual real-life birthday gift of 20 Coins. It cannot be changed after registration.</p>
                  </div>
                </div>

                <p className="tlg-birthday-warning">Check this carefully. Your full date of birth becomes permanent after your manager account is created.</p>

                <FormField id="birth-month" label="Date of birth" required error={submitted && !birthdayValid ? 'Enter your complete, valid date of birth. The year is required.' : undefined}>
                  <div className="tlg-birthday-fields">
                    <select id="birth-month" value={month} onChange={(event) => { const value = event.target.value; setMonth(value); if (day && Number(day) > createAvailableDays(value, year).length) setDay(''); clearStatus() }} className={`tlg-input ${submitted && !birthdayValid ? 'tlg-input-error' : ''}`}>
                      <option value="">Month</option>
                      {MONTHS.map((label, index) => <option key={label} value={String(index + 1)}>{label}</option>)}
                    </select>
                    <select value={day} onChange={(event) => { setDay(event.target.value); clearStatus() }} className={`tlg-input ${submitted && !birthdayValid ? 'tlg-input-error' : ''}`} aria-label="Birthday day">
                      <option value="">Day</option>
                      {availableDays.map((value) => <option key={value} value={String(value)}>{value}</option>)}
                    </select>
                    <input value={year} onChange={(event) => { const value = event.target.value.replace(/\D/g, '').slice(0, 4); setYear(value); if (day && Number(day) > createAvailableDays(month, value).length) setDay(''); clearStatus() }} className={`tlg-input ${submitted && !yearValid ? 'tlg-input-error' : ''}`} placeholder="Year" inputMode="numeric" autoComplete="bday-year" aria-label="Birthday year" />
                  </div>
                </FormField>
              </div>

              {status && (
                <div className={`tlg-auth-status ${status.type === 'success' ? 'tlg-auth-status-success' : 'tlg-auth-status-information'}`} role={status.type === 'error' ? 'alert' : 'status'}>
                  <ShieldCheck size={18} /><span>{status.message}</span>
                </div>
              )}

              <AppButton type="submit" variant="primary" size="large" fullWidth loading={loading} rightIcon={<ArrowRight size={18} />}>
                {loading ? 'Creating account…' : 'Create account'}
              </AppButton>
            </form>

            <div className="tlg-auth-divider"><span>Already registered?</span></div>
            <Link to="/login" className="tlg-auth-outline-button">Sign in to your account <ArrowRight size={17} /></Link>
            <p className="tlg-auth-supabase-note">Your account is secured by Tennis Legacy Supabase Auth. Game and profile state remains server-side.</p>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer"><span>Tennis Legacy: Rise to Glory</span><span>Secure manager registration</span></footer>

      <GameConfirmDialog
        open={confirmOpen}
        eyebrow="Permanent account information"
        title="Confirm your date of birth"
        message={
          <span>
            You entered <strong>{day} {MONTHS[Math.max(0, Number(month) - 1)]} {year}</strong>.
            This is your real account-holder birthday and cannot be changed after registration.
          </span>
        }
        detail="Please correct it now if anything is wrong. Your annual 20-Coin Birthday Gift will use this date."
        confirmLabel="Confirm & create account"
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
        color: passed ? '#9ED7B9' : '#9EB1C5',
        fontSize: '12px',
        fontWeight: 600,
      }}
    >
      <Check size={13} />
      {text}
    </span>
  )
}

function AuthFeature({ icon, title, description }: { icon: ReactNode; title: string; description: string }) {
  return <div className="tlg-auth-feature"><span className="tlg-auth-feature-icon">{icon}</span><div><strong>{title}</strong><p>{description}</p></div></div>
}

function AuthBackground() {
  return <div className="tlg-auth-background" aria-hidden="true"><div className="tlg-auth-background-grid" /><div className="tlg-auth-background-glow-one" /><div className="tlg-auth-background-glow-two" /><div className="tlg-auth-background-court" /></div>
}
