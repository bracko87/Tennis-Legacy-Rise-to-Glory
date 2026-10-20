import { useEffect, useMemo, useState } from 'react'
import { BarChart3, Crown, LockKeyhole, TrendingUp } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { trainingEffectivenessLabels } from '../../lib/trainingEffectivenessI18n'
import '../../styles/training-effectiveness-premium.css'

type TrainingSource = 'regular' | 'camp'

type TrainingEvent = {
  id: string
  source: TrainingSource
  season: number
  game_week: number
  activity: string
  focus_attribute: string | null
  efficiency: number | null
  gains: Record<string, number>
  level_ups: Record<string, number>
  progress_total: number
  levels_total: number
}

type TrainingReport = {
  player_id: string
  events: TrainingEvent[]
  total_events: number
  window_limited: boolean
  window_events: number
  regular_sessions: number
  camp_days: number
  average_efficiency: number | null
  fractional_progress_total: number
  whole_level_ups: number
}

const skills = new Set([
  'serve','forehand','backhand','return_skill','volley','slice','drop_shot',
  'lob','smash','fitness','stamina','recovery','movement',
])

const asNumber = (value: unknown) =>
  typeof value === 'number' && Number.isFinite(value) ? value : 0

const asProgress = (value: number) => `+${value.toFixed(4)}`

