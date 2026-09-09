import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { formatAbsoluteGameDay } from '../../lib/competitionCalendar'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-match-tactic-status.css'

interface DrawMatch {
  match_id: string
  round_label: string
  match_number: number
  player1_id: string | null
  player2_id: string | null
}

interface MatchTacticStatusData {
  editable: boolean
  source: 'automatic_default' | 'tournament_default' | 'match_override'
  tactic_lock_game_second: number | null
}

function parseSelectedMatch(modal: HTMLElement, matches: DrawMatch[]) {
  const heading = modal.querySelector<HTMLElement>('.tlg-match-modal-head h2')?.textContent?.trim() ?? ''
  const marker = ' · Match '
  const markerIndex = heading.lastIndexOf(marker)
  if (markerIndex < 0) return null
  const roundLabel = heading.slice(0, markerIndex).trim()
  const matchNumber = Number.parseInt(heading.slice(markerIndex + marker.length).trim(), 10)
  if (!Number.isInteger(matchNumber)) return null
  return matches.find((match) => match.round_label === roundLabel && match.match_number === matchNumber) ?? null
}

function formatLockDeadline(gameSecond: number | null) {
  if (gameSecond === null || !Number.isFinite(gameSecond)) return null
  const absoluteDay = Math.floor(gameSecond / 86400)
  const season = Math.floor(absoluteDay / 366) + 1
  const minuteOfDay = Math.floor((gameSecond % 86400) / 60)
  const hours = Math.floor(minuteOfDay / 60)
  const minutes = minuteOfDay % 60
  return `${formatAbsoluteGameDay(absoluteDay, season)}, ${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`
}

export default function TournamentMatchTacticStatus() {
  const { competitionId } = useParams()
  const { player } = useAuth()
  const [matches, setMatches] = useState<DrawMatch[]>([])
  const [selected, setSelected] = useState<DrawMatch | null>(null)
  const [target, setTarget] = useState<HTMLElement | null>(null)
  const [status, setStatus] = useState<MatchTacticStatusData | null>(null)

  useEffect(() => {
    if (!competitionId) {
      setMatches([])
      return
    }
    let cancelled = false
    async function loadDraw() {
      const { data, error } = await supabase.rpc('get_tournament_draw_v1', { p_competition_id: competitionId })
      if (!cancelled) setMatches(error ? [] : ((data ?? []) as DrawMatch[]))
    }
    void loadDraw()
    return () => { cancelled = true }
  }, [competitionId])

  useEffect(() => {
    let disposed = false
    let host: HTMLElement | null = null
    let currentSection: HTMLElement | null = null

    const locate = () => {
      if (disposed) return
      const modal = document.querySelector<HTMLElement>('.tlg-match-modal')
      const section = modal?.querySelector<HTMLElement>('.tlg-match-tactic-section') ?? null
      if (!modal || !section || matches.length === 0) {
        host?.remove()
        host = null
        currentSection = null
        setTarget(null)
        setSelected(null)
        return
      }

      const next = parseSelectedMatch(modal, matches)
      if (!next) return

      if (section !== currentSection) {
        host?.remove()
        host = document.createElement('div')
        host.dataset.tlgMatchTacticStatus = 'true'
        section.insertAdjacentElement('beforebegin', host)
        currentSection = section
        setTarget(host)
      }
      setSelected((value) => value?.match_id === next.match_id ? value : next)
    }

    locate()
    const observer = new MutationObserver(locate)
    observer.observe(document.body, { childList: true, subtree: true })
    return () => {
      disposed = true
      observer.disconnect()
      host?.remove()
      setTarget(null)
      setSelected(null)
    }
  }, [matches])

  useEffect(() => {
    if (!selected || !player?.id || (selected.player1_id !== player.id && selected.player2_id !== player.id)) {
      setStatus(null)
      return
    }
    let cancelled = false
    const load = async () => {
      const { data, error } = await supabase.rpc('get_tournament_match_tactic_v1', {
        p_player_id: player.id,
        p_match_id: selected.match_id,
      })
      if (!cancelled) setStatus(error ? null : (data as MatchTacticStatusData))
    }
    void load()

    const section = document.querySelector<HTMLElement>('.tlg-match-tactic-section')
    const onClick = (event: Event) => {
      const button = (event.target as HTMLElement | null)?.closest('button')
      const text = button?.textContent?.trim() ?? ''
      if (text.includes('Save Match Tactic') || text.includes('Use Tournament Default')) {
        window.setTimeout(() => { void load() }, 350)
      }
    }
    section?.addEventListener('click', onClick)
    return () => {
      cancelled = true
      section?.removeEventListener('click', onClick)
    }
  }, [player?.id, selected])

  const deadline = useMemo(() => formatLockDeadline(status?.tactic_lock_game_second ?? null), [status?.tactic_lock_game_second])

  if (!target || !selected || !player?.id || !status) return null

  const stateLabel = status.source === 'match_override' ? 'Match tactic saved' : 'Tactic unchanged'
  const deadlineLabel = status.editable
    ? deadline ?? 'Still editable'
    : 'Locked'

  return createPortal(
    <div className={`tlg-match-tactic-status-strip${status.editable ? '' : ' locked'}`}>
      <div>
        <span>Match tactic status</span>
        <strong>{status.editable ? stateLabel : 'Tactic locked'}</strong>
        <small>{status.source === 'match_override' ? 'A match-specific override is active for this opponent.' : 'No match-specific override has been saved. Your tournament/default tactic will be used.'}</small>
      </div>
      <div>
        <span>{status.editable ? 'Tactic can be changed until' : 'Tactic deadline'}</span>
        <strong>{deadlineLabel}</strong>
        <small>{status.editable ? 'The tactic locks 60 minutes before the scheduled match start.' : 'This match tactic can no longer be changed.'}</small>
      </div>
    </div>,
    target,
  )
}
