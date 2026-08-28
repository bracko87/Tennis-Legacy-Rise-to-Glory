/**
 * CreatePlayer.tsx
 *
 * Player creation UI for Tennis Legacy: Rise to Glory.
 * Desktop: two-column layout with the form on the left and a sticky live preview on the right.
 * Mobile: stacked single-column layout.
 *
 * This page is UI-only: no persistence, no uploads to storage, no localStorage usage.
 */

import { useEffect, useMemo, useRef, useState } from 'react'
import { Link } from 'react-router'
import MarketingHeader from '../../components/layout/MarketingHeader'
import AppButton from '../../components/common/AppButton'
import AppCard from '../../components/common/AppCard'
import FormField from '../../components/common/FormField'
import type { Country } from '../../data/countries'
import { COUNTRIES } from '../../data/countries'

/**
 * Allowed image mime types for the upload control.
 */
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp']

/**
 * Maximum file size in bytes (2 MB).
 */
const MAX_FILE_BYTES = 2 * 1024 * 1024

/**
 * PlayerWorld - permitted worlds for selection.
 */
type PlayerWorld = 'ATP' | 'WTA' | null

/**
 * CreatePlayerPage
 *
 * Renders the player creation form and live preview. The upload control
 * validates size and file type but does not persist the file.
 */
