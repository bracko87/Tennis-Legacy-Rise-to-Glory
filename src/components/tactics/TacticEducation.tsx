import { createPortal } from 'react-dom'
import { Info, Target } from 'lucide-react'
import { useEffect, useState } from 'react'

import '../../styles/tactic-education.css'

const TACTIC_ROWS = [
  ['Overall approach', 'Aggressive', 'Slightly increases attacking serve/rally pressure.', 'Raises unforced-error risk.'],
  ['Overall approach', 'Conservative', 'Improves return/rally stability and lowers error risk.', 'Reduces serve pressure.'],
  ['Rally strategy', 'Short points', 'Rewards serve, attacking shots and net finishing.', 'Higher variance and execution risk.'],
  ['Rally strategy', 'Long points', 'Rewards return, movement and stamina.', 'Less serve pressure; fatigue and heat matter more.'],
  ['Serve strategy', 'Aggressive first serve', 'More serve pressure and aces.', 'Lower first-serve percentage and more double-fault risk.'],
  ['Serve strategy', 'High percentage', 'More first serves in and fewer double faults.', 'Fewer free points and less serving pressure.'],
  ['Return strategy', 'Attack second serve', 'Adds pressure when the opponent misses the first serve.', 'Slightly raises return-error risk.'],
  ['Return strategy', 'Deep neutral return', 'Improves stable return quality and point entry.', 'Less immediate attacking pressure.'],
  ['Court position', 'Step inside', 'Adds return and net pressure.', 'Slightly harder execution.'],
  ['Court position', 'Deep baseline', 'Helps return and rally defense.', 'Reduces net pressure.'],
  ['Opponent target', 'Forehand / Backhand', 'Modestly exploits the selected wing when it is weaker than the opponent’s other side.', 'Forcing the stronger wing can be counterproductive.'],
  ['Risk level', 'High risk', 'Small attacking boost and more winner chances.', 'Substantially more unforced-error risk.'],
  ['Risk level', 'Low risk', 'Reduces unforced errors and stabilizes points.', 'Less attacking pressure and fewer high-payoff attempts.'],
] as const

function TacticGuide({ matchSpecific = false }: { matchSpecific?: boolean }) {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <details
      className="tlg-tactic-education"
      open={isOpen}
      onToggle={(event) => setIsOpen(event.currentTarget.open)}
    >
      <summary>
        <span><Info size={16} /><strong>{matchSpecific ? 'Match tactic guide' : 'How tactic settings change the match plan'}</strong></span>
        <b>{isOpen ? 'Collapse' : 'Expand'}</b>
      </summary>
      <div className="tlg-tactic-education-body">
        <p>{matchSpecific
          ? 'All match-tactic help is collected here. A saved one-match plan overrides your Tournament Default only for this opponent and locks 60 minutes before the scheduled start. Every aggressive choice has a trade-off; there is no universal “best” tactic.'
          : 'All tactic guidance is collected here. Your Tournament Default is used for every match at this event unless you save a match-specific override. Presets are shortcuts; the individual choices below are what the match engine actually uses.'}</p>
        <div className="tlg-tactic-education-grid">
          {TACTIC_ROWS.map(([group, option, benefit, tradeoff]) => (
            <article key={`${group}-${option}`}>
              <span>{group}</span>
              <strong>{option}</strong>
              <small className="benefit">+ {benefit}</small>
              <small className="tradeoff">− {tradeoff}</small>
            </article>
          ))}
        </div>
        <div className="tlg-tactic-education-rule"><Target size={16} /><span><strong>Balanced / Automatic choices:</strong> no special bias is applied. Your permanent playing style still determines which skills naturally appear more often in the underlying point calculation.</span></div>
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
