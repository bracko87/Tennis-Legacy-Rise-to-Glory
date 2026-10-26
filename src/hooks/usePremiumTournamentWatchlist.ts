import { useCallback, useEffect, useMemo, useState } from 'react'
import { useCommerce } from './useCommerce'
import { supabase } from '../lib/supabase'

export type WatchedTournament = {
  competition_id: string
  name: string
  city: string
  category_code: string
  season: number
  open_game_second: number | null
  close_game_second: number | null
  already_applied: boolean
  status: 'upcoming' | 'open' | 'applied' | 'closed' | 'canceled'
}

type WatchReport = {
  player_id: string
  season: number
  watches: WatchedTournament[]
  now_game_second: number
  limit: number
}

export function usePremiumTournamentWatchlist(playerId: string | null, season: number, gameDay: number) {
  const { isPremium, loading: premiumLoading } = useCommerce()
  const [report, setReport] = useState<WatchReport | null>(null)
  const [loading, setLoading] = useState(false)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!playerId || !isPremium) {
      setReport(null)
      return
    }
    const { data, error: rpcError } = await supabase.rpc('get_premium_tournament_watchlist_v1', {
      p_player_id: playerId,
    })
    if (rpcError) throw rpcError
    const fresh = data as WatchReport | null
    if (!fresh || fresh.player_id !== playerId || fresh.season !== season ||
      !Array.isArray(fresh.watches)) throw new Error('Invalid tournament watchlist response')
    setReport(fresh)
  }, [playerId, isPremium, season])

  useEffect(() => {
    let active = true
    setReport(null)
    setError(null)
    if (!playerId || premiumLoading || !isPremium) return
    setLoading(true)
    void supabase.rpc('get_premium_tournament_watchlist_v1', { p_player_id: playerId })
      .then(({ data, error: rpcError }) => {
        if (!active) return
        const fresh = data as WatchReport | null
        if (rpcError || !fresh || fresh.player_id !== playerId || fresh.season !== season ||
          !Array.isArray(fresh.watches)) {
          setError(rpcError?.message ?? 'Watchlist unavailable')
        } else {
          setReport(fresh)
        }
        setLoading(false)
      }).catch(() => { if (active) { setError('Watchlist unavailable'); setLoading(false) } })
    return () => { active = false }
  }, [playerId, premiumLoading, isPremium, season, gameDay])

  const watches = useMemo(() =>
    report?.player_id === playerId && report?.season === season ? report.watches : [],
    [report, playerId, season],
  )
  const watchedIds = useMemo(() => new Set(watches.map(row => row.competition_id)), [watches])

  const setWatch = useCallback(async (competitionId: string, watch: boolean) => {
    if (!playerId || !isPremium || busyId) return false
    setBusyId(competitionId)
    setError(null)
    try {
      const { error: mutationError } = await supabase.rpc('set_premium_tournament_watch_v1', {
        p_player_id: playerId, p_competition_id: competitionId, p_watch: watch,
      })
      if (mutationError) throw mutationError
      await refresh()
      return true
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Unable to save tournament reminder')
      return false
    } finally {
      setBusyId(null)
    }
  }, [playerId, isPremium, busyId, refresh])

  return { watches, watchedIds, isPremium, premiumLoading, loading, busyId, error,
    setWatch, refresh }
}
