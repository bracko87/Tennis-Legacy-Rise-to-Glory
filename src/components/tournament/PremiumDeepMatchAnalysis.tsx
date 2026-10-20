import { Fragment, useEffect, useMemo, useState } from 'react'
import { Crown, LockKeyhole } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import '../../styles/premium-deep-match.css'

type StatKey =
  | 'aces' | 'double_faults' | 'first_serves_in' | 'first_serves_total'
  | 'first_serve_points_won' | 'first_serve_points_played'
  | 'second_serve_points_won' | 'second_serve_points_played'
  | 'break_points_won' | 'break_points_total'
  | 'winners' | 'unforced_errors' | 'total_points_won'

type MatchStats = Partial<Record<StatKey, number>> | null

type AnalysisPlayer = {
  id: string
  first_name: string
  last_name: string
  country_code: string | null
  stats: MatchStats
}

type AnalysisSet = {
  set_number: number
  my_games: number
  opponent_games: number
  my_tiebreak_points: number | null
  opponent_tiebreak_points: number | null
}

type AnalysisReport = {
  match_id: string
  tournament_name: string
  round_label: string
  world: string
  won: boolean
  player: AnalysisPlayer
  opponent: AnalysisPlayer
  sets: AnalysisSet[]
}

type Group = 'serve' | 'breakPoints' | 'shots' | 'points'
type Metric = {
  key: string
  group: Group
  read: (stats: MatchStats, other: MatchStats) => number | null
  unit?: '%'
}

