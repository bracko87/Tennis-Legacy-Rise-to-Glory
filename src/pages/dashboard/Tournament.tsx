import { createPortal } from 'react-dom'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useLocation, useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-logo.css'
import '../../styles/tournament-live-draw.css'
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
    const label = participants === 2
      ? 'Final'
      : participants === 4
        ? 'Semifinal'
        : participants === 8
          ? 'Quarterfinal'
          : `Round of ${participants}`
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
  const contextClassName = [
    logoStatus === 'ready' ? 'tlg-tournament-logo-context' : '',
    hasPublishedDraw ? 'tlg-tournament-real-draw-context' : '',
  ].filter(Boolean).join(' ') || undefined

  return (
    <div className={contextClassName}>
      <TournamentPageV3 />

      {showRealLogo && logoTarget && logoUrl && createPortal(
        <img
          className={`tlg-tournament-logo-image ${logoStatus === 'ready' ? 'tlg-tournament-logo-image-ready' : ''}`}
          src={logoUrl}
          alt={`${tournamentName} tournament logo`}
          decoding="async"
          fetchPriority="high"
          onLoad={() => setLogoStatus('ready')}
          onError={() => setLogoStatus('error')}
        />,
        logoTarget,
      )}

      {hasPublishedDraw && pageTarget && createPortal(
        <PublishedDrawTree
          matches={mainDrawMatches}
          currentPlayerId={player?.id ?? null}
          returnPath={returnPath}
          tournamentName={tournamentName}
          onOpenMatch={setSelectedMatchId}
        />,
        pageTarget,
      )}

      {selectedMatchId && (
        <MatchDetailModal
          detail={matchDetail}
          loading={matchLoading}
          error={matchError}
          returnPath={returnPath}
          tournamentName={tournamentName}
          onClose={() => setSelectedMatchId(null)}
        />
      )}
    </div>
  )
}

function PublishedDrawTree({
  matches,
  currentPlayerId,
  returnPath,
  tournamentName,
  onOpenMatch,
}: {
  matches: TournamentDrawMatch[]
  currentPlayerId: string | null
  returnPath: string
  tournamentName: string
  onOpenMatch: (matchId: string) => void
}) {
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
        <div>
          <span>Tournament draw</span>
          <h2>Knockout bracket</h2>
          <p>{entrantIds.size} entered players · Season Week {first?.scheduled_season_week} · First-round match day {first?.scheduled_day}</p>
        </div>
        <strong className="tlg-live-draw-status">Draw published</strong>
      </header>

      <div className="tlg-detail-bracket-scroll tlg-live-bracket-scroll">
        <div className="tlg-detail-bracket-headings" style={{ width }}>
          {rounds.map((round, roundIndex) => (
            <header key={`${round.label}-${round.matches}`} style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP), width: BRACKET_MATCH_WIDTH }}>
              <strong>{round.label}</strong>
              <span>{round.matches} {round.matches === 1 ? 'match' : 'matches'}</span>
            </header>
          ))}
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
                  <div
                    key={`${round.label}-${matchIndex}`}
                    className={`tlg-detail-bracket-match tlg-live-tree-match${ownMatch ? ' own-match' : ''}${match ? ' clickable' : ''}`}
                    style={{ top, width: BRACKET_MATCH_WIDTH, height: BRACKET_MATCH_HEIGHT }}
                    role={match ? 'button' : undefined}
                    tabIndex={match ? 0 : undefined}
                    onClick={match ? () => onOpenMatch(match.match_id) : undefined}
                    onKeyDown={match ? (event) => { if (event.key === 'Enter' || event.key === ' ') onOpenMatch(match.match_id) } : undefined}
                  >
                    <BracketPlayer
                      matchExists={Boolean(match)}
                      playerId={match?.player1_id ?? null}
                      firstName={match?.player1_first_name ?? null}
                      lastName={match?.player1_last_name ?? null}
                      countryCode={match?.player1_country_code ?? null}
                      seed={match?.player1_seed ?? null}
                      scores={match?.player1_set_scores ?? []}
                      winner={Boolean(match?.winner_id && match.winner_id === match.player1_id)}
                      returnPath={returnPath}
                      tournamentName={tournamentName}
                    />
                    <BracketPlayer
                      matchExists={Boolean(match)}
                      playerId={match?.player2_id ?? null}
                      firstName={match?.player2_first_name ?? null}
                      lastName={match?.player2_last_name ?? null}
                      countryCode={match?.player2_country_code ?? null}
                      seed={match?.player2_seed ?? null}
                      scores={match?.player2_set_scores ?? []}
                      winner={Boolean(match?.winner_id && match.winner_id === match.player2_id)}
                      returnPath={returnPath}
                      tournamentName={tournamentName}
                    />
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

