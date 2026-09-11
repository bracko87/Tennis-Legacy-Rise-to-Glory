import { createPortal } from 'react-dom'
import { AlertTriangle, HeartPulse, ShieldCheck } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-match-health-control.css'

interface DrawMatch {
  match_id: string
  round_label: string
  match_number: number
  player1_id: string | null
  player2_id: string | null
}

interface RiskStatus {
  risk_percent: number
  risk_level: string
  reasons?: string[]
}

interface MatchHealthStatus {
  match_id: string
  match_status: string
  player_id: string
  match_absolute_day: number
  fatigue: number
  health_concern: boolean
  simulation_prepared: boolean
  can_surrender: boolean
  surrender_reason: string | null
  health: {
    state: string
    label: string
    can_train: boolean
    can_compete: boolean
    performance_penalty: number
    primary_condition: null | {
      kind: 'injury' | 'illness'
      name: string
      severity: string
      progress_percent: number
    }
  }
  match_injury_risk: RiskStatus
  illness_risk: RiskStatus
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

function titleCase(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

export default function TournamentMatchHealthControl() {
  const { competitionId } = useParams()
  const { player } = useAuth()
  const [matches, setMatches] = useState<DrawMatch[]>([])
  const [selectedMatch, setSelectedMatch] = useState<DrawMatch | null>(null)
  const [host, setHost] = useState<HTMLElement | null>(null)
  const [health, setHealth] = useState<MatchHealthStatus | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!competitionId) { setMatches([]); return }
    let cancelled = false
    async function loadDraw() {
      const { data, error: drawError } = await supabase.rpc('get_tournament_draw_v1', { p_competition_id: competitionId })
      if (!cancelled) setMatches(drawError ? [] : ((data ?? []) as DrawMatch[]))
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
        currentHost?.remove(); currentHost = null; setHost(null); setSelectedMatch(null); return
      }
      const match = parseModalMatch(modal, matches)
      if (!match) return
      if (!currentHost || !currentHost.isConnected || currentHost.nextElementSibling !== tacticSection) {
        currentHost?.remove()
        currentHost = document.createElement('div')
        currentHost.dataset.tlgMatchHealthControlHost = 'true'
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

  const loadHealth = useCallback(async () => {
    if (!selectedMatch?.match_id || !player?.id || (selectedMatch.player1_id !== player.id && selectedMatch.player2_id !== player.id)) {
      setHealth(null); return
    }
    const { data, error: healthError } = await supabase.rpc('get_tournament_match_health_status_v1', { p_match_id: selectedMatch.match_id })
    if (healthError) { setHealth(null); setError(healthError.message); return }
    setHealth(data as MatchHealthStatus)
    setError(null)
  }, [player?.id, selectedMatch?.match_id, selectedMatch?.player1_id, selectedMatch?.player2_id])

  useEffect(() => {
    void loadHealth()
    if (!selectedMatch?.match_id) return
    const timer = window.setInterval(() => void loadHealth(), 15000)
    return () => window.clearInterval(timer)
  }, [loadHealth, selectedMatch?.match_id])

  async function surrenderMatch() {
    if (!selectedMatch?.match_id || !health?.can_surrender || busy) return
    const condition = health.health.primary_condition?.name ?? health.health.label
    const confirmed = window.confirm(`Surrender this match for health reasons?\n\nCurrent concern: ${condition}.\n\nThis immediately gives the match to your opponent and cannot be undone.`)
    if (!confirmed) return
    setBusy(true); setError(null)
    const { error: surrenderError } = await supabase.rpc('surrender_tournament_match_v1', { p_match_id: selectedMatch.match_id })
    setBusy(false)
    if (surrenderError) { setError(surrenderError.message); return }
    window.location.reload()
  }

  if (!host || !selectedMatch || !player?.id) return null
  if (selectedMatch.player1_id !== player.id && selectedMatch.player2_id !== player.id) return null
  if (!health && !error) return null

  const condition = health?.health.primary_condition
  return createPortal(
    <section className={`tlg-match-health-control ${health?.health_concern ? 'concern' : 'clear'}`}>
      <div className="tlg-match-health-heading">
        <div className="icon">{health?.health_concern ? <HeartPulse size={20} /> : <ShieldCheck size={20} />}</div>
        <div>
          <span>Match health check</span>
          <strong>{health?.health_concern ? 'Health concern detected' : 'No elevated health concern'}</strong>
          <small>{condition ? `${condition.name} · ${titleCase(condition.severity)} · ${condition.progress_percent}% recovered` : health?.health.label ?? 'Health status unavailable'}</small>
        </div>
      </div>
      {health ? <div className="tlg-match-health-metrics">
        <div><span>Fatigue</span><strong>{health.fatigue}/100</strong></div>
        <div><span>Match injury risk</span><strong>{titleCase(health.match_injury_risk.risk_level)} · {Number(health.match_injury_risk.risk_percent).toFixed(2)}%</strong></div>
        <div><span>Illness risk</span><strong>{titleCase(health.illness_risk.risk_level)} · {Number(health.illness_risk.risk_percent).toFixed(2)}%</strong></div>
        <div><span>Performance penalty</span><strong>{Math.round(Number(health.health.performance_penalty ?? 0) * 100)}%</strong></div>
      </div> : null}
      {health?.health_concern ? <div className="tlg-match-health-action">
        <AlertTriangle size={18} />
        <p>Playing while not fully fit can cause a recovery setback. If the risk is not acceptable, you can surrender before the match simulation is prepared.</p>
        <button type="button" disabled={!health.can_surrender || busy} onClick={surrenderMatch}>{busy ? 'Surrendering…' : 'Surrender match for health'}</button>
      </div> : null}
      {health && !health.can_surrender && health.health_concern ? <small className="tlg-match-health-disabled-reason">{health.surrender_reason}</small> : null}
      {error ? <div className="tlg-match-health-error">{error}</div> : null}
    </section>,
    host,
  )
}