function count(stats: MatchStats, key: StatKey): number | null {
  const value = stats?.[key]
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function ratio(stats: MatchStats, earned: StatKey, played: StatKey): number | null {
  const top = count(stats, earned)
  const bottom = count(stats, played)
  return top === null || bottom === null || bottom <= 0 ? null : 100 * top / bottom
}

function servicePoints(stats: MatchStats, key: 'won' | 'played'): number | null {
  const first = count(stats, key === 'won' ? 'first_serve_points_won' : 'first_serve_points_played')
  const second = count(stats, key === 'won' ? 'second_serve_points_won' : 'second_serve_points_played')
  return first === null || second === null ? null : first + second
}

function serviceWinPercent(stats: MatchStats): number | null {
  const won = servicePoints(stats, 'won')
  const played = servicePoints(stats, 'played')
  return won === null || played === null || played <= 0 ? null : won / played * 100
}

function pointShare(stats: MatchStats, other: MatchStats): number | null {
  const own = count(stats, 'total_points_won')
  const theirs = count(other, 'total_points_won')
  return own === null || theirs === null || own + theirs <= 0 ? null : 100 * own / (own + theirs)
}

const metrics: Metric[] = [
  { key: 'aces', group: 'serve', read: (s) => count(s, 'aces') },
  { key: 'doubleFaults', group: 'serve', read: (s) => count(s, 'double_faults') },
  { key: 'firstServesIn', group: 'serve', read: (s) => count(s, 'first_serves_in') },
  { key: 'firstServesTotal', group: 'serve', read: (s) => count(s, 'first_serves_total') },
  { key: 'firstServePercent', group: 'serve', read: (s) => ratio(s, 'first_serves_in', 'first_serves_total'), unit: '%' },
  { key: 'firstServeWon', group: 'serve', read: (s) => count(s, 'first_serve_points_won') },
  { key: 'firstServePlayed', group: 'serve', read: (s) => count(s, 'first_serve_points_played') },
  { key: 'firstServeWinPercent', group: 'serve', read: (s) => ratio(s, 'first_serve_points_won', 'first_serve_points_played'), unit: '%' },
  { key: 'secondServeWon', group: 'serve', read: (s) => count(s, 'second_serve_points_won') },
  { key: 'secondServePlayed', group: 'serve', read: (s) => count(s, 'second_serve_points_played') },
  { key: 'secondServeWinPercent', group: 'serve', read: (s) => ratio(s, 'second_serve_points_won', 'second_serve_points_played'), unit: '%' },
  { key: 'serviceWinPercent', group: 'serve', read: (s) => serviceWinPercent(s), unit: '%' },
  { key: 'breakWon', group: 'breakPoints', read: (s) => count(s, 'break_points_won') },
  { key: 'breakTotal', group: 'breakPoints', read: (s) => count(s, 'break_points_total') },
  { key: 'breakConversion', group: 'breakPoints', read: (s) => ratio(s, 'break_points_won', 'break_points_total'), unit: '%' },
  { key: 'winners', group: 'shots', read: (s) => count(s, 'winners') },
  { key: 'errors', group: 'shots', read: (s) => count(s, 'unforced_errors') },
  { key: 'winnerErrorBalance', group: 'shots', read: (s) => {
    const a = count(s, 'winners'), b = count(s, 'unforced_errors')
    return a === null || b === null ? null : a - b
  } },
  { key: 'totalPoints', group: 'points', read: (s) => count(s, 'total_points_won') },
  { key: 'pointShare', group: 'points', read: pointShare, unit: '%' },
]

function formatMetric(value: number | null, unit?: '%') {
  return value === null ? '—' : `${unit ? value.toFixed(1) : Number.isInteger(value) ? String(value) : value.toFixed(1)}${unit ?? ''}`
}

export default function PremiumDeepMatchAnalysis({ matchId }: { matchId: string }) {
  const { t } = useTranslation()
  const { isPremium, loading: membershipLoading } = useCommerce()
  const [report, setReport] = useState<AnalysisReport | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(false)

  useEffect(() => {
    let cancelled = false
    setReport(null)
    setError(false)
    if (!isPremium || membershipLoading) {
      setLoading(false)
      return () => { cancelled = true }
    }
    setLoading(true)
    void supabase.rpc('get_premium_deep_match_analysis_v1', { p_match_id: matchId })
      .then(({ data, error: requestError }) => {
        if (cancelled) return
        setReport(!requestError && data ? data as AnalysisReport : null)
        setError(Boolean(requestError || !data))
        setLoading(false)
      }).catch(() => {
        if (!cancelled) { setError(true); setLoading(false) }
      })
    return () => { cancelled = true }
  }, [matchId, isPremium, membershipLoading])

  const notes = useMemo(() => {
    if (!report) return []
    const mine = report.player.stats, theirs = report.opponent.stats
    const observations: string[] = []
    const first = ratio(mine, 'first_serve_points_won', 'first_serve_points_played')
    const theirFirst = ratio(theirs, 'first_serve_points_won', 'first_serve_points_played')
    if (first !== null && theirFirst !== null && theirFirst - first >= 8)
      observations.push(t('deepMatchAnalysis.firstServeGap', { value: (theirFirst - first).toFixed(1) }))
    const second = ratio(mine, 'second_serve_points_won', 'second_serve_points_played')
    const theirSecond = ratio(theirs, 'second_serve_points_won', 'second_serve_points_played')
    if (second !== null && theirSecond !== null && theirSecond - second >= 8)
      observations.push(t('deepMatchAnalysis.secondServeGap', { value: (theirSecond - second).toFixed(1) }))
    const myErrors = count(mine, 'unforced_errors'), theirErrors = count(theirs, 'unforced_errors')
    if (myErrors !== null && theirErrors !== null && myErrors - theirErrors >= 4)
      observations.push(t('deepMatchAnalysis.errorGap', { value: myErrors - theirErrors }))
    const myBreak = ratio(mine, 'break_points_won', 'break_points_total')
    const theirBreak = ratio(theirs, 'break_points_won', 'break_points_total')
    if (myBreak !== null && theirBreak !== null && theirBreak - myBreak >= 12)
      observations.push(t('deepMatchAnalysis.breakGap', { value: (theirBreak - myBreak).toFixed(1) }))
    return observations.slice(0, 3)
  }, [report, t])

  const playerName = report ? `${report.player.first_name} ${report.player.last_name}` : ''
  const opponentName = report ? `${report.opponent.first_name} ${report.opponent.last_name}` : ''
  return (
    <section className="tlg-deep-analysis" aria-label={t('deepMatchAnalysis.title')}>
      <div className="tlg-deep-analysis-head">
        <div>
          <span><Crown size={15} /> {t('deepMatchAnalysis.premium')}</span>
          <h3>{t('deepMatchAnalysis.title')}</h3>
          <p>{t('deepMatchAnalysis.intro')}</p>
        </div>
      </div>
      {membershipLoading || loading ? (
        <p className="tlg-deep-analysis-state">{t('deepMatchAnalysis.loading')}</p>
      ) : !isPremium ? (
        <div className="tlg-deep-analysis-locked">
          <LockKeyhole size={20} />
          <p>{t('deepMatchAnalysis.locked')}</p>
          <Link to="/game/pro-packages">{t('deepMatchAnalysis.viewPremium')}</Link>
        </div>
      ) : error ? (
        <p className="tlg-deep-analysis-state" role="alert">{t('deepMatchAnalysis.error')}</p>
      ) : !report ? (
        <p className="tlg-deep-analysis-state">{t('deepMatchAnalysis.notAvailable')}</p>
      ) : (
        <div className="tlg-deep-analysis-body">
          <div className="tlg-deep-analysis-players">
            <strong>{playerName} · {t(report.won ? 'deepMatchAnalysis.won' : 'deepMatchAnalysis.lost')}</strong>
            <strong>{opponentName}</strong>
          </div>
          {report.sets.length > 0 && <p className="tlg-deep-analysis-sets">
            {t('deepMatchAnalysis.sets')}: {report.sets.map((set) => `${set.my_games}–${set.opponent_games}`).join(' · ')}
          </p>}
          {!report.player.stats || !report.opponent.stats ? (
            <p className="tlg-deep-analysis-state">{t('deepMatchAnalysis.missingStats')}</p>
          ) : null}
          <div className="tlg-deep-analysis-scroll">
            <table>
              <thead><tr><th>{t('deepMatchAnalysis.parameter')}</th><th>{t('deepMatchAnalysis.yourPlayer')}</th><th>{t('deepMatchAnalysis.opponent')}</th></tr></thead>
              <tbody>
                {(['serve','breakPoints','shots','points'] as Group[]).map((group) => (
                  <Fragment key={group}>
                    <tr className="tlg-deep-analysis-group"><th colSpan={3}>{t(`deepMatchAnalysis.groups.${group}`)}</th></tr>
                    {metrics.filter((m) => m.group === group).map((metric) => (
                      <tr key={metric.key}>
                        <th scope="row">{t(`deepMatchAnalysis.metrics.${metric.key}`)}</th>
                        <td>{formatMetric(metric.read(report.player.stats, report.opponent.stats), metric.unit)}</td>
                        <td>{formatMetric(metric.read(report.opponent.stats, report.player.stats), metric.unit)}</td>
                      </tr>
                    ))}
                  </Fragment>
                ))}
              </tbody>
            </table>
          </div>
          <div className="tlg-deep-analysis-observations">
            <h4>{t('deepMatchAnalysis.observations')}</h4>
            {notes.length > 0 ? <ul>{notes.map((note, index) => <li key={index}>{note}</li>)}</ul>
              : <p>{t('deepMatchAnalysis.noConclusions')}</p>}
            <small>{t('deepMatchAnalysis.disclaimer')}</small>
          </div>
        </div>
      )}
    </section>
  )
}
