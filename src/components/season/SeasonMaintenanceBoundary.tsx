import type { ReactNode } from 'react'
import { createContext, useContext, useEffect, useRef, useState } from 'react'
import { AlertTriangle, CalendarClock, Clock3, ShieldCheck } from 'lucide-react'
import { supabase } from '../../lib/supabase'
import '../../styles/season-maintenance.css'

type MaintenancePhase = 'off' | 'announced' | 'active' | 'extended'

export interface SeasonMaintenanceState {
  status: MaintenancePhase
  source_season: number | null
  target_season: number | null
  starts_at: string | null
  planned_reopen_at: string | null
  estimated_reopen_at: string | null
  maintenance_active: boolean
  announcement_visible: boolean
  reopening_delayed: boolean
  notice: string | null
  checked_at: string
}

const MaintenanceContext = createContext<SeasonMaintenanceState | null>(null)

/** This status is fetched through a public, read-only RPC before any player UI mounts. */
export const useSeasonMaintenance = () => useContext(MaintenanceContext)

function formatDateTime(value: string | null): string {
  if (!value) return 'To be announced'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'To be announced'
  return new Intl.DateTimeFormat(undefined, {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    timeZoneName: 'short',
  }).format(date)
}

function Brand() {
  return (
    <div className="tlg-season-maintenance-brand">
      <span className="tlg-season-maintenance-mark" aria-hidden="true">T</span>
      <span><strong>Tennis Legacy</strong><small>Rise to Glory</small></span>
    </div>
  )
}

function MaintenanceScreen({ state }: { state: SeasonMaintenanceState }) {
  const target = state.target_season
  const delayed = state.reopening_delayed
  return (
    <div className="tlg-season-maintenance-page">
      <main className="tlg-season-maintenance-card" aria-labelledby="tlg-maintenance-title">
        <Brand />
        <div className="tlg-season-maintenance-icon"><CalendarClock size={30} aria-hidden="true" /></div>
        <span className="tlg-season-maintenance-eyebrow">SCHEDULED GAME MAINTENANCE</span>
        <h1 id="tlg-maintenance-title">
          {target ? `Season ${target} migration in progress` : 'The game is under maintenance'}
        </h1>
        <p className="tlg-season-maintenance-lead">
          Tennis Legacy is temporarily offline while we move to the next season,
          preserve player progress and verify the new competition calendar.
          Sign-in and gameplay are unavailable during this maintenance window.
        </p>
        <div className="tlg-season-maintenance-timing">
          <Clock3 size={20} aria-hidden="true" />
          <div>
            <span>{delayed ? 'Reopening update' : 'Expected reopening'}</span>
            <strong>{delayed ? 'Maintenance is taking longer than planned' : formatDateTime(state.estimated_reopen_at)}</strong>
            {delayed && <small>We will publish an updated reopening time here when it is confirmed.</small>}
          </div>
        </div>
        {state.notice && <p className="tlg-season-maintenance-note" role="status">{state.notice}</p>}
        <p className="tlg-season-maintenance-reassurance">
          <ShieldCheck size={18} aria-hidden="true" />
          Your career, rankings, purchases and existing game progress are being preserved.
          The game will reopen only when the migration is verified.
        </p>
      </main>
    </div>
  )
}

/**
 * Blocks all website gameplay and sign-in routes while the server-managed
 * maintenance status is active, even for already authenticated browser sessions.
 * This is the WEB access boundary; independent server-side API/write controls
 * must also be included in the operator's production maintenance checklist.
 */
export function SeasonMaintenanceBoundary({ children }: { readonly children: ReactNode }) {
  const [state, setState] = useState<SeasonMaintenanceState | null>(null)
  const [unavailable, setUnavailable] = useState(false)
  const sequence = useRef(0)
  const signedOut = useRef(false)

  useEffect(() => {
    let mounted = true
    async function refresh() {
      const request = ++sequence.current
      const { data, error } = await supabase.rpc('get_tennis_public_maintenance_v1')
      if (!mounted || request !== sequence.current) return
      if (error || !data || typeof data.maintenance_active !== 'boolean') {
        // Fail closed instead of showing a game login while the operator's
        // maintenance state is unavailable. The next poll retries automatically.
        setUnavailable(true)
        setState(null)
        return
      }
      setUnavailable(false)
      setState(data as SeasonMaintenanceState)
    }

    void refresh()
    const polling = window.setInterval(() => void refresh(), 15_000)
    const onFocus = () => { void refresh() }
    document.addEventListener('visibilitychange', onFocus)
    window.addEventListener('focus', onFocus)
    return () => {
      mounted = false
      sequence.current += 1
      window.clearInterval(polling)
      document.removeEventListener('visibilitychange', onFocus)
      window.removeEventListener('focus', onFocus)
    }
  }, [])

  useEffect(() => {
    if (!state?.maintenance_active || signedOut.current) return
    signedOut.current = true
    // Existing browser sessions lose local access when the window begins.
    // Do not revoke other devices or disconnect service accounts.
    void supabase.auth.signOut({ scope: 'local' })
  }, [state?.maintenance_active])

  if (!state) {
    return (
      <div className="tlg-season-maintenance-page">
        <main className="tlg-season-maintenance-card" role="status">
          <Brand />
          <div className="tlg-season-maintenance-icon">
            <AlertTriangle size={28} aria-hidden="true" />
          </div>
          <h1>{unavailable ? 'Game availability cannot be verified' : 'Checking game availability'}</h1>
          <p className="tlg-season-maintenance-lead">
            {unavailable
              ? 'The game access check is temporarily unavailable. We will retry automatically to protect your account and progress.'
              : 'Checking whether Tennis Legacy is available.'}
          </p>
        </main>
      </div>
    )
  }

  if (state.maintenance_active) return <MaintenanceScreen state={state} />

  return <MaintenanceContext.Provider value={state}>{children}</MaintenanceContext.Provider>
}

export function SeasonMaintenanceAnnouncement() {
  const state = useSeasonMaintenance()
  if (!state?.announcement_visible) return null
  return (
    <section className="tlg-season-maintenance-announcement" role="status" aria-label="Upcoming season migration">
      <CalendarClock size={23} aria-hidden="true" />
      <div>
        <strong>Scheduled maintenance — Season {state.target_season}</strong>
        <p>
          Tennis Legacy will be unavailable from <strong>{formatDateTime(state.starts_at)}</strong>.
          We have reserved 24 real-world hours for the season migration,
          with expected reopening on <strong>{formatDateTime(state.estimated_reopen_at)}</strong>.
          If more time is required, this announcement will be updated.
        </p>
        {state.notice && <p>{state.notice}</p>}
      </div>
    </section>
  )
}
