/**
 * CreatePlayer.tsx
 * First-login player onboarding for Tennis Legacy: Rise to Glory.
 */

import type { FormEvent } from 'react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
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
import { useLocalization } from '../../i18n/LocalizationProvider'
import { supabase } from '../../lib/supabase'
import '../../styles/create-player-enhancements.css'

type PlayerWorld = 'ATP' | 'WTA'
type PreferredSurface = 'Hard' | 'Clay' | 'Grass'
type PlayingStyle = 'Aggressive Baseliner' | 'Defensive Baseliner' | 'All-court' | 'Serve & Volley'
type PlayingHand = 'right' | 'left'
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
  playingHand?: PlayingHand | null
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

const ONBOARDING_STEPS: Array<{ id: OnboardingStep; labelKey: string; shortKey: string }> = [
  { id: 1, labelKey: 'createPlayer.steps.career', shortKey: 'createPlayer.steps.tour' },
  { id: 2, labelKey: 'createPlayer.steps.player', shortKey: 'createPlayer.steps.identity' },
  { id: 3, labelKey: 'createPlayer.steps.appearance', shortKey: 'createPlayer.steps.portrait' },
  { id: 4, labelKey: 'createPlayer.steps.profile', shortKey: 'createPlayer.steps.style' },
  { id: 5, labelKey: 'createPlayer.steps.confirm', shortKey: 'createPlayer.steps.review' },
]

const SURFACES: Array<{ value: PreferredSurface; labelKey: string; textKey: string }> = [
  { value: 'Hard', labelKey: 'createPlayer.surfaces.Hard', textKey: 'createPlayer.surfaces.hardBody' },
  { value: 'Clay', labelKey: 'createPlayer.surfaces.Clay', textKey: 'createPlayer.surfaces.clayBody' },
  { value: 'Grass', labelKey: 'createPlayer.surfaces.Grass', textKey: 'createPlayer.surfaces.grassBody' },
]

const PLAYING_STYLES: Array<{ value: PlayingStyle; labelKey: string; textKey: string }> = [
  { value: 'Aggressive Baseliner', labelKey: 'createPlayer.styles.aggressive', textKey: 'createPlayer.styles.aggressiveBody' },
  { value: 'Defensive Baseliner', labelKey: 'createPlayer.styles.defensive', textKey: 'createPlayer.styles.defensiveBody' },
  { value: 'All-court', labelKey: 'createPlayer.styles.allCourt', textKey: 'createPlayer.styles.allCourtBody' },
  { value: 'Serve & Volley', labelKey: 'createPlayer.styles.serveVolley', textKey: 'createPlayer.styles.serveVolleyBody' },
]

const PLAYING_HANDS: Array<{ value: PlayingHand; labelKey: string; textKey: string }> = [
  { value: 'right', labelKey: 'createPlayer.hands.right', textKey: 'createPlayer.hands.rightBody' },
  { value: 'left', labelKey: 'createPlayer.hands.left', textKey: 'createPlayer.hands.leftBody' },
]

