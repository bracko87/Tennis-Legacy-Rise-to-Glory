import { useCallback, useEffect, useMemo, useState } from 'react'

import { supabase } from '../lib/supabase'

const MONTH_NAMES = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
] as const

const MONTH_DAYS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] as const
const SEASON_SECONDS = 366 * 24 * 60 * 60

interface ClockRpcRow {
  server_now: string
  speed_multiplier: number | string
  game_total_seconds: number | string
}

interface ClockAnchor {
  gameSeconds: number
  speedMultiplier: number
  receivedAtMs: number
}

export interface GameClockView {
  season: number
  month: string
  monthIndex: number
  day: number
  hour: number
  minute: number
  formattedTime: string
  totalGameSeconds: number
  speedMultiplier: number
  loading: boolean
  error: string | null
  refresh: () => Promise<void>
}

export function useGameClock(): GameClockView {
  const [anchor, setAnchor] = useState<ClockAnchor | null>(null)
  const [nowMs, setNowMs] = useState(() => Date.now())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    const { data, error: rpcError } = await supabase.rpc('get_game_clock_v1')

    if (rpcError) {
      setError(rpcError.message)
      setLoading(false)
      return
    }

    const row = (Array.isArray(data) ? data[0] : data) as ClockRpcRow | null
    if (!row) {
      setError('Game clock is unavailable.')
      setLoading(false)
      return
    }

    const gameSeconds = Number(row.game_total_seconds)
    const speedMultiplier = Number(row.speed_multiplier)

    if (!Number.isFinite(gameSeconds) || !Number.isFinite(speedMultiplier)) {
      setError('Game clock returned invalid data.')
      setLoading(false)
      return
    }

    const receivedAtMs = Date.now()
    setAnchor({ gameSeconds, speedMultiplier, receivedAtMs })
    setNowMs(receivedAtMs)
    setError(null)
    setLoading(false)
  }, [])

  useEffect(() => {
    void refresh()

    const tickTimer = window.setInterval(() => setNowMs(Date.now()), 1000)
    const resyncTimer = window.setInterval(() => void refresh(), 5 * 60 * 1000)

    return () => {
      window.clearInterval(tickTimer)
      window.clearInterval(resyncTimer)
    }
  }, [refresh])

  const computed = useMemo(() => {
    if (!anchor) {
      return {
        season: 1,
        month: MONTH_NAMES[0],
        monthIndex: 0,
        day: 1,
        hour: 0,
        minute: 0,
        formattedTime: '00:00',
        totalGameSeconds: 0,
        speedMultiplier: 2,
      }
    }

    const elapsedRealSeconds = Math.max(0, (nowMs - anchor.receivedAtMs) / 1000)
    const totalGameSeconds = Math.max(
      0,
      Math.floor(anchor.gameSeconds + elapsedRealSeconds * anchor.speedMultiplier),
    )

    const seasonIndex = Math.floor(totalGameSeconds / SEASON_SECONDS)
    let seasonRemainder = totalGameSeconds % SEASON_SECONDS
    const dayIndex = Math.floor(seasonRemainder / 86400)
    seasonRemainder %= 86400

    const hour = Math.floor(seasonRemainder / 3600)
    const minute = Math.floor((seasonRemainder % 3600) / 60)

    let monthIndex = 0
    let dayRemainder = dayIndex

    while (monthIndex < MONTH_DAYS.length - 1 && dayRemainder >= MONTH_DAYS[monthIndex]) {
      dayRemainder -= MONTH_DAYS[monthIndex]
      monthIndex += 1
    }

    return {
      season: seasonIndex + 1,
      month: MONTH_NAMES[monthIndex],
      monthIndex,
      day: dayRemainder + 1,
      hour,
      minute,
      formattedTime: `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`,
      totalGameSeconds,
      speedMultiplier: anchor.speedMultiplier,
    }
  }, [anchor, nowMs])

  return {
    ...computed,
    loading,
    error,
    refresh,
  }
}
