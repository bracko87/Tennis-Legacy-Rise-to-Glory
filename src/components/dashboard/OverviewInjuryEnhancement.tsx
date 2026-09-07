import { createPortal } from 'react-dom'
import { Activity, ChevronRight, HeartPulse, ShieldCheck } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'

import { supabase } from '../../lib/supabase'
import '../../styles/overview-injury-enhancement.css'

type InjuryDashboard = {
  absolute_day: number
  healthy: boolean
  risk: { risk_percent: number; risk_level: string; reasons: string[] }
  current_injuries: Array<{
    id: string
    name: string
    body_area: string
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
  const [data, setData] = useState<InjuryDashboard | null>(null)

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
      if (!cancelled && !error && response) setData(response as InjuryDashboard)
    }
    void load()
    const timer = window.setInterval(() => void load(), 20000)
    return () => {
      cancelled = true
      window.clearInterval(timer)
    }
  }, [])

  const active = useMemo(() => data?.current_injuries[0] ?? null, [data])
  if (!target || !data) return null

  return createPortal(
    <section className={`tlg-overview-injury-card ${data.healthy ? 'healthy' : 'injured'}`}>
      <div className="tlg-overview-injury-icon">{data.healthy ? <ShieldCheck size={22} /> : <HeartPulse size={22} />}</div>
      <div className="tlg-overview-injury-main">
        <span>Injury & health</span>
        <strong>{data.healthy ? 'No active injury' : active?.name ?? 'Injury active'}</strong>
        <small>{data.healthy ? 'Training and tournament availability are clear.' : `${titleCase(active?.severity ?? '')} · ${active?.body_area ?? ''} · ${active?.progress_percent ?? 0}% recovered`}</small>
      </div>
      <div className={`tlg-overview-injury-risk risk-${data.risk.risk_level}`}>
        <Activity size={15} />
        <span>Risk</span>
        <strong>{titleCase(data.risk.risk_level)} · {Number(data.risk.risk_percent).toFixed(2)}%</strong>
      </div>
      {!data.healthy && active ? (
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
