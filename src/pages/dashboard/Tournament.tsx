import { createPortal } from 'react-dom'
import { useCallback, useEffect, useMemo, useState, type CSSProperties } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link, useLocation, useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import TournamentMatchReplayModal from '../../components/tournament/TournamentMatchReplayModal'
import TournamentReplayWeatherEnhancement from '../../components/tournament/TournamentReplayWeatherEnhancement'
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
  world: 'ATP' | 'WTA'
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
  playing_hand: 'right' | 'left'
  preferred_surface: 'Hard' | 'Clay' | 'Grass' | null
  playing_style: 'Aggressive Baseliner' | 'Defensive Baseliner' | 'All-court' | 'Serve & Volley'
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
  completion_reason: string | null
  winner_id: string | null
  started_at: string | null
  completed_at: string | null
  player1: MatchPlayerDetail | null
  player2: MatchPlayerDetail | null
  sets: MatchSetDetail[]
  player1_stats: MatchStats
  player2_stats: MatchStats
}

interface MatchTacticResponse {
  match_status: MatchDetail['status']
  editable: boolean
  source: 'automatic_default' | 'tournament_default' | 'match_override'
  tournament_default: TournamentTactic
  override: TournamentTactic | null
  effective: TournamentTactic
}

interface MatchScoutingReport {
  available: boolean
  reason?: string
  analyst_rating?: number
  analyst_name?: string
  estimate_margin?: number
  confidence_percent?: number
  report_stage?: 'general' | 'quick' | 'partial' | 'normal' | 'full'
  preparation_hours?: number
  attributes?: Record<string, { min: number; max: number }>
  identified_strength?: string
  identified_weakness?: string
  preferred_surface?: string | null
  playing_style?: string
  playing_hand?: 'right' | 'left'
  tactical_observations?: string[]
  recommendations?: string[]
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
const OPEN_TOURNAMENT_MATCH_EVENT = 'tlg-open-tournament-match'

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

function statusLabel(status: MatchDetail['status'], t: TFunction) {
  if (status === 'in_progress') return t('tournamentPage.match.live')
  if (status === 'completed') return t('tournamentPage.match.final')
  if (status === 'walkover') return t('tournamentPage.match.walkover')
  if (status === 'bye') return t('tournamentPage.match.bye')
  if (status === 'cancelled') return t('tournamentPage.match.cancelled')
  return t('tournamentPage.match.scheduled')
}

function playerName(player: MatchPlayerDetail | null) {
  return player ? `${player.first_name} ${player.last_name}` : 'BYE'
}

function drawPlayerName(match: TournamentDrawMatch, side: 1 | 2) {
  const first = side === 1 ? match.player1_first_name : match.player2_first_name
  const last = side === 1 ? match.player1_last_name : match.player2_last_name
  return `${first ?? ''} ${last ?? ''}`.trim() || 'BYE'
}

function formatDrawScore(match: TournamentDrawMatch, perspectivePlayerId: string, t?: TFunction) {
  const playerIsOne = match.player1_id === perspectivePlayerId
  const own = playerIsOne ? match.player1_set_scores : match.player2_set_scores
  const opponent = playerIsOne ? match.player2_set_scores : match.player1_set_scores
  if (match.match_status === 'walkover') return 'W/O'
  if (!own.length || own.length !== opponent.length) return t ? t('tournamentPage.draw.resultRecorded') : 'Result recorded'
  return own.map((games, index) => `${games}–${opponent[index]}`).join(', ')
}

export default function TournamentPage() {
  const { t } = useTranslation()
  const { competitionId } = useParams()
  const location = useLocation()
  const { player } = useAuth()
  const [logoUrl, setLogoUrl] = useState<string | null>(null)
  const [logoStatus, setLogoStatus] = useState<LogoStatus>('none')
  const [logoTarget, setLogoTarget] = useState<HTMLElement | null>(null)
  const [pageTarget, setPageTarget] = useState<HTMLElement | null>(null)
  const [tournamentName, setTournamentName] = useState(t('tournamentPage.fallbackName'))
  const [tournamentWorld, setTournamentWorld] = useState<'ATP' | 'WTA' | null>(null)
  const [drawMatches, setDrawMatches] = useState<TournamentDrawMatch[]>([])
  const [selectedMatchId, setSelectedMatchId] = useState<string | null>(null)
  const [replayMatchId, setReplayMatchId] = useState<string | null>(null)
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
      setTournamentName(row?.tournament_name ?? t('tournamentPage.fallbackName'))
      setTournamentWorld(row?.world === 'WTA' ? 'WTA' : row?.world === 'ATP' ? 'ATP' : null)
      setLogoStatus(nextLogoUrl ? 'loading' : 'none')
    }
    setDrawMatches(drawResponse.error ? [] : ((drawResponse.data ?? []) as TournamentDrawMatch[]))
  }, [competitionId])

  useEffect(() => {
    if (!competitionId) {
      setLogoUrl(null)
      setLogoStatus('none')
      setTournamentWorld(null)
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
      setMatchError(error?.message ?? t('tournamentPage.match.unavailable'))
    } else {
      setMatchDetail(data as MatchDetail)
    }
    setMatchLoading(false)
  }, [])

  useEffect(() => {
    const openMatch = (event: Event) => {
      const matchId = (event as CustomEvent<{ matchId?: string }>).detail?.matchId
      if (matchId) setSelectedMatchId(matchId)
    }
    window.addEventListener(OPEN_TOURNAMENT_MATCH_EVENT, openMatch)
    return () => window.removeEventListener(OPEN_TOURNAMENT_MATCH_EVENT, openMatch)
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
        <img className={`tlg-tournament-logo-image ${logoStatus === 'ready' ? 'tlg-tournament-logo-image-ready' : ''}`} src={logoUrl} alt={t('tournamentPage.logoAlt', { name: tournamentName })} decoding="async" fetchPriority="high" onLoad={() => setLogoStatus('ready')} onError={() => setLogoStatus('error')} />,
        logoTarget,
      )}

      {hasPublishedDraw && pageTarget && createPortal(
        <PublishedDrawTree matches={mainDrawMatches} currentPlayerId={player?.id ?? null} returnPath={returnPath} tournamentName={tournamentName} onOpenMatch={setSelectedMatchId} />,
        pageTarget,
      )}

      {selectedMatchId && !replayMatchId && (
        <MatchDetailModal detail={matchDetail} drawMatches={drawMatches} loading={matchLoading} error={matchError} currentPlayerId={player?.id ?? null} returnPath={returnPath} tournamentName={tournamentName} tournamentWorld={tournamentWorld} onClose={() => setSelectedMatchId(null)} onReplay={setReplayMatchId} />
      )}
      {replayMatchId && (
        <>
          <TournamentMatchReplayModal matchId={replayMatchId} onClose={() => setReplayMatchId(null)} />
          <TournamentReplayWeatherEnhancement matchId={replayMatchId} />
        </>
      )}
    </div>
  )
}

