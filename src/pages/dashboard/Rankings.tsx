import { ArrowDown, ArrowUp, ChevronDown, ChevronLeft, ChevronRight, ChevronUp, LockKeyhole } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link, useLocation, useSearchParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
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
  const { t } = useTranslation()
  return (
    <div className={`tlg-ranking-pagination${placement === 'top' ? ' tlg-ranking-pagination-top' : ''}`}>
      <button type="button" disabled={page === 0 || loading} onClick={onPrevious}><ChevronLeft size={15} /> {t('rankingsPage.previous50')}</button>
      {placement !== 'top' && <span>{t('rankingsPage.positions', { from: page * PAGE_SIZE + 1, to: page * PAGE_SIZE + Math.max(rowCount, 1) })}</span>}
      <button type="button" disabled={rowCount < PAGE_SIZE || loading} onClick={onNext}>{t('rankingsPage.next50')} <ChevronRight size={15} /></button>
    </div>
  )
}

function WeeklyRankChange({ row, t }: { row: RankingRow; t: TFunction }) {
  if (row.previous_week_position === null || row.rank_change === null) {
    return <span className="tlg-live-rank-change tlg-live-rank-change-new" title={t('rankingsPage.noPreviousRanking')}>{t('rankingsPage.new')}</span>
  }

  if (row.rank_change > 0) {
    return (
      <span
        className="tlg-live-rank-change tlg-live-rank-change-up"
        title={t('rankingsPage.lastWeekRank', { rank: row.previous_week_position })}
        aria-label={t('rankingsPage.rankUpAria', { count: row.rank_change, rank: row.previous_week_position })}
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
        aria-label={t('rankingsPage.rankDownAria', { count: Math.abs(row.rank_change), rank: row.previous_week_position })}
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
      aria-label={t('rankingsPage.rankSameAria', { rank: row.previous_week_position })}
    >
      —
    </span>
  )
}

function WeeklyPointsChange({ row, t, formatNumber }: { row: RankingRow; t: TFunction; formatNumber: (value: number) => string }) {
  if (row.previous_week_points === null || row.points_change === null) {
    return <span className="tlg-live-points-change tlg-live-points-change-same">—</span>
  }

  const title = t('rankingsPage.lastWeekPoints', { points: formatNumber(row.previous_week_points) })

  if (row.points_change > 0) {
    return <strong className="tlg-live-points-change tlg-live-points-change-up" title={title}>+{formatNumber(row.points_change)}</strong>
  }

  if (row.points_change < 0) {
    return <strong className="tlg-live-points-change tlg-live-points-change-down" title={title}>{formatNumber(row.points_change)}</strong>
  }

  return <span className="tlg-live-points-change tlg-live-points-change-same" title={title}>0</span>
}

export default function RankingsPage() {
  const { t } = useTranslation()
  const { formatNumber } = useLocalization()
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
    <GameLayout title={t('rankingsPage.title')} subtitle={t('rankingsPage.subtitle', { world, discipline: discipline === 'doubles' ? t('rankingsPage.doubles').toLowerCase() : t('rankingsPage.singles').toLowerCase() })}>
      <header className="tlg-v2-page-head tlg-page-head-with-tabs">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">{t('rankingsPage.eyebrow')}</div>
          <h2 className="tlg-v2-page-title">{t('rankingsPage.heading', { world })}</h2>
          <p className="tlg-v2-page-description">
            {t('rankingsPage.description')}
          </p>
        </div>

        <div className="tlg-ranking-discipline-tabs tlg-standard-tabs" role="tablist" aria-label={t('rankingsPage.disciplineAria')}>
          <button type="button" role="tab" aria-selected={discipline === 'singles'} className={discipline === 'singles' ? 'active' : ''} onClick={() => setDiscipline('singles')}>{t('rankingsPage.singles')}</button>
          <button type="button" role="tab" aria-selected={discipline === 'doubles'} className={discipline === 'doubles' ? 'active' : ''} onClick={() => setDiscipline('doubles')}>{t('rankingsPage.doubles')}</button>
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
            <span>{t('rankingsPage.premiumProtection')}</span>
            <h3>{t('rankingsPage.upcomingExpirations')}</h3>
            <p>
              {discipline === 'doubles'
                ? t('rankingsPage.doublesExpiryIntro')
                : t('rankingsPage.singlesExpiryIntro')}
            </p>
          </div>
          {rankingProtection?.premium ? (
            <strong>
              {rankingProtectionOpen ? t('rankingsPage.minimize') : t('rankingsPage.expand')}
              {rankingProtectionOpen ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
            </strong>
          ) : (
            <strong className="locked"><LockKeyhole size={14} /> Premium</strong>
          )}
        </button>

        {!rankingProtection?.premium ? (
          <div className="tlg-ranking-protection-locked">
            <LockKeyhole size={16} />
            <span>{t('rankingsPage.upgrade')}</span>
          </div>
        ) : rankingProtectionOpen ? (
          rankingProtection.contributions.length > 0 ? (
            <div className="tlg-ranking-protection-list">
              {rankingProtection.contributions.slice(0, 5).map((item) => (
                <article key={item.contribution_id}>
                  <div>
                    <span>{item.next_edition_scheduled ? t('rankingsPage.defendingPoints') : t('rankingsPage.scheduledExpiration')}</span>
                    <strong>{item.tournament_name}</strong>
                    <small>{item.source_result_label}</small>
                  </div>
                  <div className="points">
                    <strong>{t('rankingsPage.pointsShort', { count: formatNumber(item.ranking_points) })}</strong>
                    <small>{t('rankingsPage.gameDaysRemaining', { count: item.days_remaining })}</small>
                  </div>
                  <div className="expires">
                    <span>{t('rankingsPage.expires')}</span>
                    <strong>{t('rankingsPage.seasonWeek', { season: item.expiration_season, week: item.expiration_week })}</strong>
                    <small>{t('rankingsPage.monthDay', { month: item.expiration_month, day: item.expiration_day })}</small>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="tlg-ranking-protection-empty">
              {t('rankingsPage.noExpirations', { discipline: discipline === 'doubles' ? t('rankingsPage.doubles').toLowerCase() : t('rankingsPage.singles').toLowerCase() })}
            </div>
          )
        ) : null}
      </section>

      <section className="tlg-v2-panel">
        <header className="tlg-v2-panel-header tlg-ranking-panel-header">
          <div>
            <span>{world} {discipline}</span>
            <h3>{discipline === 'doubles' ? t('rankingsPage.worldRankingDoubles') : t('rankingsPage.worldRankingSingles')}</h3>
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
          <span>{t('rankingsPage.rank')}</span>
          <span>{t('rankingsPage.rankChange')}</span>
          <span>{t('rankingsPage.player')}</span>
          <span>{t('rankingsPage.country')}</span>
          <span>{t('rankingsPage.points')}</span>
          <span>{t('rankingsPage.pointsChange')}</span>
        </div>

        {loading ? (
          <div className="tlg-ranking-empty"><strong>{t('rankingsPage.loading')}</strong></div>
        ) : error ? (
          <div className="tlg-ranking-empty"><strong>{t('rankingsPage.loadError')}</strong><p>{error}</p></div>
        ) : rows.length === 0 ? (
          <div className="tlg-ranking-empty">
            <strong>{t('rankingsPage.noPlayers')}</strong>
            <p>{t('rankingsPage.noPlayersBody')}</p>
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
                    playerProfileReturnLabel: t('rankingsPage.back'),
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
                  <WeeklyRankChange row={row} t={t} />
                  <span className="tlg-live-player-name">{row.first_name} {row.last_name}</span>
                  <span className="tlg-live-country"><CountryFlag countryCode={row.country_code} countryName={row.country_code} width={22} height={15} /> {row.country_code}</span>
                  <strong className="tlg-live-points">{formatNumber(row.ranking_points)}</strong>
                  <WeeklyPointsChange row={row} t={t} formatNumber={formatNumber} />
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
