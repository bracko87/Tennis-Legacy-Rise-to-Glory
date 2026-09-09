import { createPortal } from 'react-dom'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { formatCompetitionWeekDay } from '../../lib/competitionCalendar'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-match-tactic-status.css'

type MatchStatus = 'scheduled' | 'in_progress' | 'bye' | 'completed' | 'walkover' | 'cancelled'

interface DrawMatch {
  match_id: string
  round_label: string
  match_number: number
  player1_id: string | null
  player2_id: string | null
}

interface MatchDetail {
  match_id: string
  scheduled_season_week: number
  scheduled_day: number
  scheduled_start_minute: number | null
  status: MatchStatus
}

interface MatchTacticData {
  match_status: MatchStatus
  editable: boolean
  source: 'automatic_default' | 'tournament_default' | 'match_override'
  tactic_lock_game_second: number | null
}

function parseModalMatch(modal: HTMLElement, matches: DrawMatch[]) {
  const text = modal.querySelector<HTMLElement>('.tlg-match-modal-head h2')?.textContent?.trim() ?? ''
  const marker = ' · Match '
  const markerIndex = text.lastIndexOf(marker)
  if (markerIndex < 0) return null

  const roundLabel = text.slice(0, markerIndex).trim()
  const matchNumber = Number.parseInt(text.slice(markerIndex + marker.length).trim(), 10)
  if (!Number.isInteger(matchNumber)) return null

  return matches.find((match) => match.round_label === roundLabel && match.match_number === matchNumber) ?? null
}

function formatMinute(minuteOfDay: number) {
  const safe = ((minuteOfDay % 1440) + 1440) % 1440
  const hours = Math.floor(safe / 60)
  const minutes = safe % 60
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`
}

function formatLockDeadline(detail: MatchDetail | null) {
  if (!detail) return null

  let week = detail.scheduled_season_week
  let day = detail.scheduled_day
  let lockMinute = (detail.scheduled_start_minute ?? 600) - 60

  while (lockMinute < 0) {
    lockMinute += 1440
    day -= 1
  }
  while (day < 1) {
    week -= 1
    day += 7
  }
  while (day > 7) {
    week += 1
    day -= 7
  }

  if (week < 1) return `Previous day · ${formatMinute(lockMinute)}`
  return `${formatCompetitionWeekDay(week, day)} · ${formatMinute(lockMinute)}`
}

export default function TournamentMatchTacticStatus() {
  const { competitionId } = useParams()
  const { player } = useAuth()
  const [matches, setMatches] = useState<DrawMatch[]>([])
  const [selectedMatch, setSelectedMatch] = useState<DrawMatch | null>(null)
  const [host, setHost] = useState<HTMLElement | null>(null)
  const [detail, setDetail] = useState<MatchDetail | null>(null)
  const [tactic, setTactic] = useState<MatchTacticData | null>(null)

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
    let frame = 0
    let disposed = false
    let currentHost: HTMLElement | null = null

    const locate = () => {
      if (disposed) return
      const modal = document.querySelector<HTMLElement>('.tlg-match-modal')
      const tacticSection = modal?.querySelector<HTMLElement>('.tlg-match-tactic-section') ?? null

      if (!modal || !tacticSection || matches.length === 0) {
        currentHost?.remove()
        currentHost = null
        setHost(null)
        setSelectedMatch(null)
        return
      }

      const match = parseModalMatch(modal, matches)
      if (!match) return

      if (!currentHost || !currentHost.isConnected || currentHost.nextElementSibling !== tacticSection) {
        currentHost?.remove()
        currentHost = document.createElement('div')
        currentHost.dataset.tlgMatchTacticStatusHost = 'true'
        tacticSection.insertAdjacentElement('beforebegin', currentHost)
      }

      setHost((value) => value === currentHost ? value : currentHost)
      setSelectedMatch((value) => value?.match_id === match.match_id ? value : match)
    }

    frame = window.requestAnimationFrame(locate)
    const observer = new MutationObserver(locate)
    observer.observe(document.body, { childList: true, subtree: true })

    return () => {
      disposed = true
      window.cancelAnimationFrame(frame)
      observer.disconnect()
      currentHost?.remove()
      setHost(null)
      setSelectedMatch(null)
    }
  }, [matches])

  const loadStatus = useCallback(async () => {
    if (!selectedMatch?.match_id || !player?.id) {
      setDetail(null)
      setTactic(null)
      return
    }
    if (selectedMatch.player1_id !== player.id && selectedMatch.player2_id !== player.id) {
      setDetail(null)
      setTactic(null)
      return
    }

    const [detailResponse, tacticResponse] = await Promise.all([
      supabase.rpc('get_tournament_match_detail_v1', { p_match_id: selectedMatch.match_id }),
      supabase.rpc('get_tournament_match_tactic_v1', { p_player_id: player.id, p_match_id: selectedMatch.match_id }),
    ])

    setDetail(detailResponse.error || !detailResponse.data ? null : (detailResponse.data as MatchDetail))
    setTactic(tacticResponse.error || !tacticResponse.data ? null : (tacticResponse.data as MatchTacticData))
  }, [player?.id, selectedMatch?.match_id, selectedMatch?.player1_id, selectedMatch?.player2_id])

  useEffect(() => {
    void loadStatus()
    if (!selectedMatch?.match_id || !player?.id) return

    const reload = () => { void loadStatus() }
    const channel = supabase.channel(`match-tactic-status-${selectedMatch.match_id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'player_tournament_match_tactics', filter: `match_id=eq.${selectedMatch.match_id}` }, reload)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'tournament_matches', filter: `id=eq.${selectedMatch.match_id}` }, reload)
      .subscribe()

    return () => { void supabase.removeChannel(channel) }
  }, [loadStatus, player?.id, selectedMatch?.match_id])

  const lockDeadline = useMemo(() => formatLockDeadline(detail), [detail])

  if (!host || !selectedMatch || !player?.id || !tactic) return null
  if (selectedMatch.player1_id !== player.id && selectedMatch.player2_id !== player.id) return null

  const hasOverride = tactic.source === 'match_override'
  const statusTitle = hasOverride ? 'Match tactic saved' : 'Tactic unchanged'
  const sourceText = tactic.source === 'tournament_default'
    ? 'Using your Tournament Default until you save a match-specific tactic.'
    : tactic.source === 'automatic_default'
      ? 'Using the Automatic Balanced default until you save a match-specific tactic.'
      : 'A match-specific override is saved for this opponent.'

  return createPortal(
    <section className={`tlg-match-tactic-status-strip${tactic.editable ? ' editable' : ' locked'}`}>
      <div>
        <span>Tactic status</span>
        <strong>{statusTitle}</strong>
        <small>{sourceText}</small>
      </div>
      <div>
        <span>{tactic.editable ? 'Editable until' : 'Match tactic'}</span>
        <strong>{tactic.editable ? (lockDeadline ?? '60 minutes before match') : 'Locked'}</strong>
        <small>{tactic.editable ? 'Changes lock 60 minutes before the scheduled start.' : 'The match has started, finished, or reached its tactic lock time.'}</small>
      </div>
    </section>,
    host,
  )
}