export default function CreatePlayerPage(): JSX.Element {
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [country, setCountry] = useState<string>('US')
  const [world, setWorld] = useState<PlayerWorld>('ATP')
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imageUrl, setImageUrl] = useState('')
  const [fileError, setFileError] = useState<string | null>(null)
  const [submitted, setSubmitted] = useState(false)

  const objectUrlRef = useRef<string | null>(null)

  /**
   * Create a preview URL from the selected file or use the provided image URL.
   * URL created from local file is revoked on change/unmount.
   */
  const previewSrc = useMemo(() => {
    if (imageFile) {
      // Create a temporary object URL for preview
      if (objectUrlRef.current) {
        URL.revokeObjectURL(objectUrlRef.current)
        objectUrlRef.current = null
      }
      const u = URL.createObjectURL(imageFile)
      objectUrlRef.current = u
      return u
    }
    // if valid URL string, display it; otherwise null to show placeholder
    try {
      if (imageUrl && new URL(imageUrl)) return imageUrl
    } catch {
      // invalid URL - ignore
    }
    return null
  }, [imageFile, imageUrl])

  useEffect(() => {
    return () => {
      // cleanup created object URL on unmount
      if (objectUrlRef.current) {
        URL.revokeObjectURL(objectUrlRef.current)
        objectUrlRef.current = null
      }
    }
  }, [])

  /**
   * Handle native file input changes; validate type and size.
   * @param f - optional File list from input
   */
  function handleFileChange(f?: FileList | null) {
    setFileError(null)
    setImageFile(null)
    if (!f || f.length === 0) return
    const file = f[0]
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

  /**
   * Simple form validation rules.
   * @returns boolean whether the form is currently valid
   */
  function isFormValid() {
    const fn = firstName.trim().length >= 2
    const ln = lastName.trim().length >= 2
    const cc = Boolean(country && country.length === 2)
    const w = world === 'ATP' || world === 'WTA'
    return fn && ln && cc && w && !fileError
  }

  /**
   * Handle the create player action.
   * This is UI-only: it validates and informs the user that backend
   * integration will be added later (Supabase storage/DB).
   * No data is persisted.
   * @param e - form event
   */
  function handleCreate(e?: React.FormEvent) {
    e?.preventDefault()
    setSubmitted(true)
    if (!isFormValid()) return
    // eslint-disable-next-line no-alert
    alert('Supabase player creation will be connected in a later phase.')
  }

  /**
   * Handle world card selection.
   * @param w - 'ATP' or 'WTA'
   */
  function selectWorld(w: PlayerWorld) {
    setWorld(w)
  }

  return (
    <div>
      <MarketingHeader />

      <main className="min-h-screen bg-transparent pb-12">
        <section className="max-w-6xl mx-auto px-6 pt-8">
          <div className="mb-6 flex items-center justify-between gap-4">
            <h1 className="text-2xl font-semibold text-[color:var(--tlg-white)]">Create Player</h1>
            <div className="flex items-center gap-3">
              <Link to="/" className="text-sm text-[var(--tlg-text-muted)] underline">Home</Link>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Left: Form (span 2 on desktop) */}
            <div className="md:col-span-2 space-y-6">
              <AppCard title="Player details">
                <form onSubmit={handleCreate} className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <FormField id="first" label="Player First Name" required>
                      <input
                        id="first"
                        value={firstName}
                        onChange={(e) => setFirstName(e.target.value)}
                        className={`tlg-input ${submitted && firstName.trim().length < 2 ? 'tlg-input-error' : ''}`}
                        placeholder="First name"
                        aria-invalid={submitted && firstName.trim().length < 2}
                      />
                    </FormField>

                    <FormField id="last" label="Player Last Name" required>
                      <input
                        id="last"
                        value={lastName}
                        onChange={(e) => setLastName(e.target.value)}
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
                      onChange={(e) => setCountry(e.target.value)}
                      className="tlg-input"
                    >
                      {COUNTRIES.map((c: Country) => (
                        <option key={c.code} value={c.code}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </FormField>

                  <AppCard eyebrow="World selection" title="Choose a world" className="mt-2">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <button
                        type="button"
                        onClick={() => selectWorld('ATP')}
                        className={`w-full text-left p-4 border rounded-md transition-colors ${
                          world === 'ATP'
                            ? 'bg-[linear-gradient(135deg,#054E98, #001D3F)] text-white border-transparent'
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
                        onClick={() => selectWorld('WTA')}
                        className={`w-full text-left p-4 border rounded-md transition-colors ${
                          world === 'WTA'
                            ? 'bg-[linear-gradient(135deg,#054E98, #001D3F)] text-white border-transparent'
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
                          onChange={(e) => handleFileChange(e.target.files)}
                          className="tlg-input"
                        />
                        {fileError && <p className="tlg-field-error">{fileError}</p>}
                        <p className="tlg-field-hint">Upload preview is temporary. Upload integration is TODO.</p>
                        {/* TODO: Integrate Supabase Storage for image uploads in a future phase. */}
                      </FormField>

                      <FormField id="imageUrl" label="Image URL (optional)">
                        <input
                          id="imageUrl"
                          value={imageUrl}
                          onChange={(e) => setImageUrl(e.target.value)}
                          className="tlg-input"
                          placeholder="https://example.com/player.jpg"
                        />
                      </FormField>
                    </div>
                  </AppCard>

                  <div className="mt-2 text-sm text-[var(--tlg-text-muted)]">
                    <strong>Player name notice</strong>
                    <p className="mt-1">
                      To protect the authenticity of the game world, player names should resemble
                      realistic first and last names. Clearly fictional, offensive or deliberately
                      misleading names may be reviewed and removed by the moderation team.
                    </p>
                  </div>

                  <div className="flex items-center gap-3 mt-4">
                    <Link to="/" className="inline-block">
                      <AppButton variant="secondary">Back Home</AppButton>
                    </Link>
                    <AppButton type="button" variant="primary" onClick={handleCreate}>
                      Create Player
                    </AppButton>
                  </div>
                </form>
              </AppCard>
            </div>

            {/* Right: Live preview (sticky on desktop) */}
            <aside className="md:col-span-1">
              <div className="sticky top-24">
                <AppCard title="Live preview">
                  <div className="flex flex-col items-center text-center gap-3">
                    <div className="w-44 h-44 rounded-md overflow-hidden border border-[rgba(148,163,184,0.08)] bg-[rgba(0,7,19,0.6)] flex items-center justify-center">
                      {previewSrc ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={previewSrc} alt="Player preview" className="w-full h-full object-cover" />
                      ) : (
                        <svg viewBox="0 0 120 120" className="w-full h-full">
                          <rect width="120" height="120" fill="#001D3F" />
                          <g fill="#FFFFFF" fillOpacity="0.06">
                            <rect x="8" y="8" width="104" height="104" rx="6" />
                          </g>
                          <text x="50%" y="54%" dominantBaseline="middle" textAnchor="middle" fontSize="10" fill="#ffffff" fillOpacity="0.18">
                            No image
                          </text>
                        </svg>
                      )}
                    </div>

                    <div className="w-full">
                      <h3 className="text-lg font-semibold text-[color:var(--tlg-white)]">
                        {firstName || lastName ? `${firstName} ${lastName}`.trim() : 'Unnamed Player'}
                      </h3>

                      <p className="text-sm text-[var(--tlg-text-muted)] mt-1">
                        {COUNTRIES.find((c) => c.code === country)?.name || 'Unknown country'}
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
                        <div>Player ID</div>
                        <div className="font-mono">#{'—'}</div>
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