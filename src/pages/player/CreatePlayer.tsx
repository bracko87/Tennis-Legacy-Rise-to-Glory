/**
 * CreatePlayer.tsx
 *
 * First-login player onboarding connected to the Tennis Legacy Supabase
 * project. Countries come from the canonical database reference table and
 * profile portraits come from the curated ATP/WTA avatar catalog.
 */

import type { FormEvent } from 'react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { Link } from 'react-router'
import {
  ArrowRight,
  Check,
  ChevronDown,
  Globe2,
  ImagePlus,
  Search,
  ShieldCheck,
  UserRound,
} from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import AppButton from '../../components/common/AppButton'
import FormField from '../../components/common/FormField'
import { COUNTRIES } from '../../data/countries'
import { supabase } from '../../lib/supabase'

type PlayerWorld = 'ATP' | 'WTA'

interface CountryOption {
  code: string
  name: string
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

export default function CreatePlayerPage(): JSX.Element {
  const { user, refreshPlayer } = useAuth()

  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [country, setCountry] = useState('')
  const [countries, setCountries] = useState<CountryOption[]>([])
  const [countriesLoading, setCountriesLoading] = useState(true)
  const [countryOpen, setCountryOpen] = useState(false)
  const [countryQuery, setCountryQuery] = useState('')
  const [world, setWorld] = useState<PlayerWorld>('ATP')
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
      const { data, error } = await supabase
        .from('countries')
        .select('code, name')
        .eq('is_active', true)
        .order('name')

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
    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    function handleDocumentPointerDown(event: MouseEvent) {
      const target = event.target as Node
      if (!countryPickerRef.current?.contains(target)) {
        setCountryOpen(false)
      }
    }

    document.addEventListener('mousedown', handleDocumentPointerDown)
    return () => document.removeEventListener('mousedown', handleDocumentPointerDown)
  }, [])

  useEffect(() => {
    let active = true

    async function loadAvatars() {
      setAvatarsLoading(true)
      setAvatarError(null)

      const { data, error } = await supabase.rpc('get_player_avatar_catalog', {
        p_world: world,
      })

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
        current && nextAvatars.some((item) => item.path === current && item.available)
          ? current
          : null,
      )
      setAvatarsLoading(false)
    }

    void loadAvatars()
    return () => {
      active = false
    }
  }, [world, avatarRefreshKey])

  const selectedCountry = useMemo(
    () => countries.find((item) => item.code === country) ?? null,
    [countries, country],
  )

  const filteredCountries = useMemo(() => {
    const query = countryQuery.trim().toLocaleLowerCase()
    if (!query) return countries

    return countries.filter((item) =>
      `${item.name} ${item.code}`.toLocaleLowerCase().includes(query),
    )
  }, [countries, countryQuery])

  const selectedAvatar = useMemo(
    () => avatars.find((item) => item.path === selectedAvatarPath) ?? null,
    [avatars, selectedAvatarPath],
  )

  const selectedCountryName = selectedCountry?.name ?? 'Country not selected'
  const availableAvatarCount = avatars.filter((item) => item.available).length

  const firstNameValid = firstName.trim().length >= 2
  const lastNameValid = lastName.trim().length >= 2
  const countryValid = country.length === 2
  const formValid = firstNameValid && lastNameValid && countryValid

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setSaveError(null)

    if (!formValid || !user || saving) return

    setSaving(true)

    try {
      const { error } = await supabase.from('players').insert({
        owner_user_id: user.id,
        world,
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        country_code: country,
        image_path: selectedAvatarPath,
      })

      if (error) {
        if (error.code === '23505') {
          const existingPlayer = await refreshPlayer()
          if (existingPlayer) {
            window.location.replace('/game/overview')
            return
          }

          setSelectedAvatarPath(null)
          setAvatarRefreshKey((value) => value + 1)
          setSaving(false)
          setSaveError(
            'That player portrait was just selected by another manager. Choose another available portrait and try again.',
          )
          return
        }

        throw error
      }

      await refreshPlayer()
      window.location.replace('/game/overview')
    } catch (error) {
      console.error('Unable to create Tennis Legacy player:', error)
      setSaving(false)
      setSaveError(
        'Your player could not be created. Check the selected details and try again.',
      )
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
            <p>
              Choose the identity that will represent your entire Tennis Legacy career.
              Your world and core player identity become part of the shared multiplayer universe.
            </p>
          </div>
        </div>

        <form className="tlg-onboarding-grid" onSubmit={handleCreate} noValidate>
          <div className="space-y-4">
            <section className="tlg-onboarding-section">
              <header className="tlg-onboarding-section-header">
                <div>
                  <span>01 · Identity</span>
                  <h2>Professional profile</h2>
                </div>
                <UserRound size={20} className="text-[color:var(--tlg-cyan)]" />
              </header>
              <div className="tlg-onboarding-section-body space-y-4">
                <div className="tlg-onboarding-form-grid">
                  <FormField
                    id="first-name"
                    label="First name"
                    required
                    error={submitted && !firstNameValid ? 'Enter at least 2 characters.' : undefined}
                  >
                    <input
                      id="first-name"
                      value={firstName}
                      onChange={(event) => {
                        setFirstName(event.target.value)
                        setSaveError(null)
                      }}
                      className={`tlg-input ${submitted && !firstNameValid ? 'tlg-input-error' : ''}`}
                      placeholder="First name"
                      maxLength={40}
                      autoComplete="off"
                    />
                  </FormField>

                  <FormField
                    id="last-name"
                    label="Last name"
                    required
                    error={submitted && !lastNameValid ? 'Enter at least 2 characters.' : undefined}
                  >
                    <input
                      id="last-name"
                      value={lastName}
                      onChange={(event) => {
                        setLastName(event.target.value)
                        setSaveError(null)
                      }}
                      className={`tlg-input ${submitted && !lastNameValid ? 'tlg-input-error' : ''}`}
                      placeholder="Last name"
                      maxLength={40}
                      autoComplete="off"
                    />
                  </FormField>
                </div>

                <FormField
                  id="country"
                  label="Representing country"
                  required
                  error={submitted && !countryValid ? 'Choose the country your player represents.' : undefined}
                >
                  <div className="tlg-country-picker" ref={countryPickerRef}>
                    <button
                      id="country"
                      type="button"
                      className={`tlg-country-trigger ${countryOpen ? 'open' : ''} ${submitted && !countryValid ? 'tlg-input-error' : ''}`}
                      onClick={() => {
                        if (countriesLoading) return
                        setCountryOpen((value) => !value)
                        setCountryQuery('')
                      }}
                      aria-haspopup="listbox"
                      aria-expanded={countryOpen}
                      disabled={countriesLoading}
                    >
                      <span className="tlg-country-trigger-main">
                        {selectedCountry ? (
                          <>
                            <CountryFlag code={selectedCountry.code} name={selectedCountry.name} />
                            <span>{selectedCountry.name}</span>
                          </>
                        ) : (
                          <span className="tlg-country-trigger-placeholder">
                            {countriesLoading ? 'Loading countries…' : 'Choose a country'}
                          </span>
                        )}
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
                            onKeyDown={(event) => {
                              if (event.key === 'Escape') setCountryOpen(false)
                            }}
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
                                setSaveError(null)
                              }}
                            >
                              <CountryFlag code={item.code} name={item.name} />
                              <span>{item.name}</span>
                              {country === item.code && <Check size={15} />}
                            </button>
                          ))}
                          {!filteredCountries.length && (
                            <div className="tlg-country-empty">No country matches your search.</div>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                </FormField>

                <div className="tlg-onboarding-notice">
                  Use a realistic first and last name. Clearly offensive, misleading or deliberately fictional identities can be reviewed by game moderation.
                </div>
              </div>
            </section>

            <section className="tlg-onboarding-section">
              <header className="tlg-onboarding-section-header">
                <div>
                  <span>02 · Competition</span>
                  <h2>Choose your professional world</h2>
                </div>
                <Globe2 size={20} className="text-[color:var(--tlg-cyan)]" />
              </header>
              <div className="tlg-onboarding-section-body">
                <div className="tlg-world-grid">
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
                      <span className="tlg-world-option-badge">{world === option ? 'SELECTED' : 'WORLD'}</span>
                      <strong>{option}</strong>
                      <p>
                        {option === 'ATP'
                          ? 'Enter the men’s professional multiplayer ecosystem.'
                          : 'Enter the women’s professional multiplayer ecosystem.'}
                      </p>
                      {world === option && <Check size={17} className="absolute right-4 top-4 text-[color:var(--tlg-cyan)]" />}
                    </button>
                  ))}
                </div>
              </div>
            </section>

            <section className="tlg-onboarding-section">
              <header className="tlg-onboarding-section-header">
                <div>
                  <span>03 · Presentation</span>
                  <h2>Player portrait</h2>
                </div>
                <ImagePlus size={20} className="text-[color:var(--tlg-cyan)]" />
              </header>
              <div className="tlg-onboarding-section-body">
                <div className="tlg-avatar-picker-header">
                  <div>
                    <strong>Choose a {world} portrait · optional</strong>
                    <p>Curated portraits are shared across the game world. A portrait already used by another active player cannot be selected.</p>
                  </div>
                  {!avatarsLoading && avatars.length > 0 && (
                    <span className="tlg-avatar-count">{availableAvatarCount} available</span>
                  )}
                </div>

                {avatarsLoading ? (
                  <div className="tlg-avatar-state">Loading {world} player portraits…</div>
                ) : avatarError ? (
                  <div className="tlg-avatar-state">{avatarError}</div>
                ) : avatars.length === 0 ? (
                  <div className="tlg-avatar-state">
                    No {world} portraits are available in the avatar library yet.
                  </div>
                ) : (
                  <div className="tlg-avatar-grid" aria-label={`${world} player portraits`}>
                    {avatars.map((avatar) => {
                      const selected = selectedAvatarPath === avatar.path
                      return (
                        <button
                          key={avatar.path}
                          type="button"
                          className={`tlg-avatar-option ${selected ? 'selected' : ''} ${!avatar.available ? 'unavailable' : ''}`}
                          disabled={!avatar.available}
                          onClick={() => {
                            setSelectedAvatarPath(avatar.path)
                            setSaveError(null)
                          }}
                          aria-label={
                            avatar.available
                              ? `Select ${avatar.label}`
                              : `${avatar.label} is already in use`
                          }
                          aria-pressed={selected}
                        >
                          <img src={avatar.signedUrl} alt="" loading="lazy" />
                          {selected && (
                            <span className="tlg-avatar-selected-mark"><Check size={15} /></span>
                          )}
                          {!avatar.available && <span className="tlg-avatar-in-use">In use</span>}
                        </button>
                      )
                    })}
                  </div>
                )}

                <p className="tlg-avatar-note">
                  Portrait upload is disabled during player creation. Custom image upload can be offered later from the in-game profile settings.
                </p>
              </div>
            </section>

            {saveError && (
              <div className="tlg-auth-status tlg-auth-status-information" role="alert">
                <ShieldCheck size={18} />
                <span>{saveError}</span>
              </div>
            )}

            <div className="tlg-onboarding-actions">
              <AppButton
                type="submit"
                variant="primary"
                size="large"
                loading={saving}
                disabled={!user || countriesLoading}
                rightIcon={<ArrowRight size={18} />}
              >
                {saving ? 'Creating player…' : 'Enter Tennis Legacy'}
              </AppButton>
            </div>
          </div>

          <aside className="tlg-player-preview-card">
            <div className="tlg-player-preview-visual">
              {selectedAvatar ? (
                <img src={selectedAvatar.signedUrl} alt="Selected player portrait" />
              ) : (
                <div className="tlg-player-preview-placeholder">
                  <UserRound size={45} />
                </div>
              )}
            </div>

            <div className="tlg-player-preview-copy">
              <p className="tlg-page-heading-eyebrow">Career identity</p>
              <h3>{`${firstName} ${lastName}`.trim() || 'Your Player'}</h3>
              <p className="tlg-player-preview-country">
                {selectedCountry && <CountryFlag code={selectedCountry.code} name={selectedCountry.name} />}
                <span>{selectedCountryName}</span>
              </p>

              <div className="tlg-player-preview-tags">
                <span className="tlg-player-preview-tag">{world} World</span>
                <span className="tlg-player-preview-tag">New Professional</span>
              </div>

              <div className="tlg-player-preview-meta">
                <div className="tlg-player-preview-meta-row">
                  <span>Manager account</span>
                  <strong>{user?.email ?? 'Authenticated'}</strong>
                </div>
                <div className="tlg-player-preview-meta-row">
                  <span>Moderation</span>
                  <strong>Review on creation</strong>
                </div>
                <div className="tlg-player-preview-meta-row">
                  <span>Career status</span>
                  <strong>Ready to initialize</strong>
                </div>
              </div>
            </div>
          </aside>
        </form>
      </main>
    </div>
  )
}

function CountryFlag({ code, name }: { code: string; name: string }) {
  return (
    <img
      className="tlg-country-flag"
      src={`https://flagcdn.com/24x18/${code.toLowerCase()}.png`}
      srcSet={`https://flagcdn.com/48x36/${code.toLowerCase()}.png 2x`}
      alt={`${name} flag`}
      loading="lazy"
      onError={(event) => {
        event.currentTarget.style.visibility = 'hidden'
      }}
    />
  )
}

function avatarLabel(path: string) {
  const fileName = path.split('/').pop() ?? path
  return fileName.replace(/\.[^.]+$/, '')
}
