import { createPortal } from 'react-dom'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
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

interface GameCalendarDate {
  season: number
  month: number
  day: number
  season_week: number
}

interface MatchTacticData {
  match_status: MatchStatus
  editable: boolean
  source: 'automatic_default' | 'tournament_default' | 'match_override'
  tactic_lock_game_second: number | null
  tactic_lock_game_date: GameCalendarDate | null
  tactic_lock_minute_of_day: number | null
  lock_minutes_before_start: number
}

const GAME_MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'] as const

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

function formatLockDeadline(tactic: MatchTacticData | null) {
  const date = tactic?.tactic_lock_game_date
  const minuteOfDay = tactic?.tactic_lock_minute_of_day
  if (!date || minuteOfDay === null || minuteOfDay === undefined) return null

  const hours = Math.floor(minuteOfDay / 60)
  const minutes = minuteOfDay % 60
  const month = GAME_MONTH_NAMES[date.month - 1] ?? `Month ${date.month}`
  return `${month} ${date.day}, Season ${date.season} · ${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`
}

export default function TournamentMatchTacticStatus() {
  const { competitionId } = useParams()
  const { player } = useAuth()
  const [matches, setMatches] = useState<DrawMatch[]>([])
  const [selectedMatch, setSelectedMatch] = useState<DrawMatch | null>(null)
  const [host, setHost] = useState<HTMLElement | null>(null)
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
      setTactic(null)
      return
    }
    if (selectedMatch.player1_id !== player.id && selectedMatch.player2_id !== player.id) {
      setTactic(null)
      return
    }

    const { data, error } = await supabase.rpc('get_tournament_match_tactic_v1', {
      p_player_id: player.id,
      p_match_id: selectedMatch.match_id,
    })
    setTactic(error || !data ? null : (data as MatchTacticData))
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

  const lockDeadline = useMemo(() => formatLockDeadline(tactic), [tactic?.tactic_lock_game_date, tactic?.tactic_lock_minute_of_day])

  if (!host || !selectedMatch || !player?.id || !tactic) return null
  if (selectedMatch.player1_id !== player.id && selectedMatch.player2_id !== player.id) return null

  const hasOverride = tactic.source === 'match_override'
  const statusTitle = hasOverride ? 'Match tactic override saved' : 'Tactic unchanged'
  const sourceText = tactic.source === 'tournament_default'
    ? 'Using your Tournament Default until you save a match-specific tactic.'
    : tactic.source === 'automatic_default'
      ? 'Using the Automatic Balanced default until you save a match-specific tactic.'
      : 'A match-specific override is saved for this opponent.'
  const lockMinutes = tactic.lock_minutes_before_start ?? 60

  return createPortal(
    <section className={`tlg-match-tactic-status-strip${tactic.editable ? ' editable' : ' locked'}`}>
      <div>
        <span>Tactic status</span>
        <strong>{statusTitle}</strong>
        <small>{sourceText}</small>
      </div>
      <div>
        <span>{tactic.editable ? 'Tactic can be changed until' : 'Tactic deadline'}</span>
        <strong>{tactic.editable ? (lockDeadline ?? 'Schedule pending') : 'Locked'}</strong>
        <small>{tactic.editable ? `Changes lock ${lockMinutes} minutes before the scheduled start.` : 'The match has started, finished, or reached its tactic lock time.'}</small>
      </div>
    </section>,
    host,
  )
}
