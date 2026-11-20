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
  const { user, player, authLoading } = useAuth()

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

  useEffect(() => {
    // Recent page activity for the administrator's live-page report. Official
    // production hosts only: localhost testing must not affect live analytics.
    // Send no email, name, IP, or client-controlled registration flags.
    if (authLoading) return
    if (!OFFICIAL_ANALYTICS_HOSTS.has(window.location.hostname.toLowerCase())) return
    if (location.pathname.startsWith('/game/admin/')) return

    const visitorId = getStoredUuid(localStorage, VISITOR_KEY)
    const sessionId = getStoredUuid(sessionStorage, SESSION_KEY)
    const path = location.pathname || '/'
    let active = true
    let inFlight = false
    let lastSentAt = 0
    let lastInteractionAt = document.visibilityState === 'visible' ? Date.now() : 0

    async function recordLivePage() {
      if (!active || inFlight || document.visibilityState !== 'visible') return
      const now = Date.now()
      // An idle tab is NOT continuously counted as a live visitor.
      if (!lastInteractionAt || now - lastInteractionAt > 90_000 || now - lastSentAt < 25_000) return
      inFlight = true
      lastSentAt = now
      try {
        const { error } = await supabase.rpc('record_live_page_presence_v1', {
          p_visitor_id: visitorId,
          p_session_id: sessionId,
          p_path: path,
        })
        if (error) console.warn('Tennis Legacy live page activity not recorded:', error.message)
      } catch (error) {
        console.warn('Tennis Legacy live page activity not recorded:', error)
      } finally {
        inFlight = false
      }
    }

    function noteLiveInteraction() {
      if (document.visibilityState !== 'visible') return
      lastInteractionAt = Date.now()
      void recordLivePage()
    }

    function onLiveVisibilityChange() {
      if (document.visibilityState !== 'visible') {
        lastInteractionAt = 0
        // A hidden tab stops heartbeats; existing rows expire within two minutes.
      }
    }

    void recordLivePage() // A visible page navigation counts once on entry.
    window.addEventListener('pointerdown', noteLiveInteraction, { passive: true })
    window.addEventListener('keydown', noteLiveInteraction)
    window.addEventListener('scroll', noteLiveInteraction, { passive: true })
    document.addEventListener('visibilitychange', onLiveVisibilityChange)
    const interval = window.setInterval(() => { void recordLivePage() }, 30_000)
    return () => {
      active = false
      window.clearInterval(interval)
      window.removeEventListener('pointerdown', noteLiveInteraction)
      window.removeEventListener('keydown', noteLiveInteraction)
      window.removeEventListener('scroll', noteLiveInteraction)
      document.removeEventListener('visibilitychange', onLiveVisibilityChange)
    }
  }, [authLoading, location.pathname, user?.id])

  useEffect(() => {
    // An actual foreground interaction, not an open/background browser tab,
    // qualifies an authenticated human tennis player as recently active.
    if (authLoading || !user?.id || !player?.id) return
    if (!OFFICIAL_ANALYTICS_HOSTS.has(window.location.hostname.toLowerCase())) return
    if (location.pathname.startsWith('/game/admin/')) return

    let lastInteraction = 0
    let lastSent = 0
    let inFlight = false
    let active = true

    async function sendPresence() {
      if (!active || document.visibilityState !== 'visible' || inFlight) return
      const now = Date.now()
      if (now - lastInteraction > 90_000 || now - lastSent < 30_000) return
      lastSent = now
      inFlight = true
      try {
        const { error } = await supabase.rpc('record_my_tennis_presence_v1')
        if (error) console.warn('Tennis Legacy activity presence failed:', error.message)
      } catch (error) {
        console.warn('Tennis Legacy activity presence failed:', error)
      } finally {
        inFlight = false
      }
    }

    function noteInteraction() {
      if (document.visibilityState !== 'visible') return
      lastInteraction = Date.now()
      void sendPresence()
    }

    function onVisibilityChange() {
      if (document.visibilityState !== 'visible') {
        lastInteraction = 0
      }
      // Returning to the tab does not imply game activity until interaction.
    }

    window.addEventListener('pointerdown', noteInteraction, { passive: true })
    window.addEventListener('keydown', noteInteraction)
    window.addEventListener('scroll', noteInteraction, { passive: true })
    document.addEventListener('visibilitychange', onVisibilityChange)
    const interval = window.setInterval(() => { void sendPresence() }, 45_000)
    return () => {
      active = false
      window.clearInterval(interval)
      window.removeEventListener('pointerdown', noteInteraction)
      window.removeEventListener('keydown', noteInteraction)
      window.removeEventListener('scroll', noteInteraction)
      document.removeEventListener('visibilitychange', onVisibilityChange)
    }
  }, [authLoading, user?.id, player?.id, location.pathname])

  return null
}
