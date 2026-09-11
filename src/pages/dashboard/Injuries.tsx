import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  Clock3,
  HeartPulse,
  ShieldCheck,
  Stethoscope,
  Thermometer,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/injuries.css'
import '../../styles/health-system.css'
import '../../styles/health-condition-colors.css'

type Severity = 'minor' | 'moderate' | 'major' | 'severe'
type HealthState = 'healthy' | 'at_risk' | 'ill' | 'injured' | 'recovering' | 'not_fully_fit' | 'fully_recovered'
type ConditionKind = 'injury' | 'illness'

type GameDate = { season: number; month: number; day: number; season_week?: number }

type Treatment = {
  code: string
  label: string
  description: string
  care_level: string
  notes: string | null
}

type Risk = {
  risk_percent: number
  risk_level: string
  reasons: string[]
}

type HealthSummary = {
  state: HealthState
  label: string
  can_train: boolean
  can_compete: boolean
  performance_penalty: number
  injury_count: number
  illness_count: number
  primary_condition: null | {
    kind: ConditionKind
    id: string
    code: string
    name: string
    severity: Severity
    body_area: string | null
    progress_percent: number
    onset_absolute_day: number
    training_return_absolute_day: number
    tournament_return_absolute_day: number
    expected_full_recovery_absolute_day: number
  }
  injury_risk: Risk
  illness_risk: Risk
}

type HealthCondition = {
  id: string
  kind: ConditionKind
  code: string
  name: string
  body_area: string | null
  injury_group: string | null
  severity: Severity
  description: string
  causes: string[]
  source_type: string
  onset_absolute_day: number
  onset_game_date: GameDate
  training_return_absolute_day: number
  training_return_game_date: GameDate
  tournament_return_absolute_day: number
  tournament_return_game_date: GameDate
  expected_full_recovery_absolute_day: number
  expected_full_recovery_game_date: GameDate
  days_remaining: number
  progress_percent: number
  performance_penalty: number
  aggravation_risk: number
  skill_effects: Record<string, number>
  treatment_status: string
  treatment_started_absolute_day: number | null
  treatment: Treatment
  can_train: boolean
  can_compete: boolean
  phase: 'treatment' | 'returning_to_training' | 'not_fully_fit'
  details: Record<string, unknown>
}

type HealthHistory = {
  id: string
  kind: ConditionKind
  code: string
  name: string
  body_area: string | null
  severity: Severity
  source_type: string
  onset_absolute_day: number
  onset_game_date: GameDate
  recovered_absolute_day: number | null
  recovered_game_date: GameDate | null
  recovery_days: number
  treatment_label: string
}

type CatalogRow = {
  code: string
  name: string
  body_area?: string | null
  severity: Severity
  description: string
  causes: string[]
  skill_effects: Record<string, number>
  training_out_days: [number, number]
  tournament_out_days: [number, number]
  recovery_days: [number, number]
  treatment_code: string
  treatment_label: string
  aggravation_risk?: number
}

