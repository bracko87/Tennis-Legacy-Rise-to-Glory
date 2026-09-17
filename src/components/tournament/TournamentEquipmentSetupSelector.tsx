import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router'

import { supabase } from '../../lib/supabase'
import '../../styles/equipment-refinement-v2.css'
import '../../styles/equipment-match-setups-polish.css'

type Json = Record<string, any>

export default function TournamentEquipmentSetupSelector() {
  const { competitionId } = useParams()
  const [matches, setMatches] = useState<Json[]>([])
  const [host, setHost] = useState<HTMLElement | null>(null)
  const [matchId, setMatchId] = useState<string | null>(null)
  const [setups, setSetups] = useState<Json[]>([])
  const [selected, setSelected] = useState(0)
  const [editable, setEditable] = useState(false)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    if (!competitionId) return
    void supabase.rpc('get_tournament_draw_v1', { p_competition_id: competitionId }).then(({ data, error }) => setMatches(error ? [] : ((data ?? []) as Json[])))
    void supabase.rpc('get_player_equipment_match_setups_v1').then(({ data, error }) => setSetups(error ? [] : (((data as Json)?.setups ?? []) as Json[])))
  }, [competitionId])

  useEffect(() => {
    let currentHost: HTMLElement | null = null
    const locate = () => {
      const modal = document.querySelector<HTMLElement>('.tlg-match-modal')
      const tactic = modal?.querySelector<HTMLElement>('.tlg-match-tactic-section') ?? null
      const heading = modal?.querySelector<HTMLElement>('.tlg-match-modal-head h2')?.textContent?.trim() ?? ''
      const marker = ' · Match '
      const idx = heading.lastIndexOf(marker)
      let nextMatch: Json | undefined
      if (idx >= 0) {
        const round = heading.slice(0, idx).trim()
        const num = Number.parseInt(heading.slice(idx + marker.length), 10)
        nextMatch = matches.find((match) => match.round_label === round && match.match_number === num)
      }
      if (tactic && nextMatch) {
        setMatchId((value) => value === nextMatch!.match_id ? value : nextMatch!.match_id)
        if (!currentHost || !document.body.contains(currentHost)) {
          currentHost = document.createElement('div')
          currentHost.dataset.tlgEquipmentMatchSelector = 'true'
          const head = tactic.querySelector('.tlg-match-tactic-head')
          head?.insertAdjacentElement('afterend', currentHost)
          setHost(currentHost)
        }
      } else if (currentHost) {
        currentHost.remove()
        currentHost = null
        setHost(null)
        setMatchId(null)
      }
    }
    locate()
    const observer = new MutationObserver(locate)
    observer.observe(document.body, { childList: true, subtree: true })
    return () => {
      observer.disconnect()
      currentHost?.remove()
      setHost(null)
    }
  }, [matches])

  useEffect(() => {
    if (!matchId) return
    setMessage(null)
    void supabase.rpc('get_player_tournament_match_equipment_setup_v1', { p_match_id: matchId }).then(({ data, error }) => {
      if (error || !data) {
        setMessage(error?.message ?? 'Unable to load match equipment setup.')
        return
      }
      const row = data as Json
      setSelected(Number(row.setup_slot ?? 0))
      setEditable(Boolean(row.editable))
    })
  }, [matchId])

  const options = useMemo(() => [...setups].sort((a, b) => a.slot_index - b.slot_index), [setups])

  async function save() {
    if (!matchId) return
    setBusy(true)
    setMessage(null)
    const { data, error } = await supabase.rpc('save_player_tournament_match_equipment_setup_v1', { p_match_id: matchId, p_setup_slot: selected })
    setBusy(false)
    if (error) setMessage(error.message)
    else setMessage(`Match equipment: ${(data as Json)?.setup_name ?? 'Default Match Setup'}.`)
  }

  if (!host || !matchId) return null
  return createPortal(
    <section className="tlg-match-equipment-selector">
      <div><span>MATCH EQUIPMENT</span><strong>Choose equipment setup</strong><small>Default Match Setup is used automatically when no custom setup is selected.</small></div>
      <div className="tlg-match-equipment-selector-controls">
        <select value={selected} disabled={!editable || busy} onChange={(event) => setSelected(Number(event.target.value))}>
          <option value={0}>Default Match Setup</option>
          {options.map((setup) => <option key={setup.slot_index} value={setup.slot_index} disabled={!setup.racket_inventory_id || !setup.shoes_inventory_id || !setup.apparel_inventory_id}>{setup.name}{!setup.racket_inventory_id || !setup.shoes_inventory_id || !setup.apparel_inventory_id ? ' · not configured' : ''}</option>)}
        </select>
        <button type="button" disabled={!editable || busy} onClick={() => void save()}>{busy ? 'Saving…' : 'Save equipment'}</button>
      </div>
      {message && <p>{message}</p>}
    </section>,
    host,
  )
}
