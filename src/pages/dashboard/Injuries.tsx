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
import { useTranslation, type TFunction } from 'react-i18next'

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

function titleCase(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function gameDate(value: GameDate | null | undefined, t: TFunction) {
  if (!value) return '—'
  const months = t('staffPage.months', { returnObjects: true }) as string[]
  const month = months[value.month] ?? `M${value.month}`
  return t('staffPage.profile.seasonDate', { season: value.season, month, day: value.day })
}

function rangeLabel(range: [number, number], t: TFunction) {
  if (range[0] === range[1]) return t('healthPage.day', { count: range[0] })
  return t('healthPage.dayRange', { from: range[0], to: range[1] })
}

function percentage(value: number) {
  return `${Math.round(Number(value ?? 0) * 100)}%`
}

function riskPercent(value: number) {
  return `${Number(value ?? 0).toFixed(2)}%`
}

function skillName(value: string, t: TFunction) {
  return t(`healthPage.skill.${value}`, { defaultValue: value === 'return_skill' ? 'Return' : titleCase(value) })
}

function phaseLabel(value: HealthCondition['phase'], t: TFunction) {
  return t(`healthPage.phase.${value}`)
}

function severityLabel(value: Severity, t: TFunction) {
  return t(`healthPage.severity.${value}`, { defaultValue: titleCase(value) })
}

function stateLabel(value: HealthState, fallback: string, t: TFunction) {
  return t(`healthPage.state.${value}`, { defaultValue: fallback })
}

function riskLabel(value: string, t: TFunction) {
  return t(`healthPage.risk.${value.toLowerCase()}`, { defaultValue: titleCase(value) })
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

function nextStep(summary: HealthSummary, condition: HealthCondition | null, t: TFunction) {
  if (summary.state === 'healthy') return t('healthPage.nextStep.healthy')
  if (summary.state === 'fully_recovered') return t('healthPage.nextStep.fully_recovered')
  if (summary.state === 'at_risk') return t('healthPage.nextStep.at_risk')
  if (!condition) return t('healthPage.nextStep.fallback')
  if (!condition.can_train) return t('healthPage.nextStep.trainingBlocked', { treatment: condition.treatment.label, date: gameDate(condition.training_return_game_date, t) })
  if (!condition.can_compete) return t('healthPage.nextStep.competitionBlocked', { date: gameDate(condition.tournament_return_game_date, t) })
  return t('healthPage.nextStep.notFullyFit', { date: gameDate(condition.expected_full_recovery_game_date, t) })
}

export default function InjuriesPage() {
  const { t } = useTranslation()
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
    if (!data) return t('healthPage.noMedicalModifier')
    const prevention = Number(data.staff_effects.injury_prevention_reduction ?? 0)
    const rehab = Number(data.staff_effects.rehabilitation_duration_reduction ?? 0)
    const returnReduction = Number(data.staff_effects.return_to_play_duration_reduction ?? 0)
    if (prevention <= 0 && rehab <= 0 && returnReduction <= 0) return t('healthPage.noMedicalModifier')
    return t('healthPage.medicalModifier', { prevention: Math.round(prevention * 100), rehab: Math.round(rehab * 100), return: Math.round(returnReduction * 100) })
  }, [data, t])

  return (
    <GameLayout title={t('healthPage.title')} subtitle={t('healthPage.subtitle')}>
      <main className="tlg-health-page">
        <header className="tlg-health-head">
          <div>
            <span>{t('healthPage.kicker')}</span>
            <h1>{t('healthPage.title')}</h1>
            <p>{t('healthPage.intro')}</p>
          </div>
          {data ? <div className={`tlg-health-state-pill state-${data.summary.state}`}><HeartPulse size={18} /><span>{stateLabel(data.summary.state, data.summary.label, t)}</span></div> : null}
        </header>

        {loading ? <section className="tlg-health-loading">{t('healthPage.loading')}</section> : error ? <section className="tlg-health-loading error">{error}</section> : data ? (
          <>
            <section className="tlg-health-summary-grid">
              <article className={`tlg-health-summary-card main state-${data.summary.state}`}>
                <span>{t('healthPage.currentStatus')}</span>
                <div className="icon">{data.summary.state === 'healthy' || data.summary.state === 'fully_recovered' ? <CheckCircle2 size={25} /> : <HeartPulse size={25} />}</div>
                <strong>{stateLabel(data.summary.state, data.summary.label, t)}</strong>
                <small>{primary ? `${t(primary.kind === 'illness' ? 'healthPage.illness' : 'healthPage.injury')} · ${primary.name} · ${severityLabel(primary.severity, t)}` : t('healthPage.noActive')}</small>
              </article>
              <article className={`tlg-health-summary-card risk risk-${data.summary.injury_risk.risk_level}`}>
                <span>{t('healthPage.injuryRisk')}</span><Activity size={23} /><strong>{riskLabel(data.summary.injury_risk.risk_level, t)} · {riskPercent(data.summary.injury_risk.risk_percent)}</strong><small>{t('healthPage.injuryRiskBody')}</small>
              </article>
              <article className={`tlg-health-summary-card risk risk-${data.summary.illness_risk.risk_level}`}>
                <span>{t('healthPage.illnessRisk')}</span><Thermometer size={23} /><strong>{riskLabel(data.summary.illness_risk.risk_level, t)} · {riskPercent(data.summary.illness_risk.risk_percent)}</strong><small>{t('healthPage.illnessRiskBody')}</small>
              </article>
              <article className="tlg-health-summary-card"><span>{t('healthPage.training')}</span><Clock3 size={23} /><strong>{data.summary.can_train ? t('healthPage.available') : t('healthPage.medicallyBlocked')}</strong><small>{primary && !primary.can_train ? t('healthPage.returnTarget', { date: gameDate(primary.training_return_game_date, t) }) : t('healthPage.trainingPermitted')}</small></article>
              <article className="tlg-health-summary-card"><span>{t('healthPage.tournaments')}</span><ShieldCheck size={23} /><strong>{data.summary.can_compete ? t('healthPage.available') : t('healthPage.medicallyUnavailable')}</strong><small>{primary && !primary.can_compete ? t('healthPage.competitionTarget', { date: gameDate(primary.tournament_return_game_date, t) }) : t('healthPage.competitionPermitted')}</small></article>
            </section>

            <section className="tlg-health-guidance">
              <AlertTriangle size={21} />
              <div><span>{t('healthPage.next')}</span><strong>{nextStep(data.summary, primary, t)}</strong></div>
            </section>

            <section className="tlg-health-condition-strip">
              <article className={conditionTone(data.condition.fatigue, true)}><span>{t('healthPage.fatigue')}</span><strong>{data.condition.fatigue}/100</strong></article>
              <article className={conditionTone(data.condition.sharpness)}><span>{t('healthPage.sharpness')}</span><strong>{data.condition.sharpness}/100</strong></article>
              <article className={conditionTone(data.condition.fitness)}><span>{t('healthPage.fitness')}</span><strong>{data.condition.fitness}/100</strong></article>
              <article className={conditionTone(data.condition.recovery)}><span>{t('healthPage.recovery')}</span><strong>{data.condition.recovery}/100</strong></article>
              <article className="metric-neutral"><span>{t('healthPage.medicalStaffEffect')}</span><strong>{medicalStaffText}</strong></article>
            </section>

            <section className="tlg-health-risk-grid">
              <article>
                <header><Activity size={18} /><div><span>{t('healthPage.injuryDrivers')}</span><strong>{riskPercent(data.summary.injury_risk.risk_percent)}</strong></div></header>
                <div className="tlg-health-risk-meter"><span style={{ width: `${Math.min(100, Number(data.summary.injury_risk.risk_percent) * 14)}%` }} /></div>
                <div className="reasons">{data.summary.injury_risk.reasons.map((reason) => <span key={reason}>{reason}</span>)}</div>
              </article>
              <article>
                <header><Thermometer size={18} /><div><span>{t('healthPage.illnessDrivers')}</span><strong>{riskPercent(data.summary.illness_risk.risk_percent)}</strong></div></header>
                <div className="tlg-health-risk-meter"><span style={{ width: `${Math.min(100, Number(data.summary.illness_risk.risk_percent) * 80)}%` }} /></div>
                <div className="reasons">{data.summary.illness_risk.reasons.map((reason) => <span key={reason}>{reason}</span>)}</div>
              </article>
            </section>

            <section className="tlg-health-current">
              <div className="tlg-health-section-head"><div><span>{t('healthPage.currentMedical')}</span><h2>{data.current_conditions.length ? t('healthPage.activeConditions', { count: data.current_conditions.length }) : stateLabel(data.summary.state, data.summary.label, t)}</h2></div><small>{gameDate(data.game_date, t)}</small></div>
              {data.current_conditions.length === 0 ? (
                <div className="tlg-health-clear-state"><CheckCircle2 size={34} /><div><strong>{data.summary.state === 'fully_recovered' ? t('healthPage.fullRecoveryToday') : t('healthPage.noActiveHeading')}</strong><p>{data.summary.state === 'at_risk' ? t('healthPage.elevatedBody') : t('healthPage.clearBody')}</p></div></div>
              ) : data.current_conditions.map((condition) => (
                <article key={condition.id} className={`tlg-health-condition severity-${condition.severity} kind-${condition.kind}`}>
                  <header>
                    <div><span>{condition.kind === 'illness' ? t('healthPage.illness') : condition.body_area ?? t('healthPage.injury')} · {severityLabel(condition.severity, t)}</span><h3>{condition.name}</h3><p>{condition.description}</p></div>
                    <div className="progress-number"><strong>{condition.progress_percent}%</strong><span>{t('healthPage.recovered')}</span></div>
                  </header>
                  <div className="tlg-health-progress"><span style={{ width: `${condition.progress_percent}%` }} /></div>
                  <div className="tlg-health-phase-row"><span>{phaseLabel(condition.phase, t)}</span><strong>{condition.days_remaining === 0 ? t('healthPage.recoveryReached') : t('healthPage.daysToRecovery', { count: condition.days_remaining })}</strong></div>
                  <div className="tlg-health-detail-grid">
                    <div><span>{t('healthPage.started')}</span><strong>{gameDate(condition.onset_game_date, t)}</strong></div>
                    <div><span>{t('healthPage.treatmentStatus')}</span><strong>{titleCase(condition.treatment_status)}</strong></div>
                    <div><span>{t('healthPage.trainingReturn')}</span><strong>{gameDate(condition.training_return_game_date, t)}</strong><small>{condition.can_train ? t('healthPage.cleared') : t('healthPage.blocked')}</small></div>
                    <div><span>{t('healthPage.tournamentReturn')}</span><strong>{gameDate(condition.tournament_return_game_date, t)}</strong><small>{condition.can_compete ? t('healthPage.cleared') : t('healthPage.blocked')}</small></div>
                    <div><span>{t('healthPage.expectedRecovery')}</span><strong>{gameDate(condition.expected_full_recovery_game_date, t)}</strong></div>
                    <div><span>{t('healthPage.performancePenalty')}</span><strong>{percentage(condition.performance_penalty)}</strong></div>
                    {condition.kind === 'injury' ? <div><span>{t('healthPage.aggravationRisk')}</span><strong>{percentage(condition.aggravation_risk)}</strong><small>{t('healthPage.aggravationNote')}</small></div> : null}
                  </div>
                  <div className="tlg-health-two-column">
                    <div><span>{t('healthPage.typicalCauses')}</span><ul>{condition.causes.map((cause) => <li key={cause}>{cause}</li>)}</ul></div>
                    <div><span>{t('healthPage.affectedPerformance')}</span><ul>{Object.entries(condition.skill_effects).map(([skill, modifier]) => <li key={skill}>{skillName(skill, t)} <b>{Math.round(Number(modifier) * 100)}%</b></li>)}</ul></div>
                  </div>
                  <div className="tlg-health-treatment"><Stethoscope size={20} /><div><span>{t('healthPage.currentTreatment')}</span><strong>{condition.treatment.label}</strong><p>{condition.treatment.description}</p>{condition.treatment.notes ? <small>{condition.treatment.notes}</small> : null}</div></div>
                </article>
              ))}
            </section>

            <section className="tlg-health-history">
              <div className="tlg-health-section-head"><div><span>{t('healthPage.recordKicker')}</span><h2>{t('healthPage.historyHeading')}</h2></div><strong>{t('healthPage.recorded', { count: data.health_history.length })}</strong></div>
              {data.health_history.length === 0 ? <div className="tlg-health-empty">{t('healthPage.noHistory')}</div> : (
                <div className="tlg-health-history-table">
                  <div className="head"><span>{t('healthPage.historyColumns.condition')}</span><span>{t('healthPage.historyColumns.type')}</span><span>{t('healthPage.historyColumns.severity')}</span><span>{t('healthPage.historyColumns.started')}</span><span>{t('healthPage.historyColumns.recovered')}</span><span>{t('healthPage.historyColumns.duration')}</span><span>{t('healthPage.historyColumns.treatment')}</span></div>
                  {data.health_history.map((item) => <div key={`${item.kind}-${item.id}`}><strong>{item.name}<small>{item.body_area ?? ''}</small></strong><span>{t(item.kind === 'illness' ? 'healthPage.illness' : 'healthPage.injury')}</span><span>{severityLabel(item.severity, t)}</span><span>{gameDate(item.onset_game_date, t)}</span><span>{gameDate(item.recovered_game_date, t)}</span><span>{t('healthPage.durationDays', { count: item.recovery_days })}</span><span>{item.treatment_label}</span></div>)}
                </div>
              )}
            </section>

            <section className="tlg-health-reference">
              <button type="button" onClick={() => setInjuryReferenceOpen((open) => !open)} aria-expanded={injuryReferenceOpen}><div><AlertTriangle size={18} /><span><strong>{t('healthPage.injuryReference')}</strong><small>{t('healthPage.injuryReferenceBody')}</small></span></div><b>{injuryReferenceOpen ? t('healthPage.hide') : t('healthPage.open')}</b></button>
              {injuryReferenceOpen ? <div className="tlg-health-reference-table"><div className="head"><span>{t('healthPage.referenceColumns.injury')}</span><span>{t('healthPage.referenceColumns.severity')}</span><span>{t('healthPage.referenceColumns.trainingOut')}</span><span>{t('healthPage.referenceColumns.tournamentOut')}</span><span>{t('healthPage.referenceColumns.fullRecovery')}</span><span>{t('healthPage.referenceColumns.treatment')}</span></div>{data.injury_catalog.map((item) => <div key={item.code}><strong>{item.name}<small>{item.body_area ?? ''}</small></strong><span>{severityLabel(item.severity, t)}</span><span>{rangeLabel(item.training_out_days, t)}</span><span>{rangeLabel(item.tournament_out_days, t)}</span><span>{rangeLabel(item.recovery_days, t)}</span><span>{item.treatment_label}</span></div>)}</div> : null}

              <button type="button" onClick={() => setIllnessReferenceOpen((open) => !open)} aria-expanded={illnessReferenceOpen}><div><Thermometer size={18} /><span><strong>{t('healthPage.illnessReference')}</strong><small>{t('healthPage.illnessReferenceBody')}</small></span></div><b>{illnessReferenceOpen ? t('healthPage.hide') : t('healthPage.open')}</b></button>
              {illnessReferenceOpen ? <div className="tlg-health-reference-table illness"><div className="head"><span>{t('healthPage.referenceColumns.illness')}</span><span>{t('healthPage.referenceColumns.severity')}</span><span>{t('healthPage.referenceColumns.trainingOut')}</span><span>{t('healthPage.referenceColumns.tournamentOut')}</span><span>{t('healthPage.referenceColumns.fullRecovery')}</span><span>{t('healthPage.referenceColumns.treatment')}</span></div>{data.illness_catalog.map((item) => <div key={item.code}><strong>{item.name}</strong><span>{severityLabel(item.severity, t)}</span><span>{rangeLabel(item.training_out_days, t)}</span><span>{rangeLabel(item.tournament_out_days, t)}</span><span>{rangeLabel(item.recovery_days, t)}</span><span>{item.treatment_label}</span></div>)}</div> : null}

              <button type="button" onClick={() => setTreatmentsOpen((open) => !open)} aria-expanded={treatmentsOpen}><div><Stethoscope size={18} /><span><strong>{t('healthPage.treatmentReference')}</strong><small>{t('healthPage.treatmentReferenceBody')}</small></span></div><b>{treatmentsOpen ? t('healthPage.hide') : t('healthPage.open')}</b></button>
              {treatmentsOpen ? <div className="tlg-health-treatment-list">{data.treatments.map((item) => <article key={item.code}><span>{titleCase(item.care_level)}</span><strong>{item.label}</strong><p>{item.description}</p>{item.notes ? <small>{item.notes}</small> : null}</article>)}</div> : null}
            </section>
          </>
        ) : null}
      </main>
    </GameLayout>
  )
}