function BracketPlayer({
  matchExists,
  playerId,
  firstName,
  lastName,
  countryCode,
  seed,
  scores,
  winner,
  returnPath,
  tournamentName,
}: {
  matchExists: boolean
  playerId: string | null
  firstName: string | null
  lastName: string | null
  countryCode: string | null
  seed: number | null
  scores: number[]
  winner: boolean
  returnPath: string
  tournamentName: string
}) {
  if (!matchExists) {
    return <div className="tlg-live-tree-player"><span className="flag-slot" /><strong className="player-name">TBD</strong><span className="seed-slot" /><span className="score-slot">—</span></div>
  }
  if (!playerId) {
    return <div className="tlg-live-tree-player tlg-live-tree-bye"><span className="flag-slot" /><strong className="player-name">BYE</strong><span className="seed-slot" /><span className="score-slot">—</span></div>
  }

  const name = `${firstName ?? ''} ${lastName ?? ''}`.trim() || 'Player'
  return (
    <div className={`tlg-live-tree-player${winner ? ' tlg-live-tree-winner' : ''}`}>
      <span className="flag-slot"><CountryFlag countryCode={countryCode ?? ''} countryName={countryCode ?? ''} width={19} height={13} /></span>
      <Link
        className="player-name"
        to={`/game/players/${playerId}`}
        state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: `Back to ${tournamentName}` }}
        onClick={(event) => event.stopPropagation()}
      >{name}</Link>
      <span className="seed-slot">{seed ? <strong>{seed}</strong> : null}</span>
      <span className="score-slot">{scores.length > 0 ? scores.join(' ') : '—'}</span>
    </div>
  )
}

function MatchDetailModal({
  detail,
  loading,
  error,
  returnPath,
  tournamentName,
  onClose,
}: {
  detail: MatchDetail | null
  loading: boolean
  error: string | null
  returnPath: string
  tournamentName: string
  onClose: () => void
}) {
  return createPortal(
    <div className="tlg-match-modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose() }}>
      <section className="tlg-match-modal" role="dialog" aria-modal="true" aria-label="Tournament match details">
        <button type="button" className="tlg-match-modal-close" onClick={onClose} aria-label="Close match details">×</button>
        {loading ? (
          <div className="tlg-match-modal-state">Loading match…</div>
        ) : error || !detail ? (
          <div className="tlg-match-modal-state">{error ?? 'Match details are unavailable.'}</div>
        ) : (
          <MatchDetailContent detail={detail} returnPath={returnPath} tournamentName={tournamentName} />
        )}
      </section>
    </div>,
    document.body,
  )
}

