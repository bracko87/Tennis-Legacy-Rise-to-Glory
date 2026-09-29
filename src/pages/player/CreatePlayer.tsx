/**
 * CreatePlayer.tsx
 * First-login player onboarding for Tennis Legacy: Rise to Glory.
 */

import type { FormEvent } from 'react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router'
import {
  AlertTriangle,
  ArrowLeft,
  ArrowRight,
  Check,
  ChevronDown,
  Circle,
  Search,
  ShieldCheck,
  UserRound,
} from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import AppButton from '../../components/common/AppButton'
import SharedCountryFlag from '../../components/common/CountryFlag'
import FormField from '../../components/common/FormField'
import { COUNTRIES } from '../../data/countries'
import { supabase } from '../../lib/supabase'
import '../../styles/create-player-enhancements.css'

type PlayerWorld = 'ATP' | 'WTA'
type PreferredSurface = 'Hard' | 'Clay' | 'Grass'
type PlayingStyle = 'Aggressive Baseliner' | 'Defensive Baseliner' | 'All-court' | 'Serve & Volley'
type OnboardingStep = 1 | 2 | 3 | 4 | 5

interface PlayerDraft {
  step?: number
  world?: PlayerWorld
  firstName?: string
  lastName?: string
  country?: string
  homeCity?: string
  selectedAvatarPath?: string | null
  preferredSurface?: PreferredSurface | null
  playingStyle?: PlayingStyle | null
}


interface CountryOption {
  code: string
  name: string
}

interface HomeCityOption {
  city: string
  sort_order: number
  latitude?: number | null
  longitude?: number | null
}

interface AvatarCatalogRow {
  path: string
  is_available: boolean
}

interface SignedAvatarRow {
  path?: string | null
  signedUrl?: string | null
}

interface AvatarOption {
  path: string
  signedUrl: string
  available: boolean
  label: string
}

