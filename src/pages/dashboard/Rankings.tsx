import { ArrowDown, ArrowUp, ChevronDown, ChevronLeft, ChevronRight, ChevronUp, LockKeyhole } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { Link, useLocation, useSearchParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/rankings-live.css'
import '../../styles/shared-segmented-tabs.css'

interface RankingRow {
  rank_position: number
  player_id: string
  first_name: string
  last_name: string
  country_code: string
  image_path: string | null
  ranking_points: number
  previous_week_position: number | null
  rank_change: number | null
  previous_week_points: number | null
  points_change: number | null
}


interface RankingProtectionEntry {
  contribution_id: string
  tournament_name: string
  source_result_label: string
  ranking_points: number
  expiration_season: number
  expiration_week: number
  expiration_month: number
  expiration_day: number
  days_remaining: number
  next_edition_scheduled: boolean
}

interface RankingProtectionResponse {
  premium: boolean
  locked: boolean
  contributions: RankingProtectionEntry[]
}


interface RankingReturnState {
  rankingReturnPlayerId?: string
  rankingReturnScrollKey?: string
}

interface RankingPaginationProps {
  page: number
  rowCount: number
  loading: boolean
  placement?: 'top' | 'bottom'
  onPrevious: () => void
  onNext: () => void
}

const PAGE_SIZE = 50

function pageFromSearch(value: string | null) {
  if (!value) return 0
  const parsed = Number.parseInt(value, 10)
  return Number.isInteger(parsed) && parsed > 0 ? parsed - 1 : 0
}

type RankingDiscipline = 'singles' | 'doubles'

function rankingScrollKey(world: string, discipline: RankingDiscipline, page: number, playerId: string) {
  return `tlg-ranking-return:${world}:${discipline}:${page + 1}:${playerId}`
}

function RankingPagination({ page, rowCount, loading, placement = 'bottom', onPrevious, onNext }: RankingPaginationProps) {
  return (
    <div className={`tlg-ranking-pagination${placement === 'top' ? ' tlg-ranking-pagination-top' : ''}`}>
      <button type="button" disabled={page === 0 || loading} onClick={onPrevious}><ChevronLeft size={15} /> Previous 50</button>
      {placement !== 'top' && <span>Positions {page * PAGE_SIZE + 1}–{page * PAGE_SIZE + Math.max(rowCount, 1)}</span>}
      <button type="button" disabled={rowCount < PAGE_SIZE || loading} onClick={onNext}>Next 50 <ChevronRight size={15} /></button>
    </div>
  )
}

function WeeklyRankChange({ row }: { row: RankingRow }) {
  if (row.previous_week_position === null || row.rank_change === null) {
    return <span className="tlg-live-rank-change tlg-live-rank-change-new" title="No previous weekly ranking">NEW</span>
  }

  if (row.rank_change > 0) {
    return (
      <span
        className="tlg-live-rank-change tlg-live-rank-change-up"
        title={`Last week: #${row.previous_week_position}`}
        aria-label={`Up ${row.rank_change} positions from number ${row.previous_week_position} last week`}
      >
        <ArrowUp size={14} strokeWidth={2.4} />
        <strong>+{row.rank_change}</strong>
      </span>
    )
  }

  if (row.rank_change < 0) {
    return (
      <span
        className="tlg-live-rank-change tlg-live-rank-change-down"
        title={`Last week: #${row.previous_week_position}`}
        aria-label={`Down ${Math.abs(row.rank_change)} positions from number ${row.previous_week_position} last week`}
      >
        <ArrowDown size={14} strokeWidth={2.4} />
        <strong>{row.rank_change}</strong>
      </span>
    )
  }

  return (
    <span
      className="tlg-live-rank-change tlg-live-rank-change-same"
      title={`Last week: #${row.previous_week_position}`}
      aria-label={`No ranking change from number ${row.previous_week_position} last week`}
    >
      —
    </span>
  )
}

function WeeklyPointsChange({ row }: { row: RankingRow }) {
  if (row.previous_week_points === null || row.points_change === null) {
    return <span className="tlg-live-points-change tlg-live-points-change-same">—</span>
  }

  if (row.points_change > 0) {
    return <strong className="tlg-live-points-change tlg-live-points-change-up" title={`Last week: ${row.previous_week_points.toLocaleString()} points`}>+{row.points_change.toLocaleString()}</strong>
  }

  if (row.points_change < 0) {
    return <strong className="tlg-live-points-change tlg-live-points-change-down" title={`Last week: ${row.previous_week_points.toLocaleString()} points`}>{row.points_change.toLocaleString()}</strong>
  }

  return <span className="tlg-live-points-change tlg-live-points-change-same" title={`Last week: ${row.previous_week_points.toLocaleString()} points`}>0</span>
}

export default function RankingsPage() {
  const { player } = useAuth()
  const world = player?.world ?? 'ATP'
  const location = useLocation()
  const [searchParams, setSearchParams] = useSearchParams()
  const page = pageFromSearch(searchParams.get('page'))
  const discipline: RankingDiscipline = searchParams.get('discipline') === 'doubles' ? 'doubles' : 'singles'
  const [rows, setRows] = useState<RankingRow[]>([])
  const [rankingProtection, setRankingProtection] = useState<RankingProtectionResponse | null>(null)
  const [rankingProtectionOpen, setRankingProtectionOpen] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const previousWorldRef = useRef(world)
  const restoredReturnRef = useRef<string | null>(null)
  const returnState = location.state as RankingReturnState | null
  const returnPlayerId = returnState?.rankingReturnPlayerId ?? null
  const returnScrollKey = returnState?.rankingReturnScrollKey ?? null
  const returnPath = `${location.pathname}${location.search}${location.hash}`

  const loadRankings = useCallback(async () => {
    setLoading(true)
    setError(null)

    const [rankingResponse, protectionResponse] = await Promise.all([
      discipline === 'doubles'
        ? supabase.rpc('get_world_doubles_rankings_v1', {
          p_world: world,
          p_offset: page * PAGE_SIZE,
          p_limit: PAGE_SIZE,
        })
        : supabase.rpc('get_world_rankings_v3', {
          p_world: world,
          p_offset: page * PAGE_SIZE,
          p_limit: PAGE_SIZE,
        }),
      discipline === 'doubles'
        ? supabase.rpc('get_premium_doubles_ranking_protection_v1')
        : supabase.rpc('get_premium_ranking_protection_v1'),
    ])

    if (rankingResponse.error) {
      setError(rankingResponse.error.message)
      setRows([])
    } else {
      setRows((rankingResponse.data ?? []) as RankingRow[])
    }

    if (!protectionResponse.error && protectionResponse.data) {
      setRankingProtection(protectionResponse.data as RankingProtectionResponse)
    } else {
      setRankingProtection(null)
    }

    setLoading(false)
  }, [discipline, page, world])

  const setDiscipline = useCallback((nextDiscipline: RankingDiscipline) => {
    setRankingProtectionOpen(false)
    setSearchParams((current) => {
      const next = new URLSearchParams(current)
      next.delete('page')
      if (nextDiscipline === 'singles') next.delete('discipline')
      else next.set('discipline', 'doubles')
      return next
    })
  }, [setSearchParams])

  const goToPage = useCallback((nextPage: number) => {
    const safePage = Math.max(0, nextPage)
    setSearchParams((current) => {
      const next = new URLSearchParams(current)
      if (safePage === 0) next.delete('page')
      else next.set('page', String(safePage + 1))
      return next
    })
  }, [setSearchParams])

  useEffect(() => {
    if (previousWorldRef.current === world) return
    previousWorldRef.current = world
    setSearchParams((current) => {
      const next = new URLSearchParams(current)
      next.delete('page')
      return next
    }, { replace: true })
  }, [setSearchParams, world])

  useEffect(() => {
    void loadRankings()
  }, [loadRankings])

  useEffect(() => {
    if (loading || !returnPlayerId) return
    const signature = `${returnPlayerId}:${returnScrollKey ?? ''}`
    if (restoredReturnRef.current === signature) return

    const frame = window.requestAnimationFrame(() => {
      let restored = false
      if (returnScrollKey) {
        try {
          const stored = window.sessionStorage.getItem(returnScrollKey)
          const scrollY = stored === null ? Number.NaN : Number(stored)
          if (Number.isFinite(scrollY)) {
            window.scrollTo(0, scrollY)
            restored = true
          }
          window.sessionStorage.removeItem(returnScrollKey)
        } catch {
          // Session storage can be unavailable in restricted browser modes.
        }
      }

      if (!restored) {
        const row = document.getElementById(`ranking-player-${returnPlayerId}`)
        if (row) {
          const target = Math.max(0, row.getBoundingClientRect().top + window.scrollY - window.innerHeight * 0.35)
          window.scrollTo(0, target)
        }
      }
      restoredReturnRef.current = signature
    })

    return () => window.cancelAnimationFrame(frame)
  }, [loading, returnPlayerId, returnScrollKey, rows])

  return (
    <GameLayout title="Rankings" subtitle={`${world} ${discipline} world ranking`}>
      <header className="tlg-v2-page-head tlg-ranking-page-head-with-tabs">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">World competition</div>
          <h2 className="tlg-v2-page-title">{world} Ranking</h2>
          <p className="tlg-v2-page-description">
            Singles and doubles have completely separate ATP/WTA rankings. Doubles points belong to the individual player and stay with them when partners change.
          </p>
        </div>
        <div className="tlg-ranking-discipline-tabs tlg-standard-tabs" role="tablist" aria-label="Ranking discipline">
          <button type="button" role="tab" aria-selected={discipline === 'singles'} className={discipline === 'singles' ? 'active' : ''} onClick={() => setDiscipline('singles')}>Singles</button>
          <button type="button" role="tab" aria-selected={discipline === 'doubles'} className={discipline === 'doubles' ? 'active' : ''} onClick={() => setDiscipline('doubles')}>Doubles</button>
        </div>
      </header>

      <section className={'tlg-v2-panel tlg-ranking-protection-panel' + (rankingProtectionOpen ? ' is-open' : '')}>
        <button
          type="button"
          className="tlg-ranking-protection-summary"
          aria-expanded={Boolean(rankingProtection?.premium && rankingProtectionOpen)}
          onClick={() => {
            if (rankingProtection?.premium) setRankingProtectionOpen((current) => !current)
          }}
        >
          <div>
            <span>PREMIUM · RANKING PROTECTION</span>
            <h3>Upcoming Point Expirations</h3>
            <p>
              {discipline === 'doubles'
                ? 'Your next doubles ranking results due to expire.'
                : 'Your next singles ranking results due to expire.'}
            </p>
          </div>
          {rankingProtection?.premium ? (
            <strong>
              {rankingProtectionOpen ? 'Minimize' : 'Expand'}
              {rankingProtectionOpen ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
            </strong>
          ) : (
            <strong className="locked"><LockKeyhole size={14} /> Premium</strong>
          )}
        </button>

        {!rankingProtection?.premium ? (
          <div className="tlg-ranking-protection-locked">
            <LockKeyhole size={16} />
            <span>Upgrade to Premium to see the next five ranking-point expirations.</span>
          </div>
        ) : rankingProtectionOpen ? (
          rankingProtection.contributions.length > 0 ? (
            <div className="tlg-ranking-protection-list">
              {rankingProtection.contributions.slice(0, 5).map((item) => (
                <article key={item.contribution_id}>
                  <div>
                    <span>{item.next_edition_scheduled ? 'Defending points' : 'Scheduled expiration'}</span>
                    <strong>{item.tournament_name}</strong>
                    <small>{item.source_result_label}</small>
                  </div>
                  <div className="points">
                    <strong>{item.ranking_points.toLocaleString()} pts</strong>
                    <small>{item.days_remaining.toLocaleString()} game days remaining</small>
                  </div>
                  <div className="expires">
                    <span>Expires</span>
                    <strong>Season {item.expiration_season} · Week {item.expiration_week}</strong>
                    <small>Month {item.expiration_month}, Day {item.expiration_day}</small>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="tlg-ranking-protection-empty">
              No {discipline} ranking results are currently waiting to expire.
            </div>
          )
        ) : null}
      </section>

      <section className="tlg-v2-panel">
        <header className="tlg-v2-panel-header tlg-ranking-panel-header">
          <div>
            <span>{world} {discipline}</span>
            <h3>{discipline === 'doubles' ? 'Doubles World Ranking' : 'Singles World Ranking'}</h3>
          </div>
          <RankingPagination
            page={page}
            rowCount={rows.length}
            loading={loading}
            placement="top"
            onPrevious={() => goToPage(page - 1)}
            onNext={() => goToPage(page + 1)}
          />
        </header>

        <div className="tlg-ranking-table-head">
          <span>Rank</span>
          <span>Rank change</span>
          <span>Player</span>
          <span>Country</span>
          <span>Points</span>
          <span>Points change</span>
        </div>

        {loading ? (
          <div className="tlg-ranking-empty"><strong>Loading ranking…</strong></div>
        ) : error ? (
          <div className="tlg-ranking-empty"><strong>Unable to load ranking</strong><p>{error}</p></div>
        ) : rows.length === 0 ? (
          <div className="tlg-ranking-empty">
            <strong>No ranked players yet</strong>
            <p>Created players will appear here automatically.</p>
          </div>
        ) : (
          <div className="tlg-live-ranking-rows">
            {rows.map((row) => {
              const scrollKey = rankingScrollKey(world, discipline, page, row.player_id)
              return (
                <Link
                  key={row.player_id}
                  id={`ranking-player-${row.player_id}`}
                  to={`/game/players/${row.player_id}`}
                  state={{
                    playerProfileReturn: returnPath,
                    playerProfileReturnLabel: 'Back to Rankings',
                    playerProfileReturnState: {
                      rankingReturnPlayerId: row.player_id,
                      rankingReturnScrollKey: scrollKey,
                    },
                  }}
                  onClick={() => {
                    try {
                      window.sessionStorage.setItem(scrollKey, String(window.scrollY))
                    } catch {
                      // Row anchoring will still restore the user's place.
                    }
                  }}
                  className={`tlg-live-ranking-row ${row.player_id === player?.id ? 'tlg-live-ranking-row-own' : ''}`}
                >
                  <strong className="tlg-live-rank-number">{row.rank_position}</strong>
                  <WeeklyRankChange row={row} />
                  <span className="tlg-live-player-name">{row.first_name} {row.last_name}</span>
                  <span className="tlg-live-country"><CountryFlag countryCode={row.country_code} countryName={row.country_code} width={22} height={15} /> {row.country_code}</span>
                  <strong className="tlg-live-points">{row.ranking_points.toLocaleString()}</strong>
                  <WeeklyPointsChange row={row} />
                </Link>
              )
            })}
          </div>
        )}

        <RankingPagination
          page={page}
          rowCount={rows.length}
          loading={loading}
          onPrevious={() => goToPage(page - 1)}
          onNext={() => goToPage(page + 1)}
        />
      </section>
    </GameLayout>
  )
}
