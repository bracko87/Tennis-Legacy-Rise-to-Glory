import { createPortal } from 'react-dom'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useLocation, useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import {
  BALANCED_TACTIC,
  TACTIC_OPTIONS,
  TACTIC_PRESETS,
  tacticFromPreset,
  type TournamentTactic,
} from '../../lib/tournamentTactics'
import '../../styles/tournament-logo.css'
import '../../styles/tournament-live-draw.css'
import '../../styles/tournament-match-modal-expanded.css'
import '../../styles/tournament-match-tactics.css'
import '../../styles/tournament-match-polish.css'
import TournamentPageV3 from './TournamentV3'

interface TournamentLogoRow {
  logo_url: string | null
  tournament_name: string
}

interface TournamentDrawMatch {
  match_id: string
  draw_type: 'main_draw' | 'qualification'
  round_number: number
  round_label: string
  match_number: number
  bracket_size: number
  scheduled_season_week: number
  scheduled_day: number
  match_status: 'scheduled' | 'in_progress' | 'bye' | 'completed' | 'walkover' | 'cancelled'
  player1_id: string | null
  player1_first_name: string | null
  player1_last_name: string | null
  player1_country_code: string | null
  player1_seed: number | null
  player1_set_scores: number[]
  player2_id: string | null
  player2_first_name: string | null
  player2_last_name: string | null
  player2_country_code: string | null
  player2_seed: number | null
  player2_set_scores: number[]
  winner_id: string | null
}

interface BracketRound {
  label: string
  matches: number
  roundNumber: number
}

interface MatchPlayerDetail {
  id: string
  first_name: string
  last_name: string
  country_code: string
  image_path: string | null
  ranking_position: number | null
  seed: number | null
}

interface MatchSetDetail {
  set_number: number
  player1_games: number
  player2_games: number
  player1_tiebreak_points: number | null
  player2_tiebreak_points: number | null
  status: 'in_progress' | 'completed'
}

interface MatchStats {
  aces?: number
  double_faults?: number
  first_serves_in?: number
  first_serves_total?: number
  first_serve_points_won?: number
  first_serve_points_played?: number
  second_serve_points_won?: number
  second_serve_points_played?: number
  break_points_won?: number
  break_points_total?: number
  winners?: number
  unforced_errors?: number
  total_points_won?: number
}

interface MatchDetail {
  match_id: string
  competition_id: string
  tournament_name: string
  city: string
  country_code: string
  round_label: string
  match_number: number
  scheduled_season_week: number
  scheduled_day: number
  status: TournamentDrawMatch['match_status']
  winner_id: string | null
  started_at: string | null
  completed_at: string | null
  player1: MatchPlayerDetail | null
  player2: MatchPlayerDetail | null
  sets: MatchSetDetail[]
  player1_stats: MatchStats
  player2_stats: MatchStats
}

interface GameCalendarDate {
  season: number
  month: number
  day: number
  season_week: number
}

interface MatchTacticResponse {
  match_status: MatchDetail['status']
  editable: boolean
  source: 'automatic_default' | 'tournament_default' | 'match_override'
  tournament_default: TournamentTactic
  override: TournamentTactic | null
  effective: TournamentTactic
  scheduled_game_second: number | null
  scheduled_start_minute: number | null
  scheduled_game_date: GameCalendarDate | null
  tactic_lock_game_second: number | null
  tactic_lock_game_date: GameCalendarDate | null
  tactic_lock_minute_of_day: number | null
  current_game_second: number
  lock_minutes_before_start: number
}

interface TacticEffect {
  label: string
  value: number | null
  text: string
  tone: 'positive' | 'warning' | 'neutral'
}

type LogoStatus = 'none' | 'loading' | 'ready' | 'error'

const BRACKET_MATCH_WIDTH = 240
const BRACKET_MATCH_HEIGHT = 68
const BRACKET_COLUMN_GAP = 72
const BRACKET_FIRST_ROUND_GAP = 12
const BRACKET_STEP = BRACKET_MATCH_HEIGHT + BRACKET_FIRST_ROUND_GAP

function mainDrawRounds(capacity: number): BracketRound[] {
  const rounds: BracketRound[] = []
  let participants = capacity
  let roundNumber = 1
  while (participants >= 2) {
    const label = participants === 2 ? 'Final' : participants === 4 ? 'Semifinal' : participants === 8 ? 'Quarterfinal' : `Round of ${participants}`
    rounds.push({ label, matches: participants / 2, roundNumber })
    participants /= 2
    roundNumber += 1
  }
  return rounds
}

function bracketMatchCenter(roundIndex: number, matchIndex: number) {
  const firstRoundMatchSpan = 2 ** roundIndex
  const representedFirstMatchCenter = matchIndex * firstRoundMatchSpan + (firstRoundMatchSpan - 1) / 2
  return BRACKET_MATCH_HEIGHT / 2 + representedFirstMatchCenter * BRACKET_STEP
}

function statusLabel(status: MatchDetail['status']) {
  if (status === 'in_progress') return 'LIVE'
  if (status === 'completed') return 'FINAL'
  if (status === 'walkover') return 'W/O'
  if (status === 'bye') return 'BYE'
  if (status === 'cancelled') return 'CANCELLED'
  return 'SCHEDULED'
}

function playerName(player: MatchPlayerDetail | null) {
  return player ? `${player.first_name} ${player.last_name}` : 'BYE'
}

function drawPlayerName(match: TournamentDrawMatch, side: 1 | 2) {
  const first = side === 1 ? match.player1_first_name : match.player2_first_name
  const last = side === 1 ? match.player1_last_name : match.player2_last_name
  return `${first ?? ''} ${last ?? ''}`.trim() || 'BYE'
}

