import { useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'

import type { TrainingIntensity, TrainingPlan, TrainingType } from '../../hooks/useTraining'
import { useLocalization } from '../../i18n/LocalizationProvider'
import {
  useTrainingWeekPlanner,
  type TrainingDaySaveDraft,
  type TrainingWeekDay,
  type TrainingWeekPlanner,
} from '../../hooks/useTrainingWeekPlanner'

const TECHNICAL_SKILLS = ['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'] as const
const PHYSICAL_SKILLS = ['fitness','stamina','recovery','movement'] as const

type DayDraft = Pick<TrainingWeekDay, 'training_type' | 'focus_attribute' | 'intensity'>

function attributeLabel(key: string, t: TFunction) {
  return t(`trainingPage.attributes.${key}`, { defaultValue: key.replace(/_/g, ' ') })
}

function activityLabel(value: TrainingWeekDay['activity_type'], t: TFunction) {
  if (value === 'training_camp') return t('trainingPage.activity.trainingCamp')
  if (value === 'home') return t('trainingPage.activity.home')
  if (value === 'travel') return t('trainingPage.activity.travel')
  if (value === 'tournament') return t('trainingPage.activity.tournament')
  if (value === 'injury') return t('trainingPage.activity.injury')
  if (value === 'training') return t('trainingPage.activity.training')
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function planLabel(day: TrainingWeekDay, t: TFunction) {
  if (day.training_type === 'day_off') {
    if (day.plan_source === 'automatic_recovery' && day.session_role === 'active_recovery') return t('trainingPage.sessionRoles.activeRecovery')
    if (day.plan_source === 'automatic_recovery' && day.session_role === 'full_rest') return t('trainingPage.sessionRoles.fullRest')
    return t('trainingPage.planner.dayOff')
  }
  return `${attributeLabel(day.focus_attribute ?? '', t)} · ${t(`trainingPage.planner.${day.intensity}`)}`
}

function weekSummary(week: TrainingWeekPlanner | null, drafts: Record<number, DayDraft>, t: TFunction) {
  if (!week) return ''
  const days = week.days.map((day) => ({ ...day, ...(drafts[day.absolute_day] ?? {}) }))
  const blocked = days.filter((day) => day.activity_type !== 'home').length
  const planned = days.filter((day) => day.activity_type === 'home' && day.training_type !== 'day_off').length
  const rest = days.filter((day) => day.activity_type === 'home' && day.training_type === 'day_off').length
  return t('trainingPage.planner.summary', {
    training: planned,
    recovery: rest,
    calendar: blocked ? t('trainingPage.planner.calendarSummary', { count: blocked }) : '',
  })
}

interface WeeklyTrainingPlannerProps {
  defaultPlan: TrainingPlan
  processing: boolean
  todayProcessed: boolean
  onCompleteToday: () => Promise<void>
}

export default function WeeklyTrainingPlanner({
  defaultPlan,
  processing,
  todayProcessed,
  onCompleteToday,
}: WeeklyTrainingPlannerProps) {
  const { t } = useTranslation()
  const { localeTag } = useLocalization()
  const { currentWeek, nextWeek, loading, saving, error, saveDays } = useTrainingWeekPlanner()
  const [expanded, setExpanded] = useState<'current' | 'next'>('current')
  const [templateType, setTemplateType] = useState<TrainingType>(defaultPlan.training_type)
  const [templateFocus, setTemplateFocus] = useState<string | null>(defaultPlan.focus_attribute)
  const [templateIntensity, setTemplateIntensity] = useState<TrainingIntensity>(defaultPlan.intensity)
  const [drafts, setDrafts] = useState<Record<number, DayDraft>>({})
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    setTemplateType(defaultPlan.training_type)
    setTemplateFocus(defaultPlan.focus_attribute)
    setTemplateIntensity(defaultPlan.intensity)
  }, [defaultPlan.focus_attribute, defaultPlan.intensity, defaultPlan.training_type])

  useEffect(() => {
    const liveDays = new Map(
      [...(currentWeek?.days ?? []), ...(nextWeek?.days ?? [])].map((day) => [day.absolute_day, day]),
    )
    setDrafts((current) => {
      const next: Record<number, DayDraft> = {}
      Object.entries(current).forEach(([key, draft]) => {
        const day = liveDays.get(Number(key))
        if (!day?.editable || day.activity_type !== 'home' || day.processed) return
        if (
          day.training_type === draft.training_type
          && day.focus_attribute === draft.focus_attribute
          && day.intensity === draft.intensity
        ) return
        next[Number(key)] = draft
      })
      return next
    })
  }, [currentWeek, nextWeek])

  const visibleWeek = expanded === 'current' ? currentWeek : nextWeek
  const currentDay = useMemo(
    () => currentWeek?.days.find((day) => day.absolute_day === currentWeek.current_absolute_day) ?? null,
    [currentWeek],
  )
  const unsavedCount = Object.keys(drafts).length
  const currentDayHasUnsavedChanges = Boolean(currentDay && drafts[currentDay.absolute_day])

  function focusOptions(type: TrainingType) {
    return type === 'physical' ? PHYSICAL_SKILLS : TECHNICAL_SKILLS
  }

  function normalizeFocus(type: TrainingType, focus: string | null) {
    if (type === 'day_off') return null
    const options = focusOptions(type)
    return options.some((key) => key === focus) ? focus : options[0]
  }

  function dayWithDraft(day: TrainingWeekDay) {
    return { ...day, ...(drafts[day.absolute_day] ?? {}) }
  }

  function changeTemplateType(type: TrainingType) {
    setTemplateType(type)
    setTemplateFocus(normalizeFocus(type, templateFocus))
    setMessage(null)
  }

  function setDayDraft(day: TrainingWeekDay, next: DayDraft) {
    setDrafts((current) => {
      const updated = { ...current }
      const matchesSaved = day.training_type === next.training_type
        && day.focus_attribute === next.focus_attribute
        && day.intensity === next.intensity
      if (matchesSaved) delete updated[day.absolute_day]
      else updated[day.absolute_day] = next
      return updated
    })
  }

  function handleApplyWeek() {
    if (!visibleWeek) return
    const type = templateType
    const focus = normalizeFocus(templateType, templateFocus)
    let applied = 0
    setDrafts((current) => {
      const updated = { ...current }
      visibleWeek.days.forEach((day) => {
        if (!day.editable || day.activity_type !== 'home' || day.processed) return
        const next: DayDraft = { training_type: type, focus_attribute: focus, intensity: templateIntensity }
        const matchesSaved = day.training_type === next.training_type
          && day.focus_attribute === next.focus_attribute
          && day.intensity === next.intensity
        if (matchesSaved) delete updated[day.absolute_day]
        else updated[day.absolute_day] = next
        applied += 1
      })
      return updated
    })
    setMessage(t('trainingPage.planner.planPrepared', { count: applied }))
  }

  function changeDay(day: TrainingWeekDay, patch: Partial<DayDraft>) {
    if (!day.editable || saving) return
    const effective = dayWithDraft(day)
    const type = patch.training_type ?? effective.training_type
    const focus = normalizeFocus(type, patch.focus_attribute !== undefined ? patch.focus_attribute : effective.focus_attribute)
    const intensity = patch.intensity ?? effective.intensity
    setMessage(null)
    setDayDraft(day, { training_type: type, focus_attribute: focus, intensity })
  }

  async function handleSavePlan() {
    const changes: TrainingDaySaveDraft[] = Object.entries(drafts)
      .map(([absoluteDay, draft]) => ({
        absolute_day: Number(absoluteDay),
        training_type: draft.training_type,
        focus_attribute: draft.focus_attribute,
        intensity: draft.intensity,
      }))
      .sort((a, b) => a.absolute_day - b.absolute_day)

    if (changes.length === 0) return
    setMessage(null)
    const result = await saveDays(changes)
    if (!result) return
    setDrafts({})
    setMessage(t('trainingPage.planner.saved', { count: result.saved_days }))
  }

  function renderDay(baseDay: TrainingWeekDay) {
    const day = dayWithDraft(baseDay)
    const calendarOwned = day.activity_type !== 'home'
    const isToday = currentWeek?.current_absolute_day === day.absolute_day
    const changed = Boolean(drafts[day.absolute_day])
    return (
      <article className={`tlg-week-plan-day ${calendarOwned ? 'calendar-owned' : ''} ${day.processed ? 'processed' : ''} ${isToday ? 'today' : ''} ${changed ? 'unsaved' : ''}`} key={day.absolute_day}>
        <div className="tlg-week-plan-date">
          <span>{new Intl.DateTimeFormat(localeTag, { weekday: 'short' }).format(new Date(2020, Math.max(0, day.month - 1), Math.max(1, day.day))).toUpperCase()}</span>
          <strong>{new Intl.DateTimeFormat(localeTag, { month: 'short', day: 'numeric' }).format(new Date(2020, Math.max(0, day.month - 1), Math.max(1, day.day)))}</strong>
          {isToday && <small>{t('trainingPage.planner.today')}</small>}
          {changed && <small className="draft-label">{t('trainingPage.planner.unsaved')}</small>}
        </div>

        {calendarOwned ? (
          <div className="tlg-week-plan-calendar-event">
            <span>{activityLabel(day.activity_type, t).toUpperCase()}</span>
            <strong>{day.activity_note || activityLabel(day.activity_type, t)}</strong>
            <small>{t('trainingPage.planner.calendarOverride')}</small>
          </div>
        ) : day.processed || !day.editable ? (
          <div className="tlg-week-plan-locked-home">
            <span>{day.processed ? t('trainingPage.planner.completed') : t('trainingPage.planner.locked')}</span>
            <strong>{planLabel(day, t)}</strong>
            <small>{day.lock_reason || t('trainingPage.planner.cannotChange')}</small>
          </div>
        ) : (
          <div className="tlg-week-plan-controls">
            <label>
              <span>{t('trainingPage.planner.activity')}</span>
              <select value={day.training_type} onChange={(event) => changeDay(baseDay, { training_type: event.target.value as TrainingType })} disabled={saving}>
                <option value="technical">{t('trainingPage.planner.tennisSkills')}</option>
                <option value="physical">{t('trainingPage.planner.physical')}</option>
                <option value="day_off">{t('trainingPage.planner.dayOff')}</option>
              </select>
            </label>
            <label>
              <span>{t('trainingPage.planner.focus')}</span>
              <select
                value={day.focus_attribute ?? ''}
                onChange={(event) => changeDay(baseDay, { focus_attribute: event.target.value || null })}
                disabled={saving || day.training_type === 'day_off'}
              >
                {day.training_type !== 'day_off' && focusOptions(day.training_type).map((key) => <option value={key} key={key}>{attributeLabel(key, t)}</option>)}
                {day.training_type === 'day_off' && <option value="">{t('trainingPage.planner.recovery')}</option>}
              </select>
            </label>
            <label>
              <span>{t('trainingPage.planner.load')}</span>
              <select value={day.intensity} onChange={(event) => changeDay(baseDay, { intensity: event.target.value as TrainingIntensity })} disabled={saving || day.training_type === 'day_off'}>
                <option value="light">{t('trainingPage.planner.light')}</option>
                <option value="standard">{t('trainingPage.planner.standard')}</option>
                <option value="hard">{t('trainingPage.planner.hard')}</option>
              </select>
            </label>
          </div>
        )}
      </article>
    )
  }

  if (loading && !currentWeek) return <div className="tlg-week-plan-loading">{t('trainingPage.planner.loading')}</div>

  return (
    <div className="tlg-week-planner">
      {error && <div className="tlg-week-plan-error">{error}</div>}
      {message && <div className="tlg-week-plan-message">{message}</div>}

      <div className="tlg-week-planner-tabs" role="tablist" aria-label={t('trainingPage.planner.weeksAria')}>
        <button type="button" className={expanded === 'current' ? 'active' : ''} onClick={() => setExpanded('current')}>
          <span>{t('trainingPage.planner.thisWeek')}</span>
          <strong>{currentWeek ? t('trainingPage.planner.week', { week: currentWeek.season_week }) : '—'}</strong>
          <small>{weekSummary(currentWeek, drafts, t)}</small>
        </button>
        <button type="button" className={expanded === 'next' ? 'active' : ''} onClick={() => setExpanded('next')}>
          <span>{t('trainingPage.planner.nextWeek')}</span>
          <strong>{nextWeek ? t('trainingPage.planner.week', { week: nextWeek.season_week }) : '—'}</strong>
          <small>{weekSummary(nextWeek, drafts, t)}</small>
        </button>
      </div>

      {visibleWeek && (
        <>
          <section className="tlg-week-template">
            <header>
              <div>
                <span>{t('trainingPage.planner.quickPlan')}</span>
                <strong>{t('trainingPage.planner.quickPlanHeading')}</strong>
              </div>
              <small>{t('trainingPage.planner.quickPlanBody')}</small>
            </header>
            <div className="tlg-week-template-controls">
              <label>
                <span>{t('trainingPage.planner.training')}</span>
                <select value={templateType} onChange={(event) => changeTemplateType(event.target.value as TrainingType)}>
                  <option value="technical">{t('trainingPage.planner.tennisSkills')}</option>
                  <option value="physical">{t('trainingPage.planner.physical')}</option>
                  <option value="day_off">{t('trainingPage.planner.dayOff')}</option>
                </select>
              </label>
              <label>
                <span>{t('trainingPage.planner.focus')}</span>
                <select value={templateFocus ?? ''} onChange={(event) => setTemplateFocus(event.target.value || null)} disabled={templateType === 'day_off'}>
                  {templateType !== 'day_off' && focusOptions(templateType).map((key) => <option value={key} key={key}>{attributeLabel(key, t)}</option>)}
                  {templateType === 'day_off' && <option value="">{t('trainingPage.planner.recovery')}</option>}
                </select>
              </label>
              <label>
                <span>{t('trainingPage.planner.load')}</span>
                <select value={templateIntensity} onChange={(event) => setTemplateIntensity(event.target.value as TrainingIntensity)} disabled={templateType === 'day_off'}>
                  <option value="light">{t('trainingPage.planner.light')}</option>
                  <option value="standard">{t('trainingPage.planner.standard')}</option>
                  <option value="hard">{t('trainingPage.planner.hard')}</option>
                </select>
              </label>
              <button type="button" onClick={handleApplyWeek} disabled={saving}>
                {t('trainingPage.planner.applyAvailable')}
              </button>
            </div>
          </section>

          <div className="tlg-week-plan-days">
            {visibleWeek.days.map(renderDay)}
          </div>

          <footer className="tlg-week-plan-footer">
            <div>
              <strong>{unsavedCount > 0 ? t('trainingPage.planner.unsavedChanges', { count: unsavedCount }) : t('trainingPage.planner.calendarAware')}</strong>
              <span>{unsavedCount > 0 ? t('trainingPage.planner.reviewChanges') : t('trainingPage.planner.automaticSequence')}</span>
            </div>
            <div className="tlg-week-plan-footer-actions">
              <button type="button" className="save-plan" onClick={() => void handleSavePlan()} disabled={saving || unsavedCount === 0}>
                {saving ? t('trainingPage.planner.saving') : unsavedCount > 0 ? t('trainingPage.planner.savePlanCount', { count: unsavedCount }) : t('trainingPage.planner.savePlan')}
              </button>
              {expanded === 'current' && currentDay?.activity_type === 'home' && (
                <button
                  type="button"
                  className="complete-today"
                  onClick={() => void onCompleteToday()}
                  disabled={processing || todayProcessed || !currentDay || !currentDay.editable || currentDayHasUnsavedChanges}
                  title={currentDayHasUnsavedChanges ? t('trainingPage.planner.saveTodayFirst') : undefined}
                >
                  {processing ? t('trainingPage.planner.processing') : todayProcessed ? t('trainingPage.planner.todayCompleted') : currentDayHasUnsavedChanges ? t('trainingPage.planner.savePlanFirst') : t('trainingPage.planner.completeToday')}
                </button>
              )}
            </div>
          </footer>
        </>
      )}
    </div>
  )
}
