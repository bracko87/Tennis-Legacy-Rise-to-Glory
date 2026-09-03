import { useEffect, useMemo, useState } from 'react'

import type { TrainingIntensity, TrainingPlan, TrainingType } from '../../hooks/useTraining'
import {
  useTrainingWeekPlanner,
  type TrainingDaySaveDraft,
  type TrainingWeekDay,
  type TrainingWeekPlanner,
} from '../../hooks/useTrainingWeekPlanner'

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

const TECHNICAL_SKILLS = [
  ['serve', 'Serve'], ['forehand', 'Forehand'], ['backhand', 'Backhand'], ['return_skill', 'Return'],
  ['volley', 'Volley'], ['slice', 'Slice'], ['drop_shot', 'Drop Shot'], ['lob', 'Lob'], ['smash', 'Smash'],
] as const

const PHYSICAL_SKILLS = [
  ['fitness', 'Fitness'], ['stamina', 'Stamina'], ['recovery', 'Recovery'], ['movement', 'Movement'],
] as const

const ATTRIBUTE_LABELS: Record<string, string> = Object.fromEntries([...TECHNICAL_SKILLS, ...PHYSICAL_SKILLS])

type DayDraft = Pick<TrainingWeekDay, 'training_type' | 'focus_attribute' | 'intensity'>

