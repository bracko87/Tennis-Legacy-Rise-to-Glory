import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
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

type LogoStatus = 'none' | 'loading' | 'ready' | 'error'

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
    () => drawMatches.filter((match) => match.draw_type === 'main_draw' && match.round_number === 1),
    [drawMatches],
  )
  const hasPublishedDraw = mainDrawMatches.length > 0
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
        <PublishedDrawPanel matches={mainDrawMatches} currentPlayerId={player?.id ?? null} />,
        pageTarget,
      )}
    </div>
  )
}

function PublishedDrawPanel({ matches, currentPlayerId }: { matches: TournamentDrawMatch[]; currentPlayerId: string | null }) {
  const first = matches[0]
  const entrantIds = new Set<string>()
  matches.forEach((match) => {
    if (match.player1_id) entrantIds.add(match.player1_id)
    if (match.player2_id) entrantIds.add(match.player2_id)
  })

  return (
    <section className="tlg-detail-panel tlg-live-draw-panel">
      <header className="tlg-detail-panel-head tlg-live-draw-head">
        <div>
          <span>Published tournament draw</span>
          <h2>{first?.round_label ?? 'Main Draw'}</h2>
          <p>{entrantIds.size} entered players · Season Week {first?.scheduled_season_week} · Match day {first?.scheduled_day}</p>
        </div>
        <strong className="tlg-live-draw-status">Draw published</strong>
      </header>

      <div className="tlg-live-draw-grid">
        {matches.map((match) => {
          const ownMatch = Boolean(currentPlayerId && (match.player1_id === currentPlayerId || match.player2_id === currentPlayerId))
          return (
            <article key={match.match_id} className={`tlg-live-draw-match${ownMatch ? ' own-match' : ''}`}>
              <div className="tlg-live-draw-match-head">
                <span>Match {match.match_number}</span>
                {ownMatch && <strong>Your match</strong>}
              </div>
              <PlayerLine
                playerId={match.player1_id}
                firstName={match.player1_first_name}
                lastName={match.player1_last_name}
                countryCode={match.player1_country_code}
                seed={match.player1_seed}
                winner={match.winner_id === match.player1_id}
              />
              <PlayerLine
                playerId={match.player2_id}
                firstName={match.player2_first_name}
                lastName={match.player2_last_name}
                countryCode={match.player2_country_code}
                seed={match.player2_seed}
                winner={match.winner_id === match.player2_id}
              />
            </article>
          )
        })}
      </div>
    </section>
  )
}

function PlayerLine({
  playerId,
  firstName,
  lastName,
  countryCode,
  seed,
  winner,
}: {
  playerId: string | null
  firstName: string | null
  lastName: string | null
  countryCode: string | null
  seed: number | null
  winner: boolean
}) {
  if (!playerId) {
    return <div className="tlg-live-draw-player bye"><span>—</span><strong>BYE</strong></div>
  }

  const name = `${firstName ?? ''} ${lastName ?? ''}`.trim()
  return (
    <div className={`tlg-live-draw-player${winner ? ' winner' : ''}`}>
      <CountryFlag countryCode={countryCode ?? ''} countryName={countryCode ?? ''} width={21} height={14} />
      <Link to={`/game/players/${playerId}`}>{name || 'Player'}</Link>
      {seed && <span className="seed">{seed}</span>}
    </div>
  )
}
