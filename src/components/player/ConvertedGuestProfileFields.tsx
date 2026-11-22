import { useCallback, useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { useAuth } from '../../auth/AuthContext'
import GameConfirmDialog from '../common/GameConfirmDialog'
import { supabase } from '../../lib/supabase'
import '../../styles/converted-guest-profile.css'

type CompletionStatus = {
  eligible: boolean
  username?: string | null
  username_confirmed?: boolean
  birthday_set?: boolean
  home_city?: string | null
  country_code?: string | null
}
type CityOption = { city: string }

export default function ConvertedGuestProfileFields() {
  const { user, player, refreshPlayer } = useAuth()
  const [status, setStatus] = useState<CompletionStatus | null>(null)
  const [username, setUsername] = useState('')
  const [month, setMonth] = useState('')
  const [day, setDay] = useState('')
  const [year, setYear] = useState('')
  const [city, setCity] = useState('')
  const [cities, setCities] = useState<CityOption[]>([])
  const [busy, setBusy] = useState(false)
  const [birthdayConfirmOpen, setBirthdayConfirmOpen] = useState(false)
  const [editSavedCity, setEditSavedCity] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const reload = useCallback(async () => {
    if (!user || user.is_anonymous) { setStatus(null); return }
    const { data, error: rpcError } = await supabase.rpc('get_my_tennis_converted_profile_completion_v1')
    if (rpcError) { setError(rpcError.message); return }
    const result = data as CompletionStatus | null
    setStatus(result)
    if (result?.eligible) {
      setUsername(result.username ?? '')
      setCity(result.home_city ?? '')
    }
  }, [user?.id, user?.is_anonymous])

  useEffect(() => { void reload() }, [reload])

  useEffect(() => {
    if (status?.eligible && window.location.hash === '#profile-completion') {
      document.getElementById('profile-completion')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }, [status?.eligible])


  useEffect(() => {
    if (!status?.eligible || !player?.country_code) { setCities([]); return }
    let active = true
    void supabase.rpc('get_player_home_city_options_v1', { p_country_code: player.country_code })
      .then(({ data, error: rpcError }) => {
        if (active && !rpcError) setCities((data ?? []) as CityOption[])
      }).catch(() => {
        if (active) setCities([])
      })
    return () => { active = false }
  }, [status?.eligible, player?.country_code])

  const start = () => { setBusy(true); setError(null); setNotice(null) }
  const finish = () => setBusy(false)

  async function saveUsername(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (busy) return
    const value = username.trim()
    if (!/^[A-Za-z0-9_.-]{3,24}$/.test(value)) {
      setError('Username must contain 3–24 letters, numbers, dots, underscores or hyphens.')
      return
    }
    start()
    const { error: rpcError } = await supabase.rpc('set_my_tennis_converted_username_v1', { p_username: value })
    if (rpcError) setError(rpcError.message)
    else { setNotice('Account username confirmed.'); await reload() }
    finish()
  }

  function requestBirthdayConfirmation(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (busy) return
    if (!month || !day || (year && !/^\d{4}$/.test(year))) {
      setError('Enter a valid birth month and day. The year is optional.')
      return
    }
    const date = new Date(Date.UTC(Number(year || 2000), Number(month) - 1, Number(day)))
    if (date.getUTCMonth() !== Number(month) - 1 || date.getUTCDate() !== Number(day) ||
        (year && (Number(year) < 1900 || date.getUTCFullYear() !== Number(year) || date > new Date()))) {
      setError('Please enter a real calendar date. The year can be left empty.')
      return
    }
    setError(null)
    setBirthdayConfirmOpen(true)
  }

  async function confirmBirthday() {
    if (busy) return
    start()
    const { error: rpcError } = await supabase.rpc('set_my_tennis_converted_birthday_v1', {
      p_month: Number(month),
      p_day: Number(day),
      p_year: year ? Number(year) : null,
      p_timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
    })
    if (rpcError) setError(rpcError.message)
    else { setBirthdayConfirmOpen(false); setNotice('Birthday saved permanently. Future eligible birthdays can receive the annual gift.'); await reload() }
    finish()
  }

  async function saveCity(automatic: boolean) {
    if (busy) return
    if (!automatic && !city) { setError('Choose a city or use automatic assignment.'); return }
    start()
    const { data, error: rpcError } = automatic
      ? await supabase.rpc('assign_my_tennis_converted_home_city_v1')
      : await supabase.rpc('set_player_home_city_v1', { p_home_city: city })
    const result = data as { status?: string; home_city?: string } | null
    if (rpcError) setError(rpcError.message)
    else if (result?.status === 'no_available_city') setError('There are no available home cities for this country.')
    else {
      setNotice(`Player home city: ${result?.home_city ?? city}.`)
      await refreshPlayer()
      await reload()
    }
    finish()
  }

  if (!status?.eligible) return null
  const allComplete = !!status.username_confirmed && !!status.birthday_set && !!status.home_city

  return (
    <>
    <section id="profile-completion" className="tlg-account-section">
      <header className="tlg-account-section-head">
        <div>
          <span>Guest registration follow-up</span>
          <h3>Complete your account information</h3>
          <p>Your tennis career is already permanent. You can finish these details without restarting or losing progress.</p>
        </div>
      </header>
      <div className="tlg-converted-fields">
        {allComplete && !editSavedCity ? (
          <div className="tlg-converted-complete-row" role="status">
            <div><strong>Account details completed</strong><p>Username: {status.username} · Birthday: saved and locked · Player home city: {status.home_city}</p></div>
            <button type="button" className="secondary" onClick={() => setEditSavedCity(true)}>Change home city</button>
          </div>
        ) : <>
        <fieldset>
          <legend>Account username</legend>
          {status.username_confirmed ? (
            <p>Confirmed username: <strong>{status.username}</strong>. This one-time guest registration correction has been saved.</p>
          ) : (
            <form className="field-row" onSubmit={(event) => void saveUsername(event)}>
              <label>Username
                <input value={username} maxLength={24} autoComplete="username"
                  onChange={(event) => setUsername(event.target.value)} required />
              </label>
              <button type="submit" disabled={busy}>Confirm username</button>
              <p>We assigned a temporary username during Guest Mode. Confirm it or choose your own (3–24 characters).</p>
            </form>
          )}
        </fieldset>

        <fieldset>
          <legend>Your account birthday (optional)</legend>
          {status.birthday_set ? (
            <p>Birthday saved. It is permanently locked and cannot be changed.</p>
          ) : (
            <form onSubmit={requestBirthdayConfirmation}>
              <p>Only converted Guest Players with a missing birthday can enter one now. This is your account birthday, not the fictional player's. No birthday means no annual Birthday Gift.</p>
              <div className="field-row">
                <label>Month
                  <input type="number" min={1} max={12} placeholder="1–12" value={month}
                    onChange={(event) => setMonth(event.target.value)} required />
                </label>
                <label>Day
                  <input type="number" min={1} max={31} placeholder="1–31" value={day}
                    onChange={(event) => setDay(event.target.value)} required />
                </label>
                <label>Year (optional)
                  <input type="number" min={1900} max={new Date().getFullYear()} placeholder="Optional"
                    value={year} onChange={(event) => setYear(event.target.value)} />
                </label>
                <button type="submit" disabled={busy}>Save birthday once</button>
              </div>
            </form>
          )}
        </fieldset>

        <fieldset>
          <legend>Player home city</legend>
          <p>Choose a city in your player's country ({player?.country_code ?? status.country_code ?? '—'}). If you do not choose, the game can assign an available city automatically. The assigned city can be changed later.</p>
          <div className="field-row">
            <label>Home city
              <select value={city} onChange={(event) => setCity(event.target.value)}>
                <option value="">Choose a city</option>
                {city && !cities.some((c) => c.city === city) && <option value={city}>{city}</option>}
                {cities.map((option) => <option key={option.city} value={option.city}>{option.city}</option>)}
              </select>
            </label>
            <button type="button" disabled={busy || !city || !cities.some((c) => c.city === city)} onClick={() => void saveCity(false)}>Save city</button>
            {!status.home_city && <button type="button" className="secondary" disabled={busy} onClick={() => void saveCity(true)}>Assign automatically</button>}
          </div>
          {status.home_city && <p>Current player home city: <strong>{status.home_city}</strong>.</p>}
        </fieldset>

        </>}
        {notice && <p className="field-status" role="status">{notice}</p>}
        {error && <p className="field-error" role="alert">{error}</p>}
      </div>
    </section>
    <GameConfirmDialog
      open={birthdayConfirmOpen}
      eyebrow="Account security"
      title="Confirm your birthday"
      tone="warning"
      busy={busy}
      confirmLabel="Save birthday permanently"
      cancelLabel="Go back and edit"
      message={<span>You entered <strong>{month.padStart(2,'0')}/{day.padStart(2,'0')}{year ? `/${year}` : ''}</strong>. This is the birthday for your account, not your tennis player.</span>}
      detail="This information can only be saved once. After confirming, it cannot be corrected or changed."
      onConfirm={() => void confirmBirthday()}
      onCancel={() => { if (!busy) setBirthdayConfirmOpen(false) }}
    />
    </>
  )
}