function formatDrawScore(match: TournamentDrawMatch, perspectivePlayerId: string) {
  const playerIsOne = match.player1_id === perspectivePlayerId
  const own = playerIsOne ? match.player1_set_scores : match.player2_set_scores
  const opponent = playerIsOne ? match.player2_set_scores : match.player1_set_scores
  if (!own.length || own.length !== opponent.length) return 'Result recorded'
  return own.map((games, index) => `${games}–${opponent[index]}`).join(', ')
}

const GAME_MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'] as const

function formatGameDeadline(date: GameCalendarDate | null, minuteOfDay: number | null) {
  if (!date || minuteOfDay === null || minuteOfDay === undefined) return 'Schedule pending'
  const hours = Math.floor(minuteOfDay / 60)
  const minutes = minuteOfDay % 60
  const month = GAME_MONTH_NAMES[date.month - 1] ?? `Month ${date.month}`
  return `${month} ${date.day}, Season ${date.season} · ${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`
}

export default function TournamentPage() {
  const { competitionId } = useParams()
  const location = useLocation()
  const { player } = useAuth()
  const [logoUrl, setLogoUrl] = useState<string | null>(null)
  const [logoStatus, setLogoStatus] = useState<LogoStatus>('none')
  const [logoTarget, setLogoTarget] = useState<HTMLElement | null>(null)
  const [pageTarget, setPageTarget] = useState<HTMLElement | null>(null)
  const [tournamentName, setTournamentName] = useState('Tournament')
  const [drawMatches, setDrawMatches] = useState<TournamentDrawMatch[]>([])
  const [selectedMatchId, setSelectedMatchId] = useState<string | null>(null)
  const [matchDetail, setMatchDetail] = useState<MatchDetail | null>(null)
  const [matchLoading, setMatchLoading] = useState(false)
  const [matchError, setMatchError] = useState<string | null>(null)

  const returnPath = `${location.pathname}${location.search}${location.hash}`

  const loadTournamentExtras = useCallback(async () => {
    if (!competitionId) return
    const [logoResponse, drawResponse] = await Promise.all([
      supabase.rpc('get_tournament_detail_v1', { p_competition_id: competitionId }),
      supabase.rpc('get_tournament_draw_v1', { p_competition_id: competitionId }),
    ])
    if (!logoResponse.error) {
      const row = (Array.isArray(logoResponse.data) ? logoResponse.data[0] : logoResponse.data) as TournamentLogoRow | null
      const nextLogoUrl = row?.logo_url ?? null
      setLogoUrl(nextLogoUrl)
      setTournamentName(row?.tournament_name ?? 'Tournament')
      setLogoStatus(nextLogoUrl ? 'loading' : 'none')
    }
    setDrawMatches(drawResponse.error ? [] : ((drawResponse.data ?? []) as TournamentDrawMatch[]))
  }, [competitionId])

  useEffect(() => {
    if (!competitionId) {
      setLogoUrl(null)
      setLogoStatus('none')
      setDrawMatches([])
      return
    }
    void loadTournamentExtras()
  }, [competitionId, loadTournamentExtras])

  useEffect(() => {
    let frame = 0
    let cancelled = false
    function findTargets() {
      if (cancelled) return
      const logo = document.querySelector<HTMLElement>('.tlg-detail-logo-slot')
      const page = document.querySelector<HTMLElement>('.tlg-detail-page')
      if (logo) setLogoTarget(logo)
      if (page) setPageTarget(page)
      if (logo && page) return
      frame = window.requestAnimationFrame(findTargets)
    }
    frame = window.requestAnimationFrame(findTargets)
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      setLogoTarget(null)
      setPageTarget(null)
    }
  }, [competitionId])

  const loadMatchDetail = useCallback(async (matchId: string) => {
    setMatchLoading(true)
    setMatchError(null)
    const { data, error } = await supabase.rpc('get_tournament_match_detail_v1', { p_match_id: matchId })
    if (error || !data) {
      setMatchDetail(null)
      setMatchError(error?.message ?? 'Match details are unavailable.')
    } else {
      setMatchDetail(data as MatchDetail)
    }
    setMatchLoading(false)
  }, [])

  useEffect(() => {
    if (!selectedMatchId) {
      setMatchDetail(null)
      setMatchError(null)
      return
    }
    void loadMatchDetail(selectedMatchId)
    const reload = () => {
      void loadMatchDetail(selectedMatchId)
      void loadTournamentExtras()
    }
    const channel = supabase.channel(`tournament-match-${selectedMatchId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_matches', filter: `id=eq.${selectedMatchId}` }, reload)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_match_sets', filter: `match_id=eq.${selectedMatchId}` }, reload)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_match_player_stats', filter: `match_id=eq.${selectedMatchId}` }, reload)
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [selectedMatchId, loadMatchDetail, loadTournamentExtras])

  const showRealLogo = Boolean(logoTarget && logoUrl && logoStatus !== 'error')
  const mainDrawMatches = useMemo(() => drawMatches.filter((match) => match.draw_type === 'main_draw'), [drawMatches])
  const hasPublishedDraw = mainDrawMatches.some((match) => match.round_number === 1)
  const contextClassName = [logoStatus === 'ready' ? 'tlg-tournament-logo-context' : '', hasPublishedDraw ? 'tlg-tournament-real-draw-context' : ''].filter(Boolean).join(' ') || undefined

  return (
    <div className={contextClassName}>
      <TournamentPageV3 />

      {showRealLogo && logoTarget && logoUrl && createPortal(
        <img className={`tlg-tournament-logo-image ${logoStatus === 'ready' ? 'tlg-tournament-logo-image-ready' : ''}`} src={logoUrl} alt={`${tournamentName} tournament logo`} decoding="async" fetchPriority="high" onLoad={() => setLogoStatus('ready')} onError={() => setLogoStatus('error')} />,
        logoTarget,
      )}

      {hasPublishedDraw && pageTarget && createPortal(
        <PublishedDrawTree matches={mainDrawMatches} currentPlayerId={player?.id ?? null} returnPath={returnPath} tournamentName={tournamentName} onOpenMatch={setSelectedMatchId} />,
        pageTarget,
      )}

      {selectedMatchId && (
        <MatchDetailModal detail={matchDetail} drawMatches={mainDrawMatches} loading={matchLoading} error={matchError} currentPlayerId={player?.id ?? null} returnPath={returnPath} tournamentName={tournamentName} onClose={() => setSelectedMatchId(null)} />
      )}
    </div>
  )
}

function PublishedDrawTree({ matches, currentPlayerId, returnPath, tournamentName, onOpenMatch }: { matches: TournamentDrawMatch[]; currentPlayerId: string | null; returnPath: string; tournamentName: string; onOpenMatch: (matchId: string) => void }) {
  const firstRound = matches.filter((match) => match.round_number === 1)
  const first = firstRound[0]
  const bracketSize = first?.bracket_size ?? 0
  const rounds = mainDrawRounds(bracketSize)
  const matchByRound = new Map(matches.map((match) => [`${match.round_number}:${match.match_number}`, match]))
  const entrantIds = new Set<string>()
  firstRound.forEach((match) => {
    if (match.player1_id) entrantIds.add(match.player1_id)
    if (match.player2_id) entrantIds.add(match.player2_id)
  })
  if (rounds.length === 0) return null

  const width = rounds.length * BRACKET_MATCH_WIDTH + (rounds.length - 1) * BRACKET_COLUMN_GAP
  const height = Math.max(BRACKET_MATCH_HEIGHT, (rounds[0].matches - 1) * BRACKET_STEP + BRACKET_MATCH_HEIGHT)

  return (
    <section className="tlg-detail-panel tlg-live-draw-panel">
      <header className="tlg-detail-panel-head tlg-live-draw-head">
        <div><span>Tournament draw</span><h2>Knockout bracket</h2><p>{entrantIds.size} entered players · Season Week {first?.scheduled_season_week} · First-round match day {first?.scheduled_day}</p></div>
        <strong className="tlg-live-draw-status">Draw published</strong>
      </header>

      <div className="tlg-detail-bracket-scroll tlg-live-bracket-scroll">
        <div className="tlg-detail-bracket-headings" style={{ width }}>
          {rounds.map((round, roundIndex) => <header key={`${round.label}-${round.matches}`} style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP), width: BRACKET_MATCH_WIDTH }}><strong>{round.label}</strong><span>{round.matches} {round.matches === 1 ? 'match' : 'matches'}</span></header>)}
        </div>

        <div className="tlg-detail-bracket-tree" style={{ width, height }}>
          <svg className="tlg-detail-bracket-connectors" width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
            {rounds.slice(0, -1).map((_, roundIndex) => {
              const boundaryX = (roundIndex + 1) * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) - BRACKET_COLUMN_GAP / 2
              return <line key={`round-separator-${roundIndex}`} x1={boundaryX} x2={boundaryX} y1={0} y2={height} stroke="#0b6fc8" strokeWidth="1.4" opacity="0.72" vectorEffect="non-scaling-stroke" />
            })}
            {rounds.slice(0, -1).flatMap((_, roundIndex) => {
              const parentRound = rounds[roundIndex + 1]
              const startX = roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) + BRACKET_MATCH_WIDTH
              const middleX = startX + BRACKET_COLUMN_GAP / 2
              const endX = (roundIndex + 1) * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP)
              return Array.from({ length: parentRound.matches }, (_, parentIndex) => {
                const firstY = bracketMatchCenter(roundIndex, parentIndex * 2)
                const secondY = bracketMatchCenter(roundIndex, parentIndex * 2 + 1)
                const parentY = bracketMatchCenter(roundIndex + 1, parentIndex)
                return <path key={`connector-${roundIndex}-${parentIndex}`} d={`M ${startX} ${firstY} H ${middleX} M ${startX} ${secondY} H ${middleX} M ${middleX} ${firstY} V ${secondY} M ${middleX} ${parentY} H ${endX}`} />
              })
            })}
          </svg>

          {rounds.map((round, roundIndex) => (
            <section key={`${round.label}-${round.matches}`} className="tlg-detail-bracket-round" style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP), width: BRACKET_MATCH_WIDTH }}>
              {Array.from({ length: round.matches }, (_, matchIndex) => {
                const top = bracketMatchCenter(roundIndex, matchIndex) - BRACKET_MATCH_HEIGHT / 2
                const match = matchByRound.get(`${round.roundNumber}:${matchIndex + 1}`)
                const ownMatch = Boolean(currentPlayerId && match && (match.player1_id === currentPlayerId || match.player2_id === currentPlayerId))
                return (
                  <div key={`${round.label}-${matchIndex}`} className={`tlg-detail-bracket-match tlg-live-tree-match${ownMatch ? ' own-match' : ''}${match ? ' clickable' : ''}`} style={{ top, width: BRACKET_MATCH_WIDTH, height: BRACKET_MATCH_HEIGHT }} role={match ? 'button' : undefined} tabIndex={match ? 0 : undefined} onClick={match ? () => onOpenMatch(match.match_id) : undefined} onKeyDown={match ? (event) => { if (event.key === 'Enter' || event.key === ' ') onOpenMatch(match.match_id) } : undefined}>
                    <BracketPlayer matchExists={Boolean(match)} playerId={match?.player1_id ?? null} firstName={match?.player1_first_name ?? null} lastName={match?.player1_last_name ?? null} countryCode={match?.player1_country_code ?? null} seed={match?.player1_seed ?? null} scores={match?.player1_set_scores ?? []} winner={Boolean(match?.winner_id && match.winner_id === match.player1_id)} returnPath={returnPath} tournamentName={tournamentName} />
                    <BracketPlayer matchExists={Boolean(match)} playerId={match?.player2_id ?? null} firstName={match?.player2_first_name ?? null} lastName={match?.player2_last_name ?? null} countryCode={match?.player2_country_code ?? null} seed={match?.player2_seed ?? null} scores={match?.player2_set_scores ?? []} winner={Boolean(match?.winner_id && match.winner_id === match.player2_id)} returnPath={returnPath} tournamentName={tournamentName} />
                  </div>
                )
              })}
            </section>
          ))}
        </div>
      </div>
    </section>
  )
}

function BracketPlayer({ matchExists, playerId, firstName, lastName, countryCode, seed, scores, winner, returnPath, tournamentName }: { matchExists: boolean; playerId: string | null; firstName: string | null; lastName: string | null; countryCode: string | null; seed: number | null; scores: number[]; winner: boolean; returnPath: string; tournamentName: string }) {
  if (!matchExists) return <div className="tlg-live-tree-player"><span className="flag-slot" /><strong className="player-name">TBD</strong><span className="seed-slot" /><span className="score-slot">—</span></div>
  if (!playerId) return <div className="tlg-live-tree-player tlg-live-tree-bye"><span className="flag-slot" /><strong className="player-name">BYE</strong><span className="seed-slot" /><span className="score-slot">—</span></div>
  const name = `${firstName ?? ''} ${lastName ?? ''}`.trim() || 'Player'
  return (
    <div className={`tlg-live-tree-player${winner ? ' tlg-live-tree-winner' : ''}`}>
      <span className="flag-slot"><CountryFlag countryCode={countryCode ?? ''} countryName={countryCode ?? ''} width={19} height={13} /></span>
      <Link className="player-name" to={`/game/players/${playerId}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: `Back to ${tournamentName}` }} onClick={(event) => event.stopPropagation()}>{name}</Link>
      <span className="seed-slot">{seed ? <strong>{seed}</strong> : null}</span>
      <span className="score-slot">{scores.length > 0 ? scores.join(' ') : '—'}</span>
    </div>
  )
}