function activityLabel(value: TrainingWeekDay['activity_type']) {
  if (value === 'training_camp') return 'Training Camp'
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function planLabel(day: TrainingWeekDay) {
  if (day.training_type === 'day_off') {
    if (day.plan_source === 'automatic_recovery' && day.session_role === 'active_recovery') return 'Active Recovery'
    if (day.plan_source === 'automatic_recovery' && day.session_role === 'full_rest') return 'Full Rest'
    return 'Day Off'
  }
  return `${ATTRIBUTE_LABELS[day.focus_attribute ?? ''] ?? 'Training'} · ${day.intensity}`
}

function weekSummary(week: TrainingWeekPlanner | null, drafts: Record<number, DayDraft>) {
  if (!week) return ''
  const days = week.days.map((day) => ({ ...day, ...(drafts[day.absolute_day] ?? {}) }))
  const blocked = days.filter((day) => day.activity_type !== 'home').length
  const planned = days.filter((day) => day.activity_type === 'home' && day.training_type !== 'day_off').length
  const rest = days.filter((day) => day.activity_type === 'home' && day.training_type === 'day_off').length
  return `${planned} training · ${rest} recovery${blocked ? ` · ${blocked} calendar` : ''}`
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
    return options.some(([key]) => key === focus) ? focus : options[0][0]
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
    setMessage(`Plan prepared for ${applied} available day${applied === 1 ? '' : 's'}. Click Save Training Plan to confirm the changes.`)
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
    setMessage(`${result.saved_days} training day${result.saved_days === 1 ? '' : 's'} saved successfully.`)
  }

  function renderDay(baseDay: TrainingWeekDay) {
    const day = dayWithDraft(baseDay)
    const calendarOwned = day.activity_type !== 'home'
    const isToday = currentWeek?.current_absolute_day === day.absolute_day
    const changed = Boolean(drafts[day.absolute_day])
    return (
      <article className={`tlg-week-plan-day ${calendarOwned ? 'calendar-owned' : ''} ${day.processed ? 'processed' : ''} ${isToday ? 'today' : ''} ${changed ? 'unsaved' : ''}`} key={day.absolute_day}>
        <div className="tlg-week-plan-date">
          <span>{day.weekday_name.slice(0, 3).toUpperCase()}</span>
          <strong>{MONTH_NAMES[day.month - 1]} {day.day}</strong>
          {isToday && <small>Today</small>}
          {changed && <small className="draft-label">Unsaved</small>}
        </div>

        {calendarOwned ? (
          <div className="tlg-week-plan-calendar-event">
            <span>{activityLabel(day.activity_type).toUpperCase()}</span>
            <strong>{day.activity_note || activityLabel(day.activity_type)}</strong>
            <small>Calendar ownership overrides Regular Training.</small>
          </div>
        ) : day.processed || !day.editable ? (
          <div className="tlg-week-plan-locked-home">
            <span>{day.processed ? 'COMPLETED' : 'LOCKED'}</span>
            <strong>{planLabel(day)}</strong>
            <small>{day.lock_reason || 'This day can no longer be changed.'}</small>
          </div>
        ) : (
          <div className="tlg-week-plan-controls">
            <label>
              <span>Activity</span>
              <select value={day.training_type} onChange={(event) => changeDay(baseDay, { training_type: event.target.value as TrainingType })} disabled={saving}>
                <option value="technical">Tennis Skills</option>
                <option value="physical">Physical</option>
                <option value="day_off">Day Off</option>
              </select>
            </label>
            <label>
              <span>Focus</span>
              <select
                value={day.focus_attribute ?? ''}
                onChange={(event) => changeDay(baseDay, { focus_attribute: event.target.value || null })}
                disabled={saving || day.training_type === 'day_off'}
              >
                {day.training_type !== 'day_off' && focusOptions(day.training_type).map(([key, label]) => <option value={key} key={key}>{label}</option>)}
                {day.training_type === 'day_off' && <option value="">Recovery</option>}
              </select>
            </label>
            <label>
              <span>Load</span>
              <select value={day.intensity} onChange={(event) => changeDay(baseDay, { intensity: event.target.value as TrainingIntensity })} disabled={saving || day.training_type === 'day_off'}>
                <option value="light">Light</option>
                <option value="standard">Standard</option>
                <option value="hard">Hard</option>
              </select>
            </label>
          </div>
        )}
      </article>
    )
  }

  if (loading && !currentWeek) return <div className="tlg-week-plan-loading">Loading weekly training plan…</div>

  return (
    <div className="tlg-week-planner">
      {error && <div className="tlg-week-plan-error">{error}</div>}
      {message && <div className="tlg-week-plan-message">{message}</div>}

      <div className="tlg-week-planner-tabs" role="tablist" aria-label="Training weeks">
        <button type="button" className={expanded === 'current' ? 'active' : ''} onClick={() => setExpanded('current')}>
          <span>THIS WEEK</span>
          <strong>{currentWeek ? `Week ${currentWeek.season_week}` : '—'}</strong>
          <small>{weekSummary(currentWeek, drafts)}</small>
        </button>
        <button type="button" className={expanded === 'next' ? 'active' : ''} onClick={() => setExpanded('next')}>
          <span>NEXT WEEK</span>
          <strong>{nextWeek ? `Week ${nextWeek.season_week}` : '—'}</strong>
          <small>{weekSummary(nextWeek, drafts)}</small>
        </button>
      </div>

      {visibleWeek && (
        <>
          <section className="tlg-week-template">
            <header>
              <div>
                <span>QUICK WEEK PLAN</span>
                <strong>Use one plan for every available day</strong>
              </div>
              <small>Travel, tournaments, camps, injuries and already processed days are never overwritten. Changes are saved only when you click Save Training Plan.</small>
            </header>
            <div className="tlg-week-template-controls">
              <label>
                <span>Training</span>
                <select value={templateType} onChange={(event) => changeTemplateType(event.target.value as TrainingType)}>
                  <option value="technical">Tennis Skills</option>
                  <option value="physical">Physical</option>
                  <option value="day_off">Day Off</option>
                </select>
              </label>
              <label>
                <span>Focus</span>
                <select value={templateFocus ?? ''} onChange={(event) => setTemplateFocus(event.target.value || null)} disabled={templateType === 'day_off'}>
                  {templateType !== 'day_off' && focusOptions(templateType).map(([key, label]) => <option value={key} key={key}>{label}</option>)}
                  {templateType === 'day_off' && <option value="">Recovery</option>}
                </select>
              </label>
              <label>
                <span>Load</span>
                <select value={templateIntensity} onChange={(event) => setTemplateIntensity(event.target.value as TrainingIntensity)} disabled={templateType === 'day_off'}>
                  <option value="light">Light</option>
                  <option value="standard">Standard</option>
                  <option value="hard">Hard</option>
                </select>
              </label>
              <button type="button" onClick={handleApplyWeek} disabled={saving}>
                Apply to available days
              </button>
            </div>
          </section>

          <div className="tlg-week-plan-days">
            {visibleWeek.days.map(renderDay)}
          </div>

          <footer className="tlg-week-plan-footer">
            <div>
              <strong>{unsavedCount > 0 ? `${unsavedCount} unsaved training change${unsavedCount === 1 ? '' : 's'}` : 'Calendar-aware training'}</strong>
              <span>{unsavedCount > 0 ? 'Review the changed days above, then save the plan. Tournament, travel, camp and injury ownership will still override Regular Training automatically.' : 'When Match Engine updates a tournament exit, the planner automatically follows the new Tournament → Travel → Home sequence and training becomes available again on the remaining Home days.'}</span>
            </div>
            <div className="tlg-week-plan-footer-actions">
              <button type="button" className="save-plan" onClick={() => void handleSavePlan()} disabled={saving || unsavedCount === 0}>
                {saving ? 'Saving…' : unsavedCount > 0 ? `Save Training Plan (${unsavedCount})` : 'Save Training Plan'}
              </button>
              {expanded === 'current' && currentDay?.activity_type === 'home' && (
                <button
                  type="button"
                  className="complete-today"
                  onClick={() => void onCompleteToday()}
                  disabled={processing || todayProcessed || !currentDay || !currentDay.editable || currentDayHasUnsavedChanges}
                  title={currentDayHasUnsavedChanges ? "Save today's training plan before completing it." : undefined}
                >
                  {processing ? 'Processing…' : todayProcessed ? 'Today Completed' : currentDayHasUnsavedChanges ? 'Save Plan First' : 'Complete Today'}
                </button>
              )}
            </div>
          </footer>
        </>
      )}
    </div>
  )
}
