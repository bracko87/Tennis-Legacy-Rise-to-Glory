import { useEffect, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { useSearchParams } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
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
import '../../styles/shared-segmented-tabs.css'
import '../../styles/training-weekly-planner.css'
import '../../styles/training-history.css'

type TrainingView = 'regular' | 'camps'

function attributeLabel(key: string, t: TFunction) {
  const known = ['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash','fitness','stamina','recovery','movement','fatigue','sharpness','morale','focus']
  return known.includes(key) ? t(`trainingPage.attributes.${key}`) : key.replace(/_/g, ' ')
}

function titleCase(value: string) {
  return value.split('_').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ')
}

function activityLabel(value: string, t: TFunction) {
  const key = value.replaceAll('-', '_')
  if (key === 'training_camp') return t('trainingPage.activity.trainingCamp')
  if (key === 'home') return t('trainingPage.activity.home')
  if (key === 'travel') return t('trainingPage.activity.travel')
  if (key === 'tournament') return t('trainingPage.activity.tournament')
  if (key === 'injury') return t('trainingPage.activity.injury')
  if (key === 'training') return t('trainingPage.activity.training')
  return titleCase(value)
}

function trainingLabel(type: TrainingType, focus: string | null, t: TFunction) {
  if (type === 'day_off') return t('trainingPage.trainingLabels.dayOff')
  if (focus) return t('trainingPage.trainingLabels.focus', { attribute: attributeLabel(focus, t) })
  return type === 'technical' ? t('trainingPage.trainingLabels.technical') : t('trainingPage.trainingLabels.physical')
}

function sessionRoleLabel(role: TrainingSessionRole | null | undefined, t: TFunction) {
  if (role === 'active_recovery') return t('trainingPage.sessionRoles.activeRecovery')
  if (role === 'full_rest') return t('trainingPage.sessionRoles.fullRest')
  if (role === 'user_day_off') return t('trainingPage.sessionRoles.dayOff')
  return t('trainingPage.sessionRoles.development')
}

function scoreReadiness(skills: NonNullable<ReturnType<typeof useTraining>['dashboard']>['skills']) {
  return (
    skills.morale + skills.confidence + skills.sharpness + skills.focus + (100 - skills.fatigue)
  ) / 5
}

function levelUpText(levelUps: Record<string, number> | undefined, t: TFunction) {
  if (!levelUps || Object.keys(levelUps).length === 0) return t('trainingPage.noSkillPoint')
  return Object.entries(levelUps)
    .map(([key, value]) => t('trainingPage.levelUp', { attribute: attributeLabel(key, t), value }))
    .join(', ')
}

function signedDelta(before?: number, after?: number) {
  if (before === undefined || after === undefined) return '—'
  const delta = Number(after) - Number(before)
  if (delta === 0) return '±0'
  return `${delta > 0 ? '+' : ''}${delta}`
}

function formatCampDate(month: number, day: number, localeTag: string) {
  return new Intl.DateTimeFormat(localeTag, { month: 'short', day: 'numeric' })
    .format(new Date(2020, Math.max(0, month - 1), Math.max(1, day)))
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
  const { t } = useTranslation()
  const { localeTag, formatCurrency } = useLocalization()
  const [searchParams] = useSearchParams()
  const requestedView = searchParams.get('view')
  const {
    dashboard,
    loading,
    processing,
    error,
    completeToday,
  } = useTraining()

  const [view, setView] = useState<TrainingView>(() => requestedView === 'camps' ? 'camps' : 'regular')
  const [actionMessage, setActionMessage] = useState<string | null>(null)

  useEffect(() => {
    if (requestedView === 'regular' || requestedView === 'camps') setView(requestedView)
  }, [requestedView])

  const readiness = dashboard ? scoreReadiness(dashboard.skills) : 0

  async function handleCompleteToday() {
    setActionMessage(null)
    const result = await completeToday()
    if (!result) return
    if (result.status === 'blocked') {
      setActionMessage(result.reason ?? t('trainingPage.unavailableToday'))
    } else if (result.status === 'already_processed') {
      setActionMessage(t('trainingPage.alreadyProcessed'))
    } else if (result.session_role === 'active_recovery') {
      setActionMessage(t('trainingPage.activeRecoveryDone'))
    } else if (result.session_role === 'full_rest') {
      setActionMessage(t('trainingPage.fullRestDone'))
    } else {
      setActionMessage(
        result.training_type === 'day_off'
          ? t('trainingPage.dayOffDone')
          : t('trainingPage.trainingDone', { result: levelUpText(result.level_ups, t) }),
      )
    }
  }

  if (loading && !dashboard) {
    return (
      <GameLayout title={t('trainingPage.title')} subtitle={t('trainingPage.subtitle')}>
        <div className="tlg-training-loading">{t('trainingPage.loading')}</div>
      </GameLayout>
    )
  }

  return (
    <GameLayout title={t('trainingPage.title')} subtitle={t('trainingPage.subtitle')}>
      <div className="tlg-training-page">
        <section className="tlg-training-hero">
          <div className="tlg-training-hero-copy">
            <span>{t('trainingPage.eyebrow')}</span>
            <h1>{t('trainingPage.heading')}</h1>
            <p>
              {t('trainingPage.intro')}
            </p>
          </div>

          {dashboard && (
            <div className="tlg-training-hero-metrics">
              <div>
                <span>{t('trainingPage.today')}</span>
                <strong>{activityLabel(dashboard.activity_type, t)}</strong>
                <small>{t('trainingPage.seasonDate', { season: dashboard.game_day.season, date: formatCampDate(dashboard.game_day.month, dashboard.game_day.day, localeTag) })}</small>
              </div>
              <div>
                <span>{t('trainingPage.readiness')}</span>
                <strong>{readiness.toFixed(0)}<em>/100</em></strong>
                <small>{readiness >= 70 ? t('trainingPage.readinessStrong') : readiness >= 50 ? t('trainingPage.readinessReady') : t('trainingPage.recoveryRecommended')}</small>
              </div>
              <div>
                <span>{t('trainingPage.fatigue')}</span>
                <strong>{dashboard.skills.fatigue}<em>/100</em></strong>
                <small>{t('trainingPage.lowerBetter')}</small>
              </div>
            </div>
          )}
        </section>

        <div className="tlg-training-main-tabs tlg-standard-tabs" role="tablist" aria-label={t('trainingPage.areasAria')}>
          <button type="button" className={view === 'regular' ? 'active' : ''} onClick={() => setView('regular')}>{t('trainingPage.regularTraining')}</button>
          <button type="button" className={view === 'camps' ? 'active' : ''} onClick={() => setView('camps')}>{t('trainingPage.trainingCamps')}</button>
        </div>

        {error && <div className="tlg-training-alert tlg-training-alert-error">{error}</div>}
        {actionMessage && <div className="tlg-training-alert">{actionMessage}</div>}

        {view === 'regular' && dashboard && (
          <>
            {dashboard.current_or_planned_camp && (
              <section className="tlg-training-camp-booking-banner">
                <div>
                  <span>{t('trainingPage.campBooked')}</span>
                  <h2>{dashboard.current_or_planned_camp.name}</h2>
                  <p>
                    {t('trainingPage.campMeta', {
                      city: dashboard.current_or_planned_camp.city,
                      country: dashboard.current_or_planned_camp.country,
                      season: dashboard.current_or_planned_camp.start_season,
                      week: dashboard.current_or_planned_camp.start_season_week ?? '—',
                      start: formatCampDate(dashboard.current_or_planned_camp.start_month, dashboard.current_or_planned_camp.start_day, localeTag),
                      end: formatCampDate(dashboard.current_or_planned_camp.end_month, dashboard.current_or_planned_camp.end_day, localeTag),
                      days: dashboard.current_or_planned_camp.effective_training_days,
                    })}
                    {dashboard.current_or_planned_camp.shortened_days > 0 ? t('trainingPage.campShortened', { count: dashboard.current_or_planned_camp.shortened_days }) : ''}
                  </p>
                  <small>{t('trainingPage.regularLockedByCamp')}</small>
                </div>
                <div className="tlg-training-camp-booking-actions">
                  <span className={`status ${dashboard.current_or_planned_camp.status}`}>{dashboard.current_or_planned_camp.status}</span>
                  <strong>{formatCurrency(dashboard.current_or_planned_camp.total_cost, 'USD')}</strong>
                  <button type="button" onClick={() => setView('camps')}>{t('trainingPage.openCamp')}</button>
                </div>
              </section>
            )}

            <div className="tlg-training-workspace">
              <section className="tlg-training-plan-panel">
                <header className="tlg-training-section-head">
                  <div>
                    <span>{t('trainingPage.weeklyPlan')}</span>
                    <h2>{t('trainingPage.planWeeks')}</h2>
                    <p>{t('trainingPage.planWeeksBody')}</p>
                  </div>
                  <div className={`tlg-training-status ${dashboard.eligible ? 'available' : 'blocked'}`}>
                    <span>{dashboard.eligible ? t('trainingPage.homeDay') : t('trainingPage.calendar')}</span>
                    <strong>{activityLabel(dashboard.activity_type, t)}</strong>
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
                    <span>{t('trainingPage.currentReadiness')}</span>
                    <h3>{readiness >= 70 ? t('trainingPage.strongTrainingState') : readiness >= 50 ? t('trainingPage.readyToWork') : t('trainingPage.considerRecovery')}</h3>
                    <p>{t('trainingPage.readinessBody')}</p>
                  </div>
                </section>

                <section className="tlg-training-condition-card">
                  <header><span>{t('trainingPage.liveCondition')}</span><strong>{t('trainingPage.trainingImpact')}</strong></header>
                  {[
                    [t('trainingPage.attributes.fatigue'), dashboard.skills.fatigue, true],
                    [t('trainingPage.attributes.sharpness'), dashboard.skills.sharpness, false],
                    [t('trainingPage.attributes.morale'), dashboard.skills.morale, false],
                    [t('trainingPage.attributes.focus'), dashboard.skills.focus, false],
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
              <div><span>{t('trainingPage.focusDistribution')}</span><strong>{t('trainingPage.focusDistributionValue')}</strong><small>{t('trainingPage.focusDistributionBody')}</small></div>
              <div><span>{t('trainingPage.weeklyPlanner')}</span><strong>{t('trainingPage.sevenDays')}</strong><small>{t('trainingPage.weeklyPlannerBody')}</small></div>
              <div><span>{t('trainingPage.developmentCurve')}</span><strong>{t('trainingPage.skillBased')}</strong><small>{t('trainingPage.developmentCurveBody')}</small></div>
              <div><span>{t('trainingPage.campRhythm')}</span><strong>{t('trainingPage.campRhythmValue')}</strong><small>{t('trainingPage.campRhythmBody')}</small></div>
            </section>

            <section className="tlg-training-history">
              <header className="tlg-training-section-head compact">
                <div>
                  <span>{t('trainingPage.history')}</span>
                  <h2>{t('trainingPage.recentDays')}</h2>
                  <p>{t('trainingPage.historyBody')}</p>
                </div>
              </header>

              {dashboard.recent_sessions.length === 0 ? (
                <div className="tlg-training-history-empty">{t('trainingPage.noHistory')}</div>
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
                          <span>{t('overviewPage.season', { season: session.season })}</span>
                          <strong>{formatCampDate(session.month ?? 1, session.day ?? 1, localeTag)}</strong>
                          <small>{session.session_role ? sessionRoleLabel(session.session_role, t) : t('trainingPage.sessionRoles.trainingDay')}</small>
                        </div>

                        <div className="session">
                          <span>{session.training_type === 'day_off' ? t('trainingPage.recovery') : session.training_type === 'technical' ? t('trainingPage.trainingLabels.technical').toUpperCase() : t('trainingPage.trainingLabels.physical').toUpperCase()}</span>
                          <strong>{session.session_role && session.session_role !== 'planned_training' ? sessionRoleLabel(session.session_role, t) : trainingLabel(session.training_type, session.focus_attribute, t)}</strong>
                          <small>{session.training_type === 'day_off' ? t('trainingPage.recoverySession') : t('trainingPage.load', { intensity: t(`trainingPage.intensity.${session.intensity}`) })}</small>
                        </div>

                        <div className="metric development">
                          <span>{t('trainingPage.development')}</span>
                          {session.training_type === 'day_off' ? (
                            <>
                              <strong>{t('trainingPage.recoveryDay')}</strong>
                              <small>{t('trainingPage.noPermanentDevelopment')}</small>
                            </>
                          ) : (
                            <>
                              <strong>{focusGain !== null ? `${attributeLabel(session.focus_attribute ?? '', t)} ${progressGain(focusGain)}` : t('trainingPage.developmentApplied')}</strong>
                              <small>{t('trainingPage.sharedAttributes', { gain: progressGain(sharedGain) })}</small>
                            </>
                          )}
                        </div>

                        <div className="metric condition">
                          <span>{t('trainingPage.condition')}</span>
                          <strong className={fatigueDelta > 0 ? 'fatigue-up' : fatigueDelta < 0 ? 'fatigue-down' : ''}>
                            {t('trainingPage.fatigueChange', { change: signedDelta(session.fatigue_before, session.fatigue_after), before: session.fatigue_before, after: session.fatigue_after })}
                          </strong>
                          <small>{t('trainingPage.conditionDetail', {
                            sharpness: signedDelta(session.sharpness_before, session.sharpness_after),
                            sharpBefore: session.sharpness_before,
                            sharpAfter: session.sharpness_after,
                            morale: session.morale_before !== undefined && session.morale_after !== undefined ? t('trainingPage.moraleChange', { change: signedDelta(session.morale_before, session.morale_after) }) : '',
                            focus: session.focus_before !== undefined && session.focus_after !== undefined ? t('trainingPage.focusChange', { change: signedDelta(session.focus_before, session.focus_after) }) : '',
                          })}</small>
                        </div>

                        <div className="result">
                          <span>{t('trainingPage.sessionResult')}</span>
                          <strong>{levelUpText(session.level_ups, t)}</strong>
                          <small>{t('trainingPage.sharpnessChange', { change: `${sharpnessDelta >= 0 ? '+' : ''}${sharpnessDelta}` })}</small>
                          <b className="history-efficiency">{t('trainingPage.efficiency', { value: Math.round(Number(session.efficiency) * 100) })}</b>
                        </div>
                      </article>
                    )
                  })}
                </div>
              )}
            </section>

            <div className="tlg-training-automation-note">
              <strong>{t('trainingPage.automationTitle')}</strong>
              <span>{t('trainingPage.automationBody')}</span>
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