function MatchDetailModal({ detail, drawMatches, loading, error, currentPlayerId, returnPath, tournamentName, onClose }: { detail: MatchDetail | null; drawMatches: TournamentDrawMatch[]; loading: boolean; error: string | null; currentPlayerId: string | null; returnPath: string; tournamentName: string; onClose: () => void }) {
  return createPortal(
    <div className="tlg-match-modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose() }}>
      <section className="tlg-match-modal" role="dialog" aria-modal="true" aria-label="Tournament match details">
        <button type="button" className="tlg-match-modal-close" onClick={onClose} aria-label="Close match details">×</button>
        {loading ? <div className="tlg-match-modal-state">Loading match…</div> : error || !detail ? <div className="tlg-match-modal-state">{error ?? 'Match details are unavailable.'}</div> : <MatchDetailContent detail={detail} drawMatches={drawMatches} currentPlayerId={currentPlayerId} returnPath={returnPath} tournamentName={tournamentName} />}
      </section>
    </div>,
    document.body,
  )
}

function MatchDetailContent({ detail, drawMatches, currentPlayerId, returnPath, tournamentName }: { detail: MatchDetail; drawMatches: TournamentDrawMatch[]; currentPlayerId: string | null; returnPath: string; tournamentName: string }) {
  const p1Avatar = usePlayerAvatarUrl(detail.player1?.image_path)
  const p2Avatar = usePlayerAvatarUrl(detail.player2?.image_path)
  const hasStats = Object.keys(detail.player1_stats ?? {}).length > 0 || Object.keys(detail.player2_stats ?? {}).length > 0
  const isScheduledPreview = detail.status === 'scheduled' && detail.sets.length === 0

  return (
    <>
      <header className="tlg-match-modal-head"><div><span>{detail.tournament_name} · Season Week {detail.scheduled_season_week}</span><h2>{detail.round_label} · Match {detail.match_number}</h2><p>{detail.city}, {detail.country_code} · Day {detail.scheduled_day}</p></div><strong className={`match-status status-${detail.status}`}>{statusLabel(detail.status)}</strong></header>

      <div className="tlg-match-versus">
        <MatchPlayerCard player={detail.player1} avatarUrl={p1Avatar} winner={detail.winner_id === detail.player1?.id} returnPath={returnPath} tournamentName={tournamentName} />
        <div className="tlg-match-versus-center"><strong>VS</strong><span>{detail.status === 'completed' ? 'Final result' : detail.status === 'in_progress' ? 'Match in progress' : 'Upcoming match'}</span></div>
        <MatchPlayerCard player={detail.player2} avatarUrl={p2Avatar} winner={detail.winner_id === detail.player2?.id} returnPath={returnPath} tournamentName={tournamentName} />
      </div>

      {isScheduledPreview ? (
        <PreMatchInsights detail={detail} drawMatches={drawMatches} />
      ) : (
        <>
          <section className="tlg-match-score-section"><header><span>Score</span><h3>Set-by-set result</h3></header>{detail.sets.length === 0 ? <div className="tlg-match-empty">Set scores will appear here as play begins.</div> : <div className="tlg-match-score-table"><div className="head"><span>Player</span>{detail.sets.map((set) => <strong key={set.set_number}>Set {set.set_number}</strong>)}</div><ScoreRow player={detail.player1} sets={detail.sets.map((set) => set.player1_games)} winner={detail.winner_id === detail.player1?.id} /><ScoreRow player={detail.player2} sets={detail.sets.map((set) => set.player2_games)} winner={detail.winner_id === detail.player2?.id} /></div>}</section>

          <section className="tlg-match-stats-section"><header><span>Match statistics</span><h3>{detail.status === 'in_progress' ? 'Live statistics' : 'Match statistics'}</h3></header>{!hasStats ? <div className="tlg-match-empty">Statistics will appear here when the match engine begins recording points.</div> : <div className="tlg-match-stats-table"><StatRow label="Aces" left={detail.player1_stats.aces ?? 0} right={detail.player2_stats.aces ?? 0} /><StatRow label="Double faults" left={detail.player1_stats.double_faults ?? 0} right={detail.player2_stats.double_faults ?? 0} /><StatRow label="First serve %" left={percent(detail.player1_stats.first_serves_in, detail.player1_stats.first_serves_total)} right={percent(detail.player2_stats.first_serves_in, detail.player2_stats.first_serves_total)} /><StatRow label="1st serve points won" left={ratio(detail.player1_stats.first_serve_points_won, detail.player1_stats.first_serve_points_played)} right={ratio(detail.player2_stats.first_serve_points_won, detail.player2_stats.first_serve_points_played)} /><StatRow label="2nd serve points won" left={ratio(detail.player1_stats.second_serve_points_won, detail.player1_stats.second_serve_points_played)} right={ratio(detail.player2_stats.second_serve_points_won, detail.player2_stats.second_serve_points_played)} /><StatRow label="Break points won" left={ratio(detail.player1_stats.break_points_won, detail.player1_stats.break_points_total)} right={ratio(detail.player2_stats.break_points_won, detail.player2_stats.break_points_total)} /><StatRow label="Winners" left={detail.player1_stats.winners ?? 0} right={detail.player2_stats.winners ?? 0} /><StatRow label="Unforced errors" left={detail.player1_stats.unforced_errors ?? 0} right={detail.player2_stats.unforced_errors ?? 0} /><StatRow label="Total points won" left={detail.player1_stats.total_points_won ?? 0} right={detail.player2_stats.total_points_won ?? 0} /></div>}</section>
        </>
      )}

      <MatchTacticPanel detail={detail} currentPlayerId={currentPlayerId} />
    </>
  )
}

