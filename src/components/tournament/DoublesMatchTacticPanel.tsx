import { useCallback, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { supabase } from '../../lib/supabase'
import {
  BALANCED_TACTIC,
  TACTIC_OPTIONS,
  TACTIC_PRESETS,
  tacticFromPreset,
  type TournamentTactic,
} from '../../lib/tournamentTactics'

interface DoublesMatchTacticResponse {
  match_id: string
  match_status: string
  editable: boolean
  source: 'automatic_default' | 'match_override'
  override: TournamentTactic | null
  effective: TournamentTactic
  tactic_lock_game_second: number | null
  partner_id: string | null
  partner_name: string | null
  partner_tactic: TournamentTactic | null
  partner_tactic_source: 'ai_automatic' | 'automatic_default' | 'match_override' | null
}

function TacticSelect({
  label,
  value,
  values,
  onChange,
}: {
  label: string
  value: string
  values: readonly string[]
  onChange: (value: string) => void
}) {
  const { t } = useTranslation()
  return (
    <label className="tlg-doubles-tactic-field">
      <span>{label}</span>
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {values.map((option) => <option key={option} value={option}>{t(`tournamentPage.tactic.options.${option}`, { defaultValue: option })}</option>)}
      </select>
    </label>
  )
}

export default function DoublesMatchTacticPanel({
  matchId,
  currentPlayerId,
}: {
  matchId: string
  currentPlayerId: string
}) {
  const { t } = useTranslation()
  const [data, setData] = useState<DoublesMatchTacticResponse | null>(null)
  const [draft, setDraft] = useState<TournamentTactic>({ ...BALANCED_TACTIC })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    const { data: tacticData, error } = await supabase.rpc('get_tournament_doubles_match_tactic_v1', {
      p_player_id: currentPlayerId,
      p_match_id: matchId,
    })
    setLoading(false)

    if (error || !tacticData) {
      setMessage(error?.message ?? t('tournamentPage.enhancements.doublesTactic.loadError'))
      setData(null)
      return
    }

    const next = tacticData as DoublesMatchTacticResponse
    setData(next)
    setDraft(next.override ?? next.effective ?? { ...BALANCED_TACTIC })
    setMessage(null)
  }, [currentPlayerId, matchId])

  useEffect(() => { void load() }, [load])

  async function save() {
    setSaving(true)
    setMessage(null)
    const { data: tacticData, error } = await supabase.rpc('save_tournament_doubles_match_tactic_v1', {
      p_player_id: currentPlayerId,
      p_match_id: matchId,
      p_tactic_preset: draft.preset,
      p_tactic_approach: draft.approach,
      p_tactic_rally: draft.rally,
      p_tactic_serve: draft.serve,
      p_tactic_return: draft.returnGame,
      p_tactic_court_position: draft.courtPosition,
      p_tactic_target: draft.target,
      p_tactic_risk: draft.risk,
    })
    setSaving(false)

    if (error || !tacticData) {
      setMessage(error?.message ?? t('tournamentPage.enhancements.doublesTactic.saveError'))
      return
    }

    const next = tacticData as DoublesMatchTacticResponse
    setData(next)
    setDraft(next.effective)
    setMessage(t('tournamentPage.enhancements.doublesTactic.saved'))
  }

  async function reset() {
    setSaving(true)
    setMessage(null)
    const { data: tacticData, error } = await supabase.rpc('clear_tournament_doubles_match_tactic_v1', {
      p_player_id: currentPlayerId,
      p_match_id: matchId,
    })
    setSaving(false)

    if (error || !tacticData) {
      setMessage(error?.message ?? t('tournamentPage.enhancements.doublesTactic.resetError'))
      return
    }

    const next = tacticData as DoublesMatchTacticResponse
    setData(next)
    setDraft(next.effective)
    setMessage(t('tournamentPage.enhancements.doublesTactic.automaticRestored'))
  }

  const sourceLabel = data?.source === 'match_override'
    ? t('tournamentPage.enhancements.doublesTactic.sourceOverride')
    : t('tournamentPage.enhancements.doublesTactic.sourceAutomatic')
  const partnerName = data?.partner_name ?? t('tournamentPage.enhancements.doublesTactic.partnerFallback')
  let partnerLabel = t('tournamentPage.enhancements.doublesTactic.partnerAutomatic', { name: partnerName })
  if (data?.partner_tactic_source === 'ai_automatic') {
    partnerLabel = t('tournamentPage.enhancements.doublesTactic.partnerAi', { name: partnerName })
  } else if (data?.partner_tactic_source === 'match_override') {
    partnerLabel = t('tournamentPage.enhancements.doublesTactic.partnerOverride', { name: partnerName })
  }

  if (loading) {
    return <div className="tlg-doubles-tactic-panel loading">{t('tournamentPage.enhancements.doublesTactic.loading')}</div>
  }

  if (!data) {
    return <div className="tlg-doubles-tactic-panel error">{message ?? t('tournamentPage.enhancements.doublesTactic.unavailable')}</div>
  }

  return (
    <section className="tlg-doubles-tactic-panel">
      <header>
        <div>
          <span>{t('tournamentPage.enhancements.doublesTactic.kicker')}</span>
          <h3>{t('tournamentPage.enhancements.doublesTactic.title')}</h3>
          <p>{t('tournamentPage.enhancements.doublesTactic.body')}</p>
        </div>
        <div className="tlg-doubles-tactic-source"><span>{t('tournamentPage.enhancements.doublesTactic.active')}</span><strong>{sourceLabel}</strong></div>
      </header>

      <div className="tlg-doubles-partner-tactic-note">
        <strong>{t('tournamentPage.enhancements.doublesTactic.partnerPlan')}</strong>
        <span>{partnerLabel}</span>
      </div>

      {!data.editable ? (
        <div className="tlg-doubles-tactic-locked">
          {t('tournamentPage.enhancements.doublesTactic.lockedBody')}
        </div>
      ) : (
        <>
          <div className="tlg-doubles-tactic-presets">
            {TACTIC_PRESETS.map((preset) => (
              <button
                key={t(`tournamentPage.tactic.options.${preset}`, { defaultValue: preset })}
                type="button"
                className={draft.preset === preset ? 'active' : ''}
                onClick={() => setDraft(tacticFromPreset(preset))}
              >
                {preset}
              </button>
            ))}
          </div>

          <div className="tlg-doubles-tactic-grid">
            <TacticSelect label={t('tournamentPage.enhancements.doublesTactic.overall')} value={draft.approach} values={TACTIC_OPTIONS.approach} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', approach: value }))} />
            <TacticSelect label={t('tournamentPage.enhancements.doublesTactic.rally')} value={draft.rally} values={TACTIC_OPTIONS.rally} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', rally: value }))} />
            <TacticSelect label={t('tournamentPage.enhancements.doublesTactic.serve')} value={draft.serve} values={TACTIC_OPTIONS.serve} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', serve: value }))} />
            <TacticSelect label={t('tournamentPage.enhancements.doublesTactic.return')} value={draft.returnGame} values={TACTIC_OPTIONS.returnGame} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', returnGame: value }))} />
            <TacticSelect label={t('tournamentPage.enhancements.doublesTactic.court')} value={draft.courtPosition} values={TACTIC_OPTIONS.courtPosition} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', courtPosition: value }))} />
            <TacticSelect label={t('tournamentPage.enhancements.doublesTactic.target')} value={draft.target} values={TACTIC_OPTIONS.target} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', target: value }))} />
            <TacticSelect label={t('tournamentPage.enhancements.doublesTactic.risk')} value={draft.risk} values={TACTIC_OPTIONS.risk} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', risk: value }))} />
          </div>

          <div className="tlg-doubles-tactic-actions">
            <span>{message ?? t('tournamentPage.enhancements.doublesTactic.lockNote')}</span>
            <div>
              <button type="button" disabled={saving || data.source !== 'match_override'} onClick={() => void reset()}>{t('tournamentPage.enhancements.doublesTactic.useAutomatic')}</button>
              <button type="button" className="primary" disabled={saving} onClick={() => void save()}>{saving ? t('tournamentPage.enhancements.doublesTactic.saving') : t('tournamentPage.enhancements.doublesTactic.saveTactic')}</button>
            </div>
          </div>
        </>
      )}
    </section>
  )
}
