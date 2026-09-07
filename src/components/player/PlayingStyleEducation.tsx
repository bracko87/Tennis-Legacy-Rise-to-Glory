import { createPortal } from 'react-dom'
import { Info } from 'lucide-react'
import { useEffect, useState } from 'react'

import '../../styles/playing-style-education.css'

const STYLES = [
  {
    name: 'All-court',
    strengths: 'Keeps the most balanced skill usage and adapts cleanly to different tactical plans.',
    tradeoff: 'No specialist weighting; it does not create a free advantage on any one point pattern.',
  },
  {
    name: 'Aggressive Baseliner',
    strengths: 'Uses forehand/backhand attacking quality more heavily and creates more aggressive rally pressure.',
    tradeoff: 'Slightly higher unforced-error tendency and less natural emphasis on net skills.',
  },
  {
    name: 'Defensive Baseliner',
    strengths: 'Uses return, movement and stamina more heavily in long baseline exchanges and stabilizes errors.',
    tradeoff: 'Slightly less natural serve pressure and fewer short-point advantages.',
  },
  {
    name: 'Serve & Volley',
    strengths: 'Uses serve, volley, smash and movement more heavily when finishing points at the net.',
    tradeoff: 'A poor serve/volley skill set can make the style worse, not better; baseline weighting is reduced.',
  },
] as const

export default function PlayingStyleEducation() {
  const [target, setTarget] = useState<HTMLElement | null>(null)

  useEffect(() => {
    let frame = 0
    let cancelled = false
    let host: HTMLElement | null = null
    let surfaceNote: HTMLElement | null = null
    let styleIntro: HTMLElement | null = null
    let previousSurface = ''
    let previousIntro = ''

    const locate = () => {
      if (cancelled) return
      const card = document.querySelector<HTMLElement>('.tlg-style-preference-card')
      const options = card?.querySelector<HTMLElement>('.tlg-style-options') ?? null
      if (card && options) {
        surfaceNote = document.querySelector<HTMLElement>('.tlg-surface-future-note')
        styleIntro = card.querySelector<HTMLElement>('.tlg-style-preference-head p')
        if (surfaceNote) {
          previousSurface = surfaceNote.textContent ?? ''
          surfaceNote.textContent = 'New human players begin with a varied 440–455 technical-point profile. Preferred surface changes the distribution, and individual variation prevents identical starting players.'
        }
        if (styleIntro) {
          previousIntro = styleIntro.textContent ?? ''
          styleIntro.textContent = 'Playing style changes how your existing skills are used during matches. It is not a flat bonus: the style is strongest only when your skill profile supports it.'
        }
        host = card.querySelector<HTMLElement>('[data-tlg-playing-style-guide="true"]')
        if (!host) {
          host = document.createElement('div')
          host.dataset.tlgPlayingStyleGuide = 'true'
          host.className = 'tlg-playing-style-guide-host'
          options.insertAdjacentElement('afterend', host)
        }
        setTarget(host)
        return
      }
      frame = window.requestAnimationFrame(locate)
    }

    frame = window.requestAnimationFrame(locate)
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      if (surfaceNote && previousSurface) surfaceNote.textContent = previousSurface
      if (styleIntro && previousIntro) styleIntro.textContent = previousIntro
      host?.remove()
      setTarget(null)
    }
  }, [])

  if (!target) return null
  return createPortal(
    <details className="tlg-playing-style-guide" open>
      <summary><span><Info size={16} /><strong>How playing style changes match outcomes</strong></span><b>Permanent career identity</b></summary>
      <div className="tlg-playing-style-guide-grid">
        {STYLES.map((style) => (
          <article key={style.name}>
            <strong>{style.name}</strong>
            <small className="benefit">+ {style.strengths}</small>
            <small className="tradeoff">− {style.tradeoff}</small>
          </article>
        ))}
      </div>
      <p>Surface preference and playing style are separate. Surface changes your starting distribution and court matchup; style changes which skills the match engine naturally emphasizes. Match tactics can later override point strategy, but they do not change this permanent identity.</p>
    </details>,
    target,
  )
}
