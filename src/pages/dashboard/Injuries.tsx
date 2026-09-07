import { Activity, AlertTriangle, CheckCircle2, Clock3, HeartPulse, ShieldCheck, Stethoscope } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/injuries.css'

type Severity = 'minor' | 'moderate' | 'major' | 'severe'

type Treatment = {
  code: string
  label: string
  description: string
  care_level: string
  notes: string | null
}

type ActiveInjury = {
  id: string
  injury_code: string
  name: string
  body_area: string
  injury_group: string
  severity: Severity
  description: string
  causes: string[]
  source_type: string
  onset_absolute_day: number
  training_return_absolute_day: number
  tournament_return_absolute_day: number
  expected_full_recovery_absolute_day: number
  progress_percent: number
  performance_penalty: number
  aggravation_risk: number
  skill_effects: Record<string, number>
  treatment: Treatment
  can_train: boolean
  can_compete: boolean
}

type InjuryHistory = {
  id: string
  injury_code: string
  name: string
  body_area: string
  severity: Severity
  source_type: string
  onset_absolute_day: number
  recovered_absolute_day: number | null
  recovery_days: number
  treatment_label: string
}

type InjuryCatalogRow = {
  code: string
  name: string
  body_area: string
  injury_group: string
  severity: Severity
  description: string
  causes: string[]
  skill_effects: Record<string, number>
  training_out_days: [number, number]
  tournament_out_days: [number, number]
  recovery_days: [number, number]
  treatment_code: string
  treatment_label: string
  aggravation_risk: number
}

type InjuryDashboard = {
  absolute_day: number
  current_injuries: ActiveInjury[]
  healthy: boolean
  risk: {
    risk_percent: number
    risk_level: string
    reasons: string[]
  }
  history: InjuryHistory[]
  catalog: InjuryCatalogRow[]
  treatments: Treatment[]
  rules: {
    staff_injury_modifier_active: boolean
    risk_is_per_activity: boolean
    recovery_is_game_day_based: boolean
  }
}

