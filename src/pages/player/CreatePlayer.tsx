/**
 * CreatePlayer.tsx
 *
 * First-login onboarding for an authenticated Tennis Legacy manager. Player
 * identity is stored in Supabase. Image files remain preview-only until the
 * dedicated Supabase Storage bucket is introduced in the next backend phase.
 */

import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import AppButton from '../../components/common/AppButton'
import AppCard from '../../components/common/AppCard'
import FormField from '../../components/common/FormField'
import MarketingHeader from '../../components/layout/MarketingHeader'
import type { Country } from '../../data/countries'
import { COUNTRIES } from '../../data/countries'
import { supabase } from '../../lib/supabase'

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp']
const MAX_FILE_BYTES = 2 * 1024 * 1024

type PlayerWorld = 'ATP' | 'WTA' | null

export default function CreatePlayerPage(): JSX.Element {
  const navigate = useNavigate()
  const { user, refreshPlayer } = useAuth()

  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [country, setCountry] = useState<string>('US')
  const [world, setWorld] = useState<PlayerWorld>('ATP')
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imageUrl, setImageUrl] = useState('')
  const [fileError, setFileError] = useState<string | null>(null)
  const [submitted, setSubmitted] = useState(false)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)

  const objectUrlRef = useRef<string | null>(null)

  const previewSrc = useMemo(() => {
    if (imageFile) {
      if (objectUrlRef.current) {
        URL.revokeObjectURL(objectUrlRef.current)
        objectUrlRef.current = null
      }
      const objectUrl = URL.createObjectURL(imageFile)
      objectUrlRef.current = objectUrl
      return objectUrl
    }

    try {
      if (imageUrl && new URL(imageUrl)) return imageUrl
    } catch {
      // Invalid URL simply falls back to the placeholder preview.
    }

    return null
  }, [imageFile, imageUrl])

  useEffect(() => {
    return () => {
      if (objectUrlRef.current) {
        URL.revokeObjectURL(objectUrlRef.current)
        objectUrlRef.current = null
      }
    }
  }, [])

  function handleFileChange(files?: FileList | null) {
    setFileError(null)
    setImageFile(null)

    if (!files || files.length === 0) return

    const file = files[0]
    if (!ALLOWED_TYPES.includes(file.type)) {
      setFileError('Invalid file type. Use JPG, PNG or WebP.')
      return
    }
    if (file.size > MAX_FILE_BYTES) {
      setFileError('File too large. Maximum size is 2 MB.')
      return
    }

    setImageFile(file)
  }

  function isFormValid() {
    const firstNameValid = firstName.trim().length >= 2
    const lastNameValid = lastName.trim().length >= 2
    const countryValid = Boolean(country && country.length === 2)
    const worldValid = world === 'ATP' || world === 'WTA'
    return firstNameValid && lastNameValid && countryValid && worldValid && !fileError
  }

  async function handleCreate(event?: React.FormEvent) {
    event?.preventDefault()
    setSubmitted(true)
    setSaveError(null)

    if (!isFormValid() || !user || !world || saving) return

    setSaving(true)

    const { error } = await supabase.from('players').insert({
      owner_user_id: user.id,
      world,
      first_name: firstName.trim(),
      last_name: lastName.trim(),
      country_code: country,
      image_path: null,
    })

    if (error) {
      setSaving(false)

      if (error.code === '23505') {
        await refreshPlayer()
        navigate('/game/overview', { replace: true })
        return
      }

      setSaveError(
        'Your player could not be created. Please review the details and try again.',
      )
      return
    }

    await refreshPlayer()
    setSaving(false)
    navigate('/game/overview', { replace: true })
  }

  return (
    <div>
      <MarketingHeader />

      <main className="min-h-screen bg-transparent pb-12">
        <section className="max-w-6xl mx-auto px-6 pt-8">
          <div className="mb-6 flex items-center justify-between gap-4">
            <div>
              <p className="tlg-page-heading-eyebrow">Manager onboarding</p>
              <h1 className="text-2xl font-semibold text-[color:var(--tlg-white)]">
                Create Player
              </h1>
            </div>
            <Link to="/" className="text-sm text-[var(--tlg-text-muted)] underline">
              Home
            </Link>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="md:col-span-2 space-y-6">
              <AppCard title="Player details">
                <form onSubmit={handleCreate} className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <FormField
                      id="first"
                      label="Player First Name"
                      required
                      error={submitted && firstName.trim().length < 2 ? 'Enter at least 2 characters.' : undefined}
                    >
                      <input
                        id="first"
                        value={firstName}
                        onChange={(event) => {
                          setFirstName(event.target.value)
                          setSaveError(null)
                        }}
                        className={`tlg-input ${submitted && firstName.trim().length < 2 ? 'tlg-input-error' : ''}`}
                        placeholder="First name"
                        aria-invalid={submitted && firstName.trim().length < 2}
                      />
                    </FormField>

                    <FormField
                      id="last"
                      label="Player Last Name"
                      required
                      error={submitted && lastName.trim().length < 2 ? 'Enter at least 2 characters.' : undefined}
                    >
                      <input
                        id="last"
                        value={lastName}
                        onChange={(event) => {
                          setLastName(event.target.value)
                          setSaveError(null)
                        }}
                        className={`tlg-input ${submitted && lastName.trim().length < 2 ? 'tlg-input-error' : ''}`}
                        placeholder="Last name"
                        aria-invalid={submitted && lastName.trim().length < 2}
                      />
                    </FormField>
                  </div>

                  <FormField id="country" label="Player Country" required>
                    <select
                      id="country"
                      value={country}
                      onChange={(event) => {
                        setCountry(event.target.value)
                        setSaveError(null)
                      }}
                      className="tlg-input"
                    >
                      {COUNTRIES.map((countryOption: Country) => (
                        <option key={countryOption.code} value={countryOption.code}>
                          {countryOption.name}
                        </option>
                      ))}
                    </select>
                  </FormField>

                  <AppCard eyebrow="World selection" title="Choose a world" className="mt-2">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <button
                        type="button"
                        onClick={() => {
                          setWorld('ATP')
                          setSaveError(null)
                        }}
                        className={`w-full text-left p-4 border rounded-md transition-colors ${
                          world === 'ATP'
                            ? 'bg-[linear-gradient(135deg,#054E98,#001D3F)] text-white border-transparent'
                            : 'bg-[rgba(0,7,19,0.6)] border-[rgba(148,163,184,0.06)] text-[var(--tlg-text-muted)]'
                        }`}
                        aria-pressed={world === 'ATP'}
                      >
                        <div className="flex items-center justify-between">
                          <div>
                            <div className="text-sm font-semibold">ATP World</div>
                            <div className="text-xs mt-1">Male professional tennis world</div>
                          </div>
                          <div className="text-xs font-mono text-[rgba(226,232,240,0.6)]">Select</div>
                        </div>
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setWorld('WTA')
                          setSaveError(null)
                        }}
                        className={`w-full text-left p-4 border rounded-md transition-colors ${
                          world === 'WTA'
                            ? 'bg-[linear-gradient(135deg,#054E98,#001D3F)] text-white border-transparent'
                            : 'bg-[rgba(0,7,19,0.6)] border-[rgba(148,163,184,0.06)] text-[var(--tlg-text-muted)]'
                        }`}
                        aria-pressed={world === 'WTA'}
                      >
                        <div className="flex items-center justify-between">
                          <div>
                            <div className="text-sm font-semibold">WTA World</div>
                            <div className="text-xs mt-1">Female professional tennis world</div>
                          </div>
                          <div className="text-xs font-mono text-[rgba(226,232,240,0.6)]">Select</div>
                        </div>
                      </button>
                    </div>
                  </AppCard>

                  <AppCard eyebrow="Player image" title="Image options" className="mt-2">
                    <div className="space-y-3">
                      <FormField id="upload" label="Upload image (JPG, PNG, WEBP) - max 2 MB">
                        <input
                          id="upload"
                          type="file"
                          accept="image/jpeg,image/png,image/webp"
                          onChange={(event) => handleFileChange(event.target.files)}
                          className="tlg-input"
                        />
                        {fileError && <p className="tlg-field-error">{fileError}</p>}
                        <p className="tlg-field-hint">
                          The selected image is a temporary preview only. Supabase Storage will be connected in the image-storage phase.
                        </p>
                      </FormField>

                      <FormField id="imageUrl" label="Image URL (preview only, optional)">
                        <input
                          id="imageUrl"
                          value={imageUrl}
                          onChange={(event) => setImageUrl(event.target.value)}
                          className="tlg-input"
                          placeholder="https://example.com/player.jpg"
                        />
                      </FormField>
                    </div>
                  </AppCard>

                  <div className="mt-2 text-sm text-[var(--tlg-text-muted)]">
                    <strong>Player name notice</strong>
                    <p className="mt-1">
                      To protect the authenticity of the game world, player names should resemble realistic first and last names. Clearly fictional, offensive or deliberately misleading names may be reviewed and removed by the moderation team.
                    </p>
                  </div>

                  {saveError && (
                    <div className="tlg-auth-status tlg-auth-status-information" role="alert">
                      {saveError}
                    </div>
                  )}

                  <div className="flex items-center gap-3 mt-4">
                    <Link to="/" className="inline-block">
                      <AppButton variant="secondary">Back Home</AppButton>
                    </Link>
                    <AppButton
                      type="submit"
                      variant="primary"
                      loading={saving}
                      disabled={!user}
                    >
                      {saving ? 'Creating Player…' : 'Create Player'}
                    </AppButton>
                  </div>
                </form>
              </AppCard>
            </div>

            <aside className="md:col-span-1">
              <div className="sticky top-24">
                <AppCard title="Live preview">
                  <div className="flex flex-col items-center text-center gap-3">
                    <div className="w-44 h-44 rounded-md overflow-hidden border border-[rgba(148,163,184,0.08)] bg-[rgba(0,7,19,0.6)] flex items-center justify-center">
                      {previewSrc ? (
                        <img src={previewSrc} alt="Player preview" className="w-full h-full object-cover" />
                      ) : (
                        <svg viewBox="0 0 120 120" className="w-full h-full">
                          <rect width="120" height="120" fill="#001D3F" />
                          <g fill="#FFFFFF" fillOpacity="0.06"><rect x="8" y="8" width="104" height="104" rx="6" /></g>
                          <text x="50%" y="54%" dominantBaseline="middle" textAnchor="middle" fontSize="10" fill="#ffffff" fillOpacity="0.18">No image</text>
                        </svg>
                      )}
                    </div>

                    <div className="w-full">
                      <h3 className="text-lg font-semibold text-[color:var(--tlg-white)]">
                        {firstName || lastName ? `${firstName} ${lastName}`.trim() : 'Unnamed Player'}
                      </h3>
                      <p className="text-sm text-[var(--tlg-text-muted)] mt-1">
                        {COUNTRIES.find((countryOption) => countryOption.code === country)?.name || 'Unknown country'}
                      </p>

                      <div className="mt-3 inline-flex items-center gap-3">
                        <span className="px-3 py-1 rounded-md bg-[rgba(5,78,152,0.12)] text-sm font-medium border border-[rgba(5,78,152,0.14)]">
                          {world === 'ATP' ? 'ATP' : world === 'WTA' ? 'WTA' : 'World'}
                        </span>
                        <span className="px-3 py-1 rounded-md bg-[rgba(0,7,19,0.6)] border border-[rgba(148,163,184,0.06)] text-sm">
                          Future Professional
                        </span>
                      </div>

                      <div className="mt-4 flex items-center justify-between text-xs text-[var(--tlg-text-muted)]">
                        <div>Manager account</div>
                        <div className="font-mono">{user?.email ?? '—'}</div>
                      </div>
                    </div>
                  </div>
                </AppCard>

                <div className="mt-4 text-sm text-[var(--tlg-text-muted)]">
                  <p><strong>Game-time example</strong></p>
                  <p className="mt-1">Season 1 · March 14 · 18:00</p>
                  <p className="mt-1 text-xs">1 real-life hour equals 2 in-game hours. The game uses seasons instead of real-world years.</p>
                </div>
              </div>
            </aside>
          </div>
        </section>
      </main>
    </div>
  )
}