function PreMatchInsights({ detail, drawMatches }: { detail: MatchDetail; drawMatches: TournamentDrawMatch[] }) {
  const current = drawMatches.find((match) => match.match_id === detail.match_id)
  const currentRound = current?.round_number ?? Number.MAX_SAFE_INTEGER
  return (
    <section className="tlg-prematch-insights">
      <div className="tlg-prematch-panel">
        <header><div><span>This tournament</span><h3>Road to this match</h3></div><small>Actual Palm Springs results</small></header>
        <div className="tlg-prematch-form-grid">
          <TournamentPlayerForm player={detail.player1} drawMatches={drawMatches} beforeRound={currentRound} />
          <TournamentPlayerForm player={detail.player2} drawMatches={drawMatches} beforeRound={currentRound} />
        </div>
      </div>

      <div className="tlg-prematch-panel">
        <header><div><span>Head to head</span><h3>Previous meetings</h3></div><small className="mock-badge">Preview / test history</small></header>
        <MockHeadToHead player1={detail.player1} player2={detail.player2} />
      </div>
    </section>
  )
}

function TournamentPlayerForm({ player, drawMatches, beforeRound }: { player: MatchPlayerDetail | null; drawMatches: TournamentDrawMatch[]; beforeRound: number }) {
  if (!player) return <div className="tlg-prematch-form-card"><strong>BYE</strong></div>
  const matches = drawMatches
    .filter((match) => match.round_number < beforeRound && match.match_status === 'completed' && match.winner_id === player.id && (match.player1_id === player.id || match.player2_id === player.id))
    .sort((a, b) => b.round_number - a.round_number)
  const latest = matches[0]
  const playerWasOne = latest?.player1_id === player.id
  const opponent = latest ? drawPlayerName(latest, playerWasOne ? 2 : 1) : null
  return (
    <div className="tlg-prematch-form-card">
      <div className="identity"><CountryFlag countryCode={player.country_code} countryName={player.country_code} width={24} height={16} /><strong>{playerName(player)}</strong></div>
      {latest ? <><span>{latest.round_label}</span><p>Defeated <b>{opponent}</b></p><small>{formatDrawScore(latest, player.id)}</small></> : <><span>Tournament debut</span><p>First match at this event.</p><small>No previous-round result</small></>}
    </div>
  )
}