function PublishedDrawTree({ matches, currentPlayerId, returnPath, tournamentName, onOpenMatch }: { matches: TournamentDrawMatch[]; currentPlayerId: string | null; returnPath: string; tournamentName: string; onOpenMatch: (matchId: string) => void }) {
  const { t } = useTranslation()
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
        <div><span>{t('tournamentPage.draw.kicker')}</span><h2>{t('tournamentPage.draw.title')}</h2><p>{t('tournamentPage.draw.meta', { players: entrantIds.size, week: first?.scheduled_season_week, day: first?.scheduled_day })}</p></div>
        <strong className="tlg-live-draw-status">{t('tournamentPage.draw.published')}</strong>
      </header>

      <div className="tlg-detail-bracket-scroll tlg-live-bracket-scroll">
        <div className="tlg-detail-bracket-headings" style={{ width }}>
          {rounds.map((round, roundIndex) => <header key={`${round.label}-${round.matches}`} style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP), width: BRACKET_MATCH_WIDTH }}><strong>{round.label === 'Final' ? t('tournamentPage.draw.final') : round.label === 'Semifinal' ? t('tournamentPage.draw.semifinal') : round.label === 'Quarterfinal' ? t('tournamentPage.draw.quarterfinal') : t('tournamentPage.draw.roundOf', { count: Number(round.label.replace('Round of ', '')) || round.label })}</strong><span>{t('tournamentPage.draw.matches', { count: round.matches })}</span></header>)}
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
                    <BracketPlayer matchExists={Boolean(match)} matchStatus={match?.match_status ?? null} playerId={match?.player1_id ?? null} firstName={match?.player1_first_name ?? null} lastName={match?.player1_last_name ?? null} countryCode={match?.player1_country_code ?? null} seed={match?.player1_seed ?? null} scores={match?.player1_set_scores ?? []} winner={Boolean(match?.winner_id && match.winner_id === match.player1_id)} returnPath={returnPath} tournamentName={tournamentName} />
                    <BracketPlayer matchExists={Boolean(match)} matchStatus={match?.match_status ?? null} playerId={match?.player2_id ?? null} firstName={match?.player2_first_name ?? null} lastName={match?.player2_last_name ?? null} countryCode={match?.player2_country_code ?? null} seed={match?.player2_seed ?? null} scores={match?.player2_set_scores ?? []} winner={Boolean(match?.winner_id && match.winner_id === match.player2_id)} returnPath={returnPath} tournamentName={tournamentName} />
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

