import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, CalendarDays, Clock3, RefreshCw, ShieldCheck } from 'lucide-react'
import { supabase } from '../../lib/supabase'
import '../../styles/admin-season-migration.css'

type Clock = {
  season: number
  target_season: number
  game_day: number
  speed_multiplier: number
  real_hours_remaining: number
}

type SponsorReadiness = {
  policy: string
  boundary_absolute_day: number
  main_active: number
  main_due_by_boundary: number
  main_crossing_existing: number
  technical_active: number
  technical_due_by_boundary: number
  technical_crossing_existing: number
  compliance_verified: boolean
}

type Readiness = {
  phase: string
  execution_enabled: boolean
  as_of: string
  clock: Clock
  calendar: {
    next_season_editions: number
    next_season_slots: number
    coverage_verified: boolean
  }
  blockers: string[]
  sponsors?: SponsorReadiness
}

type Milestone = { id: string; title: string; gate: string }

const CHECKPOINTS: Milestone[] = [
  { id: 'discover', title: '01 · Preflight & clock safety', gate: 'Next season fully planned; clock stop strategy validated' },
  { id: 'lock', title: '02 · Exclusive migration lock', gate: 'One authorized run; competing daily jobs safely held' },
  { id: 'settle', title: '03 · Settle Season N', gate: 'Matches, draws, rankings, prizes and refunds reconciled' },
  { id: 'snapshot', title: '04 · Preserve snapshot & baseline', gate: 'Restorable backup, checksums and immutable records' },
  { id: 'rankings', title: '05 · Ranking continuity', gate: 'Singles and doubles expiry/defence, ATP/WTA snapshots' },
  { id: 'contracts', title: '06 · Contracts & sponsors', gate: 'Staff continues by term; new main/technical deals renew annually; existing cross-season contracts retain original dates, payments and equipment rights' },
  { id: 'finance', title: '07 · Finance carryover', gate: 'Reconciled USD balances, historical transactions preserved' },
  { id: 'development', title: '08 · Training & health', gate: 'Injuries, travel, camp and fatigue continue without double processing' },
  { id: 'identity', title: '09 · Player, AI & private life', gate: 'Identities, equipment, clubs, property and national teams intact' },
  { id: 'calendar', title: '10 · Season N+1 calendar', gate: 'Valid ATP/WTA schedule slots and tournament editions published' },
  { id: 'switch', title: '11 · Guarded clock activation', gate: 'Clock advances exactly once, with rollback plan' },
  { id: 'postcheck', title: '12 · Post-transition validation', gate: 'Rankings, draws, finance, players and system checks pass' },
  { id: 'close', title: '13 · Archive report & unlock', gate: 'Permanent run log, incident report and notifications' },
]

const CARRYOVER_RULES = [
  { system: 'Player identity and career', end: 'Current player profile, skills and achievements', start: 'Preserved; career continues without reset' },
  { system: 'ATP/WTA rankings (singles and doubles)', end: 'Published points and active contributions', start: 'Points retained; defend/expire on official weekly publication' },
  { system: 'Season-specific results and finance', end: 'Season 1 wins/losses, title and income totals', start: 'New Season 2 counters; career totals and cash retained' },
  { system: 'Tournament editions and draws', end: 'Completed Season 1 draws, results and replays', start: 'New editions, slots, entries and draws; old history retained' },
  { system: 'Main & technical sponsors', end: 'Active contracts and completed obligations', start: 'New offers renewed annually; signed legacy terms survive to original expiry' },
  { system: 'Staff, training and medical', end: 'Current contracts, camps, fatigue and injuries', start: 'Continue without duplicate payouts or effects' },
  { system: 'Equipment, club and private life', end: 'All owned equipment, condition and purchased assets', start: 'Preserved, no free repair or automatic ownership change' },
  { system: 'National-team and association records', end: 'Official medals, standings and appearance history', start: 'History retained; new seasonal fixtures and grants only if applicable' },
] as const

const SEASON_SECONDS = 366 * 86400

