import { useEffect } from 'react'

const CATEGORY_LABELS: Record<string, string> = {
  grand_slam_2000: 'Grand Slam 2000',
  masters_1000: 'Masters 1000',
  tour_500: 'Tour 500',
  tour_250: 'Tour 250',
  challenger_125: 'Challenger 125',
  challenger_100: 'Challenger 100',
  challenger_75: 'Challenger 75',
  challenger_50: 'Challenger 50',
  futures_25: 'Futures 25',
  futures_15: 'Futures 15',
}

export default function ScheduleUiPolish() {
  useEffect(() => {
    const polish = () => {
      document.querySelectorAll<HTMLElement>('.tlg-schedule-tournament-row > span').forEach((element) => {
        const raw = element.textContent?.trim() ?? ''
        const label = CATEGORY_LABELS[raw]
        if (label) element.textContent = label
      })
    }

    polish()
    const root = document.querySelector('.tlg-schedule-page') ?? document.body
    const observer = new MutationObserver(polish)
    observer.observe(root, { childList: true, subtree: true })
    return () => observer.disconnect()
  }, [])

  return null
}