export default function PremiumTrainingEffectiveness({ playerId }: { playerId: string | null }) {
  const { t, i18n } = useTranslation()
  const l = trainingEffectivenessLabels(i18n.resolvedLanguage ?? i18n.language)
  const { isPremium, loading: checkingPremium } = useCommerce()
  const [report, setReport] = useState<TrainingReport | null>(null)
  const [loading, setLoading] = useState(false)
  const [loadError, setLoadError] = useState(false)

  useEffect(() => {
    let cancelled = false
    setReport(null)
    setLoadError(false)
    if (!isPremium || checkingPremium || !playerId) {
      setLoading(false)
      return () => { cancelled = true }
    }
    setLoading(true)
    void supabase.rpc('get_premium_training_effectiveness_v1', { p_player_id: playerId })
      .then(({ data, error }) => {
        if (cancelled) return
        if (error || !data || (data as TrainingReport).player_id !== playerId) {
          setReport(null)
          setLoadError(true)
        } else {
          setReport(data as TrainingReport)
        }
        setLoading(false)
      })
      .catch(() => {
        if (!cancelled) {
          setLoadError(true)
          setLoading(false)
        }
      })
    return () => { cancelled = true }
  }, [isPremium, checkingPremium, playerId])

  const events = report?.events ?? []
  const byWeek = useMemo(() => {
    const values = new Map<string, {
      season: number; week: number; progress: number; levels: number; regular: number; camps: number
    }>()
    for (const e of events) {
      const key = `${e.season}:${e.game_week}`
      const current = values.get(key) ?? {
        season: e.season, week: e.game_week, progress: 0, levels: 0, regular: 0, camps: 0,
      }
      current.progress += asNumber(e.progress_total)
      current.levels += asNumber(e.levels_total)
      if (e.source === 'regular') current.regular++
      else current.camps++
      values.set(key, current)
    }
    return [...values.values()].sort((a, b) =>
      a.season === b.season ? a.week - b.week : a.season - b.season
    ).slice(-12)
  }, [report])

  const skillTotals = useMemo(() => {
    const totals = new Map<string, { progress: number; levels: number }>()
    for (const event of events) {
      for (const [name, gain] of Object.entries(event.gains ?? {})) {
        if (!skills.has(name)) continue
        const row = totals.get(name) ?? { progress: 0, levels: 0 }
        row.progress += asNumber(gain)
        totals.set(name, row)
      }
      for (const [name, levels] of Object.entries(event.level_ups ?? {})) {
        if (!skills.has(name)) continue
        const row = totals.get(name) ?? { progress: 0, levels: 0 }
        row.levels += asNumber(levels)
        totals.set(name, row)
      }
    }
    return [...totals.entries()]
      .map(([key, value]) => ({ key, ...value }))
      .filter(row => row.progress > 0 || row.levels > 0)
      .sort((a, b) => b.progress - a.progress || a.key.localeCompare(b.key))
      .slice(0, 8)
  }, [report])

  const maxWeek = Math.max(0.01, ...byWeek.map(w => w.progress))
  const skillLabel = (key: string) => t(`developmentPremium.attributes.${key}`)
  const gameWeek = (season: number, week: number) =>
    `${t('statisticsPage.season', { season })} · ${t('overviewPage.week', { week })}`
  const activityLabel = (event: TrainingEvent) =>
    event.source === 'camp' ? l.campDevelopment
      : event.activity === 'physical' ? l.physical
      : l.technical

  return (
    <section className="tlg-tep" aria-label={l.title}>
      <header className="tlg-tep-header">
        <div>
          <span className="tlg-tep-kicker"><Crown size={15} aria-hidden="true" /> PREMIUM · {l.title}</span>
          <h2>{l.title}</h2>
          <p>{l.intro}</p>
        </div>
        <BarChart3 size={23} aria-hidden="true" />
      </header>
      {checkingPremium || loading ? <p className="tlg-tep-state">{l.loading}</p>
      : !isPremium ? (
        <div className="tlg-tep-locked">
          <LockKeyhole size={24} aria-hidden="true" />
          <p>{l.locked}</p>
          <Link to="/game/pro-packages">{l.viewPlans}</Link>
        </div>
      ) : loadError ? <p className="tlg-tep-state" role="alert">{l.error}</p>
      : !report || events.length === 0 ? <p className="tlg-tep-state">{l.empty}</p>
      : (
        <div className="tlg-tep-body">
          <div className="tlg-tep-metrics">
            <div><span>{l.sessions}</span><strong>{report.window_events}</strong></div>
            <div><span>{l.regular}</span><strong>{report.regular_sessions}</strong></div>
            <div><span>{l.camp}</span><strong>{report.camp_days}</strong></div>
            <div><span>{l.avgEfficiency}</span><strong>{report.average_efficiency === null ? '—' : `${(report.average_efficiency * 100).toFixed(1)}%`}</strong></div>
            <div><span>{l.progress}</span><strong>{asProgress(asNumber(report.fractional_progress_total))}</strong></div>
            <div><span>{l.levelUps}</span><strong>{report.whole_level_ups}</strong></div>
          </div>
          {report.window_limited && <p className="tlg-tep-warning">{l.limited}</p>}
          <p className="tlg-tep-caption">{l.scope}</p>
          <div className="tlg-tep-columns">
            <section className="tlg-tep-panel">
              <h3><TrendingUp size={16} aria-hidden="true" /> {l.weekly}</h3>
              <div className="tlg-tep-week-list">
                {byWeek.map(w => (
                  <div className="tlg-tep-week" key={`${w.season}:${w.week}`}>
                    <span>{gameWeek(w.season, w.week)}</span>
                    <div className="tlg-tep-bar" aria-hidden="true">
                      <span style={{ width: `${Math.min(100, w.progress / maxWeek * 100)}%` }} />
                    </div>
                    <strong>{asProgress(w.progress)}</strong>
                  </div>
                ))}
              </div>
            </section>
            <section className="tlg-tep-panel">
              <h3>{l.topSkills}</h3>
              {skillTotals.length ? (
                <div className="tlg-tep-table-wrap">
                  <table>
                    <thead><tr><th>{l.skill}</th><th>{l.progressValue}</th><th>{l.levelsValue}</th></tr></thead>
                    <tbody>{skillTotals.map(item => (
                      <tr key={item.key}>
                        <th scope="row">{skillLabel(item.key)}</th>
                        <td>{asProgress(item.progress)}</td>
                        <td>{item.levels > 0 ? `+${item.levels}` : '—'}</td>
                      </tr>
                    ))}</tbody>
                  </table>
                </div>
              ) : <p className="tlg-tep-caption">{l.empty}</p>}
            </section>
          </div>
          <section className="tlg-tep-panel tlg-tep-recent">
            <h3>{l.perEvent}</h3>
            <div className="tlg-tep-table-wrap">
              <table>
                <thead><tr>
                  <th>{l.gameWeek}</th><th>{l.source}</th><th>{l.focus}</th>
                  <th>{l.efficiency}</th><th>{l.progressValue}</th><th>{l.levelsValue}</th>
                </tr></thead>
                <tbody>{events.slice(0, 10).map(e => (
                  <tr key={`${e.source}:${e.id}`}>
                    <td>{gameWeek(e.season, e.game_week)}</td>
                    <td>{e.source === 'regular' ? l.regularText : l.campText}</td>
                    <td>{e.focus_attribute && skills.has(e.focus_attribute) ? skillLabel(e.focus_attribute) : activityLabel(e)}</td>
                    <td>{e.efficiency === null ? '—' : `${(asNumber(e.efficiency) * 100).toFixed(1)}%`}</td>
                    <td>{asProgress(asNumber(e.progress_total))}</td>
                    <td>{e.levels_total > 0 ? `+${e.levels_total}` : '—'}</td>
                  </tr>
                ))}</tbody>
              </table>
            </div>
          </section>
          <p className="tlg-tep-caption">{l.caution}</p>
        </div>
      )}
    </section>
  )
}
