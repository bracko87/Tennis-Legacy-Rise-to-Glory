/**
 * CreatePlayer.tsx
 *
 * Premium first-login onboarding. Player identity, country reference data and
 * optional avatar storage are connected directly to the Tennis Legacy
 * Supabase project.
 */

import type { FormEvent } from 'react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { ArrowRight, Check, Globe2, ImagePlus, ShieldCheck, UserRound } from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import AppButton from '../../components/common/AppButton'
import FormField from '../../components/common/FormField'
import { COUNTRIES } from '../../data/countries'
import { supabase } from '../../lib/supabase'

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp']
const MAX_FILE_BYTES = 2 * 1024 * 1024

type PlayerWorld = 'ATP' | 'WTA'

interface CountryOption {
  code: string
  name: string
}

export default function CreatePlayerPage(): JSX.Element {
  const { user, refreshPlayer } = useAuth()

  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [country, setCountry] = useState('')
  const [countries, setCountries] = useState<CountryOption[]>([])
  const [countriesLoading, setCountriesLoading] = useState(true)
  const [world, setWorld] = useState<PlayerWorld>('ATP')
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [fileError, setFileError] = useState<string | null>(null)
  const [submitted, setSubmitted] = useState(false)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)

  const objectUrlRef = useRef<string | null>(null)

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
        setCountries(COUNTRIES.map((item) => ({ code: item.code, name: item.name })))
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

  const previewSrc = useMemo(() => {
    if (!imageFile) return null
    if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current)
    const nextUrl = URL.createObjectURL(imageFile)
    objectUrlRef.current = nextUrl
    return nextUrl
  }, [imageFile])

  useEffect(() => {
    return () => {
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current)
    }
  }, [])

  const selectedCountryName =
    countries.find((item) => item.code === country)?.name ?? 'Country not selected'

  const firstNameValid = firstName.trim().length >= 2
  const lastNameValid = lastName.trim().length >= 2
  const countryValid = country.length === 2
  const formValid = firstNameValid && lastNameValid && countryValid && !fileError

  function handleFileChange(files?: FileList | null) {
    setFileError(null)
    setSaveError(null)
    setImageFile(null)

    if (!files?.length) return

    const file = files[0]
    if (!ALLOWED_TYPES.includes(file.type)) {
      setFileError('Use a JPG, PNG or WebP image.')
      return
    }
    if (file.size > MAX_FILE_BYTES) {
      setFileError('The image must be 2 MB or smaller.')
      return
    }

    setImageFile(file)
  }

  async function uploadAvatar(): Promise<string | null> {
    if (!imageFile || !user) return null

    const extension =
      imageFile.type === 'image/png'
        ? 'png'
        : imageFile.type === 'image/webp'
          ? 'webp'
          : 'jpg'
    const path = `${user.id}/avatar-${Date.now()}.${extension}`

    const { error } = await supabase.storage
      .from('player-avatars')
      .upload(path, imageFile, {
        cacheControl: '3600',
        contentType: imageFile.type,
        upsert: false,
      })

    if (error) throw error
    return path
  }

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitted(true)
    setSaveError(null)

    if (!formValid || !user || saving) return

    setSaving(true)
    let uploadedPath: string | null = null

    try {
      uploadedPath = await uploadAvatar()

      const { error } = await supabase.from('players').insert({
        owner_user_id: user.id,
        world,
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        country_code: country,
        image_path: uploadedPath,
      })

      if (error) {
        if (uploadedPath) {
          await supabase.storage.from('player-avatars').remove([uploadedPath])
        }

        if (error.code === '23505') {
          await refreshPlayer()
          window.location.replace('/game/overview')
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
        <div className="tlg-onboarding-brand">
          <span className="tlg-onboarding-brand-mark"><ShieldCheck size={18} /></span>
          <div>
            <strong>Tennis Legacy</strong>
            <span>Player onboarding</span>
          </div>
        </div>

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
                  <select
                    id="country"
                    value={country}
                    onChange={(event) => {
                      setCountry(event.target.value)
                      setSaveError(null)
                    }}
                    className={`tlg-input ${submitted && !countryValid ? 'tlg-input-error' : ''}`}
                    disabled={countriesLoading}
                  >
                    <option value="">{countriesLoading ? 'Loading countries…' : 'Choose a country'}</option>
                    {countries.map((item) => (
                      <option key={item.code} value={item.code}>{item.name}</option>
                    ))}
                  </select>
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
                <div className="tlg-upload-zone">
                  <FormField
                    id="player-avatar"
                    label="Upload portrait · optional"
                    hint="JPG, PNG or WebP · maximum 2 MB. The image is stored in Tennis Legacy Supabase Storage."
                    error={fileError ?? undefined}
                  >
                    <input
                      id="player-avatar"
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      onChange={(event) => handleFileChange(event.target.files)}
                      className="tlg-input"
                    />
                  </FormField>
                </div>
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
              {previewSrc ? (
                <img src={previewSrc} alt="Selected player portrait" />
              ) : (
                <div className="tlg-player-preview-placeholder">
                  <UserRound size={45} />
                </div>
              )}
            </div>

            <div className="tlg-player-preview-copy">
              <p className="tlg-page-heading-eyebrow">Career identity</p>
              <h3>{`${firstName} ${lastName}`.trim() || 'Your Player'}</h3>
              <p>{selectedCountryName}</p>

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