function BracketPlayer({ matchExists, matchStatus, playerId, firstName, lastName, countryCode, seed, scores, winner, returnPath, tournamentName }: { matchExists: boolean; matchStatus: TournamentDrawMatch['match_status'] | null; playerId: string | null; firstName: string | null; lastName: string | null; countryCode: string | null; seed: number | null; scores: number[]; winner: boolean; returnPath: string; tournamentName: string }) {
  const { t } = useTranslation()
  if (!matchExists) return <div className="tlg-live-tree-player"><span className="flag-slot" /><strong className="player-name">{t('tournamentPage.draw.tbd')}</strong><span className="seed-slot" /><span className="score-slot">—</span></div>
  if (!playerId) return <div className="tlg-live-tree-player tlg-live-tree-bye"><span className="flag-slot" /><strong className="player-name">{t('tournamentPage.draw.bye')}</strong><span className="seed-slot" /><span className="score-slot">—</span></div>
  const name = `${firstName ?? ''} ${lastName ?? ''}`.trim() || 'Player'
  const scoreLabel = scores.length > 0 ? scores.join(' ') : matchStatus === 'walkover' && winner ? 'W/O' : '—'
  return (
    <div className={`tlg-live-tree-player${winner ? ' tlg-live-tree-winner' : ''}`}>
      <span className="flag-slot"><CountryFlag countryCode={countryCode ?? ''} countryName={countryCode ?? ''} width={19} height={13} /></span>
      <Link className="player-name" to={`/game/players/${playerId}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: t('tournamentPage.match.backToTournament', { name: tournamentName }) }} onClick={(event) => event.stopPropagation()}>{name}</Link>
      <span className="seed-slot">{seed ? <strong>{seed}</strong> : null}</span>
      <span className="score-slot">{scoreLabel}</span>
    </div>
  )
}

function MatchDetailModal({ detail, drawMatches, loading, error, currentPlayerId, returnPath, tournamentName, tournamentWorld, onClose, onReplay }: { detail: MatchDetail | null; drawMatches: TournamentDrawMatch[]; loading: boolean; error: string | null; currentPlayerId: string | null; returnPath: string; tournamentName: string; tournamentWorld: 'ATP' | 'WTA' | null; onClose: () => void; onReplay: (matchId: string) => void }) {
  const { t } = useTranslation()
  return createPortal(
    <div className="tlg-match-modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose() }}>
      <section className="tlg-match-modal" role="dialog" aria-modal="true" aria-label={t('tournamentPage.match.dialogAria')}>
        <button type="button" className="tlg-match-modal-close" onClick={onClose} aria-label={t('tournamentPage.match.close')}>×</button>
        {loading ? <div className="tlg-match-modal-state">{t('tournamentPage.match.loading')}</div> : error || !detail ? <div className="tlg-match-modal-state">{error ?? t('tournamentPage.match.unavailable')}</div> : <MatchDetailContent detail={detail} drawMatches={drawMatches} currentPlayerId={currentPlayerId} returnPath={returnPath} tournamentName={tournamentName} tournamentWorld={tournamentWorld} onReplay={onReplay} />}
      </section>
    </div>,
    document.body,
  )
}

type WtaPortraitMetrics = {
  headTop: number
  shoulderTop: number
}

type WtaPortraitTransform = {
  size: number
  shift: number
}

const WTA_MATCH_PORTRAIT_FALLBACK_TRANSFORM: Record<string, WtaPortraitTransform> = {
  // Leonie's source portrait sits visibly higher in the shared match crop.
  // Automatic shoulder normalization normally replaces this fallback.
  'c54c7515-fd6b-41ae-8b91-b8b28b4eb60d': { size: 1.04, shift: 0.035 },
}

const DEFAULT_WTA_MATCH_PORTRAIT: WtaPortraitTransform = { size: 1.04, shift: 0 }

function measureWtaPortraitMetrics(image: HTMLImageElement): WtaPortraitMetrics | null {
  try {
    const naturalWidth = image.naturalWidth
    const naturalHeight = image.naturalHeight
    if (!naturalWidth || !naturalHeight) return null

    const sampleWidth = 140
    const sampleHeight = Math.max(100, Math.round(sampleWidth * naturalHeight / naturalWidth))
    const canvas = document.createElement('canvas')
    canvas.width = sampleWidth
    canvas.height = sampleHeight

    const context = canvas.getContext('2d', { willReadFrequently: true })
    if (!context) return null

    context.drawImage(image, 0, 0, sampleWidth, sampleHeight)
    const pixels = context.getImageData(0, 0, sampleWidth, sampleHeight).data

    // Generated player portraits use a near-white studio background. Sampling
    // all four corners makes the detector tolerate slightly off-white exports.
    const cornerPoints = [
      [2, 2],
      [sampleWidth - 3, 2],
      [2, sampleHeight - 3],
      [sampleWidth - 3, sampleHeight - 3],
    ]
    let bgR = 0
    let bgG = 0
    let bgB = 0
    for (const [x, y] of cornerPoints) {
      const offset = (y * sampleWidth + x) * 4
      bgR += pixels[offset]
      bgG += pixels[offset + 1]
      bgB += pixels[offset + 2]
    }
    bgR /= cornerPoints.length
    bgG /= cornerPoints.length
    bgB /= cornerPoints.length

    const xStart = Math.floor(sampleWidth * 0.06)
    const xEnd = Math.ceil(sampleWidth * 0.94)
    const rowCounts = new Array<number>(sampleHeight).fill(0)
    const rowSpans = new Array<number>(sampleHeight).fill(0)

    for (let y = 0; y < sampleHeight; y += 1) {
      let count = 0
      let minX = sampleWidth
      let maxX = -1

      for (let x = xStart; x < xEnd; x += 1) {
        const offset = (y * sampleWidth + x) * 4
        const alpha = pixels[offset + 3]
        if (alpha < 32) continue

        const dr = pixels[offset] - bgR
        const dg = pixels[offset + 1] - bgG
        const db = pixels[offset + 2] - bgB
        const distance = Math.sqrt(dr * dr + dg * dg + db * db)

        if (distance > 30) {
          count += 1
          minX = Math.min(minX, x)
          maxX = Math.max(maxX, x)
        }
      }

      rowCounts[y] = count
      rowSpans[y] = maxX >= minX ? maxX - minX + 1 : 0
    }

    const smooth = (values: number[], radius = 2) => values.map((_, index) => {
      let sum = 0
      let samples = 0
      for (let y = Math.max(0, index - radius); y <= Math.min(values.length - 1, index + radius); y += 1) {
        sum += values[y]
        samples += 1
      }
      return samples ? sum / samples : 0
    })

    const counts = smooth(rowCounts)
    const spans = smooth(rowSpans)
    const headThreshold = Math.max(4, Math.floor((xEnd - xStart) * 0.035))

    let headRow = -1
    let headRun = 0
    for (let y = 0; y < Math.floor(sampleHeight * 0.58); y += 1) {
      if (counts[y] >= headThreshold) {
        headRun += 1
        if (headRun >= 2) {
          headRow = Math.max(0, y - 1)
          break
        }
      } else {
        headRun = 0
      }
    }

    if (headRow < 0) return null

    // The shoulder line is the first sustained lower-body widening. Using both
    // filled-pixel count and horizontal span avoids treating a loose hair strand
    // or ponytail as the shoulder boundary.
    const shoulderSearchStart = Math.max(
      Math.floor(sampleHeight * 0.56),
      headRow + Math.floor(sampleHeight * 0.30),
    )
    const shoulderSearchEnd = Math.floor(sampleHeight * 0.94)
    const lowerCounts = counts.slice(shoulderSearchStart, shoulderSearchEnd + 1)
    const lowerSpans = spans.slice(shoulderSearchStart, shoulderSearchEnd + 1)
    const maxLowerCount = Math.max(...lowerCounts, 1)
    const maxLowerSpan = Math.max(...lowerSpans, 1)
    const shoulderCountThreshold = maxLowerCount * 0.62
    const shoulderSpanThreshold = maxLowerSpan * 0.70

    let shoulderRow = -1
    for (let y = shoulderSearchStart; y <= shoulderSearchEnd - 3; y += 1) {
      let stableRows = 0
      for (let lookAhead = 0; lookAhead < 4; lookAhead += 1) {
        const row = y + lookAhead
        if (counts[row] >= shoulderCountThreshold && spans[row] >= shoulderSpanThreshold) {
          stableRows += 1
        }
      }
      if (stableRows >= 3) {
        shoulderRow = y
        break
      }
    }

    if (shoulderRow < 0) return null

    return {
      headTop: headRow / sampleHeight,
      shoulderTop: shoulderRow / sampleHeight,
    }
  } catch {
    // If canvas pixel reads are unavailable, keep the safe fixed/fallback crop.
  }

  return null
}

function buildWtaPortraitTransform(
  metrics: WtaPortraitMetrics | null,
  playerId: string | undefined,
): WtaPortraitTransform {
  if (!metrics) {
    return playerId
      ? WTA_MATCH_PORTRAIT_FALLBACK_TRANSFORM[playerId] ?? DEFAULT_WTA_MATCH_PORTRAIT
      : DEFAULT_WTA_MATCH_PORTRAIT
  }

  // Keep the WTA crop deliberately conservative. The previous dynamic scale
  // could enlarge portraits too aggressively. We now keep every portrait at
  // the shared 104% crop and only make a small vertical correction so the
  // shoulder line sits consistently near the bottom of the frame.
  const size = 1.04
  const targetShoulderTop = 0.89

  let shift = targetShoulderTop - ((1 - size) / 2 + size * metrics.shoulderTop)

  // Only small corrections are allowed. This preserves the full head and
  // prevents the portrait from being pushed so far that the face is cropped.
  shift = Math.min(0.045, Math.max(-0.02, shift))

  return { size, shift }
}

function MatchDetailContent({ detail, drawMatches, currentPlayerId, returnPath, tournamentName, tournamentWorld, onReplay }: { detail: MatchDetail; drawMatches: TournamentDrawMatch[]; currentPlayerId: string | null; returnPath: string; tournamentName: string; tournamentWorld: 'ATP' | 'WTA' | null; onReplay: (matchId: string) => void }) {
  const { t } = useTranslation()
  const p1Avatar = usePlayerAvatarUrl(detail.player1?.image_path)
  const p2Avatar = usePlayerAvatarUrl(detail.player2?.image_path)
  const [wtaPortraitMetrics, setWtaPortraitMetrics] = useState<[WtaPortraitMetrics | null, WtaPortraitMetrics | null]>([null, null])

  useEffect(() => {
    setWtaPortraitMetrics([null, null])
  }, [detail.match_id, p1Avatar, p2Avatar, tournamentWorld])

  const wtaPortraitTransform = useMemo<[WtaPortraitTransform, WtaPortraitTransform]>(() => {
    if (tournamentWorld !== 'WTA') {
      return [DEFAULT_WTA_MATCH_PORTRAIT, DEFAULT_WTA_MATCH_PORTRAIT]
    }

    return [
      buildWtaPortraitTransform(wtaPortraitMetrics[0], detail.player1?.id),
      buildWtaPortraitTransform(wtaPortraitMetrics[1], detail.player2?.id),
    ]
  }, [detail.player1?.id, detail.player2?.id, tournamentWorld, wtaPortraitMetrics])

  const hasStats = Object.keys(detail.player1_stats ?? {}).length > 0 || Object.keys(detail.player2_stats ?? {}).length > 0
  const isScheduledPreview = detail.status === 'scheduled' && detail.sets.length === 0

  return (
    <>
      <header className="tlg-match-modal-head">
        <div><span>{detail.tournament_name} · Season Week {detail.scheduled_season_week}</span><h2>{detail.round_label} · Match {detail.match_number}</h2><p>{detail.city}, {detail.country_code} · Day {detail.scheduled_day}</p></div>
        <div className="tlg-match-result-actions">
          <strong className={`match-status status-${detail.status}`}>{statusLabel(detail.status, t)}</strong>
          {(detail.status === 'completed' || detail.status === 'in_progress') && (
            <button type="button" className="tlg-match-replay-open" onClick={() => onReplay(detail.match_id)}>
              <span aria-hidden="true">▶</span> {detail.status === 'in_progress' ? 'Watch Live' : t('tournamentPage.enhancements.matchSchedule.replay')}
            </button>
          )}
        </div>
      </header>

      <div className={`tlg-match-versus${tournamentWorld === 'WTA' ? ' tlg-match-versus-wta' : ''}`}>
        <MatchPlayerCard
          player={detail.player1}
          avatarUrl={p1Avatar}
          winner={detail.winner_id === detail.player1?.id}
          returnPath={returnPath}
          tournamentName={tournamentName}
          wtaAutoAlign={tournamentWorld === 'WTA'}
          portraitTransform={wtaPortraitTransform[0]}
          onPortraitMeasure={(metrics) => setWtaPortraitMetrics((current) => current[0] === metrics ? current : [metrics, current[1]] as [WtaPortraitMetrics | null, WtaPortraitMetrics | null])}
        />
        <div className="tlg-match-versus-center"><strong>VS</strong><span>{detail.status === 'completed' || detail.status === 'walkover' ? t('tournamentPage.match.finalResult') : detail.status === 'in_progress' ? t('tournamentPage.match.inProgress') : t('tournamentPage.match.upcoming')}</span></div>
        <MatchPlayerCard
          player={detail.player2}
          avatarUrl={p2Avatar}
          winner={detail.winner_id === detail.player2?.id}
          returnPath={returnPath}
          tournamentName={tournamentName}
          wtaAutoAlign={tournamentWorld === 'WTA'}
          portraitTransform={wtaPortraitTransform[1]}
          onPortraitMeasure={(metrics) => setWtaPortraitMetrics((current) => current[1] === metrics ? current : [current[0], metrics] as [WtaPortraitMetrics | null, WtaPortraitMetrics | null])}
        />
      </div>

      {isScheduledPreview ? (
        <PreMatchInsights detail={detail} drawMatches={drawMatches} />
      ) : (
        <>
          <section className="tlg-match-score-section"><header><span>{t('tournamentPage.match.score')}</span><h3>{detail.status === 'walkover' ? t('tournamentPage.match.walkoverResult') : t('tournamentPage.match.setBySet')}</h3></header>{detail.status === 'walkover' && detail.winner_id ? <div className="tlg-match-empty">{t('tournamentPage.match.walkoverAwarded', { winner: playerName(detail.winner_id === detail.player1?.id ? detail.player1 : detail.player2) })}</div> : detail.sets.length === 0 ? <div className="tlg-match-empty">{detail.status === 'completed' ? t('tournamentPage.match.resultWithoutSets') : t('tournamentPage.match.setsPending')}</div> : <div className="tlg-match-score-table"><div className="head"><span>{t('tournamentPage.match.player')}</span>{detail.sets.map((set) => <strong key={set.set_number}>{t('tournamentPage.match.set', { number: set.set_number })}</strong>)}</div><ScoreRow player={detail.player1} sets={detail.sets.map((set) => set.player1_games)} winner={detail.winner_id === detail.player1?.id} /><ScoreRow player={detail.player2} sets={detail.sets.map((set) => set.player2_games)} winner={detail.winner_id === detail.player2?.id} /></div>}</section>

          <section className="tlg-match-stats-section"><header><span>{t('tournamentPage.match.statistics')}</span><h3>{detail.status === 'in_progress' ? t('tournamentPage.match.liveStatistics') : t('tournamentPage.match.statistics')}</h3></header>{!hasStats ? <div className="tlg-match-empty">{detail.status === 'walkover' ? t('tournamentPage.match.noWalkoverStats') : detail.status === 'completed' ? t('tournamentPage.match.noCompletedStats') : t('tournamentPage.match.statsPending')}</div> : <div className="tlg-match-stats-table"><StatRow label={t('tournamentPage.match.stats.aces')} left={detail.player1_stats.aces ?? 0} right={detail.player2_stats.aces ?? 0} /><StatRow label={t('tournamentPage.match.stats.doubleFaults')} left={detail.player1_stats.double_faults ?? 0} right={detail.player2_stats.double_faults ?? 0} /><StatRow label={t('tournamentPage.match.stats.firstServe')} left={percent(detail.player1_stats.first_serves_in, detail.player1_stats.first_serves_total)} right={percent(detail.player2_stats.first_serves_in, detail.player2_stats.first_serves_total)} /><StatRow label={t('tournamentPage.match.stats.firstServeWon')} left={ratio(detail.player1_stats.first_serve_points_won, detail.player1_stats.first_serve_points_played)} right={ratio(detail.player2_stats.first_serve_points_won, detail.player2_stats.first_serve_points_played)} /><StatRow label={t('tournamentPage.match.stats.secondServeWon')} left={ratio(detail.player1_stats.second_serve_points_won, detail.player1_stats.second_serve_points_played)} right={ratio(detail.player2_stats.second_serve_points_won, detail.player2_stats.second_serve_points_played)} /><StatRow label={t('tournamentPage.match.stats.breakPointsWon')} left={ratio(detail.player1_stats.break_points_won, detail.player1_stats.break_points_total)} right={ratio(detail.player2_stats.break_points_won, detail.player2_stats.break_points_total)} /><StatRow label={t('tournamentPage.match.stats.winners')} left={detail.player1_stats.winners ?? 0} right={detail.player2_stats.winners ?? 0} /><StatRow label={t('tournamentPage.match.stats.unforcedErrors')} left={detail.player1_stats.unforced_errors ?? 0} right={detail.player2_stats.unforced_errors ?? 0} /><StatRow label={t('tournamentPage.match.stats.totalPointsWon')} left={detail.player1_stats.total_points_won ?? 0} right={detail.player2_stats.total_points_won ?? 0} /></div>}</section>
        </>
      )}

      {detail.status === 'scheduled' && <MatchTacticPanel detail={detail} currentPlayerId={currentPlayerId} />}
    </>
  )
}

function PreMatchInsights({ detail, drawMatches }: { detail: MatchDetail; drawMatches: TournamentDrawMatch[] }) {
  const { t } = useTranslation()
  const current = drawMatches.find((match) => match.match_id === detail.match_id)
  const currentRound = current?.round_number ?? Number.MAX_SAFE_INTEGER
  return (
    <section className="tlg-prematch-insights">
      <div className="tlg-prematch-panel">
        <header><div><span>{t('tournamentPage.match.tournament')}</span><h3>{t('tournamentPage.match.road')}</h3></div><small>{t('tournamentPage.match.actualResults')}</small></header>
        <div className="tlg-prematch-form-grid">
          <TournamentPlayerForm player={detail.player1} drawMatches={drawMatches} beforeRound={currentRound} />
          <TournamentPlayerForm player={detail.player2} drawMatches={drawMatches} beforeRound={currentRound} />
        </div>
      </div>

      <div className="tlg-prematch-panel">
        <header><div><span>{t('tournamentPage.match.headToHead')}</span><h3>{t('tournamentPage.match.meetings')}</h3></div><small className="mock-badge">{t('tournamentPage.match.previewHistory')}</small></header>
        <MockHeadToHead player1={detail.player1} player2={detail.player2} />
      </div>
    </section>
  )
}

function TournamentPlayerForm({ player, drawMatches, beforeRound }: { player: MatchPlayerDetail | null; drawMatches: TournamentDrawMatch[]; beforeRound: number }) {
  const { t } = useTranslation()
  if (!player) return <div className="tlg-prematch-form-card"><strong>{t('tournamentPage.draw.bye')}</strong></div>
  const matches = drawMatches
    .filter((match) => match.round_number < beforeRound && match.match_status === 'completed' && match.winner_id === player.id && (match.player1_id === player.id || match.player2_id === player.id))
    .sort((a, b) => b.round_number - a.round_number)
  const latest = matches[0]
  const playerWasOne = latest?.player1_id === player.id
  const opponent = latest ? drawPlayerName(latest, playerWasOne ? 2 : 1) : null
  return (
    <div className="tlg-prematch-form-card">
      <div className="identity"><CountryFlag countryCode={player.country_code} countryName={player.country_code} width={24} height={16} /><strong>{playerName(player)}</strong></div>
      {latest ? <><span>{latest.round_label}</span><p>{t('tournamentPage.match.defeated', { opponent })}</p><small>{formatDrawScore(latest, player.id, t)}</small></> : <><span>{t('tournamentPage.match.debut')}</span><p>{t('tournamentPage.match.firstMatch')}</p><small>{t('tournamentPage.match.noPrevious')}</small></>}
    </div>
  )
}

function MockHeadToHead({ player1, player2 }: { player1: MatchPlayerDetail | null; player2: MatchPlayerDetail | null }) {
  const { t } = useTranslation()
  if (!player1 || !player2) return <div className="tlg-match-empty">{t('tournamentPage.match.h2hUnavailable')}</div>
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
  const { t } = useTranslation()
  const isOwnMatch = Boolean(currentPlayerId && (detail.player1?.id === currentPlayerId || detail.player2?.id === currentPlayerId))
  const opponent = currentPlayerId === detail.player1?.id ? detail.player2 : currentPlayerId === detail.player2?.id ? detail.player1 : null
  const [data, setData] = useState<MatchTacticResponse | null>(null)
  const [scouting, setScouting] = useState<MatchScoutingReport | null>(null)
  const [draft, setDraft] = useState<TournamentTactic>({ ...BALANCED_TACTIC })
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [showHelp, setShowHelp] = useState(false)

  const load = useCallback(async () => {
    if (!isOwnMatch || !currentPlayerId) return
    setLoading(true)
    setMessage(null)
    const [tacticResponse, scoutingResponse] = await Promise.all([
      supabase.rpc('get_tournament_match_tactic_v1', { p_player_id: currentPlayerId, p_match_id: detail.match_id }),
      opponent?.id
        ? supabase.rpc('get_player_scouting_report_v1', { p_target_player_id: opponent.id })
        : Promise.resolve({ data: null, error: null }),
    ])
    setLoading(false)
    if (tacticResponse.error || !tacticResponse.data) {
      setMessage(tacticResponse.error?.message ?? 'Unable to load match tactic.')
      return
    }
    const next = tacticResponse.data as MatchTacticResponse
    setData(next)
    setDraft(next.override ?? next.effective ?? { ...BALANCED_TACTIC })
    setScouting(!scoutingResponse.error && scoutingResponse.data ? scoutingResponse.data as MatchScoutingReport : null)
  }, [currentPlayerId, detail.match_id, isOwnMatch, opponent?.id])

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
      p_tactic_serve_placement: draft.servePlacement,
      p_tactic_return: draft.returnGame,
      p_tactic_return_position: draft.returnPosition,
      p_tactic_court_position: draft.courtPosition,
      p_tactic_target: draft.target,
      p_tactic_risk: draft.risk,
    })
    setSaving(false)
    if (error || !tacticData) {
      setMessage(error?.message ?? t('tournamentPage.tactic.unavailable'))
      return
    }
    const next = tacticData as MatchTacticResponse
    setData(next)
    setDraft(next.effective)
    setMessage(t('tournamentPage.tactic.save'))
  }

  async function useTournamentDefault() {
    if (!currentPlayerId) return
    setSaving(true)
    setMessage(null)
    const { data: tacticData, error } = await supabase.rpc('clear_tournament_match_tactic_v1', { p_player_id: currentPlayerId, p_match_id: detail.match_id })
    setSaving(false)
    if (error || !tacticData) {
      setMessage(error?.message ?? t('tournamentPage.tactic.unavailable'))
      return
    }
    const next = tacticData as MatchTacticResponse
    setData(next)
    setDraft(next.effective)
    setMessage(t('tournamentPage.tactic.useDefault'))
  }

  const sourceLabel = data?.source ? t(`tournamentPage.tactic.source.${data.source}`) : t('tournamentPage.tactic.source.automatic_default')
  const effective = data?.effective ?? draft
  const editable = Boolean(data?.editable)

  // Once the pre-match tactic deadline has passed, the entire preparation
  // area (including equipment, health and countdown add-ons) is no longer relevant.
  if (data && !editable) return null

  return (
    <section className="tlg-match-tactic-section">
      <div className="tlg-match-tactic-head">
        <div><span>{t('tournamentPage.tactic.kicker')}</span><h3>{t('tournamentPage.tactic.title')}</h3><p>{t('tournamentPage.tactic.body')}</p></div>
        <div className="tlg-match-tactic-head-tools"><button type="button" className={`tlg-tactic-info-button${showHelp ? ' active' : ''}`} aria-label={t('tournamentPage.tactic.explain')} aria-expanded={showHelp} onClick={() => setShowHelp((current) => !current)}>i</button><div className="tlg-match-tactic-source"><span>{t('tournamentPage.tactic.active')}</span><strong>{sourceLabel}</strong></div></div>
      </div>

      {opponent && <OpponentAnalysis opponent={opponent} scouting={scouting} />}

      {showHelp && <TacticHelp tactic={editable ? draft : effective} />}

      {loading ? <div className="tlg-match-tactic-loading">{t('tournamentPage.tactic.loading')}</div> : !data ? <div className="tlg-match-tactic-loading">{message ?? t('tournamentPage.tactic.unavailable')}</div> : !editable ? (
        <><div className="tlg-match-tactic-locked">{t('tournamentPage.tactic.locked')}</div><TacticSummary tactic={effective} /><TacticEffects tactic={effective} locked /></>
      ) : (
        <>
          <div className="tlg-match-tactic-presets">{TACTIC_PRESETS.map((preset) => <button key={preset} type="button" className={draft.preset === preset ? 'selected' : ''} onClick={() => setDraft(tacticFromPreset(preset))}>{t(`tournamentPage.tactic.options.${preset}`, { defaultValue: preset })}</button>)}</div>
          <div className="tlg-match-tactic-grid">
            <TacticSelect label={t('tournamentPage.tactic.overall')} value={draft.approach} values={TACTIC_OPTIONS.approach} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', approach: value }))} />
            <TacticSelect label={t('tournamentPage.tactic.rally')} value={draft.rally} values={TACTIC_OPTIONS.rally} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', rally: value }))} />
            <TacticSelect label={t('tournamentPage.tactic.serve')} value={draft.serve} values={TACTIC_OPTIONS.serve} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', serve: value }))} />
            <TacticSelect label={t('tournamentPage.tactic.servePlacement')} value={draft.servePlacement} values={TACTIC_OPTIONS.servePlacement} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', servePlacement: value }))} />
            <TacticSelect label={t('tournamentPage.tactic.return')} value={draft.returnGame} values={TACTIC_OPTIONS.returnGame} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', returnGame: value }))} />
            <TacticSelect label={t('tournamentPage.tactic.returnPosition')} value={draft.returnPosition} values={TACTIC_OPTIONS.returnPosition} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', returnPosition: value }))} />
            <TacticSelect label={t('tournamentPage.tactic.courtPosition')} value={draft.courtPosition} values={TACTIC_OPTIONS.courtPosition} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', courtPosition: value }))} />
            <TacticSelect label={t('tournamentPage.tactic.target')} value={draft.target} values={TACTIC_OPTIONS.target} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', target: value }))} />
            <TacticSelect label={t('tournamentPage.tactic.risk')} value={draft.risk} values={TACTIC_OPTIONS.risk} onChange={(value) => setDraft((current) => ({ ...current, preset: 'Custom', risk: value }))} />
          </div>
          <TacticEffects tactic={draft} />
          <div className="tlg-match-tactic-actions"><span className="tlg-match-tactic-message">{message ?? t('tournamentPage.tactic.tournamentDefault', { preset: t(`tournamentPage.tactic.options.${data.tournament_default.preset}`, { defaultValue: data.tournament_default.preset }) })}</span><div className="tlg-match-tactic-buttons"><button type="button" onClick={useTournamentDefault} disabled={saving || data.source !== 'match_override'}>{t('tournamentPage.tactic.useDefault')}</button><button type="button" className="primary" onClick={saveOverride} disabled={saving}>{saving ? t('tournamentPage.tactic.saving') : t('tournamentPage.tactic.save')}</button></div></div>
        </>
      )}
    </section>
  )
}

function OpponentAnalysis({ opponent, scouting }: { opponent: MatchPlayerDetail; scouting: MatchScoutingReport | null }) {
  const { t } = useTranslation()
  const handLabel = opponent.playing_hand === 'left' ? t('tournamentPage.match.left') : t('tournamentPage.match.right')
  const strength = scouting?.identified_strength ? scouting.identified_strength.replaceAll('_', ' ') : null
  const weakness = scouting?.identified_weakness ? scouting.identified_weakness.replaceAll('_', ' ') : null

  return (
    <div className="tlg-opponent-analysis">
      <header>
        <div>
          <span>{t('tournamentPage.tactic.opponentAnalysis')}</span>
          <strong>{playerName(opponent)}</strong>
          <p>{handLabel} · {t(`playerProfilePage.style.${opponent.playing_style}`, { defaultValue: opponent.playing_style })} · {opponent.preferred_surface ? t(`calendarPage.surface.${opponent.preferred_surface}`, { defaultValue: opponent.preferred_surface }) : t('tournamentPage.tactic.noSurface')}</p>
        </div>
        {scouting?.available
          ? <div className="confidence"><strong>{scouting.confidence_percent ?? 0}%</strong><span>{t('tournamentPage.tactic.report', { stage: scouting.report_stage ?? 'general' })}</span><small>{t('tournamentPage.tactic.estimate', { value: scouting.estimate_margin })}</small></div>
          : <div className="confidence public"><strong>{t('tournamentPage.tactic.public')}</strong><span>{t('tournamentPage.tactic.identityOnly')}</span></div>}
      </header>

      {!scouting?.available ? (
        <div className="tlg-opponent-analysis-locked">
          <p>{scouting?.reason ?? t('tournamentPage.tactic.analystRequired')}</p>
          <Link to="/game/staff">{t('tournamentPage.tactic.openStaff')}</Link>
        </div>
      ) : (
        <>
          <div className="tlg-opponent-analysis-key">
            <div><span>{t('tournamentPage.tactic.likelyStrength')}</span><strong>{strength ?? '—'}</strong></div>
            <div><span>{t('tournamentPage.tactic.likelyWeakness')}</span><strong>{weakness ?? '—'}</strong></div>
            <div><span>{t('tournamentPage.tactic.preparation')}</span><strong>{t('tournamentPage.tactic.gameHours', { value: Number(scouting.preparation_hours ?? 0).toFixed(1) })}</strong></div>
          </div>
          <div className="tlg-opponent-analysis-notes">
            <div><span>{t('tournamentPage.tactic.observed')}</span>{scouting.tactical_observations?.map((item) => <p key={item}>{item}</p>)}</div>
            <div><span>{t('tournamentPage.tactic.considerations')}</span>{scouting.recommendations?.map((item) => <p key={item}>{item}</p>)}</div>
          </div>
        </>
      )}
    </div>
  )
}

function TacticHelp({ tactic }: { tactic: TournamentTactic }) {
  const { t } = useTranslation()
  const option = (value: string) => t(`tournamentPage.tactic.options.${value}`, { defaultValue: value })
  const rows = [
    [t('tournamentPage.tactic.overall'), option(tactic.approach), tactic.approach === 'Aggressive' ? t('tournamentPage.tactic.help.approachAggressive') : tactic.approach === 'Defensive' ? t('tournamentPage.tactic.help.approachDefensive') : t('tournamentPage.tactic.help.approachBalanced')],
    [t('tournamentPage.tactic.rally'), option(tactic.rally), tactic.rally === 'Shorten points' ? t('tournamentPage.tactic.help.rallyShort') : tactic.rally === 'Extend rallies' ? t('tournamentPage.tactic.help.rallyLong') : t('tournamentPage.tactic.help.rallyBalanced')],
    [t('tournamentPage.tactic.serve'), option(tactic.serve), tactic.serve === 'Power serving' ? t('tournamentPage.tactic.help.servePower') : tactic.serve === 'Serve + 1' ? t('tournamentPage.tactic.help.servePlusOne') : tactic.serve === 'Safe first serve' ? t('tournamentPage.tactic.help.serveSafe') : t('tournamentPage.tactic.help.serveBalanced')],
    [t('tournamentPage.tactic.servePlacement'), option(tactic.servePlacement), tactic.servePlacement === 'Wide' ? t('tournamentPage.tactic.help.placementWide') : tactic.servePlacement === 'Body' ? t('tournamentPage.tactic.help.placementBody') : tactic.servePlacement === 'T' ? t('tournamentPage.tactic.help.placementT') : t('tournamentPage.tactic.help.placementAuto')],
    [t('tournamentPage.tactic.return'), option(tactic.returnGame), tactic.returnGame === 'Aggressive return' ? t('tournamentPage.tactic.help.returnAggressive') : tactic.returnGame === 'Attack second serve' ? t('tournamentPage.tactic.help.returnSecond') : tactic.returnGame === 'Safe return' ? t('tournamentPage.tactic.help.returnSafe') : t('tournamentPage.tactic.help.returnBalanced')],
    [t('tournamentPage.tactic.returnPosition'), option(tactic.returnPosition), tactic.returnPosition === 'Closer' ? t('tournamentPage.tactic.help.positionCloser') : tactic.returnPosition === 'Deeper' ? t('tournamentPage.tactic.help.positionDeeper') : t('tournamentPage.tactic.help.positionNormal')],
    [t('tournamentPage.tactic.courtPosition'), option(tactic.courtPosition), tactic.courtPosition === 'Net attack' ? t('tournamentPage.tactic.help.courtNet') : tactic.courtPosition === 'Inside baseline' ? t('tournamentPage.tactic.help.courtInside') : tactic.courtPosition === 'Deep baseline' ? t('tournamentPage.tactic.help.courtDeep') : t('tournamentPage.tactic.help.courtNormal')],
    [t('tournamentPage.tactic.target'), option(tactic.target), tactic.target === 'Automatic' ? t('tournamentPage.tactic.help.targetAuto') : t('tournamentPage.tactic.help.targetSpecific', { target: option(tactic.target).toLowerCase() })],
    [t('tournamentPage.tactic.risk'), option(tactic.risk), tactic.risk === 'Aggressive' ? t('tournamentPage.tactic.help.riskAggressive') : tactic.risk === 'Safe' ? t('tournamentPage.tactic.help.riskSafe') : t('tournamentPage.tactic.help.riskBalanced')],
  ] as const
  return <div className="tlg-tactic-help"><header><strong>{t('tournamentPage.tactic.helpTitle')}</strong><span>{t('tournamentPage.tactic.planningGuide')}</span></header><div>{rows.map(([label, value, copy]) => <article key={label}><span>{label}</span><strong>{value}</strong><p>{copy}</p></article>)}</div></div>
}

function calculateTacticEffects(tactic: TournamentTactic, t: TFunction): TacticEffect[] {
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
  if (tactic.servePlacement === 'Wide') { servePressure += 4; attack += 2; errorRisk += 1 }
  if (tactic.servePlacement === 'Body') { servePressure += 2; errorRisk -= 1 }
  if (tactic.servePlacement === 'T') { servePressure += 3; winnerPressure += 2 }
  if (tactic.returnGame === 'Aggressive return') { returnPressure += 12; attack += 5; errorRisk += 5 }
  if (tactic.returnGame === 'Attack second serve') { returnPressure += 10; attack += 4; errorRisk += 2 }
  if (tactic.returnGame === 'Safe return') { returnPressure -= 6; errorRisk -= 4; rallyLength += 3 }
  if (tactic.returnPosition === 'Closer') { returnPressure += 4; attack += 2; errorRisk += 2 }
  if (tactic.returnPosition === 'Deeper') { returnPressure -= 1; errorRisk -= 2; rallyLength += 2 }
  if (tactic.courtPosition === 'Inside baseline') { attack += 8; winnerPressure += 5; errorRisk += 3 }
  if (tactic.courtPosition === 'Net attack') { attack += 12; winnerPressure += 10; rallyLength -= 7; errorRisk += 6; fatigue += 3 }
  if (tactic.courtPosition === 'Deep baseline') { attack -= 5; rallyLength += 7; errorRisk -= 2; fatigue += 2 }
  if (tactic.risk === 'Aggressive') { attack += 10; winnerPressure += 10; errorRisk += 12; fatigue += 4 }
  if (tactic.risk === 'Safe') { attack -= 6; winnerPressure -= 5; errorRisk -= 9; rallyLength += 4; fatigue -= 2 }

  const effect = (label: string, value: number, positiveMeaning: boolean, copy: string): TacticEffect => ({ label, value, text: copy, tone: value === 0 ? 'neutral' : positiveMeaning ? (value > 0 ? 'positive' : 'neutral') : (value > 0 ? 'warning' : 'positive') })
  return [
    effect(t('tournamentPage.tactic.effects.attack'), attack, true, attack > 7 ? t('tournamentPage.tactic.effects.attackHigh') : attack < -4 ? t('tournamentPage.tactic.effects.attackLow') : t('tournamentPage.tactic.effects.attackNormal')),
    effect(t('tournamentPage.tactic.effects.winner'), winnerPressure, true, winnerPressure > 6 ? t('tournamentPage.tactic.effects.winnerHigh') : winnerPressure < -3 ? t('tournamentPage.tactic.effects.winnerLow') : t('tournamentPage.tactic.effects.winnerNormal')),
    effect(t('tournamentPage.tactic.effects.error'), errorRisk, false, errorRisk > 5 ? t('tournamentPage.tactic.effects.errorHigh') : errorRisk < -4 ? t('tournamentPage.tactic.effects.errorLow') : t('tournamentPage.tactic.effects.errorNormal')),
    effect(t('tournamentPage.tactic.effects.rally'), rallyLength, false, rallyLength > 6 ? t('tournamentPage.tactic.effects.rallyHigh') : rallyLength < -6 ? t('tournamentPage.tactic.effects.rallyLow') : t('tournamentPage.tactic.effects.rallyNormal')),
    effect(t('tournamentPage.tactic.effects.serve'), servePressure, true, servePressure > 5 ? t('tournamentPage.tactic.effects.serveHigh') : servePressure < -4 ? t('tournamentPage.tactic.effects.serveLow') : t('tournamentPage.tactic.effects.serveNormal')),
    effect(t('tournamentPage.tactic.effects.return'), returnPressure, true, returnPressure > 5 ? t('tournamentPage.tactic.effects.returnHigh') : returnPressure < -4 ? t('tournamentPage.tactic.effects.returnLow') : t('tournamentPage.tactic.effects.returnNormal')),
    effect(t('tournamentPage.tactic.effects.fatigue'), fatigue, false, fatigue > 5 ? t('tournamentPage.tactic.effects.fatigueHigh') : fatigue < -3 ? t('tournamentPage.tactic.effects.fatigueLow') : t('tournamentPage.tactic.effects.fatigueNormal')),
    { label: t('tournamentPage.tactic.effects.opponent'), value: null, text: tactic.target === 'Automatic' ? t('tournamentPage.tactic.effects.opponentAuto') : t('tournamentPage.tactic.effects.opponentTarget', { target: t(`tournamentPage.tactic.options.${tactic.target}`, { defaultValue: tactic.target }).toLowerCase() }), tone: 'neutral' },
  ]
}

function TacticEffects({ tactic, locked = false }: { tactic: TournamentTactic; locked?: boolean }) {
  const { t } = useTranslation()
  const effects = calculateTacticEffects(tactic, t)
  return (
    <div className="tlg-tactic-effects">
      <header><div><span>{locked ? t('tournamentPage.tactic.effects.outcome') : t('tournamentPage.tactic.effects.projected')}</span><h4>{locked ? t('tournamentPage.tactic.effects.effective') : t('tournamentPage.tactic.effects.selections')}</h4></div><small>{t('tournamentPage.tactic.effects.preview')}</small></header>
      <div className="tlg-tactic-effects-grid">{effects.map((item) => <article key={item.label} className={item.tone}><div><span>{item.label}</span>{item.value !== null && <strong>{item.value > 0 ? '+' : ''}{item.value}%</strong>}</div><p>{item.text}</p></article>)}</div>
      <p className="tlg-tactic-effects-note">{t('tournamentPage.tactic.effects.note')}</p>
    </div>
  )
}

function TacticSummary({ tactic }: { tactic: TournamentTactic }) {
  const { t } = useTranslation()
  const option = (value: string) => t(`tournamentPage.tactic.options.${value}`, { defaultValue: value })
  return <div className="tlg-match-tactic-effective"><div><span>{t('tournamentPage.tactic.summary.preset')}</span><strong>{option(tactic.preset)}</strong></div><div><span>{t('tournamentPage.tactic.summary.approach')}</span><strong>{option(tactic.approach)}</strong></div><div><span>{t('tournamentPage.tactic.summary.serve')}</span><strong>{option(tactic.serve)}</strong></div><div><span>{t('tournamentPage.tactic.summary.servePlacement')}</span><strong>{option(tactic.servePlacement)}</strong></div><div><span>{t('tournamentPage.tactic.summary.return')}</span><strong>{option(tactic.returnGame)}</strong></div><div><span>{t('tournamentPage.tactic.summary.returnPosition')}</span><strong>{option(tactic.returnPosition)}</strong></div><div><span>{t('tournamentPage.tactic.summary.rallies')}</span><strong>{option(tactic.rally)}</strong></div><div><span>{t('tournamentPage.tactic.summary.position')}</span><strong>{option(tactic.courtPosition)}</strong></div><div><span>{t('tournamentPage.tactic.summary.target')}</span><strong>{option(tactic.target)}</strong></div><div><span>{t('tournamentPage.tactic.summary.risk')}</span><strong>{option(tactic.risk)}</strong></div></div>
}

function TacticSelect({ label, value, values, onChange }: { label: string; value: string; values: readonly string[]; onChange: (value: string) => void }) {
  const { t } = useTranslation()
  return <label className="tlg-match-tactic-field"><span>{label}</span><select value={value} onChange={(event) => onChange(event.target.value)}>{values.map((option) => <option key={option} value={option}>{t(`tournamentPage.tactic.options.${option}`, { defaultValue: option })}</option>)}</select></label>
}

function MatchPlayerCard({
  player,
  avatarUrl,
  winner,
  returnPath,
  tournamentName,
  wtaAutoAlign = false,
  portraitTransform = DEFAULT_WTA_MATCH_PORTRAIT,
  onPortraitMeasure,
}: {
  player: MatchPlayerDetail | null
  avatarUrl: string | null
  winner: boolean
  returnPath: string
  tournamentName: string
  wtaAutoAlign?: boolean
  portraitTransform?: WtaPortraitTransform
  onPortraitMeasure?: (metrics: WtaPortraitMetrics | null) => void
}) {
  const { t } = useTranslation()
  if (!player) return <div className="tlg-match-player-card empty"><strong>{t('tournamentPage.draw.bye')}</strong></div>
  const name = playerName(player)
  const portraitStyle = wtaAutoAlign
    ? ({
        '--portrait-size': `${(portraitTransform.size * 100).toFixed(2)}%`,
        '--portrait-auto-shift-y': `${(portraitTransform.shift * 100).toFixed(2)}%`,
      } as CSSProperties)
    : undefined

  return (
    <article className={`tlg-match-player-card tlg-match-player-card-polished${winner ? ' winner' : ''}`}>
      <div className={`tlg-match-player-portrait-stage${avatarUrl ? ' has-image' : ''}`}>
        {avatarUrl ? (
          <img
            src={avatarUrl}
            alt={t('tournamentPage.match.portraitAlt', { name })}
            crossOrigin={wtaAutoAlign ? 'anonymous' : undefined}
            style={portraitStyle}
            onLoad={wtaAutoAlign ? (event) => onPortraitMeasure?.(measureWtaPortraitMetrics(event.currentTarget)) : undefined}
            onError={wtaAutoAlign ? () => onPortraitMeasure?.(null) : undefined}
          />
        ) : (
          <span>{player.first_name[0]}{player.last_name[0]}</span>
        )}
      </div>
      <div className="tlg-match-player-summary">
        <div className="identity"><CountryFlag countryCode={player.country_code} countryName={player.country_code} width={29} height={19} /><Link to={`/game/players/${player.id}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: `Back to ${tournamentName}` }}>{name}</Link></div>
        <div className="meta"><span>{player.ranking_position ? t('tournamentPage.match.worldRank', { rank: player.ranking_position }) : t('tournamentPage.match.unranked')}</span><strong className="handedness">{player.playing_hand === 'left' ? t('tournamentPage.match.left') : t('tournamentPage.match.right')}</strong>{player.seed ? <strong>{t('tournamentPage.match.seed', { seed: player.seed })}</strong> : <strong className="unseeded">{t('tournamentPage.match.unseeded')}</strong>}</div>
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