import { Minus, ShieldCheck, TrendingDown, TrendingUp } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
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
  const location = useLocation()
  const [data, setData] = useState<DefendingPointsResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expanded, setExpanded] = useState(false)

  useEffect(() => {
    setExpanded(false)
  }, [competitionId])

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
      const { data: response, error: loadError } = await supabase.rpc('get_tournament_defending_points_v1', {
        p_competition_id: competitionId,
      })
      if (!active) return
      if (loadError || !response) {
        setData(null)
        setError(loadError?.message ?? 'Defending-points data is unavailable.')
      } else {
        setData(response as DefendingPointsResponse)
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

  return (
    <section className={`tlg-detail-panel tlg-defence-panel${expanded ? '' : ' collapsed'}`}>
      <header className="tlg-detail-panel-head tlg-defence-head">
        <div>
          <span>Ranking protection</span>
          <h2>Defending Points</h2>
          {expanded && <p>Last season's points from this same tournament series stay in the ranking until this edition's ranking cycle replaces them.</p>}
        </div>
        <div className="tlg-defence-head-actions">
          {data && <span>{data.own.points_defending.toLocaleString()} pts defending</span>}
          <button type="button" aria-expanded={expanded} onClick={() => setExpanded((value) => !value)}>
            {expanded ? 'Collapse' : 'Expand'}
          </button>
          <ShieldCheck size={20} />
        </div>
      </header>

      {loading ? (
        <div className="tlg-defence-state">Loading defending points…</div>
      ) : error || !data ? (
        <div className="tlg-defence-state tlg-defence-error">{error ?? 'Defending-points data is unavailable.'}</div>
      ) : (
        <>
          <div className="tlg-defence-status-row">
            <div>
              <span>{data.previous_season_number ? `Season ${data.previous_season_number} result` : 'First-season event'}</span>
              <strong>{data.own.previous_result_label ?? (data.previous_season_number ? 'Did not play / no points' : 'No previous edition')}</strong>
            </div>
            <div className={`tlg-defence-cycle-status ${data.cycle_processed ? 'processed' : 'pending'}`}>
              <span>{data.cycle_processed ? 'Ranking cycle processed' : 'Defence pending'}</span>
              <strong>{data.cycle_processed ? 'Old contribution replaced' : `${data.own.points_defending.toLocaleString()} pts at risk`}</strong>
            </div>
          </div>

          <div className="tlg-defence-summary-grid">
            <article>
              <span>Last season points</span>
              <strong>{data.own.previous_points.toLocaleString()}</strong>
              <small>Historical result remains stored</small>
            </article>
            <article className="primary">
              <span>Points defending this year</span>
              <strong>{data.own.points_defending.toLocaleString()}</strong>
              <small>{data.cycle_processed ? 'Already removed/replaced' : 'Removed at this edition’s ranking update'}</small>
            </article>
            <article>
              <span>Current ranking</span>
              <strong>{data.own.current_ranking_position ? `#${data.own.current_ranking_position}` : 'Unranked'}</strong>
              <small>{data.own.current_ranking_points.toLocaleString()} total points</small>
            </article>
            <article>
              <span>Current edition result</span>
              <strong>{data.own.current_result_label ?? 'Not finalized'}</strong>
              <small>{data.own.current_result_code ? `${data.own.current_result_points.toLocaleString()} pts · ${data.own.current_result_publish_status ?? 'pending'}` : 'No new contribution yet'}</small>
            </article>
          </div>

          {!data.cycle_processed && data.previous_season_number && outcomes.length > 0 && (
            <div className="tlg-defence-outcomes">
              <div className="tlg-defence-subhead">
                <div><span>Your scenarios</span><strong>Possible ranking-point change</strong></div>
                <small>Net = current-edition points − {data.own.points_defending.toLocaleString()} defending points</small>
              </div>
              <div className="tlg-defence-outcome-grid">
                {outcomes.map((row) => (
                  <div key={row.stage_code} className={`tlg-defence-outcome ${row.net > 0 ? 'positive' : row.net < 0 ? 'negative' : 'neutral'}`}>
                    <span>{row.stage_label}</span>
                    <strong>{row.ranking_points.toLocaleString()} pts</strong>
                    <small><NetIcon value={row.net} /> Net {signedPoints(row.net)}</small>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="tlg-defence-field">
            <div className="tlg-defence-subhead">
              <div><span>Tournament field</span><strong>Other players defending points</strong></div>
              <small>Confirmed entrants with an active contribution from last season.</small>
            </div>

            {fieldDefenders.length === 0 ? (
              <div className="tlg-defence-field-empty">
                {data.previous_season_number
                  ? 'No confirmed entrant is currently defending points here, or the field has not been allocated yet.'
                  : 'Season 1 has no previous-edition points to defend.'}
              </div>
            ) : (
              <div className="tlg-defence-table">
                <div className="tlg-defence-table-row head"><span>Player</span><span>Last season</span><span>Defending</span><span>Rank</span></div>
                {fieldDefenders.map((participant) => (
                  <div className="tlg-defence-table-row" key={participant.player_id}>
                    <span className="player">
                      <CountryFlag countryCode={participant.country_code} countryName={participant.country_code} width={20} height={14} />
                      <Link to={`/game/players/${participant.player_id}`} state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: 'Back to Tournament' }}>
                        {participant.first_name} {participant.last_name}
                      </Link>
                    </span>
                    <span>{participant.previous_result_label ?? 'No result'}</span>
                    <strong>{participant.points_defending.toLocaleString()} pts</strong>
                    <span>{participant.current_ranking_position ? `#${participant.current_ranking_position}` : '—'}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <p className="tlg-defence-note">If a player skips, is injured, withdraws before earning a result, or otherwise has no current contribution, the previous-season contribution expires at this tournament’s processed ranking cycle. A category or points-table change does not alter the amount being defended: the exact points actually earned last season are removed, and the current edition uses its current points table.</p>
        </>
      )}
    </section>
  )
}