function MockHeadToHead({ player1, player2 }: { player1: MatchPlayerDetail | null; player2: MatchPlayerDetail | null }) {
  if (!player1 || !player2) return <div className="tlg-match-empty">Head-to-head unavailable.</div>
  const p1 = playerName(player1)
  const p2 = playerName(player2)
  const rows = [
    { event: 'Vienna Challenger', season: '2025', round: 'Quarterfinal', winner: p1, loser: p2, score: '6–4, 7–6' },
    { event: 'Prague Challenger', season: '2025', round: 'Round of 16', winner: p2, loser: p1, score: '6–3, 4–6, 6–2' },
    { event: 'Belgrade Challenger', season: '2024', round: 'Round of 32', winner: p1, loser: p2, score: '7–5, 6–4' },
  ]
  return (
    <div className="tlg-h2h-wrap">
      <div className="tlg-h2h-score"><div><CountryFlag countryCode={player1.country_code} countryName={player1.country_code} width={22} height={15} /><strong>{p1}</strong><b>2</b></div><span>H2H</span><div><b>1</b><strong>{p2}</strong><CountryFlag countryCode={player2.country_code} countryName={player2.country_code} width={22} height={15} /></div></div>
      <div className="tlg-h2h-list">{rows.map((row) => <div key={`${row.season}-${row.event}`}><span>{row.season} · {row.event} · {row.round}</span><strong>{row.winner} def. {row.loser}</strong><b>{row.score}</b></div>)}</div>
    </div>
  )
}

