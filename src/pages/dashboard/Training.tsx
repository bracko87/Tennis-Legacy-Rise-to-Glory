import { useState } from 'react'

import GameLayout from '../../components/layout/GameLayout'
import TrainingCampsPanel from '../../components/training/TrainingCampsPanel'
import TrainingProgressOverview from '../../components/training/TrainingProgressOverview'
import WeeklyTrainingPlanner from '../../components/training/WeeklyTrainingPlanner'
import {
  type TrainingSession,
  type TrainingSessionRole,
  type TrainingType,
  useTraining,
} from '../../hooks/useTraining'
import '../../styles/training.css'
import '../../styles/training-weekly-planner.css'
import '../../styles/training-history.css'

type TrainingView = 'regular' | 'camps'

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

const ATTRIBUTE_LABELS: Record<string, string> = {
  serve: 'Serve',
  forehand: 'Forehand',
  backhand: 'Backhand',
  return_skill: 'Return',
  volley: 'Volley',
  slice: 'Slice',
  drop_shot: 'Drop Shot',
  lob: 'Lob',
  smash: 'Smash',
  fitness: 'Fitness',
  stamina: 'Stamina',
  recovery: 'Recovery',
  movement: 'Movement',
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

function signedDelta(before?: number, after?: number) {
  if (before === undefined || after === undefined) return '—'
  const delta = Number(after) - Number(before)
  if (delta === 0) return '±0'
  return `${delta > 0 ? '+' : ''}${delta}`
}

function progressGain(value: number) {
  return `+${(Number(value) * 100).toFixed(1)}%`
}

function focusDevelopment(session: TrainingSession) {
  if (session.training_type === 'day_off' || !session.focus_attribute) return null
  return Number(session.development_gains?.[session.focus_attribute] ?? 0)
}

function sharedDevelopment(session: TrainingSession) {
  if (session.training_type === 'day_off') return 0
  return Object.entries(session.development_gains ?? {}).reduce((total, [key, value]) => (
    key === session.focus_attribute ? total : total + Number(value ?? 0)
  ), 0)
}

export default function TrainingPage() {
  const {
    dashboard,
    loading,
    processing,
    error,
    completeToday,
  } = useTraining()

  const [view, setView] = useState<TrainingView>('regular')
  const [actionMessage, setActionMessage] = useState<string | null>(null)

  const readiness = dashboard ? scoreReadiness(dashboard.skills) : 0

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
              Build your weekly routine around tournaments, travel and recovery. Regular Training is available only when the calendar says your player is at home.
            </p>
          </div>

          {dashboard && (
            <div className="tlg-training-hero-metrics">
              <div>
                <span>TODAY</span>
                <strong>{activityLabel(dashboard.activity_type)}</strong>
                <small>Season {dashboard.game_day.season} · {MONTH_NAMES[dashboard.game_day.month - 1]} {dashboard.game_day.day}</small>
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
                    <span>WEEKLY TRAINING PLAN</span>
                    <h2>Plan this week and next week</h2>
                    <p>Choose a different skill and load for every Home day, use Day Off whenever you want recovery, or apply one plan across the whole available week. Tournament, travel, camp and injury days automatically take priority.</p>
                  </div>
                  <div className={`tlg-training-status ${dashboard.eligible ? 'available' : 'blocked'}`}>
                    <span>{dashboard.eligible ? 'HOME DAY' : 'CALENDAR'}</span>
                    <strong>{activityLabel(dashboard.activity_type)}</strong>
                  </div>
                </header>

                <WeeklyTrainingPlanner
                  defaultPlan={dashboard.plan}
                  processing={processing}
                  todayProcessed={Boolean(dashboard.today_session)}
                  onCompleteToday={handleCompleteToday}
                />
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

                <TrainingProgressOverview dashboard={dashboard} />
              </aside>
            </div>

            <section className="tlg-training-engine-strip">
              <div><span>FOCUS DISTRIBUTION</span><strong>85% / 15%</strong><small>Selected attribute / remaining category</small></div>
              <div><span>WEEKLY PLANNER</span><strong>7 days</strong><small>User plan on Home days · calendar ownership always wins</small></div>
              <div><span>DEVELOPMENT CURVE</span><strong>Skill based</strong><small>100% below 60, gradually falling to 20% at 95–99</small></div>
              <div><span>CAMP RHYTHM</span><strong>6 + 1</strong><small>Six development days plus one recovery day</small></div>
            </section>

            <section className="tlg-training-history">
              <header className="tlg-training-section-head compact">
                <div>
                  <span>TRAINING HISTORY</span>
                  <h2>Recent development days</h2>
                  <p>The last three processed Regular Training or recovery days are shown here, including development and condition changes from each session.</p>
                </div>
              </header>

              {dashboard.recent_sessions.length === 0 ? (
                <div className="tlg-training-history-empty">No training days have been processed yet.</div>
              ) : (
                <div className="tlg-training-history-list">
                  {dashboard.recent_sessions.slice(0, 3).map((session) => {
                    const focusGain = focusDevelopment(session)
                    const sharedGain = sharedDevelopment(session)
                    const fatigueDelta = Number(session.fatigue_after) - Number(session.fatigue_before)
                    const sharpnessDelta = Number(session.sharpness_after) - Number(session.sharpness_before)
                    return (
                      <article className="tlg-training-history-row" key={session.id}>
                        <div className="date">
                          <span>Season {session.season}</span>
                          <strong>{MONTH_NAMES[(session.month ?? 1) - 1]} {session.day}</strong>
                          <small>{session.session_role ? sessionRoleLabel(session.session_role) : 'Training day'}</small>
                        </div>

                        <div className="session">
                          <span>{session.training_type === 'day_off' ? 'RECOVERY' : session.training_type.toUpperCase()}</span>
                          <strong>{session.session_role && session.session_role !== 'planned_training' ? sessionRoleLabel(session.session_role) : trainingLabel(session.training_type, session.focus_attribute)}</strong>
                          <small>{session.training_type === 'day_off' ? 'Recovery session' : `${titleCase(session.intensity)} load`}</small>
                        </div>

                        <div className="metric development">
                          <span>DEVELOPMENT</span>
                          {session.training_type === 'day_off' ? (
                            <>
                              <strong>Recovery day</strong>
                              <small>No permanent attribute development</small>
                            </>
                          ) : (
                            <>
                              <strong>{focusGain !== null ? `${ATTRIBUTE_LABELS[session.focus_attribute ?? ''] ?? 'Focus'} ${progressGain(focusGain)}` : 'Development applied'}</strong>
                              <small>Shared attributes {progressGain(sharedGain)}</small>
                            </>
                          )}
                        </div>

                        <div className="metric condition">
                          <span>CONDITION</span>
                          <strong className={fatigueDelta > 0 ? 'fatigue-up' : fatigueDelta < 0 ? 'fatigue-down' : ''}>
                            Fatigue {signedDelta(session.fatigue_before, session.fatigue_after)} · {session.fatigue_before} → {session.fatigue_after}
                          </strong>
                          <small>Sharpness {signedDelta(session.sharpness_before, session.sharpness_after)} · {session.sharpness_before} → {session.sharpness_after}{session.morale_before !== undefined && session.morale_after !== undefined ? ` · Morale ${signedDelta(session.morale_before, session.morale_after)}` : ''}{session.focus_before !== undefined && session.focus_after !== undefined ? ` · Focus ${signedDelta(session.focus_before, session.focus_after)}` : ''}</small>
                        </div>

                        <div className="result">
                          <span>SESSION RESULT</span>
                          <strong>{levelUpText(session.level_ups)}</strong>
                          <small>Sharpness {sharpnessDelta >= 0 ? '+' : ''}{sharpnessDelta}</small>
                          <b className="history-efficiency">{Math.round(Number(session.efficiency) * 100)}% efficiency</b>
                        </div>
                      </article>
                    )
                  })}
                </div>
              )}
            </section>

            <div className="tlg-training-automation-note">
              <strong>The weekly planner is already compatible with automatic daily processing.</strong>
              <span>When the Match Engine starts assigning exact tournament days and tournament exits, those days will override training automatically; after elimination, the travel-home day remains blocked and the remaining Home days become trainable again.</span>
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
