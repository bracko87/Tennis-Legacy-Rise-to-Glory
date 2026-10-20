import { Fragment, useEffect, useMemo, useState } from 'react'
import { Crown, LockKeyhole } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import '../../styles/premium-deep-match.css'

type StatKey = 'first_serve_points_won' | 'first_serve_points_played' |
  'second_serve_points_won' | 'second_serve_points_played' |
  'unforced_errors' | 'break_points_won' | 'break_points_total'

type PlayerStats = Partial<Record<StatKey, number>> | null
type FactorKey = 'effective_overall' | 'serve' | 'return' | 'rally' | 'net' | 'physical' |
  'fatigue' | 'sharpness' | 'focus' | 'confidence' | 'morale' |
  'expression_multiplier' | 'surface_multiplier' | 'staff_bonus_pct' |
  'equipment_serve_pct' | 'equipment_rally_pct' | 'tactic_matchup_delta' |
  'injury_penalty' | 'playing_style'
type FactorValues = Partial<Record<FactorKey, number | string | null>>
type Player = { id: string; first_name: string; last_name: string; stats: PlayerStats }
type DeepMatchReport = {
  match_id: string
  tournament_name: string
  won: boolean
  player: Player
  opponent: Player
  factors: { source: string; player: FactorValues; opponent: FactorValues } | null
  context: { weather_condition?: string | null; temperature_c?: number | null; wind_kmh?: number | null } | null
}
type GroupName = 'ratings' | 'condition' | 'support'
type Row = { key: FactorKey; group: GroupName; format?: 'percent' | 'multiplier' | 'signedRatio' | 'text' }
const factors: Row[] = [
  { key: 'effective_overall', group: 'ratings' },
  { key: 'serve', group: 'ratings' },
  { key: 'return', group: 'ratings' },
  { key: 'rally', group: 'ratings' },
  { key: 'net', group: 'ratings' },
  { key: 'physical', group: 'ratings' },
  { key: 'fatigue', group: 'condition' },
  { key: 'sharpness', group: 'condition' },
  { key: 'focus', group: 'condition' },
  { key: 'confidence', group: 'condition' },
  { key: 'morale', group: 'condition' },
  { key: 'expression_multiplier', group: 'condition', format: 'percent' },
  { key: 'surface_multiplier', group: 'support', format: 'multiplier' },
  { key: 'staff_bonus_pct', group: 'support', format: 'signedRatio' },
  { key: 'equipment_serve_pct', group: 'support', format: 'signedRatio' },
  { key: 'equipment_rally_pct', group: 'support', format: 'signedRatio' },
  { key: 'tactic_matchup_delta', group: 'support', format: 'multiplier' },
  { key: 'injury_penalty', group: 'support' },
  { key: 'playing_style', group: 'support', format: 'text' },
]
function numeric(f: FactorValues | null, key: FactorKey): number | null {
  const value = f?.[key]
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}
function stat(s: PlayerStats, k: StatKey): number | null {
  const n = s?.[k]
  return typeof n === 'number' && Number.isFinite(n) ? n : null
}
function percentage(s: PlayerStats, a: StatKey, b: StatKey): number | null {
  const n = stat(s,a), d = stat(s,b)
  return n === null || d === null || d <= 0 ? null : 100*n/d
}
function display(row: Row, f: FactorValues | null): string {
  const value = f?.[row.key]
  if (value === undefined || value === null) return '—'
  if (row.format === 'text') return String(value)
  const n = numeric(f,row.key)
  if (n === null) return '—'
  if (row.format === 'percent') return (100*n).toFixed(1)+'%'
  if (row.format === 'multiplier') return (n >= 1 && row.key === 'surface_multiplier' ? '+' : n >= 0 && row.key !== 'surface_multiplier' ? '+' : '')+
    ((row.key === 'surface_multiplier' ? n-1 : n)*100).toFixed(2)+'%'
  if (row.format === 'signedRatio') return (n > 0 ? '+' : '')+n.toFixed(2)+'%'
  return n.toFixed(1)
}

