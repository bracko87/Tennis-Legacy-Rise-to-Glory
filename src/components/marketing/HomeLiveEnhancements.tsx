import { useEffect, useState } from 'react'
import { createPortal } from 'react-dom'

import { useGameClock } from '../../hooks/useGameClock'
import { supabase } from '../../lib/supabase'
import '../../styles/home-live-enhancements.css'

const CAREER_OVERVIEW_IMAGE_URL = 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/Profile%20one%20image.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9Qcm9maWxlIG9uZSBpbWFnZS5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg5Mzc0Mzc3LCJleHAiOjQ5MTE0MzgzNzd9.8eAFbuK0uBHY8PFzF87wYaglFqTH41U5NbsAsayUO4I_p1D2gy5L38ytKH_X6uHXeeTTaXpahbPr7N-qdwyDJw'

interface PublicHomeStats {
  active_players: number | string
  total_tournaments: number | string
  matches_completed: number | string
  countries_represented: number | string
}

function setText(selector: string, value: string) {
  const element = document.querySelector<HTMLElement>(selector)
  if (element) element.textContent = value
}

function formatStat(value: number | string) {
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric.toLocaleString('en-US') : '—'
}

export default function HomeLiveEnhancements() {
  const clock = useGameClock()
  const [careerPanel, setCareerPanel] = useState<HTMLElement | null>(null)

  useEffect(() => {
    const panel = document.querySelector<HTMLElement>('.tlg-career-control-panel')
    if (!panel) return
    panel.classList.add('tlg-career-control-panel-live-image')
    setCareerPanel(panel)

    return () => {
      panel.classList.remove('tlg-career-control-panel-live-image')
      setCareerPanel(null)
    }
  }, [])

  useEffect(() => {
    let active = true

    async function loadStats() {
      const { data, error } = await supabase.rpc('get_public_home_stats_v1')
      if (!active) return

      const row = (Array.isArray(data) ? data[0] : data) as PublicHomeStats | null
      if (error || !row) {
        document.querySelectorAll<HTMLElement>('.tlg-stat-card-helper').forEach((element) => {
          element.textContent = 'Live data temporarily unavailable'
        })
        return
      }

      const values = [
        row.active_players,
        row.total_tournaments,
        row.matches_completed,
        row.countries_represented,
      ]

      document.querySelectorAll<HTMLElement>('.tlg-statistics-grid .tlg-stat-card').forEach((card, index) => {
        const value = card.querySelector<HTMLElement>('.tlg-stat-card-value')
        const helper = card.querySelector<HTMLElement>('.tlg-stat-card-helper')
        if (value && values[index] !== undefined) value.textContent = formatStat(values[index])
        if (helper) helper.textContent = 'Live from the game database'
      })

      setText(
        '.tlg-statistics-heading > p',
        'Live figures from the current Tennis Legacy game world, refreshed whenever this page is opened.',
      )
    }

    void loadStats()
    const refreshTimer = window.setInterval(() => void loadStats(), 5 * 60 * 1000)

    return () => {
      active = false
      window.clearInterval(refreshTimer)
    }
  }, [])

  useEffect(() => {
    if (clock.loading || clock.error) return

    const dateLabel = `Season ${clock.season} · ${clock.month} ${clock.day}`

    setText('.tlg-hero-floating-season strong', dateLabel)
    setText('.tlg-hero-floating-season small', clock.formattedTime)

    setText('.tlg-game-clock-date span', `Season ${clock.season}`)
    setText('.tlg-game-clock-date strong', `${clock.month} ${clock.day}`)
    setText('.tlg-game-clock-date time', clock.formattedTime)

    const liveLabel = document.querySelector<HTMLElement>('.tlg-game-clock-live')
    if (liveLabel) {
      const dot = liveLabel.querySelector('span')
      liveLabel.textContent = ''
      if (dot) liveLabel.appendChild(dot)
      liveLabel.append(' Live game time')
    }

    document.querySelectorAll<HTMLElement>('.tlg-season-months > span').forEach((month, index) => {
      month.classList.toggle('tlg-season-month-active', index === clock.monthIndex)
    })

    setText(
      '.tlg-game-clock-note',
      `Connected to the centralized game clock at ${clock.speedMultiplier}× real-time speed.`,
    )
  }, [clock.day, clock.error, clock.formattedTime, clock.loading, clock.month, clock.monthIndex, clock.season, clock.speedMultiplier])

  return careerPanel
    ? createPortal(
        <img
          className="tlg-career-control-live-image"
          src={CAREER_OVERVIEW_IMAGE_URL}
          alt="Tennis Legacy player profile overview"
        />,
        careerPanel,
      )
    : null
}
