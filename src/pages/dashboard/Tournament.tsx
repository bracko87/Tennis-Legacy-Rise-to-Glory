import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
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
  match_status: 'scheduled' | 'bye' | 'completed' | 'walkover' | 'cancelled'
  player1_id: string | null
  player1_first_name: string | null
  player1_last_name: string | null
  player1_country_code: string | null
  player1_seed: number | null
  player2_id: string | null
  player2_first_name: string | null
  player2_last_name: string | null
  player2_country_code: string | null
  player2_seed: number | null
  winner_id: string | null
}

interface BracketRound {
  label: string
  matches: number
  roundNumber: number
}

type LogoStatus = 'none' | 'loading' | 'ready' | 'error'

const BRACKET_MATCH_WIDTH = 210
const BRACKET_MATCH_HEIGHT = 62
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

export default function TournamentPage() {
  const { competitionId } = useParams()
  const { player } = useAuth()
  const [logoUrl, setLogoUrl] = useState<string | null>(null)
  const [logoStatus, setLogoStatus] = useState<LogoStatus>('none')
  const [logoTarget, setLogoTarget] = useState<HTMLElement | null>(null)
  const [pageTarget, setPageTarget] = useState<HTMLElement | null>(null)
  const [tournamentName, setTournamentName] = useState('Tournament')
  const [drawMatches, setDrawMatches] = useState<TournamentDrawMatch[]>([])

  useEffect(() => {
    if (!competitionId) {
      setLogoUrl(null)
      setLogoStatus('none')
      setDrawMatches([])
      return
    }

    let cancelled = false

    async function loadTournamentExtras() {
      const [logoResponse, drawResponse] = await Promise.all([
        supabase.rpc('get_tournament_detail_v1', { p_competition_id: competitionId }),
        supabase.rpc('get_tournament_draw_v1', { p_competition_id: competitionId }),
      ])

      if (cancelled) return

      if (!logoResponse.error) {
        const row = (Array.isArray(logoResponse.data) ? logoResponse.data[0] : logoResponse.data) as TournamentLogoRow | null
        const nextLogoUrl = row?.logo_url ?? null
        setLogoUrl(nextLogoUrl)
        setTournamentName(row?.tournament_name ?? 'Tournament')
        setLogoStatus(nextLogoUrl ? 'loading' : 'none')
      }

      setDrawMatches(drawResponse.error ? [] : ((drawResponse.data ?? []) as TournamentDrawMatch[]))
    }

    void loadTournamentExtras()

    return () => {
      cancelled = true
    }
  }, [competitionId])

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

  const showRealLogo = Boolean(logoTarget && logoUrl && logoStatus !== 'error')
  const mainDrawMatches = useMemo(
    () => drawMatches.filter((match) => match.draw_type === 'main_draw'),
    [drawMatches],
  )
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
        <PublishedDrawTree matches={mainDrawMatches} currentPlayerId={player?.id ?? null} />,
        pageTarget,
      )}
    </div>
  )
}

function PublishedDrawTree({ matches, currentPlayerId }: { matches: TournamentDrawMatch[]; currentPlayerId: string | null }) {
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
  const height = Math.max(
    BRACKET_MATCH_HEIGHT,
    (rounds[0].matches - 1) * BRACKET_STEP + BRACKET_MATCH_HEIGHT,
  )

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
            <header
              key={`${round.label}-${round.matches}`}
              style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) }}
            >
              <strong>{round.label}</strong>
              <span>{round.matches} {round.matches === 1 ? 'match' : 'matches'}</span>
            </header>
          ))}
        </div>

        <div className="tlg-detail-bracket-tree" style={{ width, height }}>
          <svg
            className="tlg-detail-bracket-connectors"
            width={width}
            height={height}
            viewBox={`0 0 ${width} ${height}`}
            aria-hidden="true"
          >
            {rounds.slice(0, -1).map((_, roundIndex) => {
              const boundaryX = (roundIndex + 1) * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) - BRACKET_COLUMN_GAP / 2
              return (
                <line
                  key={`round-separator-${roundIndex}`}
                  x1={boundaryX}
                  x2={boundaryX}
                  y1={0}
                  y2={height}
                  stroke="#0b6fc8"
                  strokeWidth="1.4"
                  opacity="0.72"
                  vectorEffect="non-scaling-stroke"
                />
              )
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

                return (
                  <path
                    key={`connector-${roundIndex}-${parentIndex}`}
                    d={`M ${startX} ${firstY} H ${middleX} M ${startX} ${secondY} H ${middleX} M ${middleX} ${firstY} V ${secondY} M ${middleX} ${parentY} H ${endX}`}
                  />
                )
              })
            })}
          </svg>

          {rounds.map((round, roundIndex) => (
            <section
              key={`${round.label}-${round.matches}`}
              className="tlg-detail-bracket-round"
              style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) }}
            >
              {Array.from({ length: round.matches }, (_, matchIndex) => {
                const top = bracketMatchCenter(roundIndex, matchIndex) - BRACKET_MATCH_HEIGHT / 2
                const matchNumber = matchIndex + 1
                const match = matchByRound.get(`${round.roundNumber}:${matchNumber}`)
                const ownMatch = Boolean(currentPlayerId && match && (match.player1_id === currentPlayerId || match.player2_id === currentPlayerId))
                const firstSource = roundIndex === 0 ? matchIndex * 2 + 1 : null
                const secondSource = roundIndex === 0 ? matchIndex * 2 + 2 : null

                return (
                  <div
                    key={`${round.label}-${matchIndex}`}
                    className={`tlg-detail-bracket-match tlg-live-tree-match${ownMatch ? ' own-match' : ''}`}
                    style={{ top }}
                  >
                    <BracketPlayer
                      matchExists={Boolean(match)}
                      playerId={match?.player1_id ?? null}
                      firstName={match?.player1_first_name ?? null}
                      lastName={match?.player1_last_name ?? null}
                      seed={match?.player1_seed ?? null}
                      slot={firstSource}
                      winner={Boolean(match?.winner_id && match.winner_id === match.player1_id)}
                    />
                    <BracketPlayer
                      matchExists={Boolean(match)}
                      playerId={match?.player2_id ?? null}
                      firstName={match?.player2_first_name ?? null}
                      lastName={match?.player2_last_name ?? null}
                      seed={match?.player2_seed ?? null}
                      slot={secondSource}
                      winner={Boolean(match?.winner_id && match.winner_id === match.player2_id)}
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
  seed,
  slot,
  winner,
}: {
  matchExists: boolean
  playerId: string | null
  firstName: string | null
  lastName: string | null
  seed: number | null
  slot: number | null
  winner: boolean
}) {
  const marker = seed ?? slot ?? '—'

  if (!matchExists) {
    return <div><span>{marker}</span><strong>TBD</strong></div>
  }

  if (!playerId) {
    return <div className="tlg-live-tree-bye"><span>{marker}</span><strong>BYE</strong></div>
  }

  const name = `${firstName ?? ''} ${lastName ?? ''}`.trim() || 'Player'
  return (
    <div className={winner ? 'tlg-live-tree-winner' : undefined}>
      <span>{marker}</span>
      <Link to={`/game/players/${playerId}`}>{name}</Link>
    </div>
  )
}
