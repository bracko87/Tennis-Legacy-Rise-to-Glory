import { createPortal } from 'react-dom'
import { AlertTriangle, CheckCircle2, HeartPulse } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'

import { supabase } from '../../lib/supabase'
import '../../styles/training-health-status.css'

type HealthDashboard = {
  summary: {
    state: string
    label: string
    can_train: boolean
    can_compete: boolean
    performance_penalty: number
    fatigue: number
    primary_condition: null | { kind: string; name: string; severity: string; progress_percent: number }
    injury_risk: { risk_level: string; risk_percent: number }
    illness_risk: { risk_level: string; risk_percent: number }
  }
}

export default function TrainingHealthStatus() {
  const { t } = useTranslation()
  const [host, setHost] = useState<HTMLElement | null>(null)
  const [data, setData] = useState<HealthDashboard | null>(null)

  useEffect(() => {
    let frame = 0
    let disposed = false
    let node: HTMLElement | null = null
    const locate = () => {
      if (disposed) return
      const hero = document.querySelector<HTMLElement>('.tlg-training-hero')
      if (!hero) { frame = window.requestAnimationFrame(locate); return }
      node = document.querySelector<HTMLElement>('[data-tlg-training-health-host="true"]')
      if (!node) {
        node = document.createElement('div')
        node.dataset.tlgTrainingHealthHost = 'true'
        hero.insertAdjacentElement('afterend', node)
      }
      setHost(node)
    }
    frame = window.requestAnimationFrame(locate)
    return () => { disposed = true; window.cancelAnimationFrame(frame); node?.remove(); setHost(null) }
  }, [])

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      const { data: response, error } = await supabase.rpc('get_player_injury_dashboard_v1')
      if (!cancelled && !error && response) setData(response as HealthDashboard)
    }
    void load()
    const timer = window.setInterval(() => void load(), 20000)
    return () => { cancelled = true; window.clearInterval(timer) }
  }, [])

  if (!host || !data) return null
  const { summary } = data
  const danger = !summary.can_train
  const elevatedRisk = ['elevated', 'high', 'very_high']
  const caution = !danger && (
    summary.state === 'at_risk'
    || summary.state === 'not_fully_fit'
    || summary.state === 'recovering'
    || summary.fatigue >= 65
    || elevatedRisk.includes(summary.injury_risk.risk_level)
    || elevatedRisk.includes(summary.illness_risk.risk_level)
  )
  const condition = summary.primary_condition

  return createPortal(
    <section className={`tlg-training-health-status ${danger ? 'blocked' : caution ? 'caution' : 'clear'}`}>
      <div className="icon">{danger ? <HeartPulse size={20} /> : caution ? <AlertTriangle size={20} /> : <CheckCircle2 size={20} />}</div>
      <div>
        <span>{t('trainingPage.health.clearance')}</span>
        <strong>{danger ? t('trainingPage.health.blocked') : caution ? t('trainingPage.health.careful', { label: summary.label }) : t('trainingPage.health.cleared', { label: summary.label })}</strong>
        <small>{condition
          ? t('trainingPage.health.recovered', { kind: condition.kind === 'illness' ? t('trainingPage.health.illness') : t('trainingPage.health.injury'), name: condition.name, percent: condition.progress_percent })
          : t('trainingPage.health.risks', { fatigue: summary.fatigue, injury: Number(summary.injury_risk.risk_percent).toFixed(2), illness: Number(summary.illness_risk.risk_percent).toFixed(2) })}</small>
      </div>
      <Link to="/game/injuries">{t('trainingPage.health.openHealth')}</Link>
    </section>,
    host,
  )
}
