import type { ReactNode } from 'react'
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'
import type { User } from '@supabase/supabase-js'

import { supabase } from '../lib/supabase'

export interface TennisPlayerRecord {
  id: string
  owner_user_id: string
  world: 'ATP' | 'WTA'
  first_name: string
  last_name: string
  country_code: string
  home_city: string | null
  image_path: string | null
  preferred_surface: 'Hard' | 'Clay' | 'Grass' | null
  playing_style: 'Aggressive Baseliner' | 'Defensive Baseliner' | 'All-court' | 'Serve & Volley'
  playing_hand: 'right' | 'left'
  moderation_status: 'pending' | 'approved' | 'rejected'
}

interface AuthContextValue {
  user: User | null
  player: TennisPlayerRecord | null
  isAdmin: boolean
  authLoading: boolean
  playerLoading: boolean
  adminLoading: boolean
  refreshPlayer: () => Promise<TennisPlayerRecord | null>
  refreshAdminAccess: () => Promise<boolean>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { readonly children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [player, setPlayer] = useState<TennisPlayerRecord | null>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [authLoading, setAuthLoading] = useState(true)
  const [playerLoading, setPlayerLoading] = useState(false)
  const [adminLoading, setAdminLoading] = useState(false)

  const loadPlayerForUser = useCallback(async (currentUser: User | null) => {
    if (!currentUser) {
      setPlayer(null)
      setPlayerLoading(false)
      return null
    }

    setPlayerLoading(true)

    const { data, error } = await supabase
      .from('players')
      .select(
        'id, owner_user_id, world, first_name, last_name, country_code, home_city, image_path, preferred_surface, playing_style, playing_hand, moderation_status',
      )
      .eq('owner_user_id', currentUser.id)
      .maybeSingle()

    setPlayerLoading(false)

    if (error) {
      console.error('Unable to load Tennis Legacy player:', error.message)
      setPlayer(null)
      return null
    }

    const record = (data ?? null) as TennisPlayerRecord | null
    setPlayer(record)
    return record
  }, [])

  const loadAdminForUser = useCallback(async (currentUser: User | null) => {
    if (!currentUser) {
      setIsAdmin(false)
      setAdminLoading(false)
      return false
    }

    setAdminLoading(true)
    const { data, error } = await supabase.rpc('is_app_admin_v1')
    setAdminLoading(false)

    if (error) {
      console.error('Unable to verify Tennis Legacy admin access:', error.message)
      setIsAdmin(false)
      return false
    }

    const allowed = data === true
    setIsAdmin(allowed)
    return allowed
  }, [])

  const refreshPlayer = useCallback(async () => {
    return loadPlayerForUser(user)
  }, [loadPlayerForUser, user])

  const refreshAdminAccess = useCallback(async () => {
    return loadAdminForUser(user)
  }, [loadAdminForUser, user])

  useEffect(() => {
    let mounted = true

    async function initialiseAuth() {
      const {
        data: { session },
      } = await supabase.auth.getSession()

      if (!mounted) return

      const currentUser = session?.user ?? null
      setUser(currentUser)
      setAuthLoading(false)
      await Promise.all([
        loadPlayerForUser(currentUser),
        loadAdminForUser(currentUser),
      ])
    }

    void initialiseAuth()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!mounted) return

      const currentUser = session?.user ?? null
      setUser(currentUser)
      setAuthLoading(false)
      void loadPlayerForUser(currentUser)
      void loadAdminForUser(currentUser)
    })

    return () => {
      mounted = false
      subscription.unsubscribe()
    }
  }, [loadAdminForUser, loadPlayerForUser])

  const signOut = useCallback(async () => {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
    setUser(null)
    setPlayer(null)
    setIsAdmin(false)
  }, [])

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      player,
      isAdmin,
      authLoading,
      playerLoading,
      adminLoading,
      refreshPlayer,
      refreshAdminAccess,
      signOut,
    }),
    [
      user,
      player,
      isAdmin,
      authLoading,
      playerLoading,
      adminLoading,
      refreshPlayer,
      refreshAdminAccess,
      signOut,
    ],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const value = useContext(AuthContext)
  if (!value) {
    throw new Error('useAuth must be used inside AuthProvider.')
  }
  return value
}
