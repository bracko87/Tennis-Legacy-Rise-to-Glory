import { useEffect } from 'react'

export default function PlayingStyleEducation() {
  useEffect(() => {
    let frame = 0
    let cancelled = false
    let surfaceNote: HTMLElement | null = null
    let styleIntro: HTMLElement | null = null
    let startingPointsLabel: HTMLElement | null = null
    let startingPointsValue: HTMLElement | null = null
    let previousSurface = ''
    let previousIntro = ''
    let previousPointsLabel = ''
    let previousPointsValue = ''

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

        const previewRows = Array.from(document.querySelectorAll<HTMLElement>('.tlg-player-preview-meta-row'))
        const startingPointsRow = previewRows.find((row) => row.querySelector('span')?.textContent?.trim() === 'Starting tennis points') ?? null
        startingPointsLabel = startingPointsRow?.querySelector<HTMLElement>('span') ?? null
        startingPointsValue = startingPointsRow?.querySelector<HTMLElement>('strong') ?? null
        if (startingPointsLabel && startingPointsValue) {
          previousPointsLabel = startingPointsLabel.textContent ?? ''
          previousPointsValue = startingPointsValue.textContent ?? ''
          startingPointsLabel.textContent = 'Starting technical points'
          startingPointsValue.textContent = '440–455 · individually varied'
        }
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
      if (startingPointsLabel && previousPointsLabel) startingPointsLabel.textContent = previousPointsLabel
      if (startingPointsValue && previousPointsValue) startingPointsValue.textContent = previousPointsValue
    }
  }, [])

  return null
}