export default function AdminSeasonMigrationPanel() {
  const [status, setStatus] = useState<Readiness | null>(null)
  const [clockOnly, setClockOnly] = useState<Clock | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async (silent = false) => {
    if (!silent) setLoading(true)
    // The readiness RPC is created by a pending staging migration; until
    // deployed, show a *real* clock and explicit unavailable diagnostics.
    const { data, error: rpcError } = await supabase.rpc('get_admin_season_transition_readiness_v1')
    if (!rpcError && data && typeof data === 'object') {
      setStatus(data as Readiness)
      setClockOnly(null)
      setError(null)
    } else {
      setStatus(null)
      const clock = await supabase.rpc('get_game_clock_v1')
      const row = (Array.isArray(clock.data) ? clock.data[0] : clock.data) as {
        game_total_seconds: number | string
        speed_multiplier: number | string
      } | null
      if (clock.error || !row) {
        setClockOnly(null)
        setError(clock.error?.message ?? 'Season migration readiness is unavailable.')
      } else {
        const seconds = Number(row.game_total_seconds)
        const speed = Number(row.speed_multiplier)
        if (!Number.isFinite(seconds) || !Number.isFinite(speed) || speed <= 0) {
          setError('The game clock returned invalid data.')
          setClockOnly(null)
        } else {
          const elapsed = seconds % SEASON_SECONDS
          const season = Math.floor(seconds / SEASON_SECONDS) + 1
          setClockOnly({
            season,
            target_season: season + 1,
            game_day: Math.floor(elapsed / 86400) + 1,
            speed_multiplier: speed,
            real_hours_remaining: (SEASON_SECONDS - elapsed) / speed / 3600,
          })
          setError('The season-readiness database migration is not deployed. Calendar coverage and migration execution are not verified.')
        }
      }
    }
    if (!silent) setLoading(false)
  }, [])

  useEffect(() => {
    void refresh()
    const refreshTimer = window.setInterval(() => void refresh(true), 60000)
    return () => window.clearInterval(refreshTimer)
  }, [refresh])

  const clock = status?.clock ?? clockOnly
  const daysLeft = clock ? Math.ceil(clock.real_hours_remaining / 24) : null

  return <section className="tlg-admin-season">
    <header className="tlg-admin-season-heading">
      <div>
        <span>SEASON MIGRATION · CONTROL CENTER</span>
        <h3>Controlled season transition</h3>
        <p>Read-only migration plan. No season data will change from this screen.</p>
      </div>
      <button type="button" onClick={() => void refresh()} disabled={loading}>
        <RefreshCw size={14} aria-hidden="true" /> Refresh
      </button>
    </header>

    <div className="tlg-admin-season-warning" role="status">
      <AlertTriangle size={20} aria-hidden="true" />
      <div><strong>Migration NOT READY — season boundary guarded; execution unavailable</strong>
        <p>Execution controls are disabled. The shared game clock is now guarded at the end of Season 1, so gameplay time cannot advance into Season 2 before an approved handover. The migration runner, recovery journal, Season 2 calendar and dry-run certification are still missing.</p>
      </div>
    </div>

    {loading && <p className="tlg-admin-season-wait">Checking current game clock and readiness…</p>}
    {error && <p className="tlg-admin-season-diagnostic" role="status">{error}</p>}

    <div className="tlg-admin-season-metrics">
      <article><Clock3 size={18} aria-hidden="true" /><span>Season in progress</span><strong>{clock?.season ?? '—'}</strong><small>Game day {clock?.game_day ?? '—'} of 366</small></article>
      <article><CalendarDays size={18} aria-hidden="true" /><span>Next transition</span><strong>{clock?.target_season ?? '—'}</strong><small>{daysLeft === null ? 'Countdown unavailable' : '~' + daysLeft + ' real days remaining'}</small></article>
      <article><ShieldCheck size={18} aria-hidden="true" /><span>Clock multiplier</span><strong>{clock?.speed_multiplier ?? '—'}×</strong><small>Shared game world</small></article>
      <article><CalendarDays size={18} aria-hidden="true" /><span>Next-season coverage</span><strong>{status ? status.calendar.next_season_editions + ' editions' : 'Not checked'}</strong><small>{status ? status.calendar.next_season_slots + ' linked slots · unverified' : 'Readiness RPC pending release'}</small></article>
    </div>

    <section className="tlg-admin-season-sponsor-policy" aria-labelledby="tlg-admin-season-sponsor-title">
      <header>
        <span>APPROVED MIGRATION POLICY · 19 OCT 2026</span>
        <h4 id="tlg-admin-season-sponsor-title">Annual sponsorship renewal & existing-contract protection</h4>
        <p>New main and technical sponsorship deals must be season-bounded. A player chooses a new offer; none is auto-signed. Every contract signed before policy activation keeps its original expiration date, payment schedule and promised benefits, even into Season 2.</p>
      </header>
      <div className="tlg-admin-season-sponsor-counts" aria-label="Read-only sponsorship boundary audit">
        <div><span>Main sponsors due by boundary</span><strong>{status?.sponsors?.main_due_by_boundary ?? '—'}</strong></div>
        <div><span>Main contracts crossing boundary</span><strong>{status?.sponsors?.main_crossing_existing ?? '—'}</strong></div>
        <div><span>Technical sponsors due by boundary</span><strong>{status?.sponsors?.technical_due_by_boundary ?? '—'}</strong></div>
        <div><span>Technical contracts crossing boundary</span><strong>{status?.sponsors?.technical_crossing_existing ?? '—'}</strong></div>
      </div>
      {!status?.sponsors && <p className="tlg-admin-season-sponsor-diagnostic">Contract counts unavailable until the staged, administrator-only readiness migration is deployed. The sponsorship rules are defined; the renewal engine and compliance checks are not yet operational.</p>}
      {status?.sponsors && <p className="tlg-admin-season-sponsor-diagnostic">Boundary: absolute game day {status.sponsors.boundary_absolute_day}. Counts show existing active agreements only. Compliance not certified; never cancel crossing contracts automatically.</p>}
      <ul>
        <li>End-of-season objectives, earned rewards and scheduled payments must settle exactly once.</li>
        <li>Preserve old technical discounts, remaining free equipment/replacements and already owned items; no midnight allowance refresh.</li>
        <li>Generate separate Season 2 offers based on the player's ranking and reputation. New contracts end by that season's boundary and require acceptance.</li>
        <li>Verify there are no overlapping exclusive sponsors, changed legacy end dates or duplicate money/benefit transactions.</li>
      </ul>
      <small>Read-only policy preview · Checkpoint 06 stays pending until the sponsor reconciliation processor and dry-run tests are installed.</small>
    </section>

    <section className="tlg-admin-season-carryover" aria-labelledby="tlg-admin-season-rules-title">
      <header>
        <span>SEASON 1 → SEASON 2</span>
        <h4 id="tlg-admin-season-rules-title">What stays, resets or renews</h4>
        <p>Expected transition contract, not a report of a completed migration.</p>
      </header>
      <div className="tlg-admin-season-rules-scroll">
        <table>
          <thead><tr><th scope="col">Game system</th><th scope="col">Season 1 final state</th><th scope="col">Season 2 opening state</th></tr></thead>
          <tbody>{CARRYOVER_RULES.map((rule) => (
            <tr key={rule.system}><th scope="row">{rule.system}</th><td>{rule.end}</td><td>{rule.start}</td></tr>
          ))}</tbody>
        </table>
      </div>
    </section>

    <div className="tlg-admin-season-blockers">
      <h4>Blocking requirements</h4>
      {status?.blockers?.length ? <ul>{status.blockers.map((issue) => <li key={issue}>{issue}</li>)}</ul> :
        <p>Season N+1 tournament calendar, a tested transition runner, snapshot/recovery, idempotent step processing and dry-run validation must be completed before migration can be enabled.</p>}
    </div>

    <div className="tlg-admin-season-checkpoints">
      <header><div><span>TRANSITION RUNBOOK</span><h4>13 ordered migration checkpoints</h4></div>
        <small>Plan only · No execution or historical run data yet</small></header>
      <div className="tlg-admin-season-checkpoint-grid">
        {CHECKPOINTS.map((step) => <article key={step.id}>
          <div><strong>{step.title}</strong><span className="tlg-admin-season-pending">Not implemented</span></div>
          <p>{step.gate}</p>
        </article>)}
      </div>
    </div>
    <p className="tlg-admin-season-footnote">All career records, historical match results, finances, rankings, staff contracts, purchased assets and active player profiles are preserved by design. An executable engine and durable step journal are future phases, not part of this read-only panel.{' '}
      <a href="https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/blob/staging/docs/SEASON_MIGRATION_PLAN.md" target="_blank" rel="noopener noreferrer">View complete migration rules and operator runbook</a>
    </p>
  </section>
}
