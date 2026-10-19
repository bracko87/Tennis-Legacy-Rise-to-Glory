import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'

export type TableDensity = 'comfortable' | 'compact'
export type InterfacePreferences = { table_density: TableDensity; reduce_animations: boolean }
export const DEFAULT_INTERFACE_PREFERENCES: Readonly<InterfacePreferences> = {
  table_density: 'comfortable',
  reduce_animations: false,
}

type PreferencesContext = {
  preferences: InterfacePreferences
  loading: boolean
  saving: boolean
  error: string | null
  save: (patch: Partial<InterfacePreferences>) => Promise<boolean>
}
const Context = createContext<PreferencesContext | null>(null)

export function GamePreferencesProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const [preferences, setPreferences] = useState<InterfacePreferences>({ ...DEFAULT_INTERFACE_PREFERENCES })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)
    setPreferences({ ...DEFAULT_INTERFACE_PREFERENCES })
    if (!user?.id) {
      setLoading(false)
      return
    }
    void (async () => {
      const { data, error: queryError } = await supabase
        .from('user_interface_preferences_v1')
        .select('table_density,reduce_animations')
        .eq('user_id',user.id)
        .maybeSingle()
      if (cancelled) return
      if (queryError) setError(queryError.message)
      else setPreferences({
        table_density: data?.table_density === 'compact' ? 'compact' : 'comfortable',
        reduce_animations: data?.reduce_animations === true,
      })
      setLoading(false)
    })()
    return () => { cancelled = true }
  }, [user?.id])

  useEffect(() => {
    document.documentElement.dataset.tlgDensity = preferences.table_density
    document.documentElement.dataset.tlgReducedMotion = String(preferences.reduce_animations)
    return () => {
      delete document.documentElement.dataset.tlgDensity
      delete document.documentElement.dataset.tlgReducedMotion
    }
  }, [preferences.table_density, preferences.reduce_animations])

  const save = useCallback(async (patch: Partial<InterfacePreferences>) => {
    if (!user?.id || saving || loading) return false
    const next = { ...preferences, ...patch }
    if (next.table_density !== 'comfortable' && next.table_density !== 'compact') return false
    setSaving(true)
    setError(null)
    setPreferences(next)
    const { error: writeError } = await supabase.from('user_interface_preferences_v1')
      .upsert({ user_id:user.id, ...next, updated_at:new Date().toISOString() },{onConflict:'user_id'})
    if (writeError) {
      setPreferences(preferences)
      setError(writeError.message)
      setSaving(false)
      return false
    }
    setSaving(false)
    return true
  }, [user?.id,preferences,saving,loading])

  const value=useMemo<PreferencesContext>(()=>({
    preferences,loading,saving,error,save,
  }),[preferences,loading,saving,error,save])
  return <Context.Provider value={value}>{children}</Context.Provider>
}
export function useGamePreferences() {
  const context=useContext(Context)
  if(!context) throw new Error('useGamePreferences requires GamePreferencesProvider')
  return context
}