type HealthDashboard = {
  absolute_day: number
  game_date: GameDate
  summary: HealthSummary
  condition: {
    fatigue: number
    sharpness: number
    fitness: number
    recovery: number
    movement: number
  }
  current_conditions: HealthCondition[]
  health_history: HealthHistory[]
  injury_catalog: CatalogRow[]
  illness_catalog: CatalogRow[]
  treatments: Treatment[]
  staff_effects: {
    injury_prevention_reduction?: number
    rehabilitation_duration_reduction?: number
    return_to_play_duration_reduction?: number
  }
  rules: {
    return_is_gradual: boolean
    risk_is_per_activity: boolean
    illness_risk_is_daily: boolean
    recovery_is_game_day_based: boolean
    health_surrender_supported: boolean
  }
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function titleCase(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function gameDate(value?: GameDate | null) {
  if (!value) return '—'
  return `Season ${value.season} · ${MONTHS[value.month - 1] ?? `M${value.month}`} ${value.day}`
}

function rangeLabel(range: [number, number]) {
  if (range[0] === range[1]) return `${range[0]} day${range[0] === 1 ? '' : 's'}`
  return `${range[0]}–${range[1]} days`
}

function percentage(value: number) {
  return `${Math.round(Number(value ?? 0) * 100)}%`
}

function riskPercent(value: number) {
  return `${Number(value ?? 0).toFixed(2)}%`
}

function skillName(value: string) {
  return value === 'return_skill' ? 'Return' : titleCase(value)
}

function phaseLabel(value: HealthCondition['phase']) {
  if (value === 'treatment') return 'Treatment / protected recovery'
  if (value === 'returning_to_training') return 'Returning to training'
  return 'Not fully fit'
}

function conditionTone(value: number, lowerIsBetter = false) {
  const raw = Math.max(0, Math.min(100, Number(value ?? 0)))
  const score = lowerIsBetter ? 100 - raw : raw
  if (score >= 80) return 'metric-good'
  if (score >= 65) return 'metric-positive'
  if (score >= 50) return 'metric-caution'
  if (score >= 35) return 'metric-warning'
  return 'metric-danger'
}

function nextStep(summary: HealthSummary, condition: HealthCondition | null) {
  if (summary.state === 'healthy') return 'Normal training and competition are available. Keep fatigue controlled to preserve the low-risk state.'
  if (summary.state === 'fully_recovered') return 'You are fully cleared again. Normal training and tournament participation are restored.'
  if (summary.state === 'at_risk') return 'No injury or illness is active, but current risk is elevated. Reduce workload and prioritize recovery before the next hard session or match.'
  if (!condition) return 'Monitor your health status and avoid unnecessary load until the restriction clears.'
  if (!condition.can_train) return `Follow ${condition.treatment.label}. Normal training remains blocked until ${gameDate(condition.training_return_game_date)}.`
  if (!condition.can_compete) return `Controlled training is available, but tournament competition remains blocked until ${gameDate(condition.tournament_return_game_date)}.`
  return `You may train and compete, but you are not fully fit. Full recovery is expected ${gameDate(condition.expected_full_recovery_game_date)} and excessive load can cause a setback.`
}

export default function InjuriesPage() {
  const [data, setData] = useState<HealthDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [injuryReferenceOpen, setInjuryReferenceOpen] = useState(false)
  const [illnessReferenceOpen, setIllnessReferenceOpen] = useState(false)
  const [treatmentsOpen, setTreatmentsOpen] = useState(false)

  async function load() {
    const { data: response, error: rpcError } = await supabase.rpc('get_player_injury_dashboard_v1')
    if (rpcError) {
      setError(rpcError.message)
      setLoading(false)
      return
    }
    setData(response as HealthDashboard)
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

  const primary = useMemo(() => data?.current_conditions[0] ?? null, [data])
  const medicalStaffText = useMemo(() => {
    if (!data) return 'No active medical-staff modifier'
    const prevention = Number(data.staff_effects.injury_prevention_reduction ?? 0)
    const rehab = Number(data.staff_effects.rehabilitation_duration_reduction ?? 0)
    const returnReduction = Number(data.staff_effects.return_to_play_duration_reduction ?? 0)
    if (prevention <= 0 && rehab <= 0 && returnReduction <= 0) return 'No active medical-staff modifier'
    return `Prevention −${Math.round(prevention * 100)}% · rehab −${Math.round(rehab * 100)}% · return time −${Math.round(returnReduction * 100)}%`
  }, [data])

  return (
    <GameLayout title="Injury & Health" subtitle="Health risk, illness, injury, treatment and return to competition">
      <main className="tlg-health-page">
        <header className="tlg-health-head">
          <div>
            <span>PLAYER HEALTH CENTER</span>
            <h1>Injury & Health</h1>
            <p>One synchronized view of your current health state, risk, treatment, training clearance, tournament availability and recovery history.</p>
          </div>
          {data ? <div className={`tlg-health-state-pill state-${data.summary.state}`}><HeartPulse size={18} /><span>{data.summary.label}</span></div> : null}
        </header>

        {loading ? <section className="tlg-health-loading">Loading player health…</section> : error ? <section className="tlg-health-loading error">{error}</section> : data ? (
          <>
            <section className="tlg-health-summary-grid">
              <article className={`tlg-health-summary-card main state-${data.summary.state}`}>
                <span>Current health status</span>
                <div className="icon">{data.summary.state === 'healthy' || data.summary.state === 'fully_recovered' ? <CheckCircle2 size={25} /> : <HeartPulse size={25} />}</div>
                <strong>{data.summary.label}</strong>
                <small>{primary ? `${primary.kind === 'illness' ? 'Illness' : 'Injury'} · ${primary.name} · ${titleCase(primary.severity)}` : 'No active injury or illness.'}</small>
              </article>
              <article className={`tlg-health-summary-card risk risk-${data.summary.injury_risk.risk_level}`}>
                <span>Injury risk</span><Activity size={23} /><strong>{titleCase(data.summary.injury_risk.risk_level)} · {riskPercent(data.summary.injury_risk.risk_percent)}</strong><small>Activity-specific; increases with fatigue, load, match duration, heat and reduced physical condition.</small>
              </article>
              <article className={`tlg-health-summary-card risk risk-${data.summary.illness_risk.risk_level}`}>
                <span>Daily illness risk</span><Thermometer size={23} /><strong>{titleCase(data.summary.illness_risk.risk_level)} · {riskPercent(data.summary.illness_risk.risk_percent)}</strong><small>Rolled once per game day and influenced by fatigue, recovery condition, travel exposure and current injury recovery.</small>
              </article>
              <article className="tlg-health-summary-card"><span>Training</span><Clock3 size={23} /><strong>{data.summary.can_train ? 'Available' : 'Medically blocked'}</strong><small>{primary && !primary.can_train ? `Return target: ${gameDate(primary.training_return_game_date)}` : 'Normal training is currently permitted.'}</small></article>
              <article className="tlg-health-summary-card"><span>Tournaments</span><ShieldCheck size={23} /><strong>{data.summary.can_compete ? 'Available' : 'Medically unavailable'}</strong><small>{primary && !primary.can_compete ? `Competition target: ${gameDate(primary.tournament_return_game_date)}` : 'Tournament competition is currently permitted.'}</small></article>
            </section>

            <section className="tlg-health-guidance">
              <AlertTriangle size={21} />
              <div><span>What should I do next?</span><strong>{nextStep(data.summary, primary)}</strong></div>
            </section>

            <section className="tlg-health-condition-strip">
              <article className={conditionTone(data.condition.fatigue, true)}><span>Fatigue</span><strong>{data.condition.fatigue}/100</strong></article>
              <article className={conditionTone(data.condition.sharpness)}><span>Sharpness</span><strong>{data.condition.sharpness}/100</strong></article>
              <article className={conditionTone(data.condition.fitness)}><span>Fitness</span><strong>{data.condition.fitness}/100</strong></article>
              <article className={conditionTone(data.condition.recovery)}><span>Recovery</span><strong>{data.condition.recovery}/100</strong></article>
              <article className="metric-neutral"><span>Medical staff effect</span><strong>{medicalStaffText}</strong></article>
            </section>

            <section className="tlg-health-risk-grid">
              <article>
                <header><Activity size={18} /><div><span>Injury risk drivers</span><strong>{riskPercent(data.summary.injury_risk.risk_percent)}</strong></div></header>
                <div className="tlg-health-risk-meter"><span style={{ width: `${Math.min(100, Number(data.summary.injury_risk.risk_percent) * 14)}%` }} /></div>
                <div className="reasons">{data.summary.injury_risk.reasons.map((reason) => <span key={reason}>{reason}</span>)}</div>
              </article>
              <article>
                <header><Thermometer size={18} /><div><span>Illness risk drivers</span><strong>{riskPercent(data.summary.illness_risk.risk_percent)}</strong></div></header>
                <div className="tlg-health-risk-meter"><span style={{ width: `${Math.min(100, Number(data.summary.illness_risk.risk_percent) * 80)}%` }} /></div>
                <div className="reasons">{data.summary.illness_risk.reasons.map((reason) => <span key={reason}>{reason}</span>)}</div>
              </article>
            </section>

            <section className="tlg-health-current">
              <div className="tlg-health-section-head"><div><span>CURRENT MEDICAL STATUS</span><h2>{data.current_conditions.length ? `${data.current_conditions.length} active health condition${data.current_conditions.length === 1 ? '' : 's'}` : data.summary.label}</h2></div><small>{gameDate(data.game_date)}</small></div>
              {data.current_conditions.length === 0 ? (
                <div className="tlg-health-clear-state"><CheckCircle2 size={34} /><div><strong>{data.summary.state === 'fully_recovered' ? 'Full recovery reached today' : 'No active injury or illness'}</strong><p>{data.summary.state === 'at_risk' ? 'You are currently available, but risk is elevated. Reduce fatigue and avoid unnecessary high-load work.' : 'Your player has no medical restrictions. Risk monitoring remains active during training, camps and matches.'}</p></div></div>
              ) : data.current_conditions.map((condition) => (
                <article key={condition.id} className={`tlg-health-condition severity-${condition.severity} kind-${condition.kind}`}>
                  <header>
                    <div><span>{condition.kind === 'illness' ? 'Illness' : condition.body_area ?? 'Injury'} · {titleCase(condition.severity)}</span><h3>{condition.name}</h3><p>{condition.description}</p></div>
                    <div className="progress-number"><strong>{condition.progress_percent}%</strong><span>recovered</span></div>
                  </header>
                  <div className="tlg-health-progress"><span style={{ width: `${condition.progress_percent}%` }} /></div>
                  <div className="tlg-health-phase-row"><span>{phaseLabel(condition.phase)}</span><strong>{condition.days_remaining === 0 ? 'Recovery date reached' : `${condition.days_remaining} day${condition.days_remaining === 1 ? '' : 's'} to full recovery`}</strong></div>
                  <div className="tlg-health-detail-grid">
                    <div><span>Started</span><strong>{gameDate(condition.onset_game_date)}</strong></div>
                    <div><span>Treatment status</span><strong>{titleCase(condition.treatment_status)}</strong></div>
                    <div><span>Training return</span><strong>{gameDate(condition.training_return_game_date)}</strong><small>{condition.can_train ? 'Cleared' : 'Blocked'}</small></div>
                    <div><span>Tournament return</span><strong>{gameDate(condition.tournament_return_game_date)}</strong><small>{condition.can_compete ? 'Cleared' : 'Blocked'}</small></div>
                    <div><span>Expected full recovery</span><strong>{gameDate(condition.expected_full_recovery_game_date)}</strong></div>
                    <div><span>Current performance penalty</span><strong>{percentage(condition.performance_penalty)}</strong></div>
                    {condition.kind === 'injury' ? <div><span>Base aggravation risk</span><strong>{percentage(condition.aggravation_risk)}</strong><small>Actual setback risk also depends on activity, fatigue, match length and heat.</small></div> : null}
                  </div>
                  <div className="tlg-health-two-column">
                    <div><span>Typical causes</span><ul>{condition.causes.map((cause) => <li key={cause}>{cause}</li>)}</ul></div>
                    <div><span>Affected performance</span><ul>{Object.entries(condition.skill_effects).map(([skill, modifier]) => <li key={skill}>{skillName(skill)} <b>{Math.round(Number(modifier) * 100)}%</b></li>)}</ul></div>
                  </div>
                  <div className="tlg-health-treatment"><Stethoscope size={20} /><div><span>Current treatment</span><strong>{condition.treatment.label}</strong><p>{condition.treatment.description}</p>{condition.treatment.notes ? <small>{condition.treatment.notes}</small> : null}</div></div>
                </article>
              ))}
            </section>

            <section className="tlg-health-history">
              <div className="tlg-health-section-head"><div><span>CAREER HEALTH RECORD</span><h2>Previous injuries & illnesses</h2></div><strong>{data.health_history.length} recorded</strong></div>
              {data.health_history.length === 0 ? <div className="tlg-health-empty">No recovered injury or illness has been recorded in this career.</div> : (
                <div className="tlg-health-history-table">
                  <div className="head"><span>Condition</span><span>Type</span><span>Severity</span><span>Started</span><span>Recovered</span><span>Duration</span><span>Treatment</span></div>
                  {data.health_history.map((item) => <div key={`${item.kind}-${item.id}`}><strong>{item.name}<small>{item.body_area ?? ''}</small></strong><span>{titleCase(item.kind)}</span><span>{titleCase(item.severity)}</span><span>{gameDate(item.onset_game_date)}</span><span>{gameDate(item.recovered_game_date)}</span><span>{item.recovery_days} days</span><span>{item.treatment_label}</span></div>)}
                </div>
              )}
            </section>

            <section className="tlg-health-reference">
              <button type="button" onClick={() => setInjuryReferenceOpen((open) => !open)} aria-expanded={injuryReferenceOpen}><div><AlertTriangle size={18} /><span><strong>Injury reference</strong><small>All currently supported injury types, availability windows and treatment.</small></span></div><b>{injuryReferenceOpen ? 'Hide' : 'Open'}</b></button>
              {injuryReferenceOpen ? <div className="tlg-health-reference-table"><div className="head"><span>Injury</span><span>Severity</span><span>Training out</span><span>Tournament out</span><span>Full recovery</span><span>Treatment</span></div>{data.injury_catalog.map((item) => <div key={item.code}><strong>{item.name}<small>{item.body_area ?? ''}</small></strong><span>{titleCase(item.severity)}</span><span>{rangeLabel(item.training_out_days)}</span><span>{rangeLabel(item.tournament_out_days)}</span><span>{rangeLabel(item.recovery_days)}</span><span>{item.treatment_label}</span></div>)}</div> : null}

              <button type="button" onClick={() => setIllnessReferenceOpen((open) => !open)} aria-expanded={illnessReferenceOpen}><div><Thermometer size={18} /><span><strong>Illness reference</strong><small>Illness is rolled separately from physical injury and has its own availability and recovery windows.</small></span></div><b>{illnessReferenceOpen ? 'Hide' : 'Open'}</b></button>
              {illnessReferenceOpen ? <div className="tlg-health-reference-table illness"><div className="head"><span>Illness</span><span>Severity</span><span>Training out</span><span>Tournament out</span><span>Full recovery</span><span>Treatment</span></div>{data.illness_catalog.map((item) => <div key={item.code}><strong>{item.name}</strong><span>{titleCase(item.severity)}</span><span>{rangeLabel(item.training_out_days)}</span><span>{rangeLabel(item.tournament_out_days)}</span><span>{rangeLabel(item.recovery_days)}</span><span>{item.treatment_label}</span></div>)}</div> : null}

              <button type="button" onClick={() => setTreatmentsOpen((open) => !open)} aria-expanded={treatmentsOpen}><div><Stethoscope size={18} /><span><strong>Treatment & rehabilitation reference</strong><small>What each care level means in the current game.</small></span></div><b>{treatmentsOpen ? 'Hide' : 'Open'}</b></button>
              {treatmentsOpen ? <div className="tlg-health-treatment-list">{data.treatments.map((item) => <article key={item.code}><span>{titleCase(item.care_level)}</span><strong>{item.label}</strong><p>{item.description}</p>{item.notes ? <small>{item.notes}</small> : null}</article>)}</div> : null}
            </section>
          </>
        ) : null}
      </main>
    </GameLayout>
  )
}
