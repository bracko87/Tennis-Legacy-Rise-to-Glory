import { Minus, TrendingDown, TrendingUp, Trophy, X } from 'lucide-react'
import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link, useLocation } from 'react-router'

import CountryFlag from '../common/CountryFlag'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-defending-points.css'

interface RewardRow {
  stage_code: string
  stage_label: string
  draw_type: 'main_draw' | 'qualification' | 'bonus'
  ranking_points: number
  points_are_bonus: boolean
}

interface DefendingOwnPlayer {
  player_id: string
  previous_season: number | null
  previous_competition_id: string | null
  previous_result_code: string | null
  previous_result_label: string | null
  previous_points: number
  points_defending: number
  points_expire_absolute_day: number | null
  points_expire_season: number | null
  points_expire_week: number | null
  points_expire_month: number | null
  points_expire_day: number | null
  current_result_code: string | null
  current_result_label: string | null
  current_result_points: number
  current_result_publish_status: string | null
  current_ranking_position: number | null
  current_ranking_points: number
}

interface DefendingParticipant {
  player_id: string
  first_name: string
  last_name: string
  country_code: string
  is_ai: boolean
  current_ranking_position: number | null
  current_ranking_points: number
  previous_result_code: string | null
  previous_result_label: string | null
  previous_points: number
  points_defending: number
}

interface DefendingPointsResponse {
  competition_id: string
  tournament_series_id: string
  world: 'ATP' | 'WTA'
  season_number: number
  previous_season_number: number | null
  previous_competition_id: string | null
  ranking_cycle_absolute_day: number
  cycle_processed: boolean
  own: DefendingOwnPlayer
  participants: DefendingParticipant[]
}

interface PastWinner {
  season_number: number
  competition_id: string
  player_id: string
  first_name: string
  last_name: string
  country_code: string
  is_ai: boolean
}

interface PastWinnersResponse {
  competition_id: string
  tournament_series_id: string
  world: 'ATP' | 'WTA'
  current_season_number: number
  winners: PastWinner[]
}

function signedPoints(value: number) {
  if (value > 0) return `+${value.toLocaleString()}`
  return value.toLocaleString()
}

function NetIcon({ value }: { value: number }) {
  if (value > 0) return <TrendingUp size={13} />
  if (value < 0) return <TrendingDown size={13} />
  return <Minus size={13} />
}