function MatchDetailContent({ detail, returnPath, tournamentName }: { detail: MatchDetail; returnPath: string; tournamentName: string }) {
  const p1Avatar = usePlayerAvatarUrl(detail.player1?.image_path)
  const p2Avatar = usePlayerAvatarUrl(detail.player2?.image_path)
  const hasStats = Object.keys(detail.player1_stats ?? {}).length > 0 || Object.keys(detail.player2_stats ?? {}).length > 0

  return (
    <>
      <header className="tlg-match-modal-head">
        <div>
          <span>{detail.tournament_name} · Season Week {detail.scheduled_season_week}</span>
          <h2>{detail.round_label} · Match {detail.match_number}</h2>
          <p>{detail.city}, {detail.country_code} · Day {detail.scheduled_day}</p>
        </div>
        <strong className={`match-status status-${detail.status}`}>{statusLabel(detail.status)}</strong>
      </header>

      <div className="tlg-match-versus">
        <MatchPlayerCard player={detail.player1} avatarUrl={p1Avatar} winner={detail.winner_id === detail.player1?.id} returnPath={returnPath} tournamentName={tournamentName} />
        <div className="tlg-match-versus-center"><strong>VS</strong><span>{detail.status === 'completed' ? 'Final result' : detail.status === 'in_progress' ? 'Match in progress' : 'Upcoming match'}</span></div>
        <MatchPlayerCard player={detail.player2} avatarUrl={p2Avatar} winner={detail.winner_id === detail.player2?.id} returnPath={returnPath} tournamentName={tournamentName} />
      </div>

      <section className="tlg-match-score-section">
        <header><span>Score</span><h3>Set-by-set result</h3></header>
        {detail.sets.length === 0 ? (
          <div className="tlg-match-empty">The match has not started. Set scores will appear here as play begins.</div>
        ) : (
          <div className="tlg-match-score-table">
            <div className="head"><span>Player</span>{detail.sets.map((set) => <strong key={set.set_number}>Set {set.set_number}</strong>)}</div>
            <ScoreRow player={detail.player1} sets={detail.sets.map((set) => set.player1_games)} winner={detail.winner_id === detail.player1?.id} />
            <ScoreRow player={detail.player2} sets={detail.sets.map((set) => set.player2_games)} winner={detail.winner_id === detail.player2?.id} />
          </div>
        )}
      </section>

      <section className="tlg-match-stats-section">
        <header><span>Match statistics</span><h3>{detail.status === 'in_progress' ? 'Live statistics' : 'Match statistics'}</h3></header>
        {!hasStats ? (
          <div className="tlg-match-empty">Statistics will appear here when the match engine begins recording points.</div>
        ) : (
          <div className="tlg-match-stats-table">
            <StatRow label="Aces" left={detail.player1_stats.aces ?? 0} right={detail.player2_stats.aces ?? 0} />
            <StatRow label="Double faults" left={detail.player1_stats.double_faults ?? 0} right={detail.player2_stats.double_faults ?? 0} />
            <StatRow label="First serve %" left={percent(detail.player1_stats.first_serves_in, detail.player1_stats.first_serves_total)} right={percent(detail.player2_stats.first_serves_in, detail.player2_stats.first_serves_total)} />
            <StatRow label="1st serve points won" left={ratio(detail.player1_stats.first_serve_points_won, detail.player1_stats.first_serve_points_played)} right={ratio(detail.player2_stats.first_serve_points_won, detail.player2_stats.first_serve_points_played)} />
            <StatRow label="2nd serve points won" left={ratio(detail.player1_stats.second_serve_points_won, detail.player1_stats.second_serve_points_played)} right={ratio(detail.player2_stats.second_serve_points_won, detail.player2_stats.second_serve_points_played)} />
            <StatRow label="Break points won" left={ratio(detail.player1_stats.break_points_won, detail.player1_stats.break_points_total)} right={ratio(detail.player2_stats.break_points_won, detail.player2_stats.break_points_total)} />
            <StatRow label="Winners" left={detail.player1_stats.winners ?? 0} right={detail.player2_stats.winners ?? 0} />
            <StatRow label="Unforced errors" left={detail.player1_stats.unforced_errors ?? 0} right={detail.player2_stats.unforced_errors ?? 0} />
            <StatRow label="Total points won" left={detail.player1_stats.total_points_won ?? 0} right={detail.player2_stats.total_points_won ?? 0} />
          </div>
        )}
      </section>
    </>
  )
}

function MatchPlayerCard({ player, avatarUrl, winner, returnPath, tournamentName }: { player: MatchPlayerDetail | null; avatarUrl: string | null; winner: boolean; returnPath: string; tournamentName: string }) {
  if (!player) return <div className="tlg-match-player-card empty"><strong>BYE</strong></div>
  const name = `${player.first_name} ${player.last_name}`
  return (
    <article className={`tlg-match-player-card${winner ? ' winner' : ''}`}>
      <div className="portrait">{avatarUrl ? <img src={avatarUrl} alt={`${name} portrait`} /> : <span>{player.first_name[0]}{player.last_name[0]}</span>}</div>
      <CountryFlag countryCode={player.country_code} countryName={player.country_code} width={27} height={18} />
      <Link to={`/game/players/${player.id}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: `Back to ${tournamentName}` }}>{name}</Link>
      <div className="meta"><span>{player.ranking_position ? `World #${player.ranking_position}` : 'Unranked'}</span>{player.seed ? <strong>Seed #{player.seed}</strong> : null}</div>
    </article>
  )
}

function ScoreRow({ player, sets, winner }: { player: MatchPlayerDetail | null; sets: number[]; winner: boolean }) {
  return <div className={winner ? 'winner' : ''}><span>{player ? `${player.first_name} ${player.last_name}` : 'BYE'}</span>{sets.map((score, index) => <strong key={index}>{score}</strong>)}</div>
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