function MatchTacticPanel({ detail, currentPlayerId }: { detail: MatchDetail; currentPlayerId: string | null }) {
  const isOwnMatch = Boolean(currentPlayerId && (detail.player1?.id === currentPlayerId || detail.player2?.id === currentPlayerId))
  const [data, setData] = useState<MatchTacticResponse | null>(null)
  const [draft, setDraft] = useState<TournamentTactic>({ ...BALANCED_TACTIC })
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [showHelp, setShowHelp] = useState(false)

  const load = useCallback(async () => {
    if (!isOwnMatch || !currentPlayerId) return
    setLoading(true)
    setMessage(null)
    const { data: tacticData, error } = await supabase.rpc('get_tournament_match_tactic_v1', { p_player_id: currentPlayerId, p_match_id: detail.match_id })
    setLoading(false)
    if (error || !tacticData) {
      setMessage(error?.message ?? 'Unable to load match tactic.')
      return
    }
    const next = tacticData as MatchTacticResponse
    setData(next)
    setDraft(next.override ?? next.effective ?? { ...BALANCED_TACTIC })
  }, [currentPlayerId, detail.match_id, isOwnMatch])

  useEffect(() => { void load() }, [load])

  if (!isOwnMatch) return null

  async function saveOverride() {
    if (!currentPlayerId) return
    setSaving(true)
    setMessage(null)
    const { data: tacticData, error } = await supabase.rpc('save_tournament_match_tactic_v1', {
      p_player_id: currentPlayerId,
      p_match_id: detail.match_id,
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
      setMessage(error?.message ?? 'Unable to save match tactic.')
      return
    }
    const next = tacticData as MatchTacticResponse
    setData(next)
    setDraft(next.effective)
    setMessage('Match-specific tactic saved.')
  }

  async function useTournamentDefault() {
    if (!currentPlayerId) return
    setSaving(true)
    setMessage(null)
    const { data: tacticData, error } = await supabase.rpc('clear_tournament_match_tactic_v1', { p_player_id: currentPlayerId, p_match_id: detail.match_id })
    setSaving(false)
    if (error || !tacticData) {
      setMessage(error?.message ?? 'Unable to restore tournament default.')
      return
    }
    const next = tacticData as MatchTacticResponse
    setData(next)
    setDraft(next.effective)
    setMessage('Tournament default will be used for this match.')
  }

  const sourceLabel = data?.source === 'match_override' ? 'Match override' : data?.source === 'tournament_default' ? 'Tournament default' : 'Automatic Balanced default'
  const effective = data?.effective ?? draft
  const editable = Boolean(data?.editable)
  const lockDeadline = formatGameDeadline(data?.tactic_lock_game_date ?? null, data?.tactic_lock_minute_of_day ?? null)
  const tacticStatusLabel = data?.source === 'match_override' ? 'Match tactic override saved' : 'Tactic unchanged for this match'

  return (
    <section className="tlg-match-tactic-section">
      <div className="tlg-match-tactic-head">
        <div><span>Match tactic</span><h3>Plan for this opponent</h3><p>Your tournament default is always available. Saving an override here changes only this match and leaves the rest of the tournament unchanged.</p></div>
        <div className="tlg-match-tactic-head-tools"><button type="button" className={`tlg-tactic-guidance-toggle${showHelp ? ' active' : ''}`} aria-expanded={showHelp} onClick={() => setShowHelp((current) => !current)}>{showHelp ? 'Hide guidance' : 'Show guidance'}</button><div className="tlg-match-tactic-source"><span>Currently active</span><strong>{sourceLabel}</strong></div></div>
      </div>

      {data && <div className={`tlg-match-tactic-deadline-row${editable ? ' editable' : ' locked'}`}>
        <div className="tlg-match-tactic-deadline-copy"><span>{editable ? 'Tactic can be changed until' : 'Tactic locked at'}</span><strong>{lockDeadline}</strong><small>{data.lock_minutes_before_start} minutes before the scheduled match start</small></div>
        <div className="tlg-match-tactic-change-status"><span>Match-specific status</span><strong>{tacticStatusLabel}</strong></div>
      </div>}

      {loading ? <div className="tlg-match-tactic-loading">Loading tactical plan…</div> : !data ? <div className="tlg-match-tactic-loading">{message ?? 'Tactical plan unavailable.'}</div> : !editable ? (
        <><div className="tlg-match-tactic-locked">This match is no longer editable. The effective tactic used for the match is shown below.</div><TacticSummary tactic={effective} />{showHelp && <div className="tlg-tactic-guidance"><TacticHelp tactic={effective} /><TacticEffects tactic={effective} locked /></div>}</>
      ) : (
        <>
          <div className="tlg-match-tactic-presets">{TACTIC_PRESETS.map((preset) => <button key={preset} type="button" className={draft.preset === preset ? 'selected' : ''} onClick={() => setDraft(tacticFromPreset(preset))}>{preset}</button>)}</div>
          <div className="tlg-match-tactic-grid">
            <TacticSelect label="Overall approach" value={draft.approach} values={TACTIC_OPTIONS.approach} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', approach: value }))} />
            <TacticSelect label="Rally strategy" value={draft.rally} values={TACTIC_OPTIONS.rally} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', rally: value }))} />
            <TacticSelect label="Serve strategy" value={draft.serve} values={TACTIC_OPTIONS.serve} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', serve: value }))} />
            <TacticSelect label="Return strategy" value={draft.returnGame} values={TACTIC_OPTIONS.returnGame} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', returnGame: value }))} />
            <TacticSelect label="Court position" value={draft.courtPosition} values={TACTIC_OPTIONS.courtPosition} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', courtPosition: value }))} />
            <TacticSelect label="Opponent target" value={draft.target} values={TACTIC_OPTIONS.target} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', target: value }))} />
            <TacticSelect label="Risk level" value={draft.risk} values={TACTIC_OPTIONS.risk} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', risk: value }))} />
          </div>
          {showHelp && <div className="tlg-tactic-guidance"><TacticHelp tactic={draft} /><TacticEffects tactic={draft} /></div>}
          <div className="tlg-match-tactic-actions"><span className="tlg-match-tactic-message">{message ?? `Tournament default: ${data.tournament_default.preset}`}</span><div className="tlg-match-tactic-buttons"><button type="button" onClick={useTournamentDefault} disabled={saving || data.source !== 'match_override'}>Use Tournament Default</button><button type="button" className="primary" onClick={saveOverride} disabled={saving}>{saving ? 'Saving…' : 'Save Match Tactic'}</button></div></div>
        </>
      )}
    </section>
  )
}

function TacticHelp({ tactic }: { tactic: TournamentTactic }) {
  const rows = [
    ['Overall approach', tactic.approach, tactic.approach === 'Aggressive' ? 'Pushes the player to take initiative earlier and attempt more attacking shots, with more error exposure.' : tactic.approach === 'Defensive' ? 'Prioritises court coverage, patience and safer shot selection over early winners.' : 'Keeps attacking and defensive decisions close to the player’s normal tendencies.'],
    ['Rally strategy', tactic.rally, tactic.rally === 'Shorten points' ? 'Looks to end rallies earlier; useful for first-strike tennis but raises shot-selection pressure.' : tactic.rally === 'Extend rallies' ? 'Accepts longer exchanges to test movement, consistency and stamina.' : 'No deliberate change to normal rally length.'],
    ['Serve strategy', tactic.serve, tactic.serve === 'Power serving' ? 'Adds first-serve pressure and ace potential, but increases serve risk.' : tactic.serve === 'Serve + 1' ? 'Builds points around a strong serve followed by an immediate attacking first groundstroke.' : tactic.serve === 'Safe first serve' ? 'Reduces serve risk and double-fault pressure at the expense of free points.' : 'Uses the player’s normal serve balance.'],
    ['Return strategy', tactic.returnGame, tactic.returnGame === 'Aggressive return' ? 'Takes more risk on returns to seize control immediately.' : tactic.returnGame === 'Attack second serve' ? 'Keeps normal first-serve returns but steps in hard against second serves.' : tactic.returnGame === 'Safe return' ? 'Prioritises putting the ball in play and starting neutral rallies.' : 'Uses the player’s normal return balance.'],
    ['Court position', tactic.courtPosition, tactic.courtPosition === 'Net attack' ? 'Looks for frequent forward movement and finishing opportunities at net.' : tactic.courtPosition === 'Inside baseline' ? 'Takes time away from the opponent but leaves less reaction time.' : tactic.courtPosition === 'Deep baseline' ? 'Creates more reaction time and defensive coverage while conceding court position.' : 'Uses a normal baseline position.'],
    ['Opponent target', tactic.target, tactic.target === 'Automatic' ? 'No specific weakness is forced; the player reacts naturally to the match.' : `Directs a larger share of tactical pressure toward the opponent’s ${tactic.target.toLowerCase()}.`],
    ['Risk level', tactic.risk, tactic.risk === 'Aggressive' ? 'Raises winner attempts and attacking intent, but also raises unforced-error and fatigue risk.' : tactic.risk === 'Safe' ? 'Reduces low-percentage choices and errors, while limiting peak attacking pressure.' : 'Keeps risk close to the player’s normal level.'],
  ] as const
  return <div className="tlg-tactic-help"><header><strong>How these settings change the match plan</strong><span>Planning guide</span></header><div>{rows.map(([label, value, copy]) => <article key={label}><span>{label}</span><strong>{value}</strong><p>{copy}</p></article>)}</div></div>
}

function calculateTacticEffects(tactic: TournamentTactic): TacticEffect[] {
  let attack = 0
  let winnerPressure = 0
  let errorRisk = 0
  let rallyLength = 0
  let servePressure = 0
  let returnPressure = 0
  let fatigue = 0

  if (tactic.approach === 'Aggressive') { attack += 14; winnerPressure += 10; errorRisk += 7; fatigue += 3 }
  if (tactic.approach === 'Defensive') { attack -= 8; errorRisk -= 6; rallyLength += 8; fatigue += 2 }
  if (tactic.rally === 'Shorten points') { attack += 5; winnerPressure += 5; rallyLength -= 14; errorRisk += 3; fatigue -= 2 }
  if (tactic.rally === 'Extend rallies') { attack -= 3; rallyLength += 14; errorRisk -= 2; fatigue += 8 }
  if (tactic.serve === 'Power serving') { servePressure += 14; winnerPressure += 5; errorRisk += 5; fatigue += 2 }
  if (tactic.serve === 'Serve + 1') { servePressure += 10; attack += 8; winnerPressure += 7; errorRisk += 3 }
  if (tactic.serve === 'Safe first serve') { servePressure -= 7; errorRisk -= 5 }
  if (tactic.returnGame === 'Aggressive return') { returnPressure += 12; attack += 5; errorRisk += 5 }
  if (tactic.returnGame === 'Attack second serve') { returnPressure += 10; attack += 4; errorRisk += 2 }
  if (tactic.returnGame === 'Safe return') { returnPressure -= 6; errorRisk -= 4; rallyLength += 3 }
  if (tactic.courtPosition === 'Inside baseline') { attack += 8; winnerPressure += 5; errorRisk += 3 }
  if (tactic.courtPosition === 'Net attack') { attack += 12; winnerPressure += 10; rallyLength -= 7; errorRisk += 6; fatigue += 3 }
  if (tactic.courtPosition === 'Deep baseline') { attack -= 5; rallyLength += 7; errorRisk -= 2; fatigue += 2 }
  if (tactic.risk === 'Aggressive') { attack += 10; winnerPressure += 10; errorRisk += 12; fatigue += 4 }
  if (tactic.risk === 'Safe') { attack -= 6; winnerPressure -= 5; errorRisk -= 9; rallyLength += 4; fatigue -= 2 }

  const effect = (label: string, value: number, positiveMeaning: boolean, copy: string): TacticEffect => ({ label, value, text: copy, tone: value === 0 ? 'neutral' : positiveMeaning ? (value > 0 ? 'positive' : 'neutral') : (value > 0 ? 'warning' : 'positive') })
  return [
    effect('Attack intent', attack, true, attack > 7 ? 'Player will look to take control earlier in points.' : attack < -4 ? 'Player will wait longer before committing to attack.' : 'Close to the player’s normal attacking level.'),
    effect('Winner pressure', winnerPressure, true, winnerPressure > 6 ? 'More attempts to finish points with decisive shots.' : winnerPressure < -3 ? 'Fewer low-percentage finishing attempts.' : 'Normal winner-selection pressure.'),
    effect('Unforced-error risk', errorRisk, false, errorRisk > 5 ? 'Higher tactical error exposure from more demanding choices.' : errorRisk < -4 ? 'Safer shot selection should reduce tactical errors.' : 'No major tactical change to error exposure.'),
    effect('Rally length', rallyLength, false, rallyLength > 6 ? 'Plan favours longer exchanges and physical pressure.' : rallyLength < -6 ? 'Plan actively tries to shorten exchanges.' : 'Normal rally-length profile.'),
    effect('Serve pressure', servePressure, true, servePressure > 5 ? 'Serve is used more aggressively to create free points or first-strike chances.' : servePressure < -4 ? 'Serve reliability is prioritised over pressure.' : 'Normal serve balance.'),
    effect('Return pressure', returnPressure, true, returnPressure > 5 ? 'Returns are used to attack the opponent’s service games earlier.' : returnPressure < -4 ? 'Return consistency is prioritised.' : 'Normal return pressure.'),
    effect('Fatigue load', fatigue, false, fatigue > 5 ? 'This plan is likely to demand more physical effort.' : fatigue < -3 ? 'The plan should reduce tactical energy demand.' : 'No major tactical fatigue change.'),
    { label: 'Opponent focus', value: null, text: tactic.target === 'Automatic' ? 'No forced target — adapt naturally during the match.' : `Extra tactical attention on the opponent’s ${tactic.target.toLowerCase()}.`, tone: 'neutral' },
  ]
}

function TacticEffects({ tactic, locked = false }: { tactic: TournamentTactic; locked?: boolean }) {
  const effects = calculateTacticEffects(tactic)
  return (
    <div className="tlg-tactic-effects">
      <header><div><span>{locked ? 'Tactical outcome' : 'Projected match effects'}</span><h4>{locked ? 'Effective plan for this match' : 'What your selections are asking the player to do'}</h4></div><small>Planning preview</small></header>
      <div className="tlg-tactic-effects-grid">{effects.map((item) => <article key={item.label} className={item.tone}><div><span>{item.label}</span>{item.value !== null && <strong>{item.value > 0 ? '+' : ''}{item.value}%</strong>}</div><p>{item.text}</p></article>)}</div>
      <p className="tlg-tactic-effects-note">These numbers are a tactical preview of the intended modifiers. Final match performance also depends on player skills, surface, fatigue, opponent quality and the match engine.</p>
    </div>
  )
}

function TacticSummary({ tactic }: { tactic: TournamentTactic }) {
  return <div className="tlg-match-tactic-effective"><div><span>Preset</span><strong>{tactic.preset}</strong></div><div><span>Approach</span><strong>{tactic.approach}</strong></div><div><span>Serve</span><strong>{tactic.serve}</strong></div><div><span>Return</span><strong>{tactic.returnGame}</strong></div><div><span>Rallies</span><strong>{tactic.rally}</strong></div><div><span>Position</span><strong>{tactic.courtPosition}</strong></div><div><span>Target</span><strong>{tactic.target}</strong></div><div><span>Risk</span><strong>{tactic.risk}</strong></div></div>
}

function TacticSelect({ label, value, values, onChange }: { label: string; value: string; values: readonly string[]; onChange: (value: string) => void }) {
  return <label className="tlg-match-tactic-field"><span>{label}</span><select value={value} onChange={(event) => onChange(event.target.value)}>{values.map((option) => <option key={option} value={option}>{option}</option>)}</select></label>
}

function MatchPlayerCard({ player, avatarUrl, winner, returnPath, tournamentName }: { player: MatchPlayerDetail | null; avatarUrl: string | null; winner: boolean; returnPath: string; tournamentName: string }) {
  if (!player) return <div className="tlg-match-player-card empty"><strong>BYE</strong></div>
  const name = playerName(player)
  return (
    <article className={`tlg-match-player-card tlg-match-player-card-polished${winner ? ' winner' : ''}`}>
      <div className={`tlg-match-player-portrait-stage${avatarUrl ? ' has-image' : ''}`}>{avatarUrl ? <img src={avatarUrl} alt={`${name} portrait`} /> : <span>{player.first_name[0]}{player.last_name[0]}</span>}</div>
      <div className="tlg-match-player-summary">
        <div className="identity"><CountryFlag countryCode={player.country_code} countryName={player.country_code} width={29} height={19} /><Link to={`/game/players/${player.id}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: `Back to ${tournamentName}` }}>{name}</Link></div>
        <div className="meta"><span>{player.ranking_position ? `World #${player.ranking_position}` : 'Unranked'}</span>{player.seed ? <strong>Seed #{player.seed}</strong> : <strong className="unseeded">Unseeded</strong>}</div>
      </div>
    </article>
  )
}

function ScoreRow({ player, sets, winner }: { player: MatchPlayerDetail | null; sets: number[]; winner: boolean }) {
  return <div className={winner ? 'winner' : ''}><span>{playerName(player)}</span>{sets.map((score, index) => <strong key={index}>{score}</strong>)}</div>
}

function StatRow({ label, left, right }: { label: string; left: string | number; right: string | number }) {
  return <div><strong>{left}</strong><span>{label}</span><strong>{right}</strong></div>
}

function percent(value?: number, total?: number) {
  if (!total) return '0%'
  return `${Math.round(((value ?? 0) / total) * 100)}%`
}

function ratio(value?: number, total?: number) {
  return `${value ?? 0}/${total ?? 0}`
}