export default function TournamentDefendingPoints({ competitionId, rewardRows }: { competitionId?: string; rewardRows: RewardRow[] }) {
  const { t } = useTranslation()
  const location = useLocation()
  const [data, setData] = useState<DefendingPointsResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expanded, setExpanded] = useState(false)
  const [pastWinners, setPastWinners] = useState<PastWinner[]>([])
  const [historyError, setHistoryError] = useState<string | null>(null)
  const [historyOpen, setHistoryOpen] = useState(false)

  useEffect(() => {
    setExpanded(false)
    setHistoryOpen(false)
  }, [competitionId, t])

  useEffect(() => {
    if (!historyOpen) return
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setHistoryOpen(false)
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [historyOpen])

  useEffect(() => {
    if (!competitionId) {
      setData(null)
      setLoading(false)
      return
    }

    let active = true
    async function load() {
      setLoading(true)
      setError(null)
      setHistoryError(null)
      const [defenceResponse, winnersResponse] = await Promise.all([
        supabase.rpc('get_tournament_defending_points_v1', {
          p_competition_id: competitionId,
        }),
        supabase.rpc('get_tournament_past_winners_v1', {
          p_competition_id: competitionId,
        }),
      ])
      if (!active) return

      if (defenceResponse.error || !defenceResponse.data) {
        setData(null)
        setError(defenceResponse.error?.message ?? t('tournamentPage.enhancements.defending.unavailable'))
      } else {
        setData(defenceResponse.data as DefendingPointsResponse)
      }

      if (winnersResponse.error || !winnersResponse.data) {
        setPastWinners([])
        setHistoryError(winnersResponse.error?.message ?? t('tournamentPage.enhancements.defending.unavailable'))
      } else {
        setPastWinners(((winnersResponse.data as PastWinnersResponse).winners ?? []) as PastWinner[])
      }

      setLoading(false)
    }

    void load()
    return () => { active = false }
  }, [competitionId])

  const outcomes = useMemo(() => {
    const defending = data?.own.points_defending ?? 0
    return rewardRows
      .filter((row) => row.draw_type === 'main_draw' && !row.points_are_bonus)
      .map((row) => ({ ...row, net: row.ranking_points - defending }))
  }, [data?.own.points_defending, rewardRows])

  const fieldDefenders = useMemo(() => {
    if (!data) return []
    return data.participants
      .filter((participant) => participant.player_id !== data.own.player_id && participant.points_defending > 0)
      .slice(0, 16)
  }, [data])

  const returnPath = `${location.pathname}${location.search}${location.hash}`
  const recentWinners = pastWinners.slice(0, 5)

  return (
    <>
    <section className={`tlg-detail-panel tlg-defence-panel${expanded ? '' : ' collapsed'}`}>
      <header className="tlg-detail-panel-head tlg-defence-head">
        <div>
          <span>{t('tournamentPage.enhancements.defending.kicker')}</span>
          <h2>{t('tournamentPage.enhancements.defending.title')}</h2>
          {expanded && <p>{t('tournamentPage.enhancements.defending.body')}</p>}
        </div>
        <div className="tlg-defence-head-actions">
          {data && <span>{t('tournamentPage.enhancements.defending.ptsDefending', { count: data.own.points_defending })}</span>}
          <button type="button" aria-expanded={expanded} onClick={() => setExpanded((value) => !value)}>
            {expanded ? t('tournamentPage.enhancements.defending.collapse') : t('tournamentPage.enhancements.defending.expand')}
          </button>
        </div>
      </header>

      {loading ? (
        <div className="tlg-defence-state">{t('tournamentPage.enhancements.defending.loading')}</div>
      ) : error || !data ? (
        <div className="tlg-defence-state tlg-defence-error">{error ?? t('tournamentPage.enhancements.defending.unavailable')}</div>
      ) : (
        <>
          <div className="tlg-defence-status-row">
            <div>
              <span>{data.previous_season_number ? t('tournamentPage.enhancements.defending.seasonResult', { season: data.previous_season_number }) : t('tournamentPage.enhancements.defending.firstSeason')}</span>
              <strong>{data.own.previous_result_label ?? (data.previous_season_number ? t('tournamentPage.enhancements.defending.didNotPlay') : t('tournamentPage.enhancements.defending.noPreviousEdition'))}</strong>
            </div>
            <div className={`tlg-defence-cycle-status ${data.cycle_processed ? 'processed' : 'pending'}`}>
              <span>{data.cycle_processed ? t('tournamentPage.enhancements.defending.cycleProcessed') : t('tournamentPage.enhancements.defending.defencePending')}</span>
              <strong>{data.cycle_processed ? t('tournamentPage.enhancements.defending.oldReplaced') : t('tournamentPage.enhancements.defending.ptsAtRisk', { count: data.own.points_defending })}</strong>
              {!data.cycle_processed && data.own.points_expire_season && (
                <small>{t('tournamentPage.enhancements.defending.expires', { season: data.own.points_expire_season, week: data.own.points_expire_week ?? 0 })}</small>
              )}
            </div>
          </div>

          <div className="tlg-past-winners">
            <div className="tlg-defence-subhead">
              <div><span>{t('tournamentPage.enhancements.defending.history')}</span><strong>{t('tournamentPage.enhancements.defending.pastWinners')}</strong></div>
              {pastWinners.length > 0 && <button type="button" className="tlg-past-winners-button" onClick={() => setHistoryOpen(true)}>{t('tournamentPage.enhancements.defending.viewAll')}</button>}
            </div>

            {historyError ? (
              <div className="tlg-defence-field-empty">{historyError}</div>
            ) : recentWinners.length === 0 ? (
              <div className="tlg-defence-field-empty">{t('tournamentPage.enhancements.defending.noChampions')}</div>
            ) : (
              <div className="tlg-past-winners-strip">
                {recentWinners.map((winner) => (
                  <article key={`${winner.season_number}-${winner.player_id}`} className="tlg-past-winner-card">
                    <Trophy size={14} />
                    <span>{t('tournamentPage.enhancements.defending.season', { season: winner.season_number })}</span>
                    <div>
                      <CountryFlag countryCode={winner.country_code} countryName={winner.country_code} width={19} height={13} />
                      <Link to={`/game/players/${winner.player_id}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: t('tournamentPage.enhancements.defending.backTournament') }}>
                        {winner.first_name} {winner.last_name}
                      </Link>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </div>

          <div className="tlg-defence-summary-grid">
            <article>
              <span>{t('tournamentPage.enhancements.defending.lastSeason')}</span>
              <strong>{data.own.previous_points.toLocaleString()}</strong>
              <small>{t('tournamentPage.enhancements.defending.stored')}</small>
            </article>
            <article className="primary">
              <span>{t('tournamentPage.enhancements.defending.defendingThisYear')}</span>
              <strong>{data.own.points_defending.toLocaleString()}</strong>
              <small>
                {data.cycle_processed
                  ? t('tournamentPage.enhancements.defending.alreadyRemoved')
                  : data.own.points_expire_season
                    ? t('tournamentPage.enhancements.defending.scheduledExpiry', { season: data.own.points_expire_season, week: data.own.points_expire_week ?? 0 })
                    : t('tournamentPage.enhancements.defending.noPreviousContribution')}
              </small>
            </article>
            <article>
              <span>{t('tournamentPage.enhancements.defending.currentRanking')}</span>
              <strong>{data.own.current_ranking_position ? `#${data.own.current_ranking_position}` : t('tournamentPage.enhancements.defending.unranked')}</strong>
              <small>{t('tournamentPage.enhancements.defending.totalPoints', { count: data.own.current_ranking_points })}</small>
            </article>
            <article>
              <span>{t('tournamentPage.enhancements.defending.currentResult')}</span>
              <strong>{data.own.current_result_label ?? t('tournamentPage.enhancements.defending.notFinalized')}</strong>
              <small>{data.own.current_result_code ? t('tournamentPage.enhancements.defending.resultPoints', { count: data.own.current_result_points, status: data.own.current_result_publish_status ?? 'pending' }) : t('tournamentPage.enhancements.defending.noNewContribution')}</small>
            </article>
          </div>

          {!data.cycle_processed && data.previous_season_number && outcomes.length > 0 && (
            <div className="tlg-defence-outcomes">
              <div className="tlg-defence-subhead">
                <div><span>{t('tournamentPage.enhancements.defending.scenarios')}</span><strong>{t('tournamentPage.enhancements.defending.possibleChange')}</strong></div>
                <small>{t('tournamentPage.enhancements.defending.netFormula', { count: data.own.points_defending })}</small>
              </div>
              <div className="tlg-defence-outcome-grid">
                {outcomes.map((row) => (
                  <div key={row.stage_code} className={`tlg-defence-outcome ${row.net > 0 ? 'positive' : row.net < 0 ? 'negative' : 'neutral'}`}>
                    <span>{row.stage_label}</span>
                    <strong>{t('tournamentPage.enhancements.defending.pointsShort', { count: row.ranking_points })}</strong>
                    <small><NetIcon value={row.net} /> {t('tournamentPage.enhancements.defending.net', { value: signedPoints(row.net) })}</small>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="tlg-defence-field">
            <div className="tlg-defence-subhead">
              <div><span>{t('tournamentPage.enhancements.defending.field')}</span><strong>{t('tournamentPage.enhancements.defending.others')}</strong></div>
              <small>{t('tournamentPage.enhancements.defending.entrants')}</small>
            </div>

            {fieldDefenders.length === 0 ? (
              <div className="tlg-defence-field-empty">
                {data.previous_season_number
                  ? t('tournamentPage.enhancements.defending.noFieldDefenders')
                  : t('tournamentPage.enhancements.defending.seasonOneNoDefence')}
              </div>
            ) : (
              <div className="tlg-defence-table">
                <div className="tlg-defence-table-row head"><span>{t('tournamentPage.enhancements.defending.player')}</span><span>{t('tournamentPage.enhancements.defending.lastSeason')}</span><span>{t('tournamentPage.enhancements.defending.defending')}</span><span>{t('tournamentPage.enhancements.defending.rank')}</span></div>
                {fieldDefenders.map((participant) => (
                  <div className="tlg-defence-table-row" key={participant.player_id}>
                    <span className="player">
                      <CountryFlag countryCode={participant.country_code} countryName={participant.country_code} width={20} height={14} />
                      <Link to={`/game/players/${participant.player_id}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: t('tournamentPage.enhancements.defending.backTournament') }}>
                        {participant.first_name} {participant.last_name}
                      </Link>
                    </span>
                    <span>{participant.previous_result_label ?? t('tournamentPage.enhancements.defending.noResult')}</span>
                    <strong>{t('tournamentPage.enhancements.defending.pointsShort', { count: participant.points_defending })}</strong>
                    <span>{participant.current_ranking_position ? `#${participant.current_ranking_position}` : '—'}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <p className="tlg-defence-note">{t('tournamentPage.enhancements.defending.note')}</p>
        </>
      )}
    </section>

    {historyOpen && typeof document !== 'undefined' && createPortal(
      <div className="tlg-past-winners-modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) setHistoryOpen(false) }}>
        <section className="tlg-past-winners-modal" role="dialog" aria-modal="true" aria-label={t('tournamentPage.enhancements.defending.modalAria')}>
          <header>
            <div><span>{t('tournamentPage.enhancements.defending.history')}</span><h3>{t('tournamentPage.enhancements.defending.pastWinners')}</h3><p>{t('tournamentPage.enhancements.defending.modalBody', { world: data?.world ?? '' })}</p></div>
            <button type="button" aria-label={t('tournamentPage.enhancements.defending.close')} onClick={() => setHistoryOpen(false)}><X size={18} /></button>
          </header>
          <div className="tlg-past-winners-modal-list">
            {pastWinners.map((winner) => (
              <article key={`modal-${winner.season_number}-${winner.player_id}`}>
                <div className="season"><Trophy size={15} /><span>{t('tournamentPage.enhancements.defending.season', { season: winner.season_number })}</span></div>
                <div className="winner">
                  <CountryFlag countryCode={winner.country_code} countryName={winner.country_code} width={21} height={14} />
                  <Link to={`/game/players/${winner.player_id}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: t('tournamentPage.enhancements.defending.backTournament') }} onClick={() => setHistoryOpen(false)}>
                    {winner.first_name} {winner.last_name}
                  </Link>
                  <small>{winner.is_ai ? t('tournamentPage.enhancements.defending.aiPlayer') : t('tournamentPage.enhancements.defending.managerPlayer')}</small>
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>,
      document.body,
    )}
    </>
  )
}