function titleCase(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function relativeDay(target: number, current: number) {
  const days = target - current
  if (days <= 0) return 'Available now'
  if (days === 1) return '1 game day'
  return `${days} game days`
}

function rangeLabel(range: [number, number]) {
  if (range[0] === range[1]) return `${range[0]} day${range[0] === 1 ? '' : 's'}`
  return `${range[0]}–${range[1]} days`
}

function percentage(value: number) {
  return `${Math.round(value * 100)}%`
}

function skillName(value: string) {
  return value === 'return_skill' ? 'Return' : titleCase(value)
}

export default function InjuriesPage() {
  const [data, setData] = useState<InjuryDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [catalogOpen, setCatalogOpen] = useState(false)
  const [treatmentsOpen, setTreatmentsOpen] = useState(false)

  async function load() {
    const { data: response, error: rpcError } = await supabase.rpc('get_player_injury_dashboard_v1')
    if (rpcError) {
      setError(rpcError.message)
      setLoading(false)
      return
    }
    setData(response as InjuryDashboard)
    setError(null)
    setLoading(false)
  }

  useEffect(() => {
    void load()
    const timer = window.setInterval(() => void load(), 20000)
    const focus = () => void load()
    window.addEventListener('focus', focus)
    return () => {
      window.clearInterval(timer)
      window.removeEventListener('focus', focus)
    }
  }, [])

  const mostImportant = useMemo(() => data?.current_injuries.slice().sort((a, b) => {
    const order: Record<Severity, number> = { severe: 4, major: 3, moderate: 2, minor: 1 }
    return order[b.severity] - order[a.severity]
  })[0] ?? null, [data])

  return (
    <GameLayout title="Injury & Health" subtitle="Availability, injury risk, treatment and medical history">
      <main className="tlg-injury-page">
        <header className="tlg-injury-page-head">
          <div>
            <span>Player health center</span>
            <h1>Injury & Health</h1>
            <p>Track current injury risk, training and tournament availability, treatment guidance, recovery progress and your complete injury history.</p>
          </div>
          <div className="tlg-injury-rule-note"><ShieldCheck size={18} /><span>Staff injury-prevention effects are intentionally not active yet.</span></div>
        </header>

        {loading ? <section className="tlg-injury-state">Loading player health…</section> : error ? <section className="tlg-injury-state error">{error}</section> : data ? (
          <>
            <section className="tlg-injury-summary-grid">
              <article className={`tlg-injury-summary-card status ${data.healthy ? 'healthy' : 'injured'}`}>
                <span>Current status</span>
                <div>{data.healthy ? <CheckCircle2 size={24} /> : <HeartPulse size={24} />}</div>
                <strong>{data.healthy ? 'No active injury' : mostImportant?.name ?? 'Injured'}</strong>
                <small>{data.healthy ? 'Fully available for normal tennis activity.' : `${titleCase(mostImportant?.severity ?? '')} · ${mostImportant?.body_area ?? ''}`}</small>
              </article>

              <article className={`tlg-injury-summary-card risk risk-${data.risk.risk_level}`}>
                <span>Current injury risk</span>
                <div><Activity size={24} /></div>
                <strong>{titleCase(data.risk.risk_level)} · {Number(data.risk.risk_percent).toFixed(2)}%</strong>
                <small>Risk is recalculated from fatigue, fitness, recovery, activity load and existing injuries.</small>
              </article>

              <article className="tlg-injury-summary-card">
                <span>Training availability</span>
                <div><Clock3 size={24} /></div>
                <strong>{mostImportant && !mostImportant.can_train ? `Out · ${relativeDay(mostImportant.training_return_absolute_day, data.absolute_day)}` : 'Available'}</strong>
                <small>{mostImportant && !mostImportant.can_train ? 'Normal training is blocked until the medical return date.' : 'Normal training is currently permitted.'}</small>
              </article>

              <article className="tlg-injury-summary-card">
                <span>Tournament availability</span>
                <div><ShieldCheck size={24} /></div>
                <strong>{mostImportant && !mostImportant.can_compete ? `Out · ${relativeDay(mostImportant.tournament_return_absolute_day, data.absolute_day)}` : 'Available'}</strong>
                <small>{mostImportant && !mostImportant.can_compete ? 'A scheduled match during this window is resolved as an injury walkover.' : 'Tournament participation is currently permitted.'}</small>
              </article>
            </section>

            <section className="tlg-injury-risk-panel">
              <div className="tlg-injury-section-head"><div><span>Risk monitor</span><h2>What is driving the current risk?</h2></div></div>
              <div className="tlg-injury-risk-content">
                <div className="tlg-injury-risk-meter"><span style={{ width: `${Math.min(100, Number(data.risk.risk_percent) * 12)}%` }} /></div>
                <div className="tlg-injury-risk-reasons">{data.risk.reasons.map((reason) => <span key={reason}>{reason}</span>)}</div>
                <p>Risk is activity-specific. Hard training, long matches, accumulated fatigue and hot outdoor conditions can raise it. A notification is generated when the calculated risk reaches an elevated level.</p>
              </div>
            </section>

            <section className="tlg-injury-current-section">
              <div className="tlg-injury-section-head"><div><span>Current medical status</span><h2>{data.healthy ? 'Healthy player' : `Active ${data.current_injuries.length === 1 ? 'injury' : 'injuries'}`}</h2></div></div>
              {data.healthy ? (
                <div className="tlg-injury-healthy-state">
                  <CheckCircle2 size={34} />
                  <div><strong>No active injury</strong><p>Your player has no injury restrictions. The risk monitor above remains active during training, training camps and matches.</p></div>
                </div>
              ) : data.current_injuries.map((injury) => (
                <article key={injury.id} className={`tlg-injury-detail severity-${injury.severity}`}>
                  <header>
                    <div><span>{titleCase(injury.severity)} · {injury.body_area}</span><h3>{injury.name}</h3><p>{injury.description}</p></div>
                    <strong>{injury.progress_percent}% recovered</strong>
                  </header>
                  <div className="tlg-injury-progress"><span style={{ width: `${injury.progress_percent}%` }} /></div>
                  <div className="tlg-injury-detail-grid">
                    <div><span>Occurred during</span><strong>{titleCase(injury.source_type)}</strong></div>
                    <div><span>Normal training</span><strong>{relativeDay(injury.training_return_absolute_day, data.absolute_day)}</strong></div>
                    <div><span>Tournaments</span><strong>{relativeDay(injury.tournament_return_absolute_day, data.absolute_day)}</strong></div>
                    <div><span>Full recovery</span><strong>{relativeDay(injury.expected_full_recovery_absolute_day, data.absolute_day)}</strong></div>
                    <div><span>General match penalty</span><strong>{percentage(injury.performance_penalty)}</strong></div>
                    <div><span>Aggravation risk</span><strong>{percentage(injury.aggravation_risk)}</strong></div>
                  </div>
                  <div className="tlg-injury-two-column">
                    <div><span>Likely causes</span><ul>{injury.causes.map((cause) => <li key={cause}>{cause}</li>)}</ul></div>
                    <div><span>Affected skills</span><ul>{Object.entries(injury.skill_effects).map(([skill, modifier]) => <li key={skill}>{skillName(skill)} <b>{Math.round(modifier * 100)}%</b></li>)}</ul></div>
                  </div>
                  <div className="tlg-injury-treatment-box"><Stethoscope size={20} /><div><span>Recommended treatment</span><strong>{injury.treatment.label}</strong><p>{injury.treatment.description}</p>{injury.treatment.notes ? <small>{injury.treatment.notes}</small> : null}</div></div>
                </article>
              ))}
            </section>

            <section className="tlg-injury-history-section">
              <div className="tlg-injury-section-head"><div><span>Career record</span><h2>Injury history</h2></div><strong>{data.history.length} recorded</strong></div>
              {data.history.length === 0 ? <div className="tlg-injury-empty">No recovered injuries have been recorded in this career.</div> : (
                <div className="tlg-injury-history-table">
                  <div className="head"><span>Injury</span><span>Severity</span><span>Source</span><span>Recovery</span><span>Treatment</span></div>
                  {data.history.map((item) => <div key={item.id}><strong>{item.name}<small>{item.body_area}</small></strong><span>{titleCase(item.severity)}</span><span>{titleCase(item.source_type)}</span><span>{item.recovery_days} days</span><span>{item.treatment_label}</span></div>)}
                </div>
              )}
            </section>

            <section className="tlg-injury-reference-section">
              <button type="button" className="tlg-injury-reference-toggle" onClick={() => setCatalogOpen((open) => !open)} aria-expanded={catalogOpen}>
                <div><AlertTriangle size={18} /><span><strong>Injury reference table</strong><small>All injuries currently used by the game, expected availability windows and treatment.</small></span></div><b>{catalogOpen ? 'Hide' : 'Open'}</b>
              </button>
              {catalogOpen && <div className="tlg-injury-catalog-table"><div className="head"><span>Injury</span><span>Severity</span><span>Training out</span><span>Tournament out</span><span>Full recovery</span><span>Treatment</span></div>{data.catalog.map((item) => <div key={item.code}><strong>{item.name}<small>{item.body_area}</small></strong><span>{titleCase(item.severity)}</span><span>{rangeLabel(item.training_out_days)}</span><span>{rangeLabel(item.tournament_out_days)}</span><span>{rangeLabel(item.recovery_days)}</span><span>{item.treatment_label}</span></div>)}</div>}

              <button type="button" className="tlg-injury-reference-toggle" onClick={() => setTreatmentsOpen((open) => !open)} aria-expanded={treatmentsOpen}>
                <div><Stethoscope size={18} /><span><strong>Treatment reference</strong><small>What each treatment type means in the current injury system.</small></span></div><b>{treatmentsOpen ? 'Hide' : 'Open'}</b>
              </button>
              {treatmentsOpen && <div className="tlg-injury-treatment-list">{data.treatments.map((item) => <article key={item.code}><span>{titleCase(item.care_level)}</span><strong>{item.label}</strong><p>{item.description}</p>{item.notes ? <small>{item.notes}</small> : null}</article>)}</div>}
            </section>
          </>
        ) : null}
      </main>
    </GameLayout>
  )
}
