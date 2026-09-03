import { useState } from 'react'

import type { TrainingDashboard } from '../../hooks/useTraining'

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

export default function TrainingProgressOverview({ dashboard }: { dashboard: TrainingDashboard }) {
  const [mode, setMode] = useState<'technical' | 'physical'>('technical')
  const skills = mode === 'technical' ? TECHNICAL_SKILLS : PHYSICAL_SKILLS

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

      <footer>
        Fractional progress is permanent and shared by Regular Training, Training Camps and future match development. At 100%, the skill increases by one point.
      </footer>
    </section>
  )
}
