import { useState } from 'react'

import type { TrainingDashboard } from '../../hooks/useTraining'
import '../../styles/training-staff-impact.css'

const TECHNICAL_SKILLS = [
  ['serve', 'Serve'], ['forehand', 'Forehand'], ['backhand', 'Backhand'], ['return_skill', 'Return'],
  ['volley', 'Volley'], ['slice', 'Slice'], ['drop_shot', 'Drop Shot'], ['lob', 'Lob'], ['smash', 'Smash'],
] as const

const PHYSICAL_SKILLS = [
  ['fitness', 'Fitness'], ['stamina', 'Stamina'], ['recovery', 'Recovery'], ['movement', 'Movement'],
] as const

function clamp(value: number) {
  return Math.max(0, Math.min(100, value))
}

function multiplierPercent(value: number) {
  return Math.max(0, (Number(value || 1) - 1) * 100)
}

function signedPositive(value: number) {
  return `+${value.toFixed(1)}%`
}

function signedReduction(value: number) {
  return `-${(Math.max(0, Number(value || 0)) * 100).toFixed(1)}%`
}

export default function TrainingProgressOverview({ dashboard }: { dashboard: TrainingDashboard }) {
  const [mode, setMode] = useState<'technical' | 'physical'>('technical')
  const skills = mode === 'technical' ? TECHNICAL_SKILLS : PHYSICAL_SKILLS
  const staff = dashboard.staff_effects
  const staffRows = [
    { label: 'Technical training', value: multiplierPercent(staff.technical_training_multiplier), display: signedPositive(multiplierPercent(staff.technical_training_multiplier)), note: 'Every planned technical session' },
    { label: 'Physical training', value: multiplierPercent(staff.physical_training_multiplier), display: signedPositive(multiplierPercent(staff.physical_training_multiplier)), note: 'Every planned physical session' },
    { label: 'Training fatigue gain', value: Math.max(0, Number(staff.training_fatigue_reduction || 0) * 100), display: signedReduction(staff.training_fatigue_reduction), note: 'Every planned training session' },
    { label: 'Tennis-skill camps', value: multiplierPercent(staff.technical_camp_multiplier), display: signedPositive(multiplierPercent(staff.technical_camp_multiplier)), note: 'When the Head Coach travels with the camp' },
    { label: 'Physical camps', value: multiplierPercent(staff.physical_camp_multiplier), display: signedPositive(multiplierPercent(staff.physical_camp_multiplier)), note: 'When the Fitness Coach travels with the camp' },
    { label: 'Day Off recovery', value: multiplierPercent(staff.recovery_multiplier), display: signedPositive(multiplierPercent(staff.recovery_multiplier)), note: 'Player-selected Day Off' },
  ].filter((row) => row.value > 0.001)

  return (
    <section className="tlg-training-progress-overview">
      <header>
        <div>
          <span>DEVELOPMENT PROGRESS</span>
          <strong>Progress to next skill point</strong>
        </div>
        <div className="tlg-progress-mode-tabs">
          <button type="button" className={mode === 'technical' ? 'active' : ''} onClick={() => setMode('technical')}>Tennis</button>
          <button type="button" className={mode === 'physical' ? 'active' : ''} onClick={() => setMode('physical')}>Physical</button>
        </div>
      </header>

      <div className="tlg-training-progress-list">
        {skills.map(([key, label]) => {
          const value = Number((dashboard.skills as unknown as Record<string, number>)[key] ?? 0)
          const rawProgress = Number((dashboard.progress as unknown as Record<string, number>)[key] ?? 0)
          const percent = clamp(rawProgress * 100)
          return (
            <div className="tlg-training-progress-row" key={key}>
              <div className="tlg-training-progress-row-head">
                <div><strong>{label}</strong><span>Current {value}</span></div>
                <b>{Math.round(percent)}%</b>
              </div>
              <div className="tlg-training-progress-track"><i style={{ width: `${percent}%` }} /></div>
              <small>{Math.round(percent)}% accumulated toward {Math.min(100, value + 1)}</small>
            </div>
          )
        })}
      </div>

      <div className="tlg-training-staff-impact">
        <header>
          <div><span>ACTIVE STAFF IMPACT</span><strong>Applied automatically by the training engine</strong></div>
          <b>ENGINE LIVE</b>
        </header>
        {staffRows.length > 0 ? (
          <div className="tlg-training-staff-impact-list">
            {staffRows.map((row) => (
              <div key={row.label}>
                <span><strong>{row.label}</strong><small>{row.note}</small></span>
                <b>{row.display}</b>
              </div>
            ))}
          </div>
        ) : (
          <p className="tlg-training-staff-impact-empty">No active staff member currently provides a training modifier.</p>
        )}
        <p className="tlg-training-staff-impact-note">Regular-training bonuses are applied automatically. Camp bonuses apply only when the relevant staff member is selected to travel with that camp. New processed sessions also store the exact staff-effect snapshot used by the engine.</p>
      </div>

      <footer>
        Fractional progress is permanent and shared by Regular Training, Training Camps and future match development. At 100%, the skill increases by one point.
      </footer>
    </section>
  )
}
