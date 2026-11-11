import { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'
import '../../styles/season2-week1-preregistration.css'

interface Week1Tournament {
  competition_id: string
  name: string
  city: string
  country_code: string
  category_code: string
  surface: string
  available: boolean
  reason: string
}

interface Week1PreRegistrationState {
  enabled: boolean
  phase: string
  world: 'ATP' | 'WTA'
  target_season: number
  season_week: number
  selected_competition_id: string | null
  preference_status: 'selected' | 'withdrawn' | 'not_selected'
  accept_qualification: boolean
  tournaments: Week1Tournament[]
  message: string
}

function humanReason(reason: string): string {
  switch (reason) {
    case 'health_unavailable': return 'Player health does not allow this tournament.'
    case 'different_world': return 'This tournament is for another competitive world.'
    case 'calendar_commitment_overlap': return 'Another calendar commitment overlaps this tournament.'
    case 'singles_entry_overlap':
    case 'accepted_singles_overlap':
    case 'doubles_entry_overlap': return 'An existing tournament entry overlaps this event.'
    default: return 'Not currently eligible'
  }
}

/**
 * A pre-season CHOICE, not a normal tournament application. The backend saves
 * only the preference in a protected recovery table. It does not modify a
 * published Week 1 draw, award an entry, or charge any money.
 *
 * Server returns enabled=false after the season begins, so the form is hidden
 * rather than promising registration once the recovery window has closed.
 */
export default function Season2Week1PreRegistration() {
  const { t } = useTranslation()
  const { player } = useAuth()
  const [state, setState] = useState<Week1PreRegistrationState | null>(null)
  const [choice, setChoice] = useState('')
  const [acceptQualification, setAcceptQualification] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const load = useCallback(async (syncForm: boolean) => {
    if (!player?.id) return
    const response = await supabase.rpc('get_tennis_season2_week1_preentry_v1')
    if (response.error) {
      setError(response.error.message)
      return
    }
    const next = response.data as Week1PreRegistrationState | null
    if (!next || !next.enabled) {
      setState(null)
      return
    }
    setState(next)
    if (syncForm) {
      setChoice(next.selected_competition_id ?? '')
      setAcceptQualification(next.accept_qualification)
    }
  }, [player?.id])

  useEffect(() => {
    let active = true
    if (!player?.id) {
      setState(null)
      return
    }
    const request = async () => {
      const result = await supabase.rpc('get_tennis_season2_week1_preentry_v1')
      if (!active) return
      if (result.error || !result.data || !(result.data as Week1PreRegistrationState).enabled) {
        setState(null)
        return
      }
      const next = result.data as Week1PreRegistrationState
      setState(next)
      setChoice(next.selected_competition_id ?? '')
      setAcceptQualification(next.accept_qualification)
    }
    void request()
    return () => { active = false }
  }, [player?.id])

  const selectedTournament = useMemo(
    () => state?.tournaments.find((tournament) => tournament.competition_id === state.selected_competition_id),
    [state],
  )
  const choiceIsAvailable = state?.tournaments.some(
    (tournament) => tournament.competition_id === choice && tournament.available,
  ) ?? false

  async function save(selected: string | null) {
    if (busy || !state?.enabled) return
    setBusy(true)
    setError(null)
    setNotice(null)

    const { error: requestError } = await supabase.rpc('set_tennis_season2_week1_preentry_v1', {
      p_competition_id: selected,
      p_accept_qualification: acceptQualification,
    })
    if (requestError) {
      setError(requestError.message)
      setBusy(false)
      return
    }
    setNotice(selected
      ? t('season2Preentry.saved', { defaultValue: 'Preference saved. Your entry is not yet accepted; the Week 1 draw must be reviewed and rebuilt safely.' })
      : t('season2Preentry.withdrawn', { defaultValue: 'Your Week 1 preference has been withdrawn.' }))
    await load(true)
    setBusy(false)
  }

  if (!player?.id || !state?.enabled || !state.tournaments.length) return null

  return (
    <section className="tlg-overview-panel tlg-season2-week1-prereg" aria-labelledby="tlg-season2-week1-title">
      <header className="tlg-season2-week1-header">
        <div>
          <span>{t('season2Preentry.kicker', { defaultValue: 'SEASON 2 · WEEK 1' })}</span>
          <h3 id="tlg-season2-week1-title">{t('season2Preentry.title', { defaultValue: 'Optional Week 1 tournament preference' })}</h3>
          <p>{t('season2Preentry.intro', { defaultValue: 'This optional choice is only for the Season 1 → 2 recovery, because the first Week 1 draws were prepared before normal player registration was available. Future seasons should use the regular tournament application process.' })}</p>
        </div>
        <strong className="tlg-season2-week1-world">{state.world}</strong>
      </header>

      {state.preference_status === 'selected' && selectedTournament && (
        <p className="tlg-season2-week1-saved" role="status">
          {t('season2Preentry.current', { defaultValue: 'Current preference' })}: <strong>{selectedTournament.name} · {selectedTournament.city}</strong>
        </p>
      )}

      <div className="tlg-season2-week1-form">
        <label htmlFor="tlg-season2-week1-choice">{t('season2Preentry.select', { defaultValue: 'Week 1 tournament' })}</label>
        <select
          id="tlg-season2-week1-choice"
          value={choice}
          onChange={(event) => setChoice(event.target.value)}
          disabled={busy}
        >
          <option value="">{t('season2Preentry.placeholder', { defaultValue: 'Select a tournament' })}</option>
          {state.tournaments.map((tournament) => (
            <option
              key={tournament.competition_id}
              value={tournament.competition_id}
              disabled={!tournament.available}
            >
              {tournament.name} · {tournament.city} · {tournament.category_code.replaceAll('_', ' ')}
              {!tournament.available ? ` — ${humanReason(tournament.reason)}` : ''}
            </option>
          ))}
        </select>
        <label className="tlg-season2-week1-qualification">
          <input
            type="checkbox"
            checked={acceptQualification}
            disabled={busy}
            onChange={(event) => setAcceptQualification(event.target.checked)}
          />
          <span>{t('season2Preentry.qualification', { defaultValue: 'Accept qualification if the main draw is full' })}</span>
        </label>
        <div className="tlg-season2-week1-actions">
          <button
            type="button"
            className="primary"
            disabled={busy || !choice || !choiceIsAvailable}
            onClick={() => void save(choice)}
          >
            {busy
              ? t('season2Preentry.saving', { defaultValue: 'Saving…' })
              : t('season2Preentry.save', { defaultValue: 'Save preference' })}
          </button>
          {state.preference_status === 'selected' && (
            <button type="button" disabled={busy} onClick={() => void save(null)}>
              {t('season2Preentry.withdraw', { defaultValue: 'Withdraw preference' })}
            </button>
          )}
        </div>
      </div>

      <p className="tlg-season2-week1-disclaimer">
        {t('season2Preentry.warning', { defaultValue: 'You can skip this if you do not want to play Week 1. No player is registered automatically. A saved preference is not an accepted entry or a confirmed draw place, and no entry fee is charged. This special form will not be required for regular future seasons.' })}
      </p>
      {notice && <p className="tlg-season2-week1-message" role="status">{notice}</p>}
      {error && <p className="tlg-season2-week1-error" role="alert">{error}</p>}
    </section>
  )
}
