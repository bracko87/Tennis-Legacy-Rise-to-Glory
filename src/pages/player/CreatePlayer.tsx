/**
 * CreatePlayer.tsx
 * First-login player onboarding for Tennis Legacy: Rise to Glory.
 */

import type { FormEvent } from 'react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router'
import {
  AlertTriangle,
  ArrowRight,
  Check,
  ChevronDown,
  Circle,
  Globe2,
  ImagePlus,
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

  const countryPickerRef = useRef<HTMLDivElement | null>(null)

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
      } else {
        setHomeCities(data as HomeCityOption[])
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
  const formValid = firstNameValid && lastNameValid && countryValid && homeCityValid && surfaceValid && styleValid

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
            navigate('/game/overview', { replace: true })
            return
          }

          setSelectedAvatarPath(null)
          setAvatarRefreshKey((value) => value + 1)
          setSaving(false)
          setSaveError('That player portrait was just selected by another manager. Choose another available portrait and try again.')
          return
        }
        throw error
      }

      await refreshPlayer()
      navigate('/game/overview', { replace: true })
    } catch (error) {
      console.error('Unable to create Tennis Legacy player:', error)
      setSaving(false)
      setSaveError('Your player could not be created. Check the selected details, including the home city, and try again.')
    }
  }

  return (
    <div className="tlg-onboarding-page">
      <header className="tlg-onboarding-topbar">
        <Link to="/" className="tlg-brand" aria-label="Tennis Legacy homepage">
          <span className="tlg-brand-mark" aria-hidden="true" />
          <span className="tlg-brand-copy">
            <strong className="tlg-brand-name">Tennis Legacy</strong>
            <span className="tlg-brand-subtitle">Rise to Glory</span>
          </span>
        </Link>
        <div className="tlg-onboarding-progress" aria-label="Onboarding progress">
          <span>Account</span><i className="active" />
          <span>Player</span><i className="active" />
          <span>Career</span><i />
        </div>
      </header>

      <main className="tlg-onboarding-main">
        <div className="tlg-onboarding-hero">
          <div>
            <p className="tlg-page-heading-eyebrow">Build your professional</p>
            <h1>Create your player identity.</h1>
            <p>Choose the identity that will represent your entire Tennis Legacy career. Your world and core player identity become part of the shared multiplayer universe.</p>
          </div>
        </div>

        <form className="tlg-onboarding-grid" onSubmit={handleCreate} noValidate>
          <div className="space-y-4">
            <section className="tlg-onboarding-section">
              <header className="tlg-onboarding-section-header">
                <div><span>01 · Identity</span><h2>Professional profile</h2></div>
                <UserRound size={20} className="text-[color:var(--tlg-cyan)]" />
              </header>
              <div className="tlg-onboarding-section-body space-y-4">
                <div className="tlg-onboarding-form-grid">
                  <FormField id="first-name" label="First name" required error={submitted && !firstNameValid ? 'Use a valid first name with letters only.' : undefined}>
                    <input id="first-name" value={firstName} onChange={(event) => { setFirstName(event.target.value); setSaveError(null) }} className={`tlg-input ${submitted && !firstNameValid ? 'tlg-input-error' : ''}`} placeholder="First name" maxLength={40} autoComplete="off" />
                  </FormField>
                  <FormField id="last-name" label="Last name" required error={submitted && !lastNameValid ? 'Use a valid last name with letters only.' : undefined}>
                    <input id="last-name" value={lastName} onChange={(event) => { setLastName(event.target.value); setSaveError(null) }} className={`tlg-input ${submitted && !lastNameValid ? 'tlg-input-error' : ''}`} placeholder="Last name" maxLength={40} autoComplete="off" />
                  </FormField>
                </div>

                <FormField id="country" label="Representing country" required error={submitted && !countryValid ? 'Choose the country your player represents.' : undefined}>
                  <div className="tlg-country-picker" ref={countryPickerRef}>
                    <button id="country" type="button" className={`tlg-country-trigger ${countryOpen ? 'open' : ''} ${submitted && !countryValid ? 'tlg-input-error' : ''}`} onClick={() => { if (!countriesLoading) { setCountryOpen((value) => !value); setCountryQuery('') } }} aria-haspopup="listbox" aria-expanded={countryOpen} disabled={countriesLoading}>
                      <span className="tlg-country-trigger-main">
                        {selectedCountry ? <><CountryFlag code={selectedCountry.code} name={selectedCountry.name} /><span>{selectedCountry.name}</span></> : <span className="tlg-country-trigger-placeholder">{countriesLoading ? 'Loading countries…' : 'Choose a country'}</span>}
                      </span>
                      <ChevronDown size={18} />
                    </button>
                    {countryOpen && (
                      <div className="tlg-country-menu">
                        <div className="tlg-country-search"><Search size={16} /><input autoFocus value={countryQuery} onChange={(event) => setCountryQuery(event.target.value)} placeholder="Search country…" aria-label="Search countries" onKeyDown={(event) => { if (event.key === 'Escape') setCountryOpen(false) }} /></div>
                        <div className="tlg-country-options" role="listbox" aria-label="Countries">
                          {filteredCountries.map((item) => (
                            <button key={item.code} type="button" role="option" aria-selected={country === item.code} className={`tlg-country-option ${country === item.code ? 'selected' : ''}`} onClick={() => { setCountry(item.code); setCountryOpen(false); setCountryQuery(''); setHomeCity(''); setSaveError(null) }}>
                              <CountryFlag code={item.code} name={item.name} /><span>{item.name}</span>{country === item.code && <Check size={15} />}
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
                  label="Home city"
                  required
                  hint="Your home city is your player’s permanent home base. It is used for travel origins and will also support future private-life features."
                  error={submitted && !homeCityValid ? (homeCityLoadError ?? 'Choose one of the 10 available home cities for your country.') : undefined}
                >
                  <div className="tlg-home-city-control">
                    <select
                      id="home-city"
                      value={homeCity}
                      onChange={(event) => { setHomeCity(event.target.value); setSaveError(null) }}
                      className={`tlg-input tlg-home-city-select ${submitted && !homeCityValid ? 'tlg-input-error' : ''}`}
                      disabled={!country || homeCitiesLoading || Boolean(homeCityLoadError)}
                    >
                      <option value="">
                        {!country
                          ? 'Choose a country first'
                          : homeCitiesLoading
                            ? 'Loading 10 home cities…'
                            : homeCityLoadError
                              ? 'Home cities unavailable'
                              : 'Choose your home city'}
                      </option>
                      {homeCities.map((item) => <option key={`${country}-${item.city}`} value={item.city}>{item.city}</option>)}
                    </select>
                    {selectedCountry && homeCity && (
                      <span className="tlg-home-city-selected" aria-label={`${homeCity}, ${selectedCountry.name}`}>
                        <span>{homeCity}</span>
                        <CountryFlag code={selectedCountry.code} name={selectedCountry.name} />
                      </span>
                    )}
                  </div>
                </FormField>

                <div className="tlg-real-name-policy" role="note">
                  <AlertTriangle size={22} aria-hidden="true" />
                  <div>
                    <strong>REAL FIRST AND LAST NAME REQUIRED</strong>
                    <p>Your player identity must use a normal real-person first name and last name. Numbers, gamer tags, nicknames instead of names, joke/fake identities, offensive names, and impersonating an existing professional tennis player are not allowed.</p>
                    <p>Accounts that deliberately ignore this rule may have the player removed or access suspended by game moderation.</p>
                  </div>
                </div>
              </div>
            </section>

            <section className="tlg-onboarding-section">
              <header className="tlg-onboarding-section-header">
                <div><span>02 · Competition</span><h2>Choose your professional world</h2></div>
                <Globe2 size={20} className="text-[color:var(--tlg-cyan)]" />
              </header>
              <div className="tlg-onboarding-section-body">
                <div className="tlg-world-grid">
                  {(['ATP', 'WTA'] as PlayerWorld[]).map((option) => (
                    <button key={option} type="button" className={`tlg-world-option ${world === option ? 'active' : ''}`} onClick={() => { setWorld(option); setSelectedAvatarPath(null); setSaveError(null) }} aria-pressed={world === option}>
                      <span className="tlg-world-option-badge">{world === option ? 'SELECTED' : 'WORLD'}</span>
                      <strong>{option}</strong>
                      <p>{option === 'ATP' ? 'Enter the men’s professional multiplayer ecosystem.' : 'Enter the women’s professional multiplayer ecosystem.'}</p>
                      {world === option && <Check size={17} className="absolute right-4 top-4 text-[color:var(--tlg-cyan)]" />}
                    </button>
                  ))}
                </div>
              </div>
            </section>

            <section className="tlg-onboarding-section">
              <header className="tlg-onboarding-section-header">
                <div><span>03 · Presentation</span><h2>Player portrait</h2></div>
                <ImagePlus size={20} className="text-[color:var(--tlg-cyan)]" />
              </header>
              <div className="tlg-onboarding-section-body">
                <div className="tlg-avatar-picker-header">
                  <div><strong>Choose a {world} portrait · optional</strong><p>Curated portraits are shared across the game world. A portrait already used by another active player cannot be selected.</p></div>
                  {!avatarsLoading && avatars.length > 0 && <span className="tlg-avatar-count">{availableAvatarCount} available</span>}
                </div>

                {avatarsLoading ? <div className="tlg-avatar-state">Loading {world} player portraits…</div> : avatarError ? <div className="tlg-avatar-state">{avatarError}</div> : avatars.length === 0 ? <div className="tlg-avatar-state">No {world} portraits are available in the avatar library yet.</div> : (
                  <div className="tlg-avatar-grid" aria-label={`${world} player portraits`}>
                    {avatars.map((avatar) => {
                      const selected = selectedAvatarPath === avatar.path
                      return (
                        <button key={avatar.path} type="button" className={`tlg-avatar-option ${selected ? 'selected' : ''} ${!avatar.available ? 'unavailable' : ''}`} disabled={!avatar.available} onClick={() => { setSelectedAvatarPath(avatar.path); setSaveError(null) }} aria-label={avatar.available ? `Select ${avatar.label}` : `${avatar.label} is already in use`} aria-pressed={selected}>
                          <img src={avatar.signedUrl} alt="" loading="lazy" />
                          {selected && <span className="tlg-avatar-selected-mark"><Check size={15} /></span>}
                          {!avatar.available && <span className="tlg-avatar-in-use">In use</span>}
                        </button>
                      )
                    })}
                  </div>
                )}
                <p className="tlg-avatar-note">Portrait upload is disabled during player creation. Custom image upload can be offered later from the in-game profile settings.</p>
              </div>
            </section>

            {saveError && <div className="tlg-auth-status tlg-auth-status-information" role="alert"><ShieldCheck size={18} /><span>{saveError}</span></div>}
            {submitted && !surfaceValid && <div className="tlg-auth-status tlg-auth-status-information" role="alert"><ShieldCheck size={18} /><span>Choose your preferred playing surface before entering Tennis Legacy.</span></div>}
            {submitted && !styleValid && <div className="tlg-auth-status tlg-auth-status-information" role="alert"><ShieldCheck size={18} /><span>Choose your player style before entering Tennis Legacy.</span></div>}

            <div className="tlg-onboarding-actions">
              <AppButton type="submit" variant="primary" size="large" loading={saving} disabled={!user || countriesLoading || homeCitiesLoading} rightIcon={<ArrowRight size={18} />}>
                {saving ? 'Creating player…' : 'Enter Tennis Legacy'}
              </AppButton>
            </div>
          </div>

          <div className="tlg-player-onboarding-side">
            <aside className="tlg-player-preview-card">
              <div className="tlg-player-preview-visual">
                {selectedAvatar ? <img src={selectedAvatar.signedUrl} alt="Selected player portrait" /> : <div className="tlg-player-preview-placeholder"><UserRound size={45} /></div>}
              </div>
              <div className="tlg-player-preview-copy">
                <p className="tlg-page-heading-eyebrow">Career identity</p>
                <h3>{`${firstName} ${lastName}`.trim() || 'Your Player'}</h3>
                <p className="tlg-player-preview-country">{selectedCountry && <CountryFlag code={selectedCountry.code} name={selectedCountry.name} />}<span>{selectedCountryName}</span></p>
                <div className="tlg-player-preview-tags">
                  <span className="tlg-player-preview-tag">{world} World</span>
                  <span className="tlg-player-preview-tag">New Professional</span>
                  {preferredSurface && <span className="tlg-player-preview-tag">{preferredSurface}</span>}
                  {playingStyle && <span className="tlg-player-preview-tag">{playingStyle}</span>}
                </div>
                <div className="tlg-player-preview-meta">
                  <div className="tlg-player-preview-meta-row"><span>Home base</span><strong>{homeCity || 'Choose a city'}</strong></div>
                  <div className="tlg-player-preview-meta-row"><span>Manager account</span><strong>{user?.email ?? 'Authenticated'}</strong></div>
                  <div className="tlg-player-preview-meta-row"><span>Moderation</span><strong>Review on creation</strong></div>
                  <div className="tlg-player-preview-meta-row"><span>Starting technical points</span><strong>440–455 · individually varied</strong></div>
                </div>
              </div>
            </aside>

            <section className={`tlg-surface-preference-card ${submitted && !surfaceValid ? 'tlg-surface-preference-error' : ''}`} aria-labelledby="preferred-surface-heading">
              <div className="tlg-surface-preference-head">
                <span>04 · SURFACE IDENTITY</span>
                <h2 id="preferred-surface-heading">Preferred surface</h2>
                <p>Choose the surface your player prefers. It redistributes starting tennis skills but never changes the total starting strength.</p>
              </div>
              <div className="tlg-surface-options">
                {SURFACES.map((surface) => (
                  <button key={surface.value} type="button" className={`tlg-surface-option ${preferredSurface === surface.value ? 'selected' : ''}`} onClick={() => { setPreferredSurface(surface.value); setSaveError(null) }} aria-pressed={preferredSurface === surface.value}>
                    <span className={`tlg-surface-dot tlg-surface-dot-${surface.value.toLowerCase()}`}><Circle size={13} /></span>
                    <span><strong>{surface.value}</strong><small>{surface.text}</small></span>
                    {preferredSurface === surface.value && <Check size={17} />}
                  </button>
                ))}
              </div>
              <p className="tlg-surface-future-note">New human players begin with a varied 440–455 technical-point profile. Preferred surface changes the distribution while individual variation prevents identical starting players.</p>
            </section>

            <section className={`tlg-style-preference-card ${submitted && !styleValid ? 'tlg-style-preference-error' : ''}`} aria-labelledby="playing-style-heading">
              <div className="tlg-style-preference-head">
                <span>05 · PLAYER STYLE</span>
                <h2 id="playing-style-heading">Choose your playing style</h2>
                <p>Playing style changes how your existing skills are used during matches. It is not a flat bonus: the style is strongest only when your skill profile supports it.</p>
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
              <p className="tlg-style-note">The choice is permanent for the initial career identity. Development later comes from training and gameplay, not from join date or starting rank.</p>
            </section>
          </div>
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