export default function CreatePlayerPage(): JSX.Element {
  const { t } = useTranslation()
  const { localeTag } = useLocalization()
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
  const [homeCityOpen, setHomeCityOpen] = useState(false)
  const [homeCityQuery, setHomeCityQuery] = useState('')
  const [homeCitiesLoading, setHomeCitiesLoading] = useState(false)
  const [homeCityLoadError, setHomeCityLoadError] = useState<string | null>(null)
  const [world, setWorld] = useState<PlayerWorld>('ATP')
  const [preferredSurface, setPreferredSurface] = useState<PreferredSurface | null>(null)
  const [playingStyle, setPlayingStyle] = useState<PlayingStyle | null>(null)
  const [playingHand, setPlayingHand] = useState<PlayingHand | null>(null)
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
  const homeCityPickerRef = useRef<HTMLDivElement | null>(null)
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
        if (draft.playingHand === 'right' || draft.playingHand === 'left') {
          setPlayingHand(draft.playingHand)
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
    setHomeCityOpen(false)
    setHomeCityQuery('')
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
        setHomeCityLoadError(t('createPlayer.errors.homeCities'))
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
      if (!homeCityPickerRef.current?.contains(target)) setHomeCityOpen(false)
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
        setAvatarError(t('createPlayer.errors.portraitsLoad'))
        return
      }

      const rows = ((data ?? []) as AvatarCatalogRow[]).filter((row) => row.is_available)
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
        setAvatarError(t('createPlayer.errors.portraitsDisplay'))
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
          available: true,
          label: avatarLabel(row.path),
        }))
        .filter((item) => item.signedUrl.length > 0)

      setAvatars(nextAvatars)
      setSelectedAvatarPath((current) =>
        current && nextAvatars.some((item) => item.path === current) ? current : null,
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
      playingHand,
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
    playingHand,
  ])

  const localizedCountries = useMemo(() => {
    let displayNames: Intl.DisplayNames | null = null
    try { displayNames = new Intl.DisplayNames([localeTag], { type: 'region' }) } catch { displayNames = null }
    return countries.map((item) => ({
      ...item,
      displayName: displayNames?.of(item.code) ?? item.name,
    }))
  }, [countries, localeTag])

  const selectedCountry = useMemo(
    () => localizedCountries.find((item) => item.code === country) ?? null,
    [localizedCountries, country],
  )

  const filteredCountries = useMemo(() => {
    const query = countryQuery.trim().toLocaleLowerCase()
    if (!query) return localizedCountries
    return localizedCountries.filter((item) => `${item.displayName} ${item.name} ${item.code}`.toLocaleLowerCase().includes(query))
  }, [localizedCountries, countryQuery])

  const filteredHomeCities = useMemo(() => {
    const query = homeCityQuery.trim().toLocaleLowerCase()
    if (!query) return homeCities
    return homeCities.filter((item) => item.city.toLocaleLowerCase().includes(query))
  }, [homeCities, homeCityQuery])

  const selectedAvatar = useMemo(
    () => avatars.find((item) => item.path === selectedAvatarPath) ?? null,
    [avatars, selectedAvatarPath],
  )

  const selectedCountryName = selectedCountry?.displayName ?? t('createPlayer.identity.countryNotSelected')
  const availableAvatarCount = avatars.length
  const cleanFirstName = firstName.trim()
  const cleanLastName = lastName.trim()
  const firstNameValid = cleanFirstName.length >= 2 && NAME_PATTERN.test(cleanFirstName)
  const lastNameValid = cleanLastName.length >= 2 && NAME_PATTERN.test(cleanLastName)
  const countryValid = country.length === 2
  const homeCityValid = homeCity.length > 0 && homeCities.some((item) => item.city === homeCity)
  const surfaceValid = preferredSurface !== null
  const styleValid = playingStyle !== null
  const handValid = playingHand !== null
  const identityValid = firstNameValid && lastNameValid && countryValid && homeCityValid
  const profileValid = surfaceValid && styleValid && handValid
  const formValid = identityValid && profileValid

  const currentStep = ONBOARDING_STEPS.find((item) => item.id === step) ?? ONBOARDING_STEPS[0]
  const surfaceLabel = (value: PreferredSurface | null) => value ? t(`createPlayer.surfaces.${value}`) : t('createPlayer.review.notSelected')
  const styleLabel = (value: PlayingStyle | null) => {
    if (value === 'Aggressive Baseliner') return t('createPlayer.styles.aggressive')
    if (value === 'Defensive Baseliner') return t('createPlayer.styles.defensive')
    if (value === 'All-court') return t('createPlayer.styles.allCourt')
    if (value === 'Serve & Volley') return t('createPlayer.styles.serveVolley')
    return t('createPlayer.review.notSelected')
  }
  const handLabel = (value: PlayingHand | null) => value === 'left'
    ? t('createPlayer.hands.left')
    : value === 'right'
      ? t('createPlayer.hands.right')
      : t('createPlayer.review.notSelected')

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

    if (!formValid || !user || !preferredSurface || !playingStyle || !playingHand || saving) return
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
        playing_hand: playingHand,
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
          setSaveError(t('createPlayer.errors.portraitTaken'))
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
      setSaveError(t('createPlayer.errors.create'))
    }
  }

  return (
    <div className="tlg-onboarding-page tlg-onboarding-page-v2">
      <header className="tlg-onboarding-topbar">
        <Link to="/" className="tlg-brand" aria-label={t('createPlayer.top.homepageAria')}>
          <span className="tlg-brand-mark" aria-hidden="true" />
          <span className="tlg-brand-copy">
            <strong className="tlg-brand-name">Tennis Legacy</strong>
            <span className="tlg-brand-subtitle">{t('authPages.brandSubtitle')}</span>
          </span>
        </Link>

        <div className="tlg-onboarding-topbar-actions">
          <div className="tlg-onboarding-account-state">
            <span>{t('createPlayer.top.accountVerified')}</span>
            <strong>{user?.email ?? t('createPlayer.top.authenticated')}</strong>
          </div>

          <Link to="/" className="tlg-onboarding-home-link">
            <ArrowLeft size={15} />
            <span>{t('createPlayer.top.backHome')}</span>
          </Link>
        </div>
      </header>

      <main className="tlg-onboarding-main tlg-onboarding-main-v2">
        <div className="tlg-onboarding-hero tlg-onboarding-hero-v2">
          <div>
            <p className="tlg-page-heading-eyebrow">{t('createPlayer.top.eyebrow')}</p>
            <h1>{t('createPlayer.top.title')}</h1>
            <p>
              {t('createPlayer.top.description')}
            </p>
          </div>
        </div>

        <nav className="tlg-onboarding-stepper" aria-label={t('createPlayer.top.progressAria')}>
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
                  <strong>{t(item.labelKey)}</strong>
                  <small>{t(item.shortKey)}</small>
                </span>
              </div>
            )
          })}
        </nav>

        <form className="tlg-onboarding-wizard" onSubmit={handleCreate} noValidate>
          <section className="tlg-onboarding-stage-card">
            <header className="tlg-onboarding-stage-header">
              <div>
                <span>{t('createPlayer.top.step', { step, label: t(currentStep.labelKey) })}</span>
                <h2>
                  {step === 1 && t('createPlayer.top.step1')}
                  {step === 2 && t('createPlayer.top.step2')}
                  {step === 3 && t('createPlayer.top.step3')}
                  {step === 4 && t('createPlayer.top.step4')}
                  {step === 5 && t('createPlayer.top.step5')}
                </h2>
              </div>
              <strong>{Math.round((step / 5) * 100)}%</strong>
            </header>

            <div className="tlg-onboarding-stage-body">
              {step === 1 && (
                <div className="tlg-onboarding-stage-content">
                  <p className="tlg-onboarding-stage-intro">
                    {t('createPlayer.tour.intro')}
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
                        <span className="tlg-world-option-badge">{world === option ? t('createPlayer.tour.selected') : t('createPlayer.tour.choose')}</span>
                        <strong>{option}</strong>
                        <p>
                          {option === 'ATP'
                            ? t('createPlayer.tour.atp')
                            : t('createPlayer.tour.wta')}
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
                    {t('createPlayer.identity.intro')}
                  </p>

                  <div className="tlg-onboarding-form-grid">
                    <FormField
                      id="first-name"
                      label={t('createPlayer.identity.firstName')}"
                      required
                      error={(attemptedStep === 2 || submitted) && !firstNameValid ? t('createPlayer.errors.firstName') : undefined}
                    >
                      <input
                        id="first-name"
                        value={firstName}
                        onChange={(event) => { setFirstName(event.target.value); setSaveError(null) }}
                        className={`tlg-input ${(attemptedStep === 2 || submitted) && !firstNameValid ? 'tlg-input-error' : ''}`}
                        placeholder={t('createPlayer.identity.firstPlaceholder')}
                        maxLength={40}
                        autoComplete="off"
                      />
                    </FormField>

                    <FormField
                      id="last-name"
                      label={t('createPlayer.identity.lastName')}"
                      required
                      error={(attemptedStep === 2 || submitted) && !lastNameValid ? t('createPlayer.errors.lastName') : undefined}
                    >
                      <input
                        id="last-name"
                        value={lastName}
                        onChange={(event) => { setLastName(event.target.value); setSaveError(null) }}
                        className={`tlg-input ${(attemptedStep === 2 || submitted) && !lastNameValid ? 'tlg-input-error' : ''}`}
                        placeholder={t('createPlayer.identity.lastPlaceholder')}
                        maxLength={40}
                        autoComplete="off"
                      />
                    </FormField>
                  </div>

                  <FormField
                    id="country"
                    label={t('createPlayer.identity.nationality')}
                    required
                    error={(attemptedStep === 2 || submitted) && !countryValid ? t('createPlayer.errors.nationality') : undefined}
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
                            ? <><CountryFlag code={selectedCountry.code} name={selectedCountry.displayName} /><span>{selectedCountry.displayName}</span></>
                            : <span className="tlg-country-trigger-placeholder">{countriesLoading ? t('createPlayer.identity.loadingCountries') : t('createPlayer.identity.chooseCountry')}</span>}
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
                              placeholder={t('createPlayer.identity.searchCountry')}
                              aria-label={t('createPlayer.identity.searchCountriesAria')}
                              onKeyDown={(event) => { if (event.key === 'Escape') setCountryOpen(false) }}
                            />
                          </div>

                          <div className="tlg-country-options" role="listbox" aria-label={t('createPlayer.identity.countriesAria')}>
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
                                <CountryFlag code={item.code} name={item.displayName} />
                                <span>{item.displayName}</span>
                                {country === item.code && <Check size={15} />}
                              </button>
                            ))}
                            {!filteredCountries.length && <div className="tlg-country-empty">{t('createPlayer.identity.noCountry')}</div>}
                          </div>
                        </div>
                      )}
                    </div>
                  </FormField>

                  <FormField
                    id="home-city"
                    label={t('createPlayer.identity.homeCity')}
                    required
                    hint={t('createPlayer.identity.homeCityHint')}
                    error={(attemptedStep === 2 || submitted) && !homeCityValid ? (homeCityLoadError ?? t('createPlayer.errors.homeCity')) : undefined}
                  >
                    <div className="tlg-home-city-control tlg-city-picker" ref={homeCityPickerRef}>
                      <button
                        id="home-city"
                        type="button"
                        className={`tlg-city-trigger ${homeCityOpen ? 'open' : ''} ${(attemptedStep === 2 || submitted) && !homeCityValid ? 'tlg-input-error' : ''}`}
                        onClick={() => {
                          if (country && !homeCitiesLoading && !homeCityLoadError) {
                            setHomeCityOpen((value) => !value)
                            setHomeCityQuery('')
                          }
                        }}
                        aria-haspopup="listbox"
                        aria-expanded={homeCityOpen}
                        disabled={!country || homeCitiesLoading || Boolean(homeCityLoadError)}
                      >
                        <span className="tlg-city-trigger-main">
                          {selectedCountry && <CountryFlag code={selectedCountry.code} name={selectedCountry.displayName} />}
                          <span className={homeCity ? '' : 'tlg-city-trigger-placeholder'}>
                            {!country
                              ? t('createPlayer.identity.chooseCountryFirst')
                              : homeCitiesLoading
                                ? `${selectedCountry?.displayName ?? t('createPlayer.identity.country')} · ${t('createPlayer.identity.loadingCities')}`
                                : homeCityLoadError
                                  ? `${selectedCountry?.displayName ?? t('createPlayer.identity.country')} · ${t('createPlayer.identity.citiesUnavailable')}`
                                  : homeCity
                                    ? `${selectedCountry?.displayName ?? ''} · ${homeCity}`
                                    : `${selectedCountry?.displayName ?? t('createPlayer.identity.country')} · ${t('createPlayer.identity.chooseHomeCity')}`}
                          </span>
                        </span>
                        <ChevronDown size={18} />
                      </button>

                      {homeCityOpen && selectedCountry && (
                        <div className="tlg-city-menu">
                          <div className="tlg-city-search">
                            <Search size={16} />
                            <input
                              autoFocus
                              value={homeCityQuery}
                              onChange={(event) => setHomeCityQuery(event.target.value)}
                              placeholder={t('createPlayer.identity.searchCities', { country: selectedCountry.displayName })}
                              aria-label={t('createPlayer.identity.searchCitiesAria', { country: selectedCountry.displayName })}
                              onKeyDown={(event) => { if (event.key === 'Escape') setHomeCityOpen(false) }}
                            />
                          </div>

                          <div className="tlg-city-options" role="listbox" aria-label={t('createPlayer.identity.citiesAria', { country: selectedCountry.displayName })}>
                            {filteredHomeCities.map((item) => (
                              <button
                                key={`${country}-${item.city}`}
                                type="button"
                                role="option"
                                aria-selected={homeCity === item.city}
                                className={`tlg-city-option ${homeCity === item.city ? 'selected' : ''}`}
                                onClick={() => {
                                  setHomeCity(item.city)
                                  setHomeCityOpen(false)
                                  setHomeCityQuery('')
                                  setSaveError(null)
                                }}
                              >
                                <CountryFlag code={selectedCountry.code} name={selectedCountry.displayName} />
                                <span className="tlg-city-option-country">{selectedCountry.displayName}</span>
                                <span className="tlg-city-option-name">{item.city}</span>
                                {homeCity === item.city && <Check size={15} />}
                              </button>
                            ))}
                            {!filteredHomeCities.length && <div className="tlg-city-empty">{t('createPlayer.identity.noCity')}</div>}
                          </div>
                        </div>
                      )}
                    </div>
                  </FormField>

                  <div className="tlg-real-name-policy tlg-real-name-policy-v2" role="note">
                    <AlertTriangle size={20} aria-hidden="true" />
                    <div>
                      <strong>{t('createPlayer.identity.realisticName')}</strong>
                      <p>{t('createPlayer.identity.realisticNameBody')}</p>
                    </div>
                  </div>
                </div>
              )}

              {step === 3 && (
                <div className="tlg-onboarding-stage-content">
                  <div className="tlg-avatar-picker-header">
                    <div>
                      <strong>{t('createPlayer.portrait.title', { world })}</strong>
                      <p>{t('createPlayer.portrait.body')}</p>
                    </div>
                    {!avatarsLoading && avatars.length > 0 && <span className="tlg-avatar-count">{t('createPlayer.portrait.available', { count: availableAvatarCount })}</span>}
                  </div>

                  {avatarsLoading ? (
                    <div className="tlg-avatar-state">{t('createPlayer.portrait.loading', { world })}</div>
                  ) : avatarError ? (
                    <div className="tlg-avatar-state">{avatarError}</div>
                  ) : avatars.length === 0 ? (
                    <div className="tlg-avatar-state">{t('createPlayer.portrait.noneAvailable', { world })}</div>
                  ) : (
                    <div className="tlg-avatar-grid tlg-avatar-grid-v2" aria-label={t('createPlayer.portrait.aria', { world })}>
                      {avatars.map((avatar) => {
                        const selected = selectedAvatarPath === avatar.path
                        return (
                          <button
                            key={avatar.path}
                            type="button"
                            className={`tlg-avatar-option ${selected ? 'selected' : ''}`}
                            onClick={() => { setSelectedAvatarPath(avatar.path); setSaveError(null) }}
                            aria-label={t('createPlayer.portrait.selectAria', { label: avatar.label })}
                            aria-pressed={selected}
                          >
                            <img src={avatar.signedUrl} alt="" loading="lazy" />
                            {selected && <span className="tlg-avatar-selected-mark"><Check size={15} /></span>}
                          </button>
                        )
                      })}
                    </div>
                  )}

                  <div className="tlg-avatar-choice-footer">
                    <span>{selectedAvatar ? t('createPlayer.portrait.selected') : t('createPlayer.portrait.none')}</span>
                    {selectedAvatar && (
                      <button type="button" onClick={() => setSelectedAvatarPath(null)}>{t('createPlayer.portrait.remove')}</button>
                    )}
                  </div>
                </div>
              )}

              {step === 4 && (
                <div className="tlg-onboarding-stage-content tlg-onboarding-profile-stage">
                  <section className={`tlg-surface-preference-card ${(attemptedStep === 4 || submitted) && !surfaceValid ? 'tlg-surface-preference-error' : ''}`}>
                    <div className="tlg-surface-preference-head">
                      <span>{t('createPlayer.playing.profileLabel')}</span>
                      <h2>{t('createPlayer.playing.surfaceTitle')}</h2>
                      <p>{t('createPlayer.playing.surfaceBody')}</p>
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
                          <span><strong>{t(surface.labelKey)}</strong><small>{t(surface.textKey)}</small></span>
                          {preferredSurface === surface.value && <Check size={17} />}
                        </button>
                      ))}
                    </div>
                  </section>

                  <section className={`tlg-style-preference-card ${(attemptedStep === 4 || submitted) && !styleValid ? 'tlg-style-preference-error' : ''}`}>
                    <div className="tlg-style-preference-head">
                      <span>{t('createPlayer.playing.profileLabel')}</span>
                      <h2>{t('createPlayer.playing.styleTitle')}</h2>
                      <p>{t('createPlayer.playing.styleBody')}</p>
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
                          <span><strong>{t(style.labelKey)}</strong><small>{t(style.textKey)}</small></span>
                          <em>{playingStyle === style.value ? t('createPlayer.playing.selected') : t('createPlayer.playing.choose')}</em>
                        </button>
                      ))}
                    </div>
                  </section>

                  <section className={`tlg-hand-preference-card ${(attemptedStep === 4 || submitted) && !handValid ? 'tlg-hand-preference-error' : ''}`}>
                    <div className="tlg-hand-preference-head">
                      <span>{t('createPlayer.playing.profileLabel')}</span>
                      <h2>{t('createPlayer.playing.handTitle')}</h2>
                      <p>{t('createPlayer.playing.handBody')}</p>
                    </div>
                    <div className="tlg-hand-options">
                      {PLAYING_HANDS.map((hand) => (
                        <button
                          key={hand.value}
                          type="button"
                          className={`tlg-hand-option ${playingHand === hand.value ? 'selected' : ''}`}
                          onClick={() => { setPlayingHand(hand.value); setSaveError(null) }}
                          aria-pressed={playingHand === hand.value}
                        >
                          <span><strong>{t(hand.labelKey)}</strong><small>{t(hand.textKey)}</small></span>
                          {playingHand === hand.value && <Check size={17} />}
                        </button>
                      ))}
                    </div>
                  </section>

                  <section className="tlg-player-identity-preview">
                    <span>{t('createPlayer.playing.preview')}</span>
                    <strong>
                      {playingHand ? handLabel(playingHand) : t('createPlayer.playing.chooseHand')}
                      {' · '}
                      {playingStyle ? styleLabel(playingStyle) : t('createPlayer.playing.chooseStyle')}
                    </strong>
                    <p>
                      {preferredSurface ? t('createPlayer.playing.courtPreference', { surface: surfaceLabel(preferredSurface) }) : t('createPlayer.playing.chooseSurface')}
                      {' '}
                      {t('createPlayer.playing.geometry')}
                    </p>
                  </section>

                  {(attemptedStep === 4 || submitted) && (!surfaceValid || !styleValid || !handValid) && (
                    <div className="tlg-auth-status tlg-auth-status-information" role="alert">
                      <ShieldCheck size={18} />
                      <span>{t('createPlayer.errors.profile')}</span>
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
                          ? <img src={selectedAvatar.signedUrl} alt={t('createPlayer.portrait.selectedAlt')} />
                          : <UserRound size={42} />}
                      </div>
                      <div>
                        <span>{t('createPlayer.review.ready')}</span>
                        <h3>{cleanFirstName} {cleanLastName}</h3>
                        <p>{world} · {selectedCountryName}</p>
                      </div>
                    </div>

                    <div className="tlg-onboarding-review-grid">
                      <div><span>{t('createPlayer.review.tour')}</span><strong>{world}</strong></div>
                      <div><span>{t('createPlayer.review.nationality')}</span><strong>{selectedCountryName}</strong></div>
                      <div><span>{t('createPlayer.review.homeCity')}</span><strong>{homeCity}</strong></div>
                      <div><span>{t('createPlayer.review.portrait')}</span><strong>{selectedAvatar ? t('createPlayer.review.selected') : t('createPlayer.review.none')}</strong></div>
                      <div><span>{t('createPlayer.review.surface')}</span><strong>{surfaceLabel(preferredSurface)}</strong></div>
                      <div><span>{t('createPlayer.review.style')}</span><strong>{styleLabel(playingStyle)}</strong></div>
                      <div><span>{t('createPlayer.review.hand')}</span><strong>{handLabel(playingHand)}</strong></div>
                    </div>

                    <div className="tlg-onboarding-start-note">
                      <ShieldCheck size={18} />
                      <p>
                        <strong>{t('createPlayer.review.start')}</strong> {t('createPlayer.review.startBody')}
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
                {step < 5 ? t('createPlayer.review.progressSaved') : t('createPlayer.review.reviewFirst')}
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
                  {saving ? t('createPlayer.review.starting') : t('createPlayer.review.start')}
                </AppButton>
              )}
            </footer>
          </section>

          <aside className="tlg-player-preview-card tlg-player-preview-card-v2">
            <div className="tlg-player-preview-visual">
              {selectedAvatar
                ? <img src={selectedAvatar.signedUrl} alt={t('createPlayer.portrait.selectedAlt')} />
                : <div className="tlg-player-preview-placeholder"><UserRound size={45} /></div>}
            </div>
            <div className="tlg-player-preview-copy">
              <p className="tlg-page-heading-eyebrow">{t('createPlayer.review.yourCareer')}</p>
              <h3>{`${firstName} ${lastName}`.trim() || t('createPlayer.review.yourPlayer')}</h3>
              <p className="tlg-player-preview-country">
                {selectedCountry && <CountryFlag code={selectedCountry.code} name={selectedCountry.displayName} />}
                <span>{selectedCountryName}</span>
              </p>
              <div className="tlg-player-preview-tags">
                <span className="tlg-player-preview-tag">{world}</span>
                {preferredSurface && <span className="tlg-player-preview-tag">{preferredSurface}</span>}
                {playingStyle && <span className="tlg-player-preview-tag">{playingStyle}</span>}
                {playingHand && <span className="tlg-player-preview-tag">{handLabel(playingHand)}</span>}
              </div>
              <div className="tlg-player-preview-meta">
                <div className="tlg-player-preview-meta-row"><span>{t('createPlayer.review.currentStep')}</span><strong>{t(currentStep.labelKey)}</strong></div>
                <div className="tlg-player-preview-meta-row"><span>{t('createPlayer.review.homeBase')}</span><strong>{homeCity || t('createPlayer.review.notSelected')}</strong></div>
                <div className="tlg-player-preview-meta-row"><span>{t('createPlayer.review.hand')}</span><strong>{handLabel(playingHand)}</strong></div>
                <div className="tlg-player-preview-meta-row"><span>{t('createPlayer.review.account')}</span><strong>{user?.email ?? t('createPlayer.review.authenticated')}</strong></div>
                <div className="tlg-player-preview-meta-row"><span>{t('createPlayer.review.startingPoints')}</span><strong>440–455 · varied</strong></div>
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
