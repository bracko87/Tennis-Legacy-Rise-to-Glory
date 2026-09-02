import { useEffect, useMemo, useState } from 'react'

import GameLayout from '../../components/layout/GameLayout'
import TrainingCampsPanel from '../../components/training/TrainingCampsPanel'
import {
  type TrainingIntensity,
  type TrainingSessionRole,
  type TrainingType,
  useTraining,
} from '../../hooks/useTraining'
import '../../styles/training.css'

type TrainingView = 'regular' | 'camps'

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

const TECHNICAL_SKILLS = [
  ['serve', 'Serve'],
  ['forehand', 'Forehand'],
  ['backhand', 'Backhand'],
  ['return_skill', 'Return'],
  ['volley', 'Volley'],
  ['slice', 'Slice'],
  ['drop_shot', 'Drop Shot'],
  ['lob', 'Lob'],
  ['smash', 'Smash'],
] as const

const PHYSICAL_SKILLS = [
  ['fitness', 'Fitness'],
  ['stamina', 'Stamina'],
  ['recovery', 'Recovery'],
  ['movement', 'Movement'],
] as const

const ATTRIBUTE_LABELS: Record<string, string> = Object.fromEntries([
  ...TECHNICAL_SKILLS,
  ...PHYSICAL_SKILLS,
])

const INTENSITY_COPY: Record<TrainingIntensity, { title: string; load: string; note: string }> = {
  light: {
    title: 'Light',
    load: 'Low load',
    note: 'Smaller gains with limited fatigue. Useful around competition periods.',
  },
  standard: {
    title: 'Standard',
    load: 'Normal load',
    note: 'The regular development setting for most home training days.',
  },
  hard: {
    title: 'Hard',
    load: 'High load',
    note: 'Faster development, but fatigue rises much more quickly.',
  },
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value))
}

function titleCase(value: string) {
  return value.split('_').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ')
}

function activityLabel(value: string) {
  if (value === 'training_camp') return 'Training Camp'
  return titleCase(value)
}

function trainingLabel(type: TrainingType, focus: string | null) {
  if (type === 'day_off') return 'Day Off'
  return focus ? `${ATTRIBUTE_LABELS[focus] ?? titleCase(focus)} focus` : type === 'technical' ? 'Technical training' : 'Physical training'
}

function sessionRoleLabel(role?: TrainingSessionRole | null) {
  if (role === 'active_recovery') return 'Active Recovery'
  if (role === 'full_rest') return 'Full Rest'
  if (role === 'user_day_off') return 'Day Off'
  return 'Development Day'
}

function developmentMultiplier(value: number | null) {
  if (value === null) return 1
  if (value >= 100) return 0
  if (value >= 95) return 0.20
  if (value >= 90) return 0.35
  if (value >= 80) return 0.55
  if (value >= 70) return 0.75
  if (value >= 60) return 0.90
  return 1
}

function scoreReadiness(skills: NonNullable<ReturnType<typeof useTraining>['dashboard']>['skills']) {
  return (
    skills.morale + skills.confidence + skills.sharpness + skills.focus + (100 - skills.fatigue)
  ) / 5
}

function levelUpText(levelUps: Record<string, number> | undefined) {
  if (!levelUps || Object.keys(levelUps).length === 0) return 'No full skill point yet'
  return Object.entries(levelUps)
    .map(([key, value]) => `${ATTRIBUTE_LABELS[key] ?? titleCase(key)} +${value}`)
    .join(', ')
}

