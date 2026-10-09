import { createPortal } from 'react-dom'
import { Info, Target } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'

import '../../styles/tactic-education.css'

const TACTIC_ROW_KEYS = [
  'aggressiveApproach','defensiveApproach','shortenPoints','extendRallies','powerServing',
  'safeServe','servePlusOne','servePlacement','aggressiveReturn','attackSecond','safeReturn',
  'returnPosition','insideBaseline','netAttack','deepBaseline','wingTarget','weaknessTarget',
  'aggressiveRisk','safeRisk',
] as const

function TacticGuide({ matchSpecific = false }: { matchSpecific?: boolean }) {
  const { t } = useTranslation()
  const [isOpen, setIsOpen] = useState(false)

  return (
    <details
      className="tlg-tactic-education"
      open={isOpen}
      onToggle={(event) => setIsOpen(event.currentTarget.open)}
    >
      <summary>
        <span><Info size={16} /><strong>{matchSpecific ? t('tacticEducation.matchGuide') : t('tacticEducation.tournamentGuide')}</strong></span>
        <b>{isOpen ? t('tacticEducation.collapse') : t('tacticEducation.expand')}</b>
      </summary>
      <div className="tlg-tactic-education-body">
        <p>{matchSpecific ? t('tacticEducation.matchBody') : t('tacticEducation.tournamentBody')}</p>
        <div className="tlg-tactic-education-grid">
          {TACTIC_ROW_KEYS.map((key) => {
            const row = t(`tacticEducation.rows.${key}`, { returnObjects: true }) as string[]
            const [group, option, benefit, tradeoff] = row
            return (
              <article key={key}>
                <span>{group}</span>
                <strong>{option}</strong>
                <small className="benefit">+ {benefit}</small>
                <small className="tradeoff">− {tradeoff}</small>
              </article>
            )
          })}
        </div>
        <div className="tlg-tactic-education-rule"><Target size={16} /><span><strong>{t('tacticEducation.opponentRuleTitle')}</strong> {t('tacticEducation.opponentRule')}</span></div>
      </div>
    </details>
  )
}

function usePortalTarget(mode: 'schedule' | 'match') {
  const [target, setTarget] = useState<HTMLElement | null>(null)

  useEffect(() => {
    let frame = 0
    let cancelled = false
    let host: HTMLElement | null = null

    const find = () => {
      if (cancelled) return
      const anchor = mode === 'schedule'
        ? document.querySelector<HTMLElement>('.tlg-tactic-presets')
        : document.querySelector<HTMLElement>('.tlg-match-tactic-presets')
      const fallback = mode === 'schedule'
        ? document.querySelector<HTMLElement>('.tlg-tactic-grid')
        : document.querySelector<HTMLElement>('.tlg-match-tactic-grid')
      const location = anchor ?? fallback
      if (location?.parentElement) {
        const attr = mode === 'schedule' ? 'tlg-schedule-tactic-guide' : 'tlg-match-tactic-guide'
        host = document.querySelector<HTMLElement>(`[data-${attr}="true"]`)
        if (!host) {
          host = document.createElement('div')
          host.setAttribute(`data-${attr}`, 'true')
          host.className = `tlg-tactic-education-host ${mode === 'match' ? 'tlg-match-tactic-education-host' : 'tlg-schedule-tactic-education-host'}`
          location.insertAdjacentElement('beforebegin', host)
        }
        setTarget(host)
        return
      }
      frame = window.requestAnimationFrame(find)
    }

    frame = window.requestAnimationFrame(find)
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      host?.remove()
      setTarget(null)
    }
  }, [mode])

  return target
}

function useCurrentMatchKey() {
  const [key, setKey] = useState('no-match')

  useEffect(() => {
    let disposed = false
    const update = () => {
      if (disposed) return
      const heading = document.querySelector<HTMLElement>('.tlg-match-modal-head h2')?.textContent?.trim()
      setKey(heading || 'no-match')
    }
    update()
    const observer = new MutationObserver(update)
    observer.observe(document.body, { childList: true, subtree: true, characterData: true })
    return () => {
      disposed = true
      observer.disconnect()
    }
  }, [])

  return key
}

export function ScheduleTacticEducation() {
  const target = usePortalTarget('schedule')
  return target ? createPortal(<TacticGuide />, target) : null
}

export function TournamentTacticEducation() {
  const target = usePortalTarget('match')
  const matchKey = useCurrentMatchKey()
  return target ? createPortal(<TacticGuide key={matchKey} matchSpecific />, target) : null
}
