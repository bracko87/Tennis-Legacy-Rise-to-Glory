import { useEffect, useMemo, useState } from 'react'

import type { TrainingIntensity, TrainingPlan, TrainingType } from '../../hooks/useTraining'
import { useTrainingWeekPlanner, type TrainingWeekDay, type TrainingWeekPlanner } from '../../hooks/useTrainingWeekPlanner'

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

function weekSummary(week: TrainingWeekPlanner | null) {
  if (!week) return ''
  const blocked = week.days.filter((day) => day.activity_type !== 'home').length
  const planned = week.days.filter((day) => day.activity_type === 'home' && day.training_type !== 'day_off').length
  const rest = week.days.filter((day) => day.activity_type === 'home' && day.training_type === 'day_off').length
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
  const { currentWeek, nextWeek, loading, saving, error, saveDay, applyWeek } = useTrainingWeekPlanner()
  const [expanded, setExpanded] = useState<'current' | 'next'>('current')
  const [templateType, setTemplateType] = useState<TrainingType>(defaultPlan.training_type)
  const [templateFocus, setTemplateFocus] = useState<string | null>(defaultPlan.focus_attribute)
  const [templateIntensity, setTemplateIntensity] = useState<TrainingIntensity>(defaultPlan.intensity)
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    setTemplateType(defaultPlan.training_type)
    setTemplateFocus(defaultPlan.focus_attribute)
    setTemplateIntensity(defaultPlan.intensity)
  }, [defaultPlan.focus_attribute, defaultPlan.intensity, defaultPlan.training_type])

  const visibleWeek = expanded === 'current' ? currentWeek : nextWeek
  const currentDay = useMemo(
    () => currentWeek?.days.find((day) => day.absolute_day === currentWeek.current_absolute_day) ?? null,
    [currentWeek],
  )

  function focusOptions(type: TrainingType) {
    return type === 'physical' ? PHYSICAL_SKILLS : TECHNICAL_SKILLS
  }

  function normalizeFocus(type: TrainingType, focus: string | null) {
    if (type === 'day_off') return null
    const options = focusOptions(type)
    return options.some(([key]) => key === focus) ? focus : options[0][0]
  }

  function changeTemplateType(type: TrainingType) {
    setTemplateType(type)
    setTemplateFocus(normalizeFocus(type, templateFocus))
    setMessage(null)
  }

  async function handleApplyWeek() {
    if (!visibleWeek) return
    setMessage(null)
    const result = await applyWeek(
      visibleWeek.week_start_absolute_day,
      templateType,
      normalizeFocus(templateType, templateFocus),
      templateIntensity,
    )
    if (result) {
      setMessage(`Plan applied to ${result.applied_days} available day${result.applied_days === 1 ? '' : 's'}.${result.skipped_days ? ` ${result.skipped_days} calendar/processed day${result.skipped_days === 1 ? '' : 's'} kept unchanged.` : ''}`)
    }
  }

  async function changeDay(day: TrainingWeekDay, patch: Partial<Pick<TrainingWeekDay, 'training_type' | 'focus_attribute' | 'intensity'>>) {
    if (!day.editable || saving) return
    const type = patch.training_type ?? day.training_type
    const focus = normalizeFocus(type, patch.focus_attribute !== undefined ? patch.focus_attribute : day.focus_attribute)
    const intensity = patch.intensity ?? day.intensity
    setMessage(null)
    const saved = await saveDay(day.absolute_day, type, focus, intensity)
    if (saved) setMessage(`${day.weekday_name} plan saved.`)
  }

  function renderDay(day: TrainingWeekDay) {
    const calendarOwned = day.activity_type !== 'home'
    const isToday = currentWeek?.current_absolute_day === day.absolute_day
    return (
      <article className={`tlg-week-plan-day ${calendarOwned ? 'calendar-owned' : ''} ${day.processed ? 'processed' : ''} ${isToday ? 'today' : ''}`} key={day.absolute_day}>
        <div className="tlg-week-plan-date">
          <span>{day.weekday_name.slice(0, 3).toUpperCase()}</span>
          <strong>{MONTH_NAMES[day.month - 1]} {day.day}</strong>
          {isToday && <small>Today</small>}
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
              <select value={day.training_type} onChange={(event) => void changeDay(day, { training_type: event.target.value as TrainingType })} disabled={saving}>
                <option value="technical">Tennis Skills</option>
                <option value="physical">Physical</option>
                <option value="day_off">Day Off</option>
              </select>
            </label>
            <label>
              <span>Focus</span>
              <select
                value={day.focus_attribute ?? ''}
                onChange={(event) => void changeDay(day, { focus_attribute: event.target.value || null })}
                disabled={saving || day.training_type === 'day_off'}
              >
                {day.training_type !== 'day_off' && focusOptions(day.training_type).map(([key, label]) => <option value={key} key={key}>{label}</option>)}
                {day.training_type === 'day_off' && <option value="">Recovery</option>}
              </select>
            </label>
            <label>
              <span>Load</span>
              <select value={day.intensity} onChange={(event) => void changeDay(day, { intensity: event.target.value as TrainingIntensity })} disabled={saving || day.training_type === 'day_off'}>
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
          <small>{weekSummary(currentWeek)}</small>
        </button>
        <button type="button" className={expanded === 'next' ? 'active' : ''} onClick={() => setExpanded('next')}>
          <span>NEXT WEEK</span>
          <strong>{nextWeek ? `Week ${nextWeek.season_week}` : '—'}</strong>
          <small>{weekSummary(nextWeek)}</small>
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
              <small>Travel, tournaments, camps, injuries and already processed days are never overwritten.</small>
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
              <button type="button" onClick={() => void handleApplyWeek()} disabled={saving}>
                {saving ? 'Saving…' : 'Apply to available days'}
              </button>
            </div>
          </section>

          <div className="tlg-week-plan-days">
            {visibleWeek.days.map(renderDay)}
          </div>

          <footer className="tlg-week-plan-footer">
            <div>
              <strong>Calendar-aware training</strong>
              <span>When Match Engine updates a tournament exit, the planner automatically follows the new Tournament → Travel → Home sequence and training becomes available again on the remaining Home days.</span>
            </div>
            {expanded === 'current' && currentDay?.activity_type === 'home' && (
              <button type="button" onClick={() => void onCompleteToday()} disabled={processing || todayProcessed || !currentDay || !currentDay.editable}>
                {processing ? 'Processing…' : todayProcessed ? 'Today Completed' : 'Complete Today'}
              </button>
            )}
          </footer>
        </>
      )}
    </div>
  )
}