export default function TrainingPage() {
  const {
    dashboard,
    loading,
    saving,
    processing,
    error,
    savePlan,
    completeToday,
  } = useTraining()

  const [view, setView] = useState<TrainingView>('regular')
  const [trainingType, setTrainingType] = useState<TrainingType>('day_off')
  const [focusAttribute, setFocusAttribute] = useState<string | null>(null)
  const [intensity, setIntensity] = useState<TrainingIntensity>('standard')
  const [actionMessage, setActionMessage] = useState<string | null>(null)

  useEffect(() => {
    if (!dashboard?.plan) return
    setTrainingType(dashboard.plan.training_type)
    setFocusAttribute(dashboard.plan.focus_attribute)
    setIntensity(dashboard.plan.intensity)
  }, [dashboard?.plan])

  const readiness = dashboard ? scoreReadiness(dashboard.skills) : 0
  const scheduledRole = dashboard?.game_day.scheduled_role ?? 'planned_training'

  const planDirty = Boolean(dashboard && (
    dashboard.plan.training_type !== trainingType ||
    dashboard.plan.focus_attribute !== focusAttribute ||
    dashboard.plan.intensity !== intensity
  ))

  const selectedValue = dashboard && focusAttribute
    ? Number((dashboard.skills as unknown as Record<string, number>)[focusAttribute] ?? 0)
    : null
  const selectedProgress = dashboard && focusAttribute
    ? Number((dashboard.progress as unknown as Record<string, number>)[focusAttribute] ?? 0)
    : 0

  const impactPreview = useMemo(() => {
    if (!dashboard || trainingType === 'day_off') return null
    const conditionReadiness = (
      dashboard.skills.morale + dashboard.skills.confidence + dashboard.skills.sharpness +
      dashboard.skills.focus + (100 - dashboard.skills.fatigue)
    ) / 500
    const efficiency = clamp(0.78 + 0.37 * conditionReadiness, 0.70, 1.05)
    const developmentDayScale = dashboard.game_day.season_week && dashboard.game_day.season_week > 0 ? 1.40 : 1
    const budget = ({ light: 0.10, standard: 0.16, hard: 0.22 } as const)[intensity] * efficiency * developmentDayScale
    const multiplier = developmentMultiplier(selectedValue)
    const target = budget * 0.85 * multiplier
    const baseFatigue = trainingType === 'technical'
      ? ({ light: 3, standard: 6, hard: 10 } as const)[intensity]
      : ({ light: 4, standard: 7, hard: 11 } as const)[intensity]
    const resilience = (
      dashboard.skills.fitness + dashboard.skills.stamina + dashboard.skills.recovery
    ) / 300
    const fatigue = Math.max(1, Math.round(baseFatigue * (1.15 - 0.30 * resilience)))
    return { efficiency, target, fatigue, multiplier }
  }, [dashboard, intensity, selectedValue, trainingType])

  function chooseType(type: TrainingType) {
    setTrainingType(type)
    setActionMessage(null)
    if (type === 'technical') {
      if (!TECHNICAL_SKILLS.some(([key]) => key === focusAttribute)) setFocusAttribute('forehand')
    } else if (type === 'physical') {
      if (!PHYSICAL_SKILLS.some(([key]) => key === focusAttribute)) setFocusAttribute('fitness')
    } else {
      setFocusAttribute(null)
    }
  }

  async function handleSavePlan() {
    const saved = await savePlan(trainingType, focusAttribute, intensity)
    setActionMessage(saved ? 'Training plan saved.' : null)
  }

  async function handleCompleteToday() {
    setActionMessage(null)
    const result = await completeToday()
    if (!result) return
    if (result.status === 'blocked') {
      setActionMessage(result.reason ?? 'Training is unavailable today.')
    } else if (result.status === 'already_processed') {
      setActionMessage('Today has already been processed.')
    } else if (result.session_role === 'active_recovery') {
      setActionMessage('Scheduled Active Recovery completed. Fatigue recovery has been applied.')
    } else if (result.session_role === 'full_rest') {
      setActionMessage('Scheduled Full Rest completed. Recovery effects have been applied.')
    } else {
      setActionMessage(
        result.training_type === 'day_off'
          ? 'Day Off completed. Recovery effects have been applied.'
          : `Training completed. ${levelUpText(result.level_ups)}.`,
      )
    }
  }

  if (loading && !dashboard) {
    return (
      <GameLayout title="Training" subtitle="Regular development and training camps">
        <div className="tlg-training-loading">Loading Training Center…</div>
      </GameLayout>
    )
  }

  return (
    <GameLayout title="Training" subtitle="Regular development and training camps">
      <div className="tlg-training-page">
        <section className="tlg-training-hero">
          <div className="tlg-training-hero-copy">
            <span>PLAYER DEVELOPMENT CENTER</span>
            <h1>Training Center</h1>
            <p>
              Develop your player on home days, balance training load against fatigue, and use recovery days before the next competitive period.
            </p>
          </div>

          {dashboard && (
            <div className="tlg-training-hero-metrics">
              <div>
                <span>TODAY</span>
                <strong>{activityLabel(dashboard.activity_type)}</strong>
                <small>Season {dashboard.game_day.season} · {MONTH_NAMES[dashboard.game_day.month - 1]} {dashboard.game_day.day}{dashboard.activity_type === 'home' ? ` · ${sessionRoleLabel(scheduledRole)}` : ''}</small>
              </div>
              <div>
                <span>READINESS</span>
                <strong>{readiness.toFixed(0)}<em>/100</em></strong>
                <small>{readiness >= 70 ? 'Strong' : readiness >= 50 ? 'Ready' : 'Recovery recommended'}</small>
              </div>
              <div>
                <span>FATIGUE</span>
                <strong>{dashboard.skills.fatigue}<em>/100</em></strong>
                <small>Lower is better</small>
              </div>
            </div>
          )}
        </section>

        <div className="tlg-training-main-tabs" role="tablist" aria-label="Training areas">
          <button type="button" className={view === 'regular' ? 'active' : ''} onClick={() => setView('regular')}>Regular Training</button>
          <button type="button" className={view === 'camps' ? 'active' : ''} onClick={() => setView('camps')}>Training Camps</button>
        </div>

        {error && <div className="tlg-training-alert tlg-training-alert-error">{error}</div>}
        {actionMessage && <div className="tlg-training-alert">{actionMessage}</div>}

        {view === 'regular' && dashboard && (
          <>
            <div className="tlg-training-workspace">
              <section className="tlg-training-plan-panel">
                <header className="tlg-training-section-head">
                  <div>
                    <span>TODAY'S PLAN</span>
                    <h2>Choose the work for this home day</h2>
                    <p>Your saved plan follows a professional weekly rhythm: five development days, one active-recovery day and one full-rest day. Recovery days are scheduled automatically.</p>
                  </div>
                  <div className={`tlg-training-status ${dashboard.eligible ? 'available' : 'blocked'}`}>
                    <span>{dashboard.eligible ? 'AVAILABLE' : 'BLOCKED'}</span>
                    <strong>{dashboard.activity_type === 'home' ? sessionRoleLabel(scheduledRole) : activityLabel(dashboard.activity_type)}</strong>
                  </div>
                </header>

                {!dashboard.eligible && (
                  <div className="tlg-training-block-reason">{dashboard.block_reason}</div>
                )}

                <div className="tlg-training-type-grid">
                  <button type="button" className={trainingType === 'technical' ? 'selected' : ''} onClick={() => chooseType('technical')}>
                    <span>TECHNICAL</span>
                    <strong>Tennis Skills</strong>
                    <p>85% of technical development targets one selected tennis skill. The remaining 15% is shared by the other eight.</p>
                  </button>
                  <button type="button" className={trainingType === 'physical' ? 'selected' : ''} onClick={() => chooseType('physical')}>
                    <span>PHYSICAL</span>
                    <strong>Athletic Development</strong>
                    <p>Focus on Fitness, Stamina, Recovery or Movement while still receiving a very small technical carry-over.</p>
                  </button>
                  <button type="button" className={trainingType === 'day_off' ? 'selected' : ''} onClick={() => chooseType('day_off')}>
                    <span>RECOVERY</span>
                    <strong>Day Off</strong>
                    <p>No permanent skill development. Fatigue falls, Morale and Focus recover slightly, while Sharpness can cool down.</p>
                  </button>
                </div>

                {trainingType !== 'day_off' && (
                  <div className="tlg-training-builder">
                    <div className="tlg-training-builder-block">
                      <div className="tlg-training-builder-title">
                        <div>
                          <span>PRIMARY FOCUS</span>
                          <strong>{trainingType === 'technical' ? 'Select tennis skill' : 'Select physical skill'}</strong>
                        </div>
                        <small>85% focus / 15% shared</small>
                      </div>

                      <div className={`tlg-training-skill-grid ${trainingType === 'physical' ? 'physical' : ''}`}>
                        {(trainingType === 'technical' ? TECHNICAL_SKILLS : PHYSICAL_SKILLS).map(([key, label]) => {
                          const value = Number((dashboard.skills as unknown as Record<string, number>)[key] ?? 0)
                          const progress = Number((dashboard.progress as unknown as Record<string, number>)[key] ?? 0)
                          return (
                            <button key={key} type="button" className={focusAttribute === key ? 'selected' : ''} onClick={() => setFocusAttribute(key)}>
                              <span>{label}</span>
                              <strong>{value}</strong>
                              <div><i style={{ width: `${clamp(progress * 100, 0, 100)}%` }} /></div>
                              <small>{Math.round(progress * 100)}% to next point</small>
                            </button>
                          )
                        })}
                      </div>
                    </div>

                    <div className="tlg-training-builder-block">
                      <div className="tlg-training-builder-title">
                        <div>
                          <span>TRAINING LOAD</span>
                          <strong>Choose intensity</strong>
                        </div>
                      </div>

                      <div className="tlg-training-intensity-grid">
                        {(['light', 'standard', 'hard'] as TrainingIntensity[]).map((item) => (
                          <button key={item} type="button" className={intensity === item ? 'selected' : ''} onClick={() => setIntensity(item)}>
                            <span>{INTENSITY_COPY[item].load}</span>
                            <strong>{INTENSITY_COPY[item].title}</strong>
                            <p>{INTENSITY_COPY[item].note}</p>
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                )}

                <footer className="tlg-training-plan-actions">
                  <div>
                    <strong>{trainingLabel(trainingType, focusAttribute)}</strong>
                    <span>
                      {trainingType === 'day_off'
                        ? 'Recovery day selected.'
                        : scheduledRole !== 'planned_training'
                          ? `${sessionRoleLabel(scheduledRole)} is scheduled today. No permanent skill development is applied on this recovery day.`
                          : impactPreview
                            ? `Estimated focus progress +${impactPreview.target.toFixed(3)} · development rate ${Math.round(impactPreview.multiplier * 100)}% · expected fatigue +${impactPreview.fatigue}`
                            : 'Choose your training focus.'}
                    </span>
                  </div>
                  <button type="button" className="secondary" onClick={handleSavePlan} disabled={saving || !focusAttribute && trainingType !== 'day_off'}>
                    {saving ? 'Saving…' : planDirty ? 'Save Plan' : 'Plan Saved'}
                  </button>
                  <button
                    type="button"
                    className="primary"
                    onClick={handleCompleteToday}
                    disabled={processing || !dashboard.eligible || Boolean(dashboard.today_session) || planDirty}
                  >
                    {processing
                      ? 'Processing…'
                      : dashboard.today_session
                        ? 'Today Completed'
                        : trainingType === 'day_off'
                          ? 'Take Day Off'
                          : scheduledRole === 'active_recovery'
                            ? 'Complete Active Recovery'
                            : scheduledRole === 'full_rest'
                              ? 'Take Full Rest'
                              : 'Complete Today’s Training'}
                  </button>
                </footer>
              </section>

              <aside className="tlg-training-side">
                <section className="tlg-training-readiness-card">
                  <div className="tlg-training-readiness-ring" style={{ '--score': `${readiness * 3.6}deg` } as React.CSSProperties}>
                    <div><strong>{readiness.toFixed(0)}</strong><span>/100</span></div>
                  </div>
                  <div>
                    <span>CURRENT READINESS</span>
                    <h3>{readiness >= 70 ? 'Strong training state' : readiness >= 50 ? 'Ready to work' : 'Recovery should be considered'}</h3>
                    <p>Readiness combines Morale, Confidence, Sharpness, Focus and Freshness. It changes the efficiency of every training session.</p>
                  </div>
                </section>

                <section className="tlg-training-condition-card">
                  <header><span>LIVE CONDITION</span><strong>Training impact</strong></header>
                  {[
                    ['Fatigue', dashboard.skills.fatigue, true],
                    ['Sharpness', dashboard.skills.sharpness, false],
                    ['Morale', dashboard.skills.morale, false],
                    ['Focus', dashboard.skills.focus, false],
                  ].map(([label, rawValue, inverse]) => {
                    const value = Number(rawValue)
                    const display = Boolean(inverse) ? 100 - value : value
                    return (
                      <div className="tlg-training-condition-row" key={String(label)}>
                        <div><span>{label}</span><strong>{value}</strong></div>
                        <div><i style={{ width: `${display}%` }} /></div>
                      </div>
                    )
                  })}
                </section>

                {focusAttribute && trainingType !== 'day_off' && (
                  <section className="tlg-training-focus-card">
                    <span>SELECTED DEVELOPMENT</span>
                    <div className="tlg-training-focus-value">
                      <div>
                        <strong>{ATTRIBUTE_LABELS[focusAttribute]}</strong>
                        <small>Current skill</small>
                      </div>
                      <b>{selectedValue}</b>
                    </div>
                    <div className="tlg-training-next-level">
                      <div><span>Progress to next point</span><strong>{Math.round(selectedProgress * 100)}%</strong></div>
                      <div><i style={{ width: `${clamp(selectedProgress * 100, 0, 100)}%` }} /></div>
                    </div>
                    <p>Fractional progress accumulates between sessions. At 100%, the permanent skill increases by one point. Development naturally slows as an attribute becomes elite; there is no age-based decline or retirement modifier.</p>
                  </section>
                )}
              </aside>
            </div>

            <section className="tlg-training-engine-strip">
              <div><span>FOCUS DISTRIBUTION</span><strong>85% / 15%</strong><small>Selected attribute / remaining category</small></div>
              <div><span>WEEKLY RHYTHM</span><strong>5 + 1 + 1</strong><small>Development / active recovery / full rest</small></div>
              <div><span>DEVELOPMENT CURVE</span><strong>Skill based</strong><small>100% below 60, gradually falling to 20% at 95–99</small></div>
              <div><span>CAMP RHYTHM</span><strong>6 + 1</strong><small>Six development days plus one recovery day</small></div>
            </section>

            <section className="tlg-training-history">
              <header className="tlg-training-section-head compact">
                <div>
                  <span>TRAINING HISTORY</span>
                  <h2>Recent development days</h2>
                  <p>The last ten processed regular-training or recovery days are kept here.</p>
                </div>
              </header>

              {dashboard.recent_sessions.length === 0 ? (
                <div className="tlg-training-history-empty">No training days have been processed yet.</div>
              ) : (
                <div className="tlg-training-history-list">
                  {dashboard.recent_sessions.map((session) => (
                    <article key={session.id}>
                      <div className="date">
                        <span>S{session.season}</span>
                        <strong>{MONTH_NAMES[(session.month ?? 1) - 1]} {session.day}</strong>
                      </div>
                      <div className="session">
                        <span>{session.training_type === 'day_off' ? 'RECOVERY' : session.training_type.toUpperCase()}</span>
                        <strong>{session.session_role && session.session_role !== 'planned_training' ? sessionRoleLabel(session.session_role) : trainingLabel(session.training_type, session.focus_attribute)}</strong>
                        <small>{session.training_type === 'day_off' ? sessionRoleLabel(session.session_role) : `${titleCase(session.intensity)} intensity · ${Math.round(Number(session.efficiency) * 100)}% efficiency`}</small>
                      </div>
                      <div className="change">
                        <span>FATIGUE</span>
                        <strong>{session.fatigue_before} → {session.fatigue_after}</strong>
                      </div>
                      <div className="change">
                        <span>SKILL UPS</span>
                        <strong>{levelUpText(session.level_ups)}</strong>
                      </div>
                    </article>
                  ))}
                </div>
              )}
            </section>

            <div className="tlg-training-automation-note">
              <strong>Daily automation is prepared but intentionally not switched on yet.</strong>
              <span>It will be activated once tournament participation assigns exact travel, match, camp and injury days. Until then, today’s regular plan is processed from this page.</span>
            </div>
          </>
        )}

        {view === 'camps' && dashboard && (
          <TrainingCampsPanel gameDay={dashboard.game_day} />
        )}
      </div>
    </GameLayout>
  )
}
