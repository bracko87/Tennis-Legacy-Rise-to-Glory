import { useMemo, useState } from 'react'
import { ArrowRight, BarChart3, CalendarRange, Lightbulb } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import {
  OPTIMIZATION_SKILLS, analyzeTrainingChoices, complementarySkill,
  suggestedFocusRotation, weakestSkill,
  type OptimizationEvent, type OptimizationSkill, type SkillScores,
} from '../../lib/trainingOptimizationModel'
import { trainingOptimizationLabels } from '../../lib/trainingOptimizationI18n'
import '../../styles/training-optimization-premium.css'

type Props = {
  events: OptimizationEvent[]
  scores: SkillScores
  windowLimited: boolean
}

const gain = (n: number) => `+${n.toFixed(4)}`

/** This component never saves or triggers gameplay. The Free planner remains
 * the only place to schedule or perform training. */
export default function PremiumTrainingOptimization({ events, scores, windowLimited }: Props) {
  const { t, i18n } = useTranslation()
  const l = trainingOptimizationLabels(i18n.resolvedLanguage ?? i18n.language)
  const [chosenGoal, setChosenGoal] = useState<OptimizationSkill | null>(null)
  const [slots, setSlots] = useState(4)
  const [mode, setMode] = useState<'focused' | 'balanced'>('focused')
  const goal = chosenGoal ?? weakestSkill(scores)
  const complementary = complementarySkill(goal, scores)
  const analysis = useMemo(() => analyzeTrainingChoices(events, goal), [events, goal])
  const rotation = suggestedFocusRotation(goal, complementary, slots, mode)

  const skillLabel = (skill: OptimizationSkill) =>
    t(`developmentPremium.attributes.${skill}`, {
      defaultValue: t(`trainingPage.attributes.${skill}`, { defaultValue: skill.replaceAll('_', ' ') }),
    })
  const status = analysis.goalFocusedCount >= 3 ? l.supported
    : analysis.goalFocusedCount > 0 ? l.exploratory : l.emptyAdvice
  const trend = analysis.recentTrend
  const direction = !trend ? null
    : Math.abs(trend.recent - trend.previous) < 0.001 ? l.stable
      : trend.recent > trend.previous * 1.08 ? l.stronger
        : trend.recent < trend.previous * 0.92 ? l.weaker : l.stable
  const goalEvidence = analysis.cohorts.find(row => row.focus === goal)
  // Include the user's selected goal even if its measured gain ranks low.
  const rows = [...analysis.cohorts.slice(0, 6)]
  if (goalEvidence && !rows.some(row => row.focus === goal)) {
    rows.pop()
    rows.push(goalEvidence)
  }

  return (
    <section className="tlg-top" aria-labelledby="tlg-training-optimization-title">
      <header className="tlg-top-heading">
        <div>
          <span className="tlg-top-eyebrow"><Lightbulb size={16} aria-hidden="true" /> PREMIUM</span>
          <h3 id="tlg-training-optimization-title">{l.title}</h3>
          <p>{l.intro}</p>
        </div>
      </header>

      <div className="tlg-top-inputs">
        <label>
          <span>{l.goal}</span>
          <select value={goal} onChange={event => setChosenGoal(event.target.value as OptimizationSkill)}>
            {OPTIMIZATION_SKILLS.map(skill => <option key={skill} value={skill}>{skillLabel(skill)}</option>)}
          </select>
        </label>
        <div className="tlg-top-rating">
          <span>{l.rating}</span>
          <strong>{Number.isFinite(scores[goal]) ? scores[goal]?.toFixed(1) : '—'} / 100</strong>
        </div>
        <label>
          <span>{l.load}</span>
          <select value={slots} onChange={event => setSlots(Number(event.target.value))}>
            {[1, 2, 3, 4].map(count => <option key={count} value={count}>{count}</option>)}
          </select>
        </label>
        <label>
          <span>{l.mode}</span>
          <select value={mode} onChange={event => setMode(event.target.value as 'focused' | 'balanced')}>
            <option value="focused">{l.focused}</option>
            <option value="balanced">{l.balanced}</option>
          </select>
        </label>
      </div>

      <div className="tlg-top-grid">
        <article className="tlg-top-card">
          <h4><CalendarRange size={17} aria-hidden="true" /> {l.planTitle}</h4>
          <p>{l.planIntro}</p>
          <div className="tlg-top-rotation">
            {rotation.map((skill, index) => (
              <div key={index}>
                <span>{l.slot} {index + 1}</span>
                <strong>{skillLabel(skill)}</strong>
              </div>
            ))}
          </div>
          <p className="tlg-top-footnote">{l.secondary}: <strong>{skillLabel(complementary)}</strong></p>
          <Link className="tlg-top-link" to="/game/training?view=regular">
            {l.openTraining} <ArrowRight size={16} aria-hidden="true" />
          </Link>
        </article>

        <article className="tlg-top-card">
          <h4><Lightbulb size={17} aria-hidden="true" /> {l.insight}</h4>
          <p>{status}</p>
          <div className="tlg-top-observations">
            <span>{l.sample}: <strong>{analysis.goalFocusedCount}</strong></span>
            <span>{l.secondary}: <strong>{skillLabel(complementary)}</strong></span>
          </div>
          {typeof scores.fatigue === 'number' && scores.fatigue >= 60 && (
            <p className="tlg-top-alert">{l.fatigue}</p>
          )}
          {typeof scores[goal] === 'number' && (scores[goal] ?? 0) >= 95 && (
            <p className="tlg-top-alert">{l.ceiling}</p>
          )}
        </article>
      </div>

      <section className="tlg-top-evidence" aria-labelledby="tlg-top-evidence-heading">
        <h4 id="tlg-top-evidence-heading"><BarChart3 size={17} aria-hidden="true" /> {l.recorded}</h4>
        <p>{l.recordedIntro}</p>
        {rows.length ? (
          <div className="tlg-top-table-wrap">
            <table>
              <thead><tr>
                <th>{l.focus}</th><th>{l.sample}</th>
                <th>{l.targetGain}</th><th>{l.totalGain}</th><th>{l.efficiency}</th>
              </tr></thead>
              <tbody>{rows.map(row => (
                <tr key={row.focus} className={row.focus === goal ? 'tlg-top-selected' : ''}>
                  <th scope="row">{skillLabel(row.focus)} {row.count < 3 && <small>· {l.small}</small>}</th>
                  <td>{row.count}</td>
                  <td>{gain(row.targetGain)}</td>
                  <td>{gain(row.totalGain)}</td>
                  <td>{row.efficiency === null ? '—' : `${(row.efficiency * 100).toFixed(1)}%`}</td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        ) : <p className="tlg-top-empty">{l.noData}</p>}
        {!analysis.compared && <p className="tlg-top-footnote">{l.comparison}</p>}
      </section>

      <section className="tlg-top-trend">
        <h4>{l.trend}</h4>
        {trend ? (
          <div className="tlg-top-trend-data">
            <div><span>{l.recent}</span><strong>{gain(trend.recent)}</strong></div>
            <div><span>{l.previous}</span><strong>{gain(trend.previous)}</strong></div>
            <strong className="tlg-top-trend-label">{direction}</strong>
          </div>
        ) : <p>{l.trendUnavailable}</p>}
      </section>

      {windowLimited && <p className="tlg-top-alert">{l.limited}</p>}
      <p className="tlg-top-disclaimer">{l.caveat}</p>
    </section>
  )
}
