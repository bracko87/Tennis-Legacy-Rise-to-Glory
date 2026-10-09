import { createPortal } from 'react-dom'
import { Activity, ChevronRight, HeartPulse, ShieldCheck, Thermometer } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'

import { supabase } from '../../lib/supabase'
import '../../styles/overview-injury-enhancement.css'

type HealthDashboard = {
  absolute_day: number
  summary: {
    state: string
    label: string
    can_train: boolean
    can_compete: boolean
    injury_risk: { risk_percent: number; risk_level: string; reasons: string[] }
    illness_risk: { risk_percent: number; risk_level: string; reasons: string[] }
  }
  current_conditions: Array<{
    id: string
    kind: 'injury' | 'illness'
    name: string
    body_area: string | null
    severity: string
    progress_percent: number
    training_return_absolute_day: number
    tournament_return_absolute_day: number
    expected_full_recovery_absolute_day: number
    can_train: boolean
    can_compete: boolean
  }>
}

function titleCase(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function daysUntil(target: number, current: number, t: ReturnType<typeof useTranslation>['t']) {
  const days = Math.max(0, target - current)
  return days === 0 ? t('overviewPage.healthCard.now') : t('overviewPage.healthCard.inDays', { count: days })
}

export default function OverviewInjuryEnhancement() {
  const { t } = useTranslation()
  const [target, setTarget] = useState<HTMLElement | null>(null)
  const [data, setData] = useState<HealthDashboard | null>(null)

  useEffect(() => {
    let frame = 0
    let cancelled = false
    let host: HTMLElement | null = null
    const locate = () => {
      if (cancelled) return
      const kpis = document.querySelector<HTMLElement>('.tlg-overview-kpis')
      if (kpis?.parentElement) {
        host = document.querySelector<HTMLElement>('[data-tlg-overview-injury-host="true"]')
        if (!host) {
          host = document.createElement('div')
          host.dataset.tlgOverviewInjuryHost = 'true'
          host.className = 'tlg-overview-injury-host'
          kpis.insertAdjacentElement('afterend', host)
        }
        setTarget(host)
        return
      }
      frame = window.requestAnimationFrame(locate)
    }
    frame = window.requestAnimationFrame(locate)
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      host?.remove()
      setTarget(null)
    }
  }, [])

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      const { data: response, error } = await supabase.rpc('get_player_injury_dashboard_v1')
      if (!cancelled && !error && response) setData(response as HealthDashboard)
    }
    void load()
    const timer = window.setInterval(() => void load(), 20000)
    return () => {
      cancelled = true
      window.clearInterval(timer)
    }
  }, [])

  const active = useMemo(() => data?.current_conditions[0] ?? null, [data])
  if (!target || !data) return null

  const healthy = data.current_conditions.length === 0 && ['healthy', 'fully_recovered'].includes(data.summary.state)
  const riskOnly = data.current_conditions.length === 0 && data.summary.state === 'at_risk'
  const cardClass = healthy ? 'healthy' : 'injured'
  const stateText = t(`healthPage.state.${data.summary.state}`, { defaultValue: data.summary.label })

  return createPortal(
    <section className={`tlg-overview-injury-card ${cardClass}`}>
      <div className="tlg-overview-injury-icon">{healthy ? <ShieldCheck size={22} /> : <HeartPulse size={22} />}</div>
      <div className="tlg-overview-injury-main">
        <span>{t('overviewPage.healthCard.title')}</span>
        <strong>{active?.name ?? stateText}</strong>
        <small>{active ? `${active.kind === 'injury' ? t('healthPage.injury') : t('healthPage.illness')} · ${t(`healthPage.severity.${active.severity}`, { defaultValue: titleCase(active.severity) })}${active.body_area ? ` · ${active.body_area}` : ''} · ${t('overviewPage.healthCard.recovered', { value: active.progress_percent })}` : riskOnly ? t('overviewPage.healthCard.riskOnly') : t('overviewPage.healthCard.clear')}</small>
      </div>
      <div className={`tlg-overview-injury-risk risk-${data.summary.injury_risk.risk_level}`}>
        <Activity size={15} />
        <span>{t('overviewPage.healthCard.injuryRisk')}</span>
        <strong>{t(`healthPage.risk.${data.summary.injury_risk.risk_level}`, { defaultValue: titleCase(data.summary.injury_risk.risk_level) })} · {Number(data.summary.injury_risk.risk_percent).toFixed(2)}%</strong>
      </div>
      <div className={`tlg-overview-injury-risk risk-${data.summary.illness_risk.risk_level}`}>
        <Thermometer size={15} />
        <span>{t('overviewPage.healthCard.illnessRisk')}</span>
        <strong>{t(`healthPage.risk.${data.summary.illness_risk.risk_level}`, { defaultValue: titleCase(data.summary.illness_risk.risk_level) })} · {Number(data.summary.illness_risk.risk_percent).toFixed(2)}%</strong>
      </div>
      {active ? (
        <div className="tlg-overview-injury-availability">
          <div><span>{t('overviewPage.healthCard.training')}</span><strong>{active.can_train ? t('overviewPage.healthCard.available') : daysUntil(active.training_return_absolute_day, data.absolute_day, t)}</strong></div>
          <div><span>{t('overviewPage.healthCard.tournaments')}</span><strong>{active.can_compete ? t('overviewPage.healthCard.available') : daysUntil(active.tournament_return_absolute_day, data.absolute_day, t)}</strong></div>
          <div><span>{t('overviewPage.healthCard.fullRecovery')}</span><strong>{daysUntil(active.expected_full_recovery_absolute_day, data.absolute_day, t)}</strong></div>
        </div>
      ) : null}
      <Link to="/game/injuries">{t('overviewPage.healthCard.open')} <ChevronRight size={15} /></Link>
    </section>,
    target,
  )
}
