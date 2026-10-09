import type { ReactNode } from 'react'
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
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

const INACTIVITY_TIMEOUT_MS = 10 * 60 * 1000
const LAST_ACTIVITY_STORAGE_KEY = 'tlg:last-authenticated-activity'

export function AuthProvider({ children }: { readonly children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [player, setPlayer] = useState<TennisPlayerRecord | null>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [authLoading, setAuthLoading] = useState(true)
  const [playerLoading, setPlayerLoading] = useState(false)
  const [adminLoading, setAdminLoading] = useState(false)
  const activeUserIdRef = useRef<string | null>(null)

  const loadPlayerForUser = useCallback(async (currentUser: User | null, background = false) => {
    if (!currentUser) {
      setPlayer(null)
      setPlayerLoading(false)
      return null
    }

    if (!background) setPlayerLoading(true)

    const { data, error } = await supabase
      .from('players')
      .select(
        'id, owner_user_id, world, first_name, last_name, country_code, home_city, image_path, preferred_surface, playing_style, playing_hand, moderation_status',
      )
      .eq('owner_user_id', currentUser.id)
      .maybeSingle()

    if (!background) setPlayerLoading(false)

    if (error) {
      console.error('Unable to load Tennis Legacy player:', error.message)
      setPlayer(null)
      return null
    }

    const record = (data ?? null) as TennisPlayerRecord | null
    setPlayer(record)
    return record
  }, [])

  const loadAdminForUser = useCallback(async (currentUser: User | null, background = false) => {
    if (!currentUser) {
      setIsAdmin(false)
      setAdminLoading(false)
      return false
    }

    if (!background) setAdminLoading(true)
    const { data, error } = await supabase.rpc('is_app_admin_v1')
    if (!background) setAdminLoading(false)

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
    return loadPlayerForUser(user, true)
  }, [loadPlayerForUser, user])

  const refreshAdminAccess = useCallback(async () => {
    return loadAdminForUser(user, true)
  }, [loadAdminForUser, user])

  useEffect(() => {
    let mounted = true

    async function initialiseAuth() {
      const {
        data: { session },
      } = await supabase.auth.getSession()

      if (!mounted) return

      const currentUser = session?.user ?? null
      activeUserIdRef.current = currentUser?.id ?? null
      if (!currentUser) window.localStorage.removeItem(LAST_ACTIVITY_STORAGE_KEY)
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
      const previousUserId = activeUserIdRef.current
      const nextUserId = currentUser?.id ?? null
      const identityChanged = previousUserId !== nextUserId

      activeUserIdRef.current = nextUserId
      if (!currentUser) {
        window.localStorage.removeItem(LAST_ACTIVITY_STORAGE_KEY)
      } else if (identityChanged) {
        window.localStorage.setItem(LAST_ACTIVITY_STORAGE_KEY, String(Date.now()))
      }

      setUser(currentUser)
      setAuthLoading(false)

      // Token refreshes and other background auth events must not remount the game UI.
      // Reload player/admin state only when the authenticated identity actually changes.
      if (identityChanged) {
        void loadPlayerForUser(currentUser)
        void loadAdminForUser(currentUser)
      }
    })

    return () => {
      mounted = false
      subscription.unsubscribe()
    }
  }, [loadAdminForUser, loadPlayerForUser])

  useEffect(() => {
    if (!user?.id) return

    let timeoutId: number | null = null
    let locking = false
    let lastRecordedAt = 0

    const readLastActivity = () => {
      const value = Number(window.localStorage.getItem(LAST_ACTIVITY_STORAGE_KEY))
      return Number.isFinite(value) && value > 0 ? value : null
    }

    const lockSession = async () => {
      if (locking) return
      locking = true
      window.localStorage.removeItem(LAST_ACTIVITY_STORAGE_KEY)

      // Inactivity locks only this browser session. Other devices stay signed in.
      const { error } = await supabase.auth.signOut({ scope: 'local' })
      if (error) console.error('Unable to lock inactive Tennis Legacy session:', error.message)

      activeUserIdRef.current = null
      setUser(null)
      setPlayer(null)
      setIsAdmin(false)
    }

    const scheduleLock = () => {
      if (timeoutId !== null) window.clearTimeout(timeoutId)
      const lastActivity = readLastActivity() ?? Date.now()
      if (!readLastActivity()) window.localStorage.setItem(LAST_ACTIVITY_STORAGE_KEY, String(lastActivity))
      const remaining = INACTIVITY_TIMEOUT_MS - (Date.now() - lastActivity)

      if (remaining <= 0) {
        void lockSession()
        return
      }

      timeoutId = window.setTimeout(() => {
        const latest = readLastActivity() ?? lastActivity
        if (Date.now() - latest >= INACTIVITY_TIMEOUT_MS) void lockSession()
        else scheduleLock()
      }, remaining + 50)
    }

    const recordActivity = () => {
      if (locking) return
      const now = Date.now()
      const previous = readLastActivity()

      // Returning after the timeout locks the session instead of extending it.
      if (previous && now - previous >= INACTIVITY_TIMEOUT_MS) {
        void lockSession()
        return
      }

      // Avoid excessive localStorage writes during scrolling/pointer activity.
      if (now - lastRecordedAt < 1000) return
      lastRecordedAt = now
      window.localStorage.setItem(LAST_ACTIVITY_STORAGE_KEY, String(now))
      scheduleLock()
    }

    const checkOnReturn = () => {
      if (document.visibilityState === 'visible') {
        const lastActivity = readLastActivity()
        if (lastActivity && Date.now() - lastActivity >= INACTIVITY_TIMEOUT_MS) void lockSession()
        else scheduleLock()
      }
    }

    const syncAcrossTabs = (event: StorageEvent) => {
      if (event.key === LAST_ACTIVITY_STORAGE_KEY) scheduleLock()
    }

    const activityEvents: Array<keyof WindowEventMap> = ['pointerdown', 'keydown', 'scroll', 'touchstart']
    activityEvents.forEach((eventName) => window.addEventListener(eventName, recordActivity, { passive: true }))
    window.addEventListener('focus', checkOnReturn)
    document.addEventListener('visibilitychange', checkOnReturn)
    window.addEventListener('storage', syncAcrossTabs)

    scheduleLock()

    return () => {
      if (timeoutId !== null) window.clearTimeout(timeoutId)
      activityEvents.forEach((eventName) => window.removeEventListener(eventName, recordActivity))
      window.removeEventListener('focus', checkOnReturn)
      document.removeEventListener('visibilitychange', checkOnReturn)
      window.removeEventListener('storage', syncAcrossTabs)
    }
  }, [user?.id])

  const signOut = useCallback(async () => {
    window.localStorage.removeItem(LAST_ACTIVITY_STORAGE_KEY)
    activeUserIdRef.current = null
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
