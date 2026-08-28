/**
 * Register.tsx
 *
 * Premium manager registration connected to the Tennis Legacy Supabase Auth
 * project. Manager metadata is copied into public.profiles by the database
 * signup trigger.
 */

import type { FormEvent, ReactNode } from 'react'
import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router'
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Check,
  Coins,
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
  const [status, setStatus] = useState<FormStatus | null>(null)

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
  const yearValid = year.length === 0 || (/^\d{4}$/.test(year) && Number(year) >= 1900 && Number(year) <= currentYear)

  const availableDays = useMemo(() => createAvailableDays(month, year), [month, year])
  const birthdayValid = month.length > 0 && day.length > 0 && Number(day) <= availableDays.length && yearValid
  const formValid = usernameValid && emailValid && passwordValid && confirmPasswordValid && birthdayValid

  function clearStatus() {
    if (status) setStatus(null)
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setStatus(null)

    if (!formValid || loading) return

    setLoading(true)
    const { data, error } = await supabase.auth.signUp({
      email: email.trim(),
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/create-player`,
        data: {
          username: username.trim(),
          birthday_month: Number(month),
          birthday_day: Number(day),
          birthday_year: year ? Number(year) : null,
        },
      },
    })
    setLoading(false)

    if (error) {
      setStatus({ type: 'error', message: mapSignupError(error.message) })
      return
    }

    if (data.session) {
      navigate('/create-player', { replace: true })
      return
    }

    setStatus({
      type: 'success',
      message: 'Account created. Check your inbox and confirm your email address to continue to player creation.',
    })
  }

  return (
    <div className="tlg-auth-page tlg-auth-register-page">
      <AuthBackground />

      <header className="tlg-auth-topbar">
        <Link to="/" className="tlg-auth-brand" aria-label="Tennis Legacy homepage">
          <span className="tlg-auth-brand-mark"><TennisBallMark /></span>
          <span className="tlg-auth-brand-copy">
            <strong>Tennis Legacy</strong>
            <small>Rise to Glory</small>
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

            <div className="tlg-auth-reward-card">
              <span className="tlg-auth-reward-icon"><Coins size={22} /></span>
              <div>
                <span>Birthday reward</span>
                <strong>10 account coins</strong>
                <p>The birthday reward will activate with the game economy. Your birthday is immutable after registration.</p>
              </div>
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

                <FormField id="register-email" label="Email address" required error={submitted && !emailValid ? 'Enter a valid email address.' : undefined}>
                  <div className="tlg-input-shell">
                    <Mail className="tlg-input-leading-icon" size={18} />
                    <input id="register-email" type="email" value={email} onChange={(event) => { setEmail(event.target.value); clearStatus() }} className={`tlg-input tlg-input-with-leading-icon ${submitted && !emailValid ? 'tlg-input-error' : ''}`} placeholder="manager@example.com" autoComplete="email" />
                  </div>
                </FormField>
              </div>

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

              <div className="tlg-password-requirements">
                <PasswordRequirement passed={passwordChecks.length} text="At least 8 characters" />
                <PasswordRequirement passed={passwordChecks.letter} text="At least one letter" />
                <PasswordRequirement passed={passwordChecks.number} text="At least one number" />
              </div>

              <div className="tlg-birthday-panel">
                <div className="tlg-birthday-panel-heading">
                  <span><CalendarDays size={19} /></span>
                  <div>
                    <h3>Birthday</h3>
                    <p>Used for birthday congratulations and the future birthday reward. It cannot be changed after registration.</p>
                  </div>
                </div>

                <p className="tlg-birthday-warning">This value becomes permanent after your manager account is created.</p>

                <FormField id="birth-month" label="Birthday date" required error={submitted && !birthdayValid ? 'Choose a valid month and day. The year is optional.' : undefined}>
                  <div className="tlg-birthday-fields">
                    <select id="birth-month" value={month} onChange={(event) => { const value = event.target.value; setMonth(value); if (day && Number(day) > createAvailableDays(value, year).length) setDay(''); clearStatus() }} className={`tlg-input ${submitted && !birthdayValid ? 'tlg-input-error' : ''}`}>
                      <option value="">Month</option>
                      {MONTHS.map((label, index) => <option key={label} value={String(index + 1)}>{label}</option>)}
                    </select>
                    <select value={day} onChange={(event) => { setDay(event.target.value); clearStatus() }} className={`tlg-input ${submitted && !birthdayValid ? 'tlg-input-error' : ''}`} aria-label="Birthday day">
                      <option value="">Day</option>
                      {availableDays.map((value) => <option key={value} value={String(value)}>{value}</option>)}
                    </select>
                    <input value={year} onChange={(event) => { const value = event.target.value.replace(/\D/g, '').slice(0, 4); setYear(value); if (day && Number(day) > createAvailableDays(month, value).length) setDay(''); clearStatus() }} className={`tlg-input ${submitted && !yearValid ? 'tlg-input-error' : ''}`} placeholder="Year · optional" inputMode="numeric" autoComplete="bday-year" />
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
    </div>
  )
}

function mapSignupError(message: string) {
  const normalized = message.toLowerCase()
  if (normalized.includes('weak') || normalized.includes('easy to guess') || normalized.includes('pwned') || normalized.includes('leaked')) {
    return 'That password appears in known password-leak data or is too easy to guess. Choose a different, unique password.'
  }
  if (normalized.includes('already') || normalized.includes('duplicate') || normalized.includes('database error')) {
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
  return <span className={passed ? 'tlg-password-requirement tlg-password-requirement-passed' : 'tlg-password-requirement'}><Check size={13} />{text}</span>
}

function AuthFeature({ icon, title, description }: { icon: ReactNode; title: string; description: string }) {
  return <div className="tlg-auth-feature"><span className="tlg-auth-feature-icon">{icon}</span><div><strong>{title}</strong><p>{description}</p></div></div>
}

function TennisBallMark() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true">
      <defs><linearGradient id="registerBrandGradient" x1="5" y1="4" x2="44" y2="46" gradientUnits="userSpaceOnUse"><stop stopColor="#0874D1" /><stop offset="1" stopColor="#001D3F" /></linearGradient></defs>
      <rect x="2" y="2" width="44" height="44" rx="12" fill="url(#registerBrandGradient" />
      <circle cx="24" cy="24" r="12.5" fill="none" stroke="#FFFFFF" strokeWidth="2" />
      <path d="M15.8 14.6c5.5 3.1 9.4 8.2 11.2 14.7" fill="none" stroke="#FFFFFF" strokeWidth="2" strokeLinecap="round" />
      <path d="M21 33.9c3.1-5.9 7.1-10.1 12-12.5" fill="none" stroke="#FFFFFF" strokeWidth="2" strokeLinecap="round" />
    </svg>
  )
}

function AuthBackground() {
  return <div className="tlg-auth-background" aria-hidden="true"><div className="tlg-auth-background-grid" /><div className="tlg-auth-background-glow-one" /><div className="tlg-auth-background-glow-two" /><div className="tlg-auth-background-court" /></div>
}
