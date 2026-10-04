import { createPortal } from 'react-dom'
import { Info, Target } from 'lucide-react'
import { useEffect, useState } from 'react'

import '../../styles/tactic-education.css'

const TACTIC_ROWS = [
  ['Overall approach', 'Aggressive', 'Pushes the player to take initiative earlier.', 'Raises execution and unforced-error risk.'],
  ['Overall approach', 'Defensive', 'Prioritises patience, coverage and stable point construction.', 'Concedes some first-strike pressure.'],
  ['Rally strategy', 'Shorten points', 'Rewards serve, attacking shots and net finishing.', 'Higher variance and execution risk.'],
  ['Rally strategy', 'Extend rallies', 'Can exploit weaker opponent stamina/movement when your own physical profile supports it.', 'Raises physical demand.'],
  ['Serve strategy', 'Power serving', 'More serve pressure and ace potential.', 'Lower first-serve reliability and more double-fault risk.'],
  ['Serve strategy', 'Safe first serve', 'More first serves in and fewer double faults.', 'Fewer free points and less serving pressure.'],
  ['Serve strategy', 'Serve + 1', 'Builds around a strong serve followed by an attacking first groundstroke.', 'Requires suitable serve and attacking skills.'],
  ['Serve placement', 'Wide / Body / T', 'Changes the geometry of the service pattern and can target movement or return tendencies.', 'A predictable or unsuitable target can reduce the benefit.'],
  ['Return strategy', 'Aggressive return', 'Adds early return pressure.', 'Raises return-error exposure.'],
  ['Return strategy', 'Attack second serve', 'Steps in harder when the opponent misses the first serve.', 'Can be less useful against strong second serving.'],
  ['Return strategy', 'Safe return', 'Prioritises starting the rally.', 'Less immediate attacking pressure.'],
  ['Return position', 'Closer / Deeper', 'Closer pressures weaker serves; deeper creates reaction time against pace.', 'Each choice gives up something in reaction time or court position.'],
  ['Court position', 'Inside baseline', 'Takes time away and adds attacking pressure.', 'Less reaction time.'],
  ['Court position', 'Net attack', 'Rewards suitable serve/volley profiles.', 'Can expose weaker net skills and passing-shot defense.'],
  ['Court position', 'Deep baseline', 'Helps return and rally defense.', 'Concedes court position.'],
  ['Opponent target', 'Forehand / Backhand', 'Modestly exploits the selected wing when it is actually weaker.', 'Forcing the stronger wing can be counterproductive.'],
  ['Opponent target', 'Movement / Stamina / Second serve', 'Builds the plan around a scouted physical or serving vulnerability.', 'Works poorly when the scouting read is wrong or your own skills do not suit the plan.'],
  ['Risk level', 'Aggressive', 'Small attacking boost and more winner chances.', 'Substantially more unforced-error risk.'],
  ['Risk level', 'Safe', 'Reduces errors and stabilizes points.', 'Less attacking pressure and fewer high-payoff attempts.'],
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
        <div className="tlg-tactic-education-rule"><Target size={16} /><span><strong>Opponent-specific tactics:</strong> handedness changes rally and serve geometry, but it is not a permanent skill bonus. The match engine weighs your own skills, the opponent's real strengths/weaknesses, surface, condition and the chosen plan. A good counter helps modestly; it never guarantees a win.</span></div>
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
