import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'
import i18n, { ENABLED_LOCALES, LOCALE_TAGS, normalizeAppLocale, type AppLocale } from './index'

type LocalizationContextValue = {
  locale: AppLocale
  localeTag: string
  loading: boolean
  saving: boolean
  enabledLocales: readonly AppLocale[]
  setLocale: (locale: AppLocale) => Promise<boolean>
  formatNumber: (value: number) => string
  formatCurrency: (value: number, currency?: string) => string
  formatPercent: (value: number) => string
  formatDate: (value: Date | string | number, options?: Intl.DateTimeFormatOptions) => string
}

const LocalizationContext = createContext<LocalizationContextValue | null>(null)

const STORAGE_KEY = 'tlg:locale'

export function LocalizationProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const { i18n: reactI18n } = useTranslation()
  const [locale, setLocaleState] = useState<AppLocale>(() => normalizeAppLocale(
    window.localStorage.getItem(STORAGE_KEY) || 'en',
  ))
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  const applyLocale = useCallback(async (next: AppLocale) => {
    const enabled = ENABLED_LOCALES.includes(next) ? next : 'en'
    setLocaleState(enabled)
    window.localStorage.setItem(STORAGE_KEY, enabled)
    document.documentElement.lang = enabled === 'sr' ? 'sr-Latn' : LOCALE_TAGS[enabled]
    await reactI18n.changeLanguage(enabled)
  }, [reactI18n])

  useEffect(() => {
    let cancelled = false

    async function load() {
      if (!user?.id) {
        await applyLocale(locale)
        if (!cancelled) setLoading(false)
        return
      }

      const { data, error } = await supabase
        .from('user_language_preferences')
        .select('locale')
        .eq('user_id', user.id)
        .maybeSingle()

      if (cancelled) return

      // A different account must not inherit the previous account's cached language.
      const accountLocale = !error && data?.locale ? normalizeAppLocale(data.locale) : 'en'
      await applyLocale(accountLocale)
      if (!cancelled) setLoading(false)
    }

    setLoading(true)
    void load()
    return () => { cancelled = true }
  }, [applyLocale, user?.id])

  const setLocale = useCallback(async (next: AppLocale) => {
    if (!ENABLED_LOCALES.includes(next)) return false
    setSaving(true)
    const previous = locale
    await applyLocale(next)

    if (!user?.id) {
      setSaving(false)
      return true
    }

    const { error } = await supabase
      .from('user_language_preferences')
      .upsert({ user_id: user.id, locale: next, updated_at: new Date().toISOString() }, { onConflict: 'user_id' })

    if (error) {
      await applyLocale(previous)
      setSaving(false)
      return false
    }

    const { error: tutorialError } = await supabase
      .from('player_tutorial_progress')
      .update({ locale: next, updated_at: new Date().toISOString() })
      .eq('player_id', (await supabase.from('players').select('id').eq('owner_user_id', user.id).maybeSingle()).data?.id ?? '')

    if (tutorialError) {
      console.warn('Unable to sync tutorial locale:', tutorialError.message)
    }

    setSaving(false)
    return true
  }, [applyLocale, locale, user?.id])

  const localeTag = LOCALE_TAGS[locale]

  const value = useMemo<LocalizationContextValue>(() => ({
    locale,
    localeTag,
    loading,
    saving,
    enabledLocales: ENABLED_LOCALES,
    setLocale,
    formatNumber: (value) => new Intl.NumberFormat(localeTag).format(value),
    formatCurrency: (value, currency = 'EUR') => new Intl.NumberFormat(localeTag, { style: 'currency', currency }).format(value),
    formatPercent: (value) => new Intl.NumberFormat(localeTag, { style: 'percent', maximumFractionDigits: 1 }).format(value),
    formatDate: (value, options) => new Intl.DateTimeFormat(localeTag, options).format(new Date(value)),
  }), [locale, localeTag, loading, saving, setLocale])

  return <LocalizationContext.Provider value={value}>{children}</LocalizationContext.Provider>
}

export function useLocalization() {
  const value = useContext(LocalizationContext)
  if (!value) throw new Error('useLocalization must be used inside LocalizationProvider.')
  return value
}

export { i18n }