const NAME_PATTERN = /^[\p{L}][\p{L}'’ -]*$/u
const PLAYER_DRAFT_KEY_PREFIX = 'tlg-create-player-draft:'

const ONBOARDING_STEPS: Array<{ id: OnboardingStep; label: string; short: string }> = [
  { id: 1, label: 'Career', short: 'Tour' },
  { id: 2, label: 'Player', short: 'Identity' },
  { id: 3, label: 'Appearance', short: 'Portrait' },
  { id: 4, label: 'Profile', short: 'Style' },
  { id: 5, label: 'Confirm', short: 'Review' },
]


const SURFACES: Array<{ value: PreferredSurface; text: string }> = [
  { value: 'Hard', text: 'Balanced modern surface' },
  { value: 'Clay', text: 'Long rallies and movement' },
  { value: 'Grass', text: 'Fast points and attacking play' },
]

const PLAYING_STYLES: Array<{ value: PlayingStyle; text: string }> = [
  { value: 'Aggressive Baseliner', text: 'More emphasis on forehand pressure and attacking from the baseline.' },
  { value: 'Defensive Baseliner', text: 'More emphasis on return, backhand stability and absorbing pressure.' },
  { value: 'All-court', text: 'Neutral style with no additional starting redistribution.' },
  { value: 'Serve & Volley', text: 'More emphasis on serve, volley and moving forward quickly.' },
]

export default function CreatePlayerPage(): JSX.Element {
  const { user, refreshPlayer } = useAuth()
  const navigate = useNavigate()

  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [country, setCountry] = useState('')
  const [countries, setCountries] = useState<CountryOption[]>([])
  const [countriesLoading, setCountriesLoading] = useState(true)
  const [countryOpen, setCountryOpen] = useState(false)
  const [countryQuery, setCountryQuery] = useState('')
  const [homeCity, setHomeCity] = useState('')
  const [homeCities, setHomeCities] = useState<HomeCityOption[]>([])
  const [homeCitiesLoading, setHomeCitiesLoading] = useState(false)
  const [homeCityLoadError, setHomeCityLoadError] = useState<string | null>(null)
  const [world, setWorld] = useState<PlayerWorld>('ATP')
  const [preferredSurface, setPreferredSurface] = useState<PreferredSurface | null>(null)
  const [playingStyle, setPlayingStyle] = useState<PlayingStyle | null>(null)
  const [avatars, setAvatars] = useState<AvatarOption[]>([])
  const [avatarsLoading, setAvatarsLoading] = useState(true)
  const [avatarError, setAvatarError] = useState<string | null>(null)
  const [selectedAvatarPath, setSelectedAvatarPath] = useState<string | null>(null)
  const [avatarRefreshKey, setAvatarRefreshKey] = useState(0)
  const [submitted, setSubmitted] = useState(false)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)
  const [step, setStep] = useState<OnboardingStep>(1)
  const [attemptedStep, setAttemptedStep] = useState<OnboardingStep | null>(null)
  const [draftReady, setDraftReady] = useState(false)

  const countryPickerRef = useRef<HTMLDivElement | null>(null)
  const resumeHomeCityRef = useRef('')

  useEffect(() => {
    if (!user) {
      setDraftReady(false)
      return
    }

    try {
      const raw = window.localStorage.getItem(`${PLAYER_DRAFT_KEY_PREFIX}${user.id}`)
      if (raw) {
        const draft = JSON.parse(raw) as PlayerDraft
        if (draft.world === 'ATP' || draft.world === 'WTA') setWorld(draft.world)
        if (typeof draft.firstName === 'string') setFirstName(draft.firstName)
        if (typeof draft.lastName === 'string') setLastName(draft.lastName)
        if (typeof draft.country === 'string') setCountry(draft.country)
        if (typeof draft.homeCity === 'string') resumeHomeCityRef.current = draft.homeCity
        if (typeof draft.selectedAvatarPath === 'string' || draft.selectedAvatarPath === null) {
          setSelectedAvatarPath(draft.selectedAvatarPath)
        }
        if (draft.preferredSurface === 'Hard' || draft.preferredSurface === 'Clay' || draft.preferredSurface === 'Grass') {
          setPreferredSurface(draft.preferredSurface)
        }
        if (
          draft.playingStyle === 'Aggressive Baseliner'
          || draft.playingStyle === 'Defensive Baseliner'
          || draft.playingStyle === 'All-court'
          || draft.playingStyle === 'Serve & Volley'
        ) {
          setPlayingStyle(draft.playingStyle)
        }
        if (draft.step && draft.step >= 1 && draft.step <= 5) setStep(draft.step as OnboardingStep)
      }
    } catch {
      window.localStorage.removeItem(`${PLAYER_DRAFT_KEY_PREFIX}${user.id}`)
    } finally {
      setDraftReady(true)
    }
  }, [user])


  useEffect(() => {
    let active = true

    async function loadCountries() {
      const { data, error } = await supabase.rpc('get_player_creation_countries_v1')

      if (!active) return

      if (error || !data?.length) {
        setCountries(
          [...COUNTRIES]
            .map((item) => ({ code: item.code, name: item.name }))
            .sort((a, b) => a.name.localeCompare(b.name)),
        )
      } else {
        setCountries(data as CountryOption[])
      }
      setCountriesLoading(false)
    }

    void loadCountries()
    return () => { active = false }
  }, [])

  useEffect(() => {
    let active = true

    setHomeCity('')
    setHomeCities([])
    setHomeCityLoadError(null)

    if (!country) {
      setHomeCitiesLoading(false)
      return () => { active = false }
    }

    setHomeCitiesLoading(true)

    async function loadHomeCities() {
      const { data, error } = await supabase.rpc('get_player_home_city_options_v1', {
        p_country_code: country,
      })

      if (!active) return

      if (error || !data?.length) {
        setHomeCities([])
        setHomeCityLoadError('Home cities could not be loaded for this country. Choose the country again or refresh the page.')
        resumeHomeCityRef.current = ''
      } else {
        const rows = data as HomeCityOption[]
        setHomeCities(rows)
        const resumeCity = resumeHomeCityRef.current
        if (resumeCity && rows.some((item) => item.city === resumeCity)) setHomeCity(resumeCity)
        resumeHomeCityRef.current = ''
      }
      setHomeCitiesLoading(false)
    }

    void loadHomeCities()
    return () => { active = false }
  }, [country])

  useEffect(() => {
    function handleDocumentPointerDown(event: MouseEvent) {
      const target = event.target as Node
      if (!countryPickerRef.current?.contains(target)) setCountryOpen(false)
    }

    document.addEventListener('mousedown', handleDocumentPointerDown)
    return () => document.removeEventListener('mousedown', handleDocumentPointerDown)
  }, [])

  useEffect(() => {
    let active = true

    async function loadAvatars() {
      setAvatarsLoading(true)
      setAvatarError(null)

      const { data, error } = await supabase.rpc('get_player_avatar_catalog', { p_world: world })
      if (!active) return

      if (error) {
        console.error('Unable to load Tennis Legacy avatar catalog:', error.message)
        setAvatars([])
        setAvatarsLoading(false)
        setAvatarError('Player portraits could not be loaded. Refresh the page and try again.')
        return
      }

      const rows = (data ?? []) as AvatarCatalogRow[]
      if (!rows.length) {
        setAvatars([])
        setSelectedAvatarPath(null)
        setAvatarsLoading(false)
        return
      }

      const paths = rows.map((row) => row.path)
      const { data: signedData, error: signedError } = await supabase.storage
        .from('Admin')
        .createSignedUrls(paths, 7200)

      if (!active) return
      if (signedError) {
        console.error('Unable to sign Tennis Legacy avatar URLs:', signedError.message)
        setAvatars([])
        setAvatarsLoading(false)
        setAvatarError('Player portraits could not be displayed. Refresh the page and try again.')
        return
      }

      const signedRows = (signedData ?? []) as SignedAvatarRow[]
      const signedByPath = new Map<string, string>()
      signedRows.forEach((item, index) => {
        const path = item.path ?? rows[index]?.path
        if (path && item.signedUrl) signedByPath.set(path, item.signedUrl)
      })

      const nextAvatars = rows
        .map((row) => ({
          path: row.path,
          signedUrl: signedByPath.get(row.path) ?? '',
          available: row.is_available,
          label: avatarLabel(row.path),
        }))
        .filter((item) => item.signedUrl.length > 0)

      setAvatars(nextAvatars)
      setSelectedAvatarPath((current) =>
        current && nextAvatars.some((item) => item.path === current && item.available) ? current : null,
      )
      setAvatarsLoading(false)
    }

    void loadAvatars()
    return () => { active = false }
  }, [world, avatarRefreshKey])

  useEffect(() => {
    if (!user || !draftReady) return

    const draft: PlayerDraft = {
      step,
      world,
      firstName,
      lastName,
      country,
      homeCity,
      selectedAvatarPath,
      preferredSurface,
      playingStyle,
    }

    window.localStorage.setItem(
      `${PLAYER_DRAFT_KEY_PREFIX}${user.id}`,
      JSON.stringify(draft),
    )
  }, [
    user,
    draftReady,
    step,
    world,
    firstName,
    lastName,
    country,
    homeCity,
    selectedAvatarPath,
    preferredSurface,
    playingStyle,
  ])

  const selectedCountry = useMemo(
    () => countries.find((item) => item.code === country) ?? null,
    [countries, country],
  )

  const filteredCountries = useMemo(() => {
    const query = countryQuery.trim().toLocaleLowerCase()
    if (!query) return countries
    return countries.filter((item) => `${item.name} ${item.code}`.toLocaleLowerCase().includes(query))
  }, [countries, countryQuery])

  const selectedAvatar = useMemo(
    () => avatars.find((item) => item.path === selectedAvatarPath) ?? null,
    [avatars, selectedAvatarPath],
  )

  const selectedCountryName = selectedCountry?.name ?? 'Country not selected'
  const availableAvatarCount = avatars.filter((item) => item.available).length
  const cleanFirstName = firstName.trim()
  const cleanLastName = lastName.trim()
  const firstNameValid = cleanFirstName.length >= 2 && NAME_PATTERN.test(cleanFirstName)
  const lastNameValid = cleanLastName.length >= 2 && NAME_PATTERN.test(cleanLastName)
  const countryValid = country.length === 2
  const homeCityValid = homeCity.length > 0 && homeCities.some((item) => item.city === homeCity)
  const surfaceValid = preferredSurface !== null
  const styleValid = playingStyle !== null
  const identityValid = firstNameValid && lastNameValid && countryValid && homeCityValid
  const profileValid = surfaceValid && styleValid
  const formValid = identityValid && profileValid

  const currentStep = ONBOARDING_STEPS.find((item) => item.id === step) ?? ONBOARDING_STEPS[0]

  function scrollToWizardTop() {
    window.requestAnimationFrame(() => {
      document.querySelector('.tlg-onboarding-stage-card')?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      })
    })
  }

  function goNext() {
    setAttemptedStep(step)
    setSaveError(null)

    if (step === 2 && !identityValid) return
    if (step === 4 && !profileValid) return
    if (step >= 5) return

    setAttemptedStep(null)
    setStep((step + 1) as OnboardingStep)
    scrollToWizardTop()
  }

  function goBack() {
    if (step <= 1 || saving) return
    setAttemptedStep(null)
    setSaveError(null)
    setStep((step - 1) as OnboardingStep)
    scrollToWizardTop()
  }

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setSaveError(null)

    if (!formValid || !user || !preferredSurface || !playingStyle || saving) return
    setSaving(true)

    try {
      const { error } = await supabase.from('players').insert({
        owner_user_id: user.id,
        world,
        first_name: cleanFirstName,
        last_name: cleanLastName,
        country_code: country,
        home_city: homeCity,
        image_path: selectedAvatarPath,
        preferred_surface: preferredSurface,
        playing_style: playingStyle,
      })

      if (error) {
        if (error.code === '23505') {
          const existingPlayer = await refreshPlayer()
          if (existingPlayer) {
            window.localStorage.removeItem(`${PLAYER_DRAFT_KEY_PREFIX}${user.id}`)
            navigate('/game/overview', { replace: true })
            return
          }

          setSelectedAvatarPath(null)
          setAvatarRefreshKey((value) => value + 1)
          setStep(3)
          setSaving(false)
          setSaveError('That player portrait was just selected by another manager. Choose another available portrait and try again.')
          return
        }
        throw error
      }

      await refreshPlayer()
      window.localStorage.removeItem(`${PLAYER_DRAFT_KEY_PREFIX}${user.id}`)
      navigate('/game/overview', { replace: true })
    } catch (error) {
      console.error('Unable to create Tennis Legacy player:', error)
      setSaving(false)
      setSaveError('Your player could not be created. Check the selected details, including the home city, and try again.')
    }
  }

  return (
    <div className="tlg-onboarding-page tlg-onboarding-page-v2">
      <header className="tlg-onboarding-topbar">
        <Link to="/" className="tlg-brand" aria-label="Tennis Legacy homepage">
          <span className="tlg-brand-mark" aria-hidden="true" />
          <span className="tlg-brand-copy">
            <strong className="tlg-brand-name">Tennis Legacy</strong>
            <span className="tlg-brand-subtitle">Rise to Glory</span>
          </span>
        </Link>

        <div className="tlg-onboarding-topbar-actions">
          <div className="tlg-onboarding-account-state">
            <span>Account verified</span>
            <strong>{user?.email ?? 'Authenticated account'}</strong>
          </div>

          <Link to="/" className="tlg-onboarding-home-link">
            <ArrowLeft size={15} />
            <span>Back to Home</span>
          </Link>
        </div>
      </header>

      <main className="tlg-onboarding-main tlg-onboarding-main-v2">
        <div className="tlg-onboarding-hero tlg-onboarding-hero-v2">
          <div>
            <p className="tlg-page-heading-eyebrow">Create Your Player</p>
            <h1>Build the player who starts your career.</h1>
            <p>
              Your account is already created. These steps define only your fictional tennis player and starting career identity.
            </p>
          </div>
        </div>

        <nav className="tlg-onboarding-stepper" aria-label="Player creation progress">
          {ONBOARDING_STEPS.map((item) => {
            const active = item.id === step
            const complete = item.id < step

            return (
              <div
                key={item.id}
                className={`tlg-onboarding-step ${active ? 'active' : ''} ${complete ? 'complete' : ''}`}
                aria-current={active ? 'step' : undefined}
              >
                <span className="tlg-onboarding-step-number">{complete ? <Check size={14} /> : item.id}</span>
                <span className="tlg-onboarding-step-copy">
                  <strong>{item.label}</strong>
                  <small>{item.short}</small>
                </span>
              </div>
            )
          })}
        </nav>

        <form className="tlg-onboarding-wizard" onSubmit={handleCreate} noValidate>
          <section className="tlg-onboarding-stage-card">
            <header className="tlg-onboarding-stage-header">
              <div>
                <span>Step {step} of 5 · {currentStep.label}</span>
                <h2>
                  {step === 1 && 'Choose your professional tour'}
                  {step === 2 && 'Create your player identity'}
                  {step === 3 && 'Choose your appearance'}
                  {step === 4 && 'Set your playing profile'}
                  {step === 5 && 'Review and start your career'}
                </h2>
              </div>
              <strong>{Math.round((step / 5) * 100)}%</strong>
            </header>

            <div className="tlg-onboarding-stage-body">
              {step === 1 && (
                <div className="tlg-onboarding-stage-content">
                  <p className="tlg-onboarding-stage-intro">
                    Choose the professional world your player will join. This defines the competitive ecosystem for the career.
                  </p>

                  <div className="tlg-world-grid tlg-world-grid-v2">
                    {(['ATP', 'WTA'] as PlayerWorld[]).map((option) => (
                      <button
                        key={option}
                        type="button"
                        className={`tlg-world-option ${world === option ? 'active' : ''}`}
                        onClick={() => {
                          setWorld(option)
                          setSelectedAvatarPath(null)
                          setSaveError(null)
                        }}
                        aria-pressed={world === option}
                      >
                        <span className="tlg-world-option-badge">{world === option ? 'SELECTED' : 'CHOOSE TOUR'}</span>
                        <strong>{option}</strong>
                        <p>
                          {option === 'ATP'
                            ? 'Join the men’s professional multiplayer world.'
                            : 'Join the women’s professional multiplayer world.'}
                        </p>
                        {world === option && <Check size={18} className="absolute right-4 top-4 text-[color:var(--tlg-cyan)]" />}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {step === 2 && (
                <div className="tlg-onboarding-stage-content">
                  <p className="tlg-onboarding-stage-intro">
                    This is your in-game player, not your login account. Use a realistic first and last name and choose the country and permanent home city for the career.
                  </p>

                  <div className="tlg-onboarding-form-grid">
                    <FormField
                      id="first-name"
                      label="Player first name"
                      required
                      error={(attemptedStep === 2 || submitted) && !firstNameValid ? 'Use a valid first name with letters only.' : undefined}
                    >
                      <input
                        id="first-name"
                        value={firstName}
                        onChange={(event) => { setFirstName(event.target.value); setSaveError(null) }}
                        className={`tlg-input ${(attemptedStep === 2 || submitted) && !firstNameValid ? 'tlg-input-error' : ''}`}
                        placeholder="First name"
                        maxLength={40}
                        autoComplete="off"
                      />
                    </FormField>

                    <FormField
                      id="last-name"
                      label="Player last name"
                      required
                      error={(attemptedStep === 2 || submitted) && !lastNameValid ? 'Use a valid last name with letters only.' : undefined}
                    >
                      <input
                        id="last-name"
                        value={lastName}
                        onChange={(event) => { setLastName(event.target.value); setSaveError(null) }}
                        className={`tlg-input ${(attemptedStep === 2 || submitted) && !lastNameValid ? 'tlg-input-error' : ''}`}
                        placeholder="Last name"
                        maxLength={40}
                        autoComplete="off"
                      />
                    </FormField>
                  </div>

                  <FormField
                    id="country"
                    label="Nationality"
                    required
                    error={(attemptedStep === 2 || submitted) && !countryValid ? 'Choose the country your player represents.' : undefined}
                  >
                    <div className="tlg-country-picker" ref={countryPickerRef}>
                      <button
                        id="country"
                        type="button"
                        className={`tlg-country-trigger ${countryOpen ? 'open' : ''} ${(attemptedStep === 2 || submitted) && !countryValid ? 'tlg-input-error' : ''}`}
                        onClick={() => {
                          if (!countriesLoading) {
                            setCountryOpen((value) => !value)
                            setCountryQuery('')
                          }
                        }}
                        aria-haspopup="listbox"
                        aria-expanded={countryOpen}
                        disabled={countriesLoading}
                      >
                        <span className="tlg-country-trigger-main">
                          {selectedCountry
                            ? <><CountryFlag code={selectedCountry.code} name={selectedCountry.name} /><span>{selectedCountry.name}</span></>
                            : <span className="tlg-country-trigger-placeholder">{countriesLoading ? 'Loading countries…' : 'Choose a country'}</span>}
                        </span>
                        <ChevronDown size={18} />
                      </button>

                      {countryOpen && (
                        <div className="tlg-country-menu">
                          <div className="tlg-country-search">
                            <Search size={16} />
                            <input
                              autoFocus
                              value={countryQuery}
                              onChange={(event) => setCountryQuery(event.target.value)}
                              placeholder="Search country…"
                              aria-label="Search countries"
                              onKeyDown={(event) => { if (event.key === 'Escape') setCountryOpen(false) }}
                            />
                          </div>

                          <div className="tlg-country-options" role="listbox" aria-label="Countries">
                            {filteredCountries.map((item) => (
                              <button
                                key={item.code}
                                type="button"
                                role="option"
                                aria-selected={country === item.code}
                                className={`tlg-country-option ${country === item.code ? 'selected' : ''}`}
                                onClick={() => {
                                  setCountry(item.code)
                                  setCountryOpen(false)
                                  setCountryQuery('')
                                  setHomeCity('')
                                  setSaveError(null)
                                }}
                              >
                                <CountryFlag code={item.code} name={item.name} />
                                <span>{item.name}</span>
                                {country === item.code && <Check size={15} />}
                              </button>
                            ))}
                            {!filteredCountries.length && <div className="tlg-country-empty">No country matches your search.</div>}
                          </div>
                        </div>
                      )}
                    </div>
                  </FormField>

                  <FormField
                    id="home-city"
                    label="Permanent home city"
                    required
                    hint="Your home city is used as the starting point for travel and future home-based systems."
                    error={(attemptedStep === 2 || submitted) && !homeCityValid ? (homeCityLoadError ?? 'Choose one of the available home cities for your country.') : undefined}
                  >
                    <div className="tlg-home-city-control">
                      <select
                        id="home-city"
                        value={homeCity}
                        onChange={(event) => { setHomeCity(event.target.value); setSaveError(null) }}
                        className={`tlg-input tlg-home-city-select ${(attemptedStep === 2 || submitted) && !homeCityValid ? 'tlg-input-error' : ''}`}
                        disabled={!country || homeCitiesLoading || Boolean(homeCityLoadError)}
                      >
                        <option value="">
                          {!country
                            ? 'Choose a country first'
                            : homeCitiesLoading
                              ? 'Loading home cities…'
                              : homeCityLoadError
                                ? 'Home cities unavailable'
                                : 'Choose your home city'}
                        </option>
                        {homeCities.map((item) => (
                          <option key={`${country}-${item.city}`} value={item.city}>{item.city}</option>
                        ))}
                      </select>

                      {selectedCountry && homeCity && (
                        <span className="tlg-home-city-selected">
                          <span>{homeCity}</span>
                          <CountryFlag code={selectedCountry.code} name={selectedCountry.name} />
                        </span>
                      )}
                    </div>
                  </FormField>

                  <div className="tlg-real-name-policy tlg-real-name-policy-v2" role="note">
                    <AlertTriangle size={20} aria-hidden="true" />
                    <div>
                      <strong>REALISTIC PLAYER NAME REQUIRED</strong>
                      <p>Use a normal first and last name. Gamer tags, joke identities, offensive names and impersonating a real professional player are not allowed.</p>
                    </div>
                  </div>
                </div>
              )}

              {step === 3 && (
                <div className="tlg-onboarding-stage-content">
                  <div className="tlg-avatar-picker-header">
                    <div>
                      <strong>Choose a {world} portrait</strong>
                      <p>Portrait selection is optional. Used portraits are unavailable to other active careers.</p>
                    </div>
                    {!avatarsLoading && avatars.length > 0 && <span className="tlg-avatar-count">{availableAvatarCount} available</span>}
                  </div>

                  {avatarsLoading ? (
                    <div className="tlg-avatar-state">Loading {world} player portraits…</div>
                  ) : avatarError ? (
                    <div className="tlg-avatar-state">{avatarError}</div>
                  ) : avatars.length === 0 ? (
                    <div className="tlg-avatar-state">No {world} portraits are available in the avatar library yet.</div>
                  ) : (
                    <div className="tlg-avatar-grid tlg-avatar-grid-v2" aria-label={`${world} player portraits`}>
                      {avatars.map((avatar) => {
                        const selected = selectedAvatarPath === avatar.path
                        return (
                          <button
                            key={avatar.path}
                            type="button"
                            className={`tlg-avatar-option ${selected ? 'selected' : ''} ${!avatar.available ? 'unavailable' : ''}`}
                            disabled={!avatar.available}
                            onClick={() => { setSelectedAvatarPath(avatar.path); setSaveError(null) }}
                            aria-label={avatar.available ? `Select ${avatar.label}` : `${avatar.label} is already in use`}
                            aria-pressed={selected}
                          >
                            <img src={avatar.signedUrl} alt="" loading="lazy" />
                            {selected && <span className="tlg-avatar-selected-mark"><Check size={15} /></span>}
                            {!avatar.available && <span className="tlg-avatar-in-use">In use</span>}
                          </button>
                        )
                      })}
                    </div>
                  )}

                  <div className="tlg-avatar-choice-footer">
                    <span>{selectedAvatar ? 'Portrait selected' : 'No portrait selected — you can continue without one.'}</span>
                    {selectedAvatar && (
                      <button type="button" onClick={() => setSelectedAvatarPath(null)}>Remove selection</button>
                    )}
                  </div>
                </div>
              )}

              {step === 4 && (
                <div className="tlg-onboarding-stage-content tlg-onboarding-profile-stage">
                  <section className={`tlg-surface-preference-card ${(attemptedStep === 4 || submitted) && !surfaceValid ? 'tlg-surface-preference-error' : ''}`}>
                    <div className="tlg-surface-preference-head">
                      <span>PLAYING PROFILE</span>
                      <h2>Preferred surface</h2>
                      <p>Choose the surface your player prefers. It redistributes starting tennis skills but does not change total starting strength.</p>
                    </div>
                    <div className="tlg-surface-options">
                      {SURFACES.map((surface) => (
                        <button
                          key={surface.value}
                          type="button"
                          className={`tlg-surface-option ${preferredSurface === surface.value ? 'selected' : ''}`}
                          onClick={() => { setPreferredSurface(surface.value); setSaveError(null) }}
                          aria-pressed={preferredSurface === surface.value}
                        >
                          <span className={`tlg-surface-dot tlg-surface-dot-${surface.value.toLowerCase()}`}><Circle size={13} /></span>
                          <span><strong>{surface.value}</strong><small>{surface.text}</small></span>
                          {preferredSurface === surface.value && <Check size={17} />}
                        </button>
                      ))}
                    </div>
                  </section>

                  <section className={`tlg-style-preference-card ${(attemptedStep === 4 || submitted) && !styleValid ? 'tlg-style-preference-error' : ''}`}>
                    <div className="tlg-style-preference-head">
                      <span>PLAYING PROFILE</span>
                      <h2>Playing style</h2>
                      <p>Choose how your existing skill profile will be expressed during matches. This is not a flat strength bonus.</p>
                    </div>
                    <div className="tlg-style-options">
                      {PLAYING_STYLES.map((style) => (
                        <button
                          key={style.value}
                          type="button"
                          className={`tlg-style-option ${playingStyle === style.value ? 'selected' : ''}`}
                          onClick={() => { setPlayingStyle(style.value); setSaveError(null) }}
                          aria-pressed={playingStyle === style.value}
                        >
                          <span><strong>{style.value}</strong><small>{style.text}</small></span>
                          <em>{playingStyle === style.value ? 'Selected' : 'Choose'}</em>
                        </button>
                      ))}
                    </div>
                  </section>

                  {(attemptedStep === 4 || submitted) && (!surfaceValid || !styleValid) && (
                    <div className="tlg-auth-status tlg-auth-status-information" role="alert">
                      <ShieldCheck size={18} />
                      <span>Choose both a preferred surface and playing style before continuing.</span>
                    </div>
                  )}
                </div>
              )}

              {step === 5 && (
                <div className="tlg-onboarding-stage-content">
                  <div className="tlg-onboarding-review">
                    <div className="tlg-onboarding-review-player">
                      <div className="tlg-onboarding-review-avatar">
                        {selectedAvatar
                          ? <img src={selectedAvatar.signedUrl} alt="Selected player portrait" />
                          : <UserRound size={42} />}
                      </div>
                      <div>
                        <span>Ready to start</span>
                        <h3>{cleanFirstName} {cleanLastName}</h3>
                        <p>{world} · {selectedCountryName}</p>
                      </div>
                    </div>

                    <div className="tlg-onboarding-review-grid">
                      <div><span>Tour</span><strong>{world}</strong></div>
                      <div><span>Nationality</span><strong>{selectedCountryName}</strong></div>
                      <div><span>Home city</span><strong>{homeCity}</strong></div>
                      <div><span>Portrait</span><strong>{selectedAvatar ? 'Selected' : 'None'}</strong></div>
                      <div><span>Preferred surface</span><strong>{preferredSurface ?? 'Not selected'}</strong></div>
                      <div><span>Playing style</span><strong>{playingStyle ?? 'Not selected'}</strong></div>
                    </div>

                    <div className="tlg-onboarding-start-note">
                      <ShieldCheck size={18} />
                      <p>
                        <strong>Start Career</strong> creates this player once and starts the existing Tennis Legacy career initialization for skills, equipment, finance, rankings and other starting systems.
                      </p>
                    </div>
                  </div>
                </div>
              )}

              {saveError && (
                <div className="tlg-auth-status tlg-auth-status-information tlg-onboarding-save-error" role="alert">
                  <ShieldCheck size={18} />
                  <span>{saveError}</span>
                </div>
              )}
            </div>

            <footer className="tlg-onboarding-nav">
              <div>
                {step > 1 && (
                  <AppButton type="button" variant="secondary" size="large" onClick={goBack} disabled={saving}>
                    Back
                  </AppButton>
                )}
              </div>

              <span className="tlg-onboarding-nav-status">
                {step < 5 ? 'Your progress is saved on this device.' : 'Review everything before creating the career.'}
              </span>

              {step < 5 ? (
                <AppButton
                  type="button"
                  variant="primary"
                  size="large"
                  onClick={goNext}
                  disabled={step === 2 && (countriesLoading || homeCitiesLoading)}
                  rightIcon={<ArrowRight size={18} />}
                >
                  Continue
                </AppButton>
              ) : (
                <AppButton
                  type="submit"
                  variant="primary"
                  size="large"
                  loading={saving}
                  disabled={!user || !formValid}
                  rightIcon={<ArrowRight size={18} />}
                >
                  {saving ? 'Starting your career…' : 'Start Career'}
                </AppButton>
              )}
            </footer>
          </section>

          <aside className="tlg-player-preview-card tlg-player-preview-card-v2">
            <div className="tlg-player-preview-visual">
              {selectedAvatar
                ? <img src={selectedAvatar.signedUrl} alt="Selected player portrait" />
                : <div className="tlg-player-preview-placeholder"><UserRound size={45} /></div>}
            </div>
            <div className="tlg-player-preview-copy">
              <p className="tlg-page-heading-eyebrow">Your career</p>
              <h3>{`${firstName} ${lastName}`.trim() || 'Your Player'}</h3>
              <p className="tlg-player-preview-country">
                {selectedCountry && <CountryFlag code={selectedCountry.code} name={selectedCountry.name} />}
                <span>{selectedCountryName}</span>
              </p>
              <div className="tlg-player-preview-tags">
                <span className="tlg-player-preview-tag">{world}</span>
                {preferredSurface && <span className="tlg-player-preview-tag">{preferredSurface}</span>}
                {playingStyle && <span className="tlg-player-preview-tag">{playingStyle}</span>}
              </div>
              <div className="tlg-player-preview-meta">
                <div className="tlg-player-preview-meta-row"><span>Current step</span><strong>{currentStep.label}</strong></div>
                <div className="tlg-player-preview-meta-row"><span>Home base</span><strong>{homeCity || 'Not selected'}</strong></div>
                <div className="tlg-player-preview-meta-row"><span>Account</span><strong>{user?.email ?? 'Authenticated'}</strong></div>
                <div className="tlg-player-preview-meta-row"><span>Starting technical points</span><strong>440–455 · varied</strong></div>
              </div>
            </div>
          </aside>
        </form>
      </main>
    </div>
  )
}

function CountryFlag({ code, name }: { code: string; name: string }) {
  return <SharedCountryFlag countryCode={code} countryName={name} width={22} height={16} />
}

function avatarLabel(path: string) {
  const fileName = path.split('/').pop() ?? path
  return fileName.replace(/\.[^.]+$/, '')
}