export default function PremiumDeepMatchAnalysis({ matchId }: { matchId: string }) {
  const { t } = useTranslation()
  const { isPremium, loading: membershipLoading } = useCommerce()
  const [report, setReport] = useState<DeepMatchReport | null>(null)
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
        setReport(!requestError && data ? data as DeepMatchReport : null)
        setError(Boolean(requestError || !data))
        setLoading(false)
      }).catch(() => {
        if (!cancelled) { setReport(null); setError(true); setLoading(false) }
      })
    return () => { cancelled = true }
  }, [matchId,isPremium,membershipLoading])

  const observations = useMemo(() => {
    if (!report) return []
    const p = report.factors?.player ?? null, o = report.factors?.opponent ?? null
    const items: string[] = []
    const ownRating = numeric(p,'effective_overall'), otherRating = numeric(o,'effective_overall')
    if (ownRating !== null && otherRating !== null && Math.abs(ownRating-otherRating)>=3)
      items.push(t(ownRating>otherRating?'deepMatchAnalysis.overallAdvantage':'deepMatchAnalysis.overallDisadvantage',{
        value:Math.abs(ownRating-otherRating).toFixed(1),mine:ownRating.toFixed(1),other:otherRating.toFixed(1)
      }))
    const ownFatigue = numeric(p,'fatigue'), otherFatigue = numeric(o,'fatigue')
    if (ownFatigue !== null && otherFatigue !== null && Math.abs(ownFatigue-otherFatigue)>=10)
      items.push(t(ownFatigue<otherFatigue?'deepMatchAnalysis.fatigueAdvantage':'deepMatchAnalysis.fatigueDisadvantage',{
        value:Math.abs(ownFatigue-otherFatigue).toFixed(0)
      }))
    const serve = numeric(p,'serve'), otherServe = numeric(o,'serve')
    if (serve !== null && otherServe !== null && Math.abs(serve-otherServe)>=5)
      items.push(t(serve>otherServe?'deepMatchAnalysis.serveAdvantage':'deepMatchAnalysis.serveDisadvantage',{
        value:Math.abs(serve-otherServe).toFixed(1)
      }))
    const ownFirst = percentage(report.player.stats,'first_serve_points_won','first_serve_points_played')
    const otherFirst = percentage(report.opponent.stats,'first_serve_points_won','first_serve_points_played')
    if (ownFirst !== null && otherFirst !== null && Math.abs(ownFirst-otherFirst)>=8)
      items.push(t(ownFirst>otherFirst?'deepMatchAnalysis.firstServeEdge':'deepMatchAnalysis.firstServeGap',{
        value:Math.abs(ownFirst-otherFirst).toFixed(1)
      }))
    const ownSecond = percentage(report.player.stats,'second_serve_points_won','second_serve_points_played')
    const otherSecond = percentage(report.opponent.stats,'second_serve_points_won','second_serve_points_played')
    if (ownSecond !== null && otherSecond !== null && Math.abs(ownSecond-otherSecond)>=8)
      items.push(t(ownSecond>otherSecond?'deepMatchAnalysis.secondServeEdge':'deepMatchAnalysis.secondServeGap',{
        value:Math.abs(ownSecond-otherSecond).toFixed(1)
      }))
    const errors = stat(report.player.stats,'unforced_errors'), otherErrors = stat(report.opponent.stats,'unforced_errors')
    if (errors !== null && otherErrors !== null && Math.abs(errors-otherErrors)>=4)
      items.push(t(errors<otherErrors?'deepMatchAnalysis.errorAdvantage':'deepMatchAnalysis.errorGap',{
        value:Math.abs(errors-otherErrors)
      }))
    const ownBreak = percentage(report.player.stats,'break_points_won','break_points_total')
    const otherBreak = percentage(report.opponent.stats,'break_points_won','break_points_total')
    if (ownBreak !== null && otherBreak !== null && Math.abs(ownBreak-otherBreak)>=12)
      items.push(t(ownBreak>otherBreak?'deepMatchAnalysis.breakEdge':'deepMatchAnalysis.breakGap',{
        value:Math.abs(ownBreak-otherBreak).toFixed(1)
      }))
    return items.slice(0,6)
  },[report,t])

  return (
    <section className="tlg-deep-analysis" aria-label={t('deepMatchAnalysis.title')}>
      <div className="tlg-deep-analysis-head">
        <div>
          <span><Crown size={15} aria-hidden="true" /> {t('deepMatchAnalysis.premium')}</span>
          <h3>{t('deepMatchAnalysis.title')}</h3>
          <p>{t('deepMatchAnalysis.explainIntro')}</p>
        </div>
      </div>
      {membershipLoading || loading ? (
        <p className="tlg-deep-analysis-state">{t('deepMatchAnalysis.loading')}</p>
      ) : !isPremium ? (
        <div className="tlg-deep-analysis-locked">
          <LockKeyhole size={20} aria-hidden="true" />
          <p>{t('deepMatchAnalysis.explainLocked')}</p>
          <Link to="/game/pro-packages">{t('deepMatchAnalysis.viewPremium')}</Link>
        </div>
      ) : error ? (
        <p className="tlg-deep-analysis-state" role="alert">{t('deepMatchAnalysis.error')}</p>
      ) : !report ? (
        <p className="tlg-deep-analysis-state">{t('deepMatchAnalysis.notAvailable')}</p>
      ) : (
        <div className="tlg-deep-analysis-body">
          <div className="tlg-deep-analysis-summary">
            <div>
              <span>{t('deepMatchAnalysis.explainTitle')}</span>
              <strong>{t(report.won ? 'deepMatchAnalysis.won' : 'deepMatchAnalysis.lost')}</strong>
            </div>
            <p>{t('deepMatchAnalysis.explainCaution')}</p>
          </div>
          {report.factors?.player && report.factors?.opponent ? (
            <>
              <p className="tlg-deep-analysis-snapshot-note">{t('deepMatchAnalysis.snapshotNote')}</p>
              <div className="tlg-deep-analysis-scroll">
                <table>
                  <thead><tr>
                    <th>{t('deepMatchAnalysis.parameter')}</th>
                    <th>{t('deepMatchAnalysis.yourPlayer')}</th>
                    <th>{t('deepMatchAnalysis.opponent')}</th>
                  </tr></thead>
                  <tbody>
                    {(['ratings','condition','support'] as GroupName[]).map((group) => (
                      <Fragment key={group}>
                        <tr className="tlg-deep-analysis-group"><th colSpan={3}>{t('deepMatchAnalysis.factorGroups.'+group)}</th></tr>
                        {factors.filter((f) => f.group===group).map((row) => (
                          <tr key={row.key}><th scope="row">{t('deepMatchAnalysis.factors.'+row.key)}</th>
                            <td>{display(row,report.factors!.player)}</td>
                            <td>{display(row,report.factors!.opponent)}</td>
                          </tr>
                        ))}
                      </Fragment>
                    ))}
                  </tbody>
                </table>
              </div>
              {report.context?.weather_condition && (
                <p className="tlg-deep-analysis-context">{t('deepMatchAnalysis.weather')}: {report.context.weather_condition}
                  {typeof report.context.temperature_c === 'number' ? ' · '+report.context.temperature_c+'°C' : ''}
                  {typeof report.context.wind_kmh === 'number' ? ' · '+report.context.wind_kmh+' km/h' : ''}
                </p>
              )}
            </>
          ) : <p className="tlg-deep-analysis-state">{t('deepMatchAnalysis.snapshotUnavailable')}</p>}
          <div className="tlg-deep-analysis-observations">
            <h4>{t('deepMatchAnalysis.observations')}</h4>
            {observations.length > 0 ? <ul>{observations.map((note,index) => <li key={index}>{note}</li>)}</ul>
              : <p>{t('deepMatchAnalysis.noConclusions')}</p>}
            <small>{t('deepMatchAnalysis.disclaimer')}</small>
          </div>
        </div>
      )}
    </section>
  )
}
