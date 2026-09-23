import { useCallback, useEffect, useState } from 'react'

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
  return (
    <label className="tlg-doubles-tactic-field">
      <span>{label}</span>
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {values.map((option) => <option key={option} value={option}>{option}</option>)}
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
      setMessage(error?.message ?? 'Unable to load doubles tactic.')
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
      setMessage(error?.message ?? 'Unable to save doubles tactic.')
      return
    }

    const next = tacticData as DoublesMatchTacticResponse
    setData(next)
    setDraft(next.effective)
    setMessage('Your doubles match tactic is saved.')
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
      setMessage(error?.message ?? 'Unable to reset doubles tactic.')
      return
    }

    const next = tacticData as DoublesMatchTacticResponse
    setData(next)
    setDraft(next.effective)
    setMessage('Automatic Balanced tactic restored.')
  }

  const sourceLabel = data?.source === 'match_override' ? 'Your match override' : 'Automatic Balanced'
  let partnerLabel = (data?.partner_name ?? 'Partner') + ' uses their own automatic tactic.'
  if (data?.partner_tactic_source === 'ai_automatic') {
    partnerLabel = (data.partner_name ?? 'Partner') + ' uses an automatic AI tactic based on playing style.'
  } else if (data?.partner_tactic_source === 'match_override') {
    partnerLabel = (data.partner_name ?? 'Partner') + ' controls their own saved tactic.'
  }

  if (loading) {
    return <div className="tlg-doubles-tactic-panel loading">Loading your doubles tactic…</div>
  }

  if (!data) {
    return <div className="tlg-doubles-tactic-panel error">{message ?? 'Doubles tactic unavailable.'}</div>
  }

  return (
    <section className="tlg-doubles-tactic-panel">
      <header>
        <div>
          <span>Your doubles tactic</span>
          <h3>Control your player in this match</h3>
          <p>Your selections affect only your player. Your partner and both opponents control their own tactics independently; AI players choose theirs automatically.</p>
        </div>
        <div className="tlg-doubles-tactic-source"><span>Active</span><strong>{sourceLabel}</strong></div>
      </header>

      <div className="tlg-doubles-partner-tactic-note">
        <strong>Partner plan</strong>
        <span>{partnerLabel}</span>
      </div>

      {!data.editable ? (
        <div className="tlg-doubles-tactic-locked">
          This match tactic is locked because the match has started, finished, or reached the one-hour pre-match lock.
        </div>
      ) : (
        <>
          <div className="tlg-doubles-tactic-presets">
            {TACTIC_PRESETS.map((preset) => (
              <button
                key={preset}
                type="button"
                className={draft.preset === preset ? 'active' : ''}
                onClick={() => setDraft(tacticFromPreset(preset))}
              >
                {preset}
              </button>
            ))}
          </div>

          <div className="tlg-doubles-tactic-grid">
            <TacticSelect label="Overall approach" value={draft.approach} values={TACTIC_OPTIONS.approach} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', approach: value }))} />
            <TacticSelect label="Rally strategy" value={draft.rally} values={TACTIC_OPTIONS.rally} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', rally: value }))} />
            <TacticSelect label="Serve strategy" value={draft.serve} values={TACTIC_OPTIONS.serve} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', serve: value }))} />
            <TacticSelect label="Return strategy" value={draft.returnGame} values={TACTIC_OPTIONS.returnGame} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', returnGame: value }))} />
            <TacticSelect label="Court position" value={draft.courtPosition} values={TACTIC_OPTIONS.courtPosition} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', courtPosition: value }))} />
            <TacticSelect label="Opponent target" value={draft.target} values={TACTIC_OPTIONS.target} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', target: value }))} />
            <TacticSelect label="Risk level" value={draft.risk} values={TACTIC_OPTIONS.risk} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', risk: value }))} />
          </div>

          <div className="tlg-doubles-tactic-actions">
            <span>{message ?? 'Changes lock one game hour before the scheduled match.'}</span>
            <div>
              <button type="button" disabled={saving || data.source !== 'match_override'} onClick={() => void reset()}>Use Automatic</button>
              <button type="button" className="primary" disabled={saving} onClick={() => void save()}>{saving ? 'Saving…' : 'Save Tactic'}</button>
            </div>
          </div>
        </>
      )}
    </section>
  )
}
