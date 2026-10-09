import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import type { TrainingDashboard } from '../../hooks/useTraining'
import '../../styles/training-staff-impact.css'

const TECHNICAL_SKILLS = ['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'] as const
const PHYSICAL_SKILLS = ['fitness','stamina','recovery','movement'] as const

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
  const { t } = useTranslation()
  const [mode, setMode] = useState<'technical' | 'physical'>('technical')
  const skills = mode === 'technical' ? TECHNICAL_SKILLS : PHYSICAL_SKILLS
  const staff = dashboard.staff_effects
  const staffRows = [
    { label: t('trainingPage.progress.technical'), value: multiplierPercent(staff.technical_training_multiplier), display: signedPositive(multiplierPercent(staff.technical_training_multiplier)), note: t('trainingPage.progress.technicalNote') },
    { label: t('trainingPage.progress.physicalTraining'), value: multiplierPercent(staff.physical_training_multiplier), display: signedPositive(multiplierPercent(staff.physical_training_multiplier)), note: t('trainingPage.progress.physicalNote') },
    { label: t('trainingPage.progress.fatigueGain'), value: Math.max(0, Number(staff.training_fatigue_reduction || 0) * 100), display: signedReduction(staff.training_fatigue_reduction), note: t('trainingPage.progress.fatigueNote') },
    { label: t('trainingPage.progress.tennisCamps'), value: multiplierPercent(staff.technical_camp_multiplier), display: signedPositive(multiplierPercent(staff.technical_camp_multiplier)), note: t('trainingPage.progress.tennisCampNote') },
    { label: t('trainingPage.progress.physicalCamps'), value: multiplierPercent(staff.physical_camp_multiplier), display: signedPositive(multiplierPercent(staff.physical_camp_multiplier)), note: t('trainingPage.progress.physicalCampNote') },
    { label: t('trainingPage.progress.dayOffRecovery'), value: multiplierPercent(staff.recovery_multiplier), display: signedPositive(multiplierPercent(staff.recovery_multiplier)), note: t('trainingPage.progress.dayOffNote') },
  ].filter((row) => row.value > 0.001)

  return (
    <section className="tlg-training-progress-overview">
      <header>
        <div>
          <span>{t('trainingPage.progress.eyebrow')}</span>
          <strong>{t('trainingPage.progress.heading')}</strong>
        </div>
        <div className="tlg-progress-mode-tabs">
          <button type="button" className={mode === 'technical' ? 'active' : ''} onClick={() => setMode('technical')}>{t('trainingPage.progress.tennis')}</button>
          <button type="button" className={mode === 'physical' ? 'active' : ''} onClick={() => setMode('physical')}>{t('trainingPage.progress.physical')}</button>
        </div>
      </header>

      <div className="tlg-training-progress-list">
        {skills.map((key) => {
          const label = t(`trainingPage.attributes.${key}`)
          const value = Number((dashboard.skills as unknown as Record<string, number>)[key] ?? 0)
          const rawProgress = Number((dashboard.progress as unknown as Record<string, number>)[key] ?? 0)
          const percent = clamp(rawProgress * 100)
          return (
            <div className="tlg-training-progress-row" key={key}>
              <div className="tlg-training-progress-row-head">
                <div><strong>{label}</strong><span>{t('trainingPage.progress.current', { value })}</span></div>
                <b>{Math.round(percent)}%</b>
              </div>
              <div className="tlg-training-progress-track"><i style={{ width: `${percent}%` }} /></div>
              <small>{t('trainingPage.progress.accumulated', { percent: Math.round(percent), target: Math.min(100, value + 1) })}</small>
            </div>
          )
        })}
      </div>

      <div className="tlg-training-staff-impact">
        <header>
          <div><span>{t('trainingPage.progress.staffEyebrow')}</span><strong>{t('trainingPage.progress.staffHeading')}</strong></div>
          <b>{t('trainingPage.progress.engineLive')}</b>
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
          <p className="tlg-training-staff-impact-empty">{t('trainingPage.progress.noStaff')}</p>
        )}
        <p className="tlg-training-staff-impact-note">{t('trainingPage.progress.staffNote')}</p>
      </div>

      <footer>
        {t('trainingPage.progress.footer')}
      </footer>
    </section>
  )
}
