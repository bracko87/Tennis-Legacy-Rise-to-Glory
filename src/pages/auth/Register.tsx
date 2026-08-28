/**
 * Register.tsx
 *
 * Manager registration connected to the dedicated Tennis Legacy Supabase
 * project. Account identity is handled by Supabase Auth while manager profile
 * metadata is copied into public.profiles by the database signup trigger.
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

const months = [
  { value: '1', label: 'January' },
  { value: '2', label: 'February' },
  { value: '3', label: 'March' },
  { value: '4', label: 'April' },
  { value: '5', label: 'May' },
  { value: '6', label: 'June' },
  { value: '7', label: 'July' },
  { value: '8', label: 'August' },
  { value: '9', label: 'September' },
  { value: '10', label: 'October' },
  { value: '11', label: 'November' },
  { value: '12', label: 'December' },
] as const

interface FormStatus {
  readonly type: 'success' | 'error'
  readonly message: string
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

  const passwordValid =
    passwordChecks.length && passwordChecks.letter && passwordChecks.number
  const confirmPasswordValid =
    confirmPassword.length > 0 && password === confirmPassword
  const yearValid =
    year.length === 0 ||
    (/^\d{4}$/.test(year) && Number(year) >= 1900 && Number(year) <= currentYear)

  const availableDays = useMemo(
    () => createAvailableDays(month, year),
    [month, year],
  )

  const birthdayValid =
    month.length > 0 &&
    day.length > 0 &&
    Number(day) <= availableDays.length &&
    yearValid

  const formValid =
    usernameValid &&
    emailValid &&
    passwordValid &&
    confirmPasswordValid &&
    birthdayValid

  function handleMonthChange(value: string) {
    setMonth(value)
    setStatus(null)

    const newDays = createAvailableDays(value, year)
    if (day && Number(day) > newDays.length) setDay('')
  }

  function handleYearChange(value: string) {
    const normalized = value.replace(/\D/g, '').slice(0, 4)
    setYear(normalized)
    setStatus(null)

    const newDays = createAvailableDays(month, normalized)
    if (day && Number(day) > newDays.length) setDay('')
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
      const normalizedMessage = error.message.toLowerCase()
      const friendlyMessage =
        normalizedMessage.includes('database error') ||
        normalizedMessage.includes('duplicate') ||
        normalizedMessage.includes('already')
          ? 'That username or email address is already unavailable. Choose another username or sign in if you already have an account.'
          : 'We could not create your account. Please review the details and try again.'

      setStatus({ type: 'error', message: friendlyMessage })
      return
    }

    if (data.session) {
      navigate('/create-player', { replace: true })
      return
    }

    setStatus({
      type: 'success',
      message:
        'Account created. Check your email and confirm your address. After verification you will continue directly to Create Player.',
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

        <Link to="/" className="tlg-auth-home-link">
          <ArrowLeft size={16} />
          Home
        </Link>
      </header>

      <main className="tlg-auth-main tlg-auth-register-main">
        <section className="tlg-auth-showcase">
          <div className="tlg-auth-showcase-content">
            <span className="tlg-auth-eyebrow">Start Your Journey</span>
            <h1>
              Create the manager behind
              <strong> a future champion.</strong>
            </h1>
            <p>
              Register your account, verify your email address and then create the ATP or WTA player who will represent your career in the shared Tennis Legacy world.
            </p>

            <div className="tlg-auth-feature-list">
              <AuthFeature icon={<UserRound size={18} />} title="Create your professional" description="Build a realistic tennis identity and choose the ATP or WTA world." />
              <AuthFeature icon={<Globe2 size={18} />} title="Join a shared universe" description="Compete in a world populated by players controlled by real managers." />
              <AuthFeature icon={<Trophy size={18} />} title="Build a lasting career" description="Develop skills, win tournaments and establish historic records." />
            </div>

            <div className="tlg-auth-reward-card">
              <span className="tlg-auth-reward-icon"><Coins size={22} /></span>
              <div>
                <span>Birthday reward</span>
                <strong>10 account coins</strong>
                <p>Birthday rewards will be credited by the game economy when that system is activated.</p>
              </div>
            </div>
          </div>
        </section>

        <section className="tlg-auth-form-column">
          <div className="tlg-auth-card tlg-auth-register-card">
            <div className="tlg-auth-card-heading">
              <span className="tlg-auth-card-icon"><UserRound size={21} /></span>
              <div>
                <span>Manager registration</span>
                <h2>Create account</h2>
              </div>
            </div>

            <p className="tlg-auth-card-description">
              Create your manager account before building your ATP or WTA player.
            </p>

            <form className="tlg-auth-form" onSubmit={handleSubmit} noValidate>
              <div className="tlg-auth-form-grid">
                <FormField
                  id="register-username"
                  label="Username"
                  required
                  hint={!submitted ? '3–24 characters. Letters, numbers, dots, dashes and underscores.' : undefined}
                  error={submitted && !usernameValid ? 'Enter a valid username containing 3–24 supported characters.' : undefined}
                >
                  <div className="tlg-input-shell">
                    <UserRound className="tlg-input-leading-icon" size={18} aria-hidden="true" />
                    <input
                      id="register-username"
                      name="username"
                      value={username}
                      onChange={(event) => {
                        setUsername(event.target.value)
                        setStatus(null)
                      }}
                      className={`tlg-input tlg-input-with-leading-icon ${submitted && !usernameValid ? 'tlg-input-error' : ''}`}
                      placeholder="Choose a username"
                      autoComplete="username"
                      maxLength={24}
                      aria-invalid={submitted && !usernameValid}
                    />
                  </div>
                </FormField>

                <FormField
                  id="register-email"
                  label="Email address"
                  required
                  error={submitted && !emailValid ? 'Enter a valid email address.' : undefined}
                >
                  <div className="tlg-input-shell">
                    <Mail className="tlg-input-leading-icon" size={18} aria-hidden="true" />
                    <input
                      id="register-email"
                      name="email"
                      type="email"
                      value={email}
                      onChange={(event) => {
                        setEmail(event.target.value)
                        setStatus(null)
                      }}
                      className={`tlg-input tlg-input-with-leading-icon ${submitted && !emailValid ? 'tlg-input-error' : ''}`}
                      placeholder="manager@example.com"
                      autoComplete="email"
                      aria-invalid={submitted && !emailValid}
                    />
                  </div>
                </FormField>
              </div>

              <div className="tlg-auth-form-grid">
                <FormField
                  id="register-password"
                  label="Password"
                  required
                  error={submitted && !passwordValid ? 'Create a password that satisfies all listed requirements.' : undefined}
                >
                  <div className="tlg-input-shell">
                    <LockKeyhole className="tlg-input-leading-icon" size={18} aria-hidden="true" />
                    <input
                      id="register-password"
                      name="password"
                      type={showPassword ? 'text' : 'password'}
                      value={password}
                      onChange={(event) => {
                        setPassword(event.target.value)
                        setStatus(null)
                      }}
                      className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !passwordValid ? 'tlg-input-error' : ''}`}
                      placeholder="Create a password"
                      autoComplete="new-password"
                      aria-invalid={submitted && !passwordValid}
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
                  id="register-confirm-password"
                  label="Confirm password"
                  required
                  error={submitted && !confirmPasswordValid ? 'The passwords do not match.' : undefined}
                  success={confirmPasswordValid ? 'Passwords match.' : undefined}
                >
                  <div className="tlg-input-shell">
                    <LockKeyhole className="tlg-input-leading-icon" size={18} aria-hidden="true" />
                    <input
                      id="register-confirm-password"
                      name="confirmPassword"
                      type={showConfirmPassword ? 'text' : 'password'}
                      value={confirmPassword}
                      onChange={(event) => {
                        setConfirmPassword(event.target.value)
                        setStatus(null)
                      }}
                      className={`tlg-input tlg-input-with-leading-icon tlg-input-with-action ${submitted && !confirmPasswordValid ? 'tlg-input-error' : ''} ${confirmPasswordValid ? 'tlg-input-success' : ''}`}
                      placeholder="Repeat your password"
                      autoComplete="new-password"
                      aria-invalid={submitted && !confirmPasswordValid}
                    />
                    <button
                      type="button"
                      className="tlg-input-action"
                      aria-label={showConfirmPassword ? 'Hide password' : 'Show password'}
                      onClick={() => setShowConfirmPassword((current) => !current)}
                    >
                      {showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                </FormField>
              </div>

              <div id="password-requirements" className="tlg-password-requirements">
                <PasswordRequirement passed={passwordChecks.length} text="At least 8 characters" />
                <PasswordRequirement passed={passwordChecks.letter} text="At least one letter" />
                <PasswordRequirement passed={passwordChecks.number} text="At least one number" />
              </div>

              <div className="tlg-birthday-panel">
                <div className="tlg-birthday-panel-heading">
                  <span><CalendarDays size={19} /></span>
                  <div>
                    <h3>Birthday</h3>
                    <p>
                      Your birthday is used for birthday rewards. We will send birthday congratulations and add 10 coins to your account when the reward system is active.
                    </p>
                  </div>
                </div>

                <p className="tlg-birthday-warning">
                  Your birthday can only be entered during registration and cannot be changed later in the game.
                </p>

                <FormField
                  id="birth-month"
                  label="Birthday date"
                  required
                  error={submitted && !birthdayValid ? 'Select a valid birthday month and day. Enter a valid year or leave it empty.' : undefined}
                >
                  <div className="tlg-birthday-fields">
                    <select
                      id="birth-month"
                      name="birthMonth"
                      value={month}
                      onChange={(event) => handleMonthChange(event.target.value)}
                      className={`tlg-input ${submitted && !birthdayValid ? 'tlg-input-error' : ''}`}
                      aria-label="Birthday month"
                      aria-invalid={submitted && !birthdayValid}
                    >
                      <option value="">Select month</option>
                      {months.map((monthOption) => (
                        <option key={monthOption.value} value={monthOption.value}>{monthOption.label}</option>
                      ))}
                    </select>

                    <select
                      name="birthDay"
                      value={day}
                      onChange={(event) => {
                        setDay(event.target.value)
                        setStatus(null)
                      }}
                      className={`tlg-input ${submitted && !birthdayValid ? 'tlg-input-error' : ''}`}
                      aria-label="Birthday day"
                      aria-invalid={submitted && !birthdayValid}
                    >
                      <option value="">Select day</option>
                      {availableDays.map((dayOption) => (
                        <option key={dayOption} value={String(dayOption)}>{dayOption}</option>
                      ))}
                    </select>

                    <input
                      name="birthYear"
                      value={year}
                      onChange={(event) => handleYearChange(event.target.value)}
                      className={`tlg-input ${submitted && !yearValid ? 'tlg-input-error' : ''}`}
                      placeholder="Year — optional"
                      inputMode="numeric"
                      autoComplete="bday-year"
                      aria-label="Birthday year, optional"
                      aria-invalid={submitted && !yearValid}
                    />
                  </div>
                </FormField>
              </div>

              {status && (
                <div
                  className={`tlg-auth-status ${status.type === 'error' ? 'tlg-auth-status-information' : 'tlg-auth-status-success'}`}
                  role={status.type === 'error' ? 'alert' : 'status'}
                >
                  <ShieldCheck size={18} />
                  <span>{status.message}</span>
                </div>
              )}

              <AppButton
                type="submit"
                variant="primary"
                size="large"
                fullWidth
                loading={loading}
                rightIcon={<ArrowRight size={18} />}
              >
                {loading ? 'Creating Account…' : 'Create Account'}
              </AppButton>
            </form>

            <div className="tlg-auth-divider"><span>Already registered?</span></div>

            <Link to="/login" className="tlg-auth-outline-button">
              Sign in to your account
              <ArrowRight size={17} />
            </Link>

            <p className="tlg-auth-supabase-note">
              Authentication is handled by the dedicated Tennis Legacy Supabase project. Manager profile data is stored in Supabase and the birthday is immutable after registration.
            </p>
          </div>
        </section>
      </main>

      <footer className="tlg-auth-footer">
        <span>Tennis Legacy: Rise to Glory</span>
        <span>Season 1 · March 14 · 18:00</span>
      </footer>
    </div>
  )
}

function createAvailableDays(month: string, year: string) {
  const monthNumber = Number(month)
  if (!monthNumber) return Array.from({ length: 31 }, (_, index) => index + 1)

  let maximumDay = 31
  if ([4, 6, 9, 11].includes(monthNumber)) maximumDay = 30
  if (monthNumber === 2) {
    maximumDay = year.length === 4 ? (isLeapYear(Number(year)) ? 29 : 28) : 29
  }

  return Array.from({ length: maximumDay }, (_, index) => index + 1)
}

function isLeapYear(year: number) {
  return year % 400 === 0 || (year % 4 === 0 && year % 100 !== 0)
}

function PasswordRequirement({ passed, text }: { readonly passed: boolean; readonly text: string }) {
  return (
    <span className={passed ? 'tlg-password-requirement tlg-password-requirement-passed' : 'tlg-password-requirement'}>
      <Check size={13} />
      {text}
    </span>
  )
}

function AuthFeature({ icon, title, description }: { readonly icon: ReactNode; readonly title: string; readonly description: string }) {
  return (
    <div className="tlg-auth-feature">
      <span className="tlg-auth-feature-icon">{icon}</span>
      <div><strong>{title}</strong><p>{description}</p></div>
    </div>
  )
}

function TennisBallMark() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true">
      <defs>
        <linearGradient id="registerBrandGradient" x1="5" y1="4" x2="44" y2="46" gradientUnits="userSpaceOnUse">
          <stop stopColor="#0874D1" />
          <stop offset="1" stopColor="#001D3F" />
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="44" height="44" rx="12" fill="url(#registerBrandGradient)" />
      <circle cx="24" cy="24" r="12.5" fill="none" stroke="#FFFFFF" strokeWidth="2" />
      <path d="M15.8 14.6c5.5 3.1 9.4 8.2 11.2 14.7" fill="none" stroke="#FFFFFF" strokeWidth="2" strokeLinecap="round" />
      <path d="M21 33.9c3.1-5.9 7.1-10.1 12-12.5" fill="none" stroke="#FFFFFF" strokeWidth="2" strokeLinecap="round" />
    </svg>
  )
}

function AuthBackground() {
  return (
    <div className="tlg-auth-background" aria-hidden="true">
      <div className="tlg-auth-background-grid" />
      <div className="tlg-auth-background-glow-one" />
      <div className="tlg-auth-background-glow-two" />
      <div className="tlg-auth-background-court" />
    </div>
  )
}
