import { useEffect } from 'react'
import { useLocation } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'

const OFFICIAL_ANALYTICS_HOSTS = new Set([
  'tennislegacygame.com',
  'www.tennislegacygame.com',
])

const VISITOR_KEY = 'tlg_analytics_visitor_id_v1'
const SESSION_KEY = 'tlg_analytics_session_id_v1'
const COUNTRY_KEY = 'tlg_analytics_country_v1'

function getStoredUuid(storage: Storage, key: string) {
  try {
    const current = storage.getItem(key)
    if (current && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(current)) {
      return current
    }
    const next = crypto.randomUUID()
    storage.setItem(key, next)
    return next
  } catch {
    return crypto.randomUUID()
  }
}

function getDeviceType() {
  const width = window.innerWidth
  if (width <= 760) return 'mobile'
  if (width <= 1100) return 'tablet'
  return 'desktop'
}

function getReferrerHost() {
  if (!document.referrer) return null
  try {
    return new URL(document.referrer).hostname.toLowerCase() || null
  } catch {
    return null
  }
}

async function getCountryCode() {
  try {
    const stored = sessionStorage.getItem(COUNTRY_KEY)
    if (stored && /^(?:[A-Z]{2}|XX)$/.test(stored)) return stored
  } catch {
    // Storage can be unavailable in privacy-restricted browser modes.
  }

  let code = 'XX'
  try {
    const response = await fetch('/api/analytics-geo', {
      cache: 'no-store',
      headers: { accept: 'application/json' },
    })
    if (response.ok) {
      const payload = await response.json() as { countryCode?: string | null }
      const candidate = String(payload.countryCode ?? '').toUpperCase()
      if (/^[A-Z]{2}$/.test(candidate)) code = candidate
    }
  } catch {
    // Country is optional; the event is still useful without it.
  }

  try {
    sessionStorage.setItem(COUNTRY_KEY, code)
  } catch {
    // Ignore storage failures.
  }

  return code
}

export default function AnalyticsTracker() {
  const location = useLocation()
  const { user, authLoading } = useAuth()

  useEffect(() => {
    if (authLoading) return
    if (!OFFICIAL_ANALYTICS_HOSTS.has(window.location.hostname.toLowerCase())) return
    if (location.pathname.startsWith('/game/admin/')) return

    let cancelled = false

    async function recordPageView() {
      const visitorId = getStoredUuid(localStorage, VISITOR_KEY)
      const sessionId = getStoredUuid(sessionStorage, SESSION_KEY)
      const countryCode = await getCountryCode()
      if (cancelled) return

      const { error } = await supabase.rpc('record_site_analytics_event_v1', {
        p_visitor_id: visitorId,
        p_session_id: sessionId,
        p_path: location.pathname || '/',
        p_country_code: countryCode,
        p_device_type: getDeviceType(),
        p_referrer_host: getReferrerHost(),
      })

      if (error) {
        console.warn('Tennis Legacy analytics event was not recorded:', error.message)
      }
    }

    void recordPageView()
    return () => {
      cancelled = true
    }
  }, [authLoading, location.pathname, user?.id])

  return null
}
