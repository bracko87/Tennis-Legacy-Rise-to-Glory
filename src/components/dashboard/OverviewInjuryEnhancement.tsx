import { createPortal } from 'react-dom'
import { Activity, ChevronRight, HeartPulse, ShieldCheck, Thermometer } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
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

function daysUntil(target: number, current: number) {
  const days = Math.max(0, target - current)
  return days === 0 ? 'Now' : `${days}d`
}

export default function OverviewInjuryEnhancement() {
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
  const stateText = data.summary.label

  return createPortal(
    <section className={`tlg-overview-injury-card ${cardClass}`}>
      <div className="tlg-overview-injury-icon">{healthy ? <ShieldCheck size={22} /> : <HeartPulse size={22} />}</div>
      <div className="tlg-overview-injury-main">
        <span>Injury & health</span>
        <strong>{active?.name ?? stateText}</strong>
        <small>{active ? `${titleCase(active.kind)} · ${titleCase(active.severity)}${active.body_area ? ` · ${active.body_area}` : ''} · ${active.progress_percent}% recovered` : riskOnly ? 'No active condition, but current workload/condition has raised health risk.' : 'Training and tournament availability are clear.'}</small>
      </div>
      <div className={`tlg-overview-injury-risk risk-${data.summary.injury_risk.risk_level}`}>
        <Activity size={15} />
        <span>Injury risk</span>
        <strong>{titleCase(data.summary.injury_risk.risk_level)} · {Number(data.summary.injury_risk.risk_percent).toFixed(2)}%</strong>
      </div>
      <div className={`tlg-overview-injury-risk risk-${data.summary.illness_risk.risk_level}`}>
        <Thermometer size={15} />
        <span>Illness risk</span>
        <strong>{titleCase(data.summary.illness_risk.risk_level)} · {Number(data.summary.illness_risk.risk_percent).toFixed(2)}%</strong>
      </div>
      {active ? (
        <div className="tlg-overview-injury-availability">
          <div><span>Training</span><strong>{active.can_train ? 'Available' : `In ${daysUntil(active.training_return_absolute_day, data.absolute_day)}`}</strong></div>
          <div><span>Tournaments</span><strong>{active.can_compete ? 'Available' : `In ${daysUntil(active.tournament_return_absolute_day, data.absolute_day)}`}</strong></div>
          <div><span>Full recovery</span><strong>{daysUntil(active.expected_full_recovery_absolute_day, data.absolute_day)}</strong></div>
        </div>
      ) : null}
      <Link to="/game/injuries">Open Injury & Health <ChevronRight size={15} /></Link>
    </section>,
    target,
  )
}
