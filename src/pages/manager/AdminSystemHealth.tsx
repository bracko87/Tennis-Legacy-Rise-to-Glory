import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  Clock3,
  Mail,
  RefreshCw,
  ShieldAlert,
} from 'lucide-react'

import GameLayout from '../../components/layout/GameLayout'
import AdminSeasonMigrationPanel from '../../components/manager/AdminSeasonMigrationPanel'
import { supabase } from '../../lib/supabase'
import '../../styles/admin-system-health.css'

type AdminTab = 'overview' | 'tournaments' | 'season' | 'incidents' | 'logs'
type TournamentOpsView = 'today' | 'problems' | 'history'
type TournamentOpsStatus = 'waiting' | 'running' | 'done' | 'overdue' | 'cancelled'
type IncidentFilter = 'active' | 'resolved' | 'all'
type Severity = 'warning' | 'high' | 'critical'
type IncidentStatus = 'open' | 'acknowledged' | 'resolved'
type RunStatus = 'running' | 'success' | 'warning' | 'error' | 'stalled'

interface HealthSummary {
  open_incidents: number
  critical_incidents: number
  high_incidents: number
  warning_incidents: number
  monitored_processes: number
  user_sensitive_processes: number
}

interface HealthProcess {
  process_key: string
  label: string
  category: string
  description: string
  source_kind: string
  source_ref: string | null
  user_sensitive: boolean
  incident_severity: Severity
  expected_interval_minutes: number | null
  stale_after_minutes: number | null
  latest_status: RunStatus | null
  latest_started_at: string | null
  latest_finished_at: string | null
  latest_duration_ms: number | null
  latest_summary: string | null
  latest_error_message: string | null
  cron_active: boolean | null
  open_incidents: number
}

interface HealthIncident {
  id: string
  process_key: string
  process_label: string
  category: string
  severity: Severity
  status: IncidentStatus
  title: string
  message: string
  details: Record<string, unknown>
  first_seen_at: string
  last_seen_at: string
  occurrence_count: number
  last_emailed_at: string | null
  acknowledged_at: string | null
  resolved_at: string | null
  resolution_note?: string | null
  is_unread: boolean
}

interface HealthRun {
  id: string
  process_key: string
  process_label: string
  category: string
  status: RunStatus
  started_at: string
  finished_at: string | null
  duration_ms: number | null
  summary: string | null
  error_message: string | null
  details: Record<string, unknown>
}

interface HealthOverview {
  summary: HealthSummary
  processes: HealthProcess[]
  incidents: HealthIncident[]
  recent_runs: HealthRun[]
}


interface TournamentOperationsRow {
  competition_id: string
  tournament_name: string
  world: string
  category_code: string
  city: string
  season_number: number
  start_absolute_day: number
  end_absolute_day: number
  application_open_absolute_day: number
  application_close_absolute_day: number
  draw_due_absolute_day: number
  ranking_publish_absolute_day: number
  phase: string
  entry_status: TournamentOpsStatus
  draw_status: TournamentOpsStatus
  matches_status: TournamentOpsStatus
  rewards_status: TournamentOpsStatus
  closure_status: TournamentOpsStatus
  application_count: number
  entry_count: number
  human_entry_count: number
  match_count: number
  completed_matches: number
  bye_matches: number
  cancelled_matches: number
  scheduled_matches: number
  in_progress_matches: number
  playable_unresolved_matches: number
  result_rows: number
  pending_ranking_rows: number
  ranking_contribution_rows: number
  human_prize_results: number
  human_prize_payments: number
  stale_calendar_commitments: number
  main_final_completed: boolean
  champion_id: string | null
  champion_name: string | null
  has_problem: boolean
  issue_key: string | null
  issue_severity: Severity | null
  issue_message: string | null
  incident_id: string | null
  incident_status: string | null
  incident_first_seen_at: string | null
  incident_last_seen_at: string | null
}

interface TournamentOperationsPayload {
  game_day: {
    season: number
    month: number
    day: number
    absolute_day: number
  }
  counts: {
    lifecycle_total: number
    active_now: number
    active_problems: number
    completed_recent: number
  }
  rows: TournamentOperationsRow[]
}

const EMPTY_SUMMARY: HealthSummary = {
  open_incidents: 0,
  critical_incidents: 0,
  high_incidents: 0,
  warning_incidents: 0,
  monitored_processes: 0,
  user_sensitive_processes: 0,
}

function formatDate(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('en', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}

function formatDuration(ms: number | null | undefined) {
  if (ms === null || ms === undefined) return '—'
  if (ms < 1000) return `${ms} ms`
  const seconds = ms / 1000
  if (seconds < 60) return `${seconds.toFixed(seconds < 10 ? 1 : 0)} s`
  return `${(seconds / 60).toFixed(1)} min`
}

function severityLabel(severity: Severity) {
  if (severity === 'critical') return 'Critical'
  if (severity === 'high') return 'High'
  return 'Warning'
}

function statusLabel(status: string | null) {
  if (!status) return 'No run yet'
  return status.replaceAll('_', ' ').replace(/^./, (char) => char.toUpperCase())
}

function processIsStale(process: HealthProcess) {
  if (!process.stale_after_minutes) return false
  if (!process.latest_started_at) return true
  const started = new Date(process.latest_started_at).getTime()
  if (Number.isNaN(started)) return true
  return Date.now() - started > process.stale_after_minutes * 60_000
}

function processHealth(process: HealthProcess) {
  if (process.open_incidents > 0) return 'problem'
  if (process.source_kind === 'cron' && process.cron_active === false) return 'problem'
  if (processIsStale(process)) return 'problem'
  if (process.latest_status === 'error' || process.latest_status === 'stalled') return 'problem'
  if (process.latest_status === 'warning') return 'warning'
  if (process.latest_status === 'success') return 'healthy'
  return 'unknown'
}


function TournamentOpsStatusPill({ status }: { status: TournamentOpsStatus }) {
  return (
    <span className={`tlg-tournament-ops-status status-${status}`}>
      <i />
      {statusLabel(status)}
    </span>
  )
}

function tournamentOverallLabel(row: TournamentOperationsRow) {
  if (row.has_problem) return 'Problem'
  if (row.closure_status === 'done') return 'Closed'
  if (row.phase === 'cancelled') return 'Canceled'
  if (row.phase === 'in_progress') return 'Live'
  if (row.phase === 'pre_tournament') return 'Preparing'
  if (row.phase === 'post_tournament') return 'Closing'
  return statusLabel(row.phase)
}

export default function AdminSystemHealthPage() {
  const [tab, setTab] = useState<AdminTab>('overview')
  const [overview, setOverview] = useState<HealthOverview>({
    summary: EMPTY_SUMMARY,
    processes: [],
    incidents: [],
    recent_runs: [],
  })
  const [incidents, setIncidents] = useState<HealthIncident[]>([])
  const [incidentFilter, setIncidentFilter] = useState<IncidentFilter>('active')
  const [selectedIncidentId, setSelectedIncidentId] = useState<string | null>(null)
  const [selectedProcessKey, setSelectedProcessKey] = useState<string>('all')
  const [runs, setRuns] = useState<HealthRun[]>([])
  const [tournamentView, setTournamentView] = useState<TournamentOpsView>('today')
  const [tournamentOps, setTournamentOps] = useState<TournamentOperationsPayload | null>(null)
  const [selectedTournamentId, setSelectedTournamentId] = useState<string | null>(null)
  const [tournamentLoading, setTournamentLoading] = useState(false)
  const [loading, setLoading] = useState(true)
  const [secondaryLoading, setSecondaryLoading] = useState(false)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const selectedIncident = useMemo(
    () => incidents.find((incident) => incident.id === selectedIncidentId)
      ?? overview.incidents.find((incident) => incident.id === selectedIncidentId)
      ?? null,
    [incidents, overview.incidents, selectedIncidentId],
  )


  const selectedTournament = useMemo(
    () => tournamentOps?.rows.find((row) => row.competition_id === selectedTournamentId) ?? null,
    [tournamentOps, selectedTournamentId],
  )

  const loadOverview = useCallback(async (silent = false) => {
    if (!silent) setLoading(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc('get_admin_system_health_overview_v1')
    if (rpcError) {
      setError(rpcError.message)
      if (!silent) setLoading(false)
      return
    }

    const next = (data ?? {}) as Partial<HealthOverview>
    setOverview({
      summary: next.summary ?? EMPTY_SUMMARY,
      processes: next.processes ?? [],
      incidents: next.incidents ?? [],
      recent_runs: next.recent_runs ?? [],
    })
    if (!silent) setLoading(false)
  }, [])

  const loadIncidents = useCallback(async (filter: IncidentFilter = incidentFilter) => {
    setSecondaryLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_admin_system_incidents_v1', {
      p_status: filter,
      p_limit: 300,
    })
    if (rpcError) {
      setError(rpcError.message)
      setIncidents([])
    } else {
      setIncidents((data ?? []) as HealthIncident[])
    }
    setSecondaryLoading(false)
  }, [incidentFilter])

  const loadRuns = useCallback(async (processKey = selectedProcessKey) => {
    setSecondaryLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_admin_system_runs_v1', {
      p_process_key: processKey === 'all' ? null : processKey,
      p_limit: 400,
    })
    if (rpcError) {
      setError(rpcError.message)
      setRuns([])
    } else {
      setRuns((data ?? []) as HealthRun[])
    }
    setSecondaryLoading(false)
  }, [selectedProcessKey])


  const loadTournamentOperations = useCallback(async (
    view: TournamentOpsView = tournamentView,
    silent = false,
  ) => {
    if (!silent) setTournamentLoading(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc('get_admin_tournament_operations_v1', {
      p_view: view,
      p_days: 7,
    })

    if (rpcError) {
      setError(rpcError.message)
      if (!silent) setTournamentLoading(false)
      return
    }

    const next = (data ?? null) as TournamentOperationsPayload | null
    setTournamentOps(next ? {
      ...next,
      rows: next.rows ?? [],
    } : null)

    if (next?.rows?.length && !next.rows.some((row) => row.competition_id === selectedTournamentId)) {
      setSelectedTournamentId(null)
    }

    if (!silent) setTournamentLoading(false)
  }, [tournamentView, selectedTournamentId])

  useEffect(() => {
    void loadOverview()
  }, [loadOverview])

  useEffect(() => {
    if (tab === 'tournaments') void loadTournamentOperations(tournamentView)
  }, [tab, tournamentView, loadTournamentOperations])

  useEffect(() => {
    if (tab === 'incidents') void loadIncidents(incidentFilter)
  }, [tab, incidentFilter, loadIncidents])

  useEffect(() => {
    if (tab === 'logs') void loadRuns(selectedProcessKey)
  }, [tab, selectedProcessKey, loadRuns])

  useEffect(() => {
    const channel = supabase
      .channel('tlg-admin-system-health')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'system_incidents' },
        () => {
          void loadOverview(true)
          if (tab === 'incidents') void loadIncidents(incidentFilter)
          if (tab === 'tournaments') void loadTournamentOperations(tournamentView, true)
        },
      )
      .subscribe()

    const interval = window.setInterval(() => {
      void loadOverview(true)
      if (tab === 'logs') void loadRuns(selectedProcessKey)
      if (tab === 'tournaments') void loadTournamentOperations(tournamentView, true)
    }, 30000)

    const onFocus = () => {
      void loadOverview(true)
      if (tab === 'incidents') void loadIncidents(incidentFilter)
      if (tab === 'logs') void loadRuns(selectedProcessKey)
      if (tab === 'tournaments') void loadTournamentOperations(tournamentView, true)
    }

    window.addEventListener('focus', onFocus)
    return () => {
      window.clearInterval(interval)
      window.removeEventListener('focus', onFocus)
      void supabase.removeChannel(channel)
    }
  }, [tab, incidentFilter, selectedProcessKey, tournamentView, loadOverview, loadIncidents, loadRuns, loadTournamentOperations])

  async function refreshAll() {
    setWorking(true)
    await loadOverview(true)
    if (tab === 'incidents') await loadIncidents(incidentFilter)
    if (tab === 'logs') await loadRuns(selectedProcessKey)
    if (tab === 'tournaments') await loadTournamentOperations(tournamentView, true)
    setWorking(false)
  }

  async function runTournamentOperationsCheck() {
    setWorking(true)
    setError(null)

    const { error: rpcError } = await supabase.rpc('admin_refresh_tournament_operations_v1')
    if (rpcError) {
      setError(rpcError.message)
      setWorking(false)
      return
    }

    await Promise.all([
      loadTournamentOperations(tournamentView, true),
      loadOverview(true),
    ])
    setWorking(false)
  }

  async function openIncident(incident: HealthIncident) {
    setSelectedIncidentId(incident.id)
    if (!incident.is_unread) return

    const { error: readError } = await supabase.rpc('mark_admin_system_incident_read_v1', {
      p_incident_id: incident.id,
    })
    if (!readError) {
      setIncidents((current) => current.map((row) => (
        row.id === incident.id ? { ...row, is_unread: false } : row
      )))
      setOverview((current) => ({
        ...current,
        incidents: current.incidents.map((row) => (
          row.id === incident.id ? { ...row, is_unread: false } : row
        )),
      }))
      window.dispatchEvent(new Event('tlg-admin-notifications-refresh'))
    }
  }

  async function updateIncident(action: 'acknowledge' | 'resolve') {
    if (!selectedIncident) return
    setWorking(true)
    setError(null)

    const { error: rpcError } = await supabase.rpc('admin_update_system_incident_v1', {
      p_incident_id: selectedIncident.id,
      p_action: action,
      p_note: action === 'resolve' ? 'Resolved from System Health administration.' : null,
    })

    setWorking(false)
    if (rpcError) {
      setError(rpcError.message)
      return
    }

    setSelectedIncidentId(null)
    await loadOverview(true)
    await loadIncidents(incidentFilter)
    window.dispatchEvent(new Event('tlg-admin-notifications-refresh'))
  }

  const summary = overview.summary
  const unhealthyProcesses = overview.processes.filter((process) => processHealth(process) === 'problem').length
  const overallHealthy = summary.open_incidents === 0 && unhealthyProcesses === 0

  return (
    <GameLayout
      title="System Health"
      subtitle="Monitor critical game processes, incidents, scheduler activity and user-impacting failures"
    >
      <div className="tlg-system-health-page">
        <div className="tlg-system-health-toolbar">
          <div className="tlg-system-health-tabs" role="tablist" aria-label="System health sections">
            {([
              ['overview', 'Overview'],
              ['tournaments', 'Tournament Operations'],
              ['season', 'Season Migration'],
              ['incidents', 'Incidents'],
              ['logs', 'Process Logs'],
            ] as Array<[AdminTab, string]>).map(([key, label]) => (
              <button
                key={key}
                type="button"
                className={tab === key ? 'active' : ''}
                onClick={() => setTab(key)}
              >
                {label}
                {key === 'incidents' && summary.open_incidents > 0 && (
                  <span>{summary.open_incidents > 99 ? '99+' : summary.open_incidents}</span>
                )}
              </button>
            ))}
          </div>

          <button
            type="button"
            className="tlg-system-health-refresh"
            onClick={() => void refreshAll()}
            disabled={working || loading}
          >
            <RefreshCw size={14} className={working ? 'spin' : ''} />
            Refresh
          </button>
        </div>

        {error && <div className="tlg-system-health-error">{error}</div>}

        {loading ? (
          <div className="tlg-system-health-loading">Loading system health…</div>
        ) : (
          <>
            <section className="tlg-system-health-summary">
              <article className={overallHealthy ? 'healthy' : 'attention'}>
                <div className="icon">{overallHealthy ? <CheckCircle2 size={20} /> : <ShieldAlert size={20} />}</div>
                <div>
                  <span>Overall status</span>
                  <strong>{overallHealthy ? 'Operational' : 'Attention required'}</strong>
                  <small>{summary.open_incidents} active incident{summary.open_incidents === 1 ? '' : 's'} · {unhealthyProcesses} unhealthy process{unhealthyProcesses === 1 ? '' : 'es'}</small>
                </div>
              </article>
              <article>
                <div className="icon"><AlertTriangle size={19} /></div>
                <div>
                  <span>Critical / high</span>
                  <strong>{summary.critical_incidents} / {summary.high_incidents}</strong>
                  <small>{summary.warning_incidents} warning{summary.warning_incidents === 1 ? '' : 's'}</small>
                </div>
              </article>
              <article>
                <div className="icon"><Activity size={19} /></div>
                <div>
                  <span>Monitored processes</span>
                  <strong>{summary.monitored_processes}</strong>
                  <small>{summary.user_sensitive_processes} user-sensitive</small>
                </div>
              </article>
              <article>
                <div className="icon"><Mail size={19} /></div>
                <div>
                  <span>Alert channel</span>
                  <strong>Admin + Email</strong>
                  <small>noreply@tennislegacygame.com</small>
                </div>
              </article>
            </section>

            {tab === 'overview' && (
              <div className="tlg-system-health-overview">
                {overview.incidents.length > 0 && (
                  <section className="tlg-system-health-active-incidents">
                    <header>
                      <div>
                        <span>ACTIVE INCIDENTS</span>
                        <h3>Problems requiring attention</h3>
                      </div>
                    </header>
                    <div className="rows">
                      {overview.incidents.map((incident) => (
                        <button
                          key={incident.id}
                          type="button"
                          className={`incident-row severity-${incident.severity} ${incident.is_unread ? 'unread' : ''}`}
                          onClick={() => {
                            setTab('incidents')
                            setIncidentFilter('active')
                            void openIncident(incident)
                          }}
                        >
                          <span className="severity">{severityLabel(incident.severity)}</span>
                          <span className="copy">
                            <strong>{incident.title}</strong>
                            <small>{incident.process_label} · {incident.category}</small>
                          </span>
                          <span className="when">{formatDate(incident.last_seen_at)}</span>
                        </button>
                      ))}
                    </div>
                  </section>
                )}

                <section className="tlg-system-health-processes">
                  <header>
                    <div>
                      <span>PROCESS MONITOR</span>
                      <h3>Game systems</h3>
                    </div>
                    <small>Latest execution or watchdog state</small>
                  </header>

                  <div className="process-table">
                    <div className="head">
                      <span>Process</span>
                      <span>Category</span>
                      <span>Status</span>
                      <span>Latest run</span>
                      <span>Duration</span>
                      <span>Incidents</span>
                    </div>
                    {overview.processes.map((process) => {
                      const health = processHealth(process)
                      return (
                        <button
                          key={process.process_key}
                          type="button"
                          className={`process-row health-${health}`}
                          onClick={() => {
                            setSelectedProcessKey(process.process_key)
                            setTab('logs')
                          }}
                        >
                          <span className="process-name">
                            <strong>{process.label}</strong>
                            <small>{process.description}</small>
                            {process.user_sensitive && <em>User-sensitive</em>}
                          </span>
                          <span>{process.category}</span>
                          <span className="status">
                            <i />
                            {process.open_incidents > 0 ? 'Incident' : processIsStale(process) ? 'Overdue' : statusLabel(process.latest_status)}
                          </span>
                          <span>{formatDate(process.latest_started_at)}</span>
                          <span>{formatDuration(process.latest_duration_ms)}</span>
                          <span>{process.open_incidents}</span>
                        </button>
                      )
                    })}
                  </div>
                </section>
              </div>
            )}


            {tab === 'tournaments' && (
              <div className="tlg-tournament-ops">
                <div className="tlg-tournament-ops-toolbar">
                  <div className="tlg-tournament-ops-view-tabs" role="tablist" aria-label="Tournament Operations view">
                    {([
                      ['today', 'Today'],
                      ['problems', 'Problems only'],
                      ['history', 'Last 7 days'],
                    ] as Array<[TournamentOpsView, string]>).map(([view, label]) => (
                      <button
                        key={view}
                        type="button"
                        className={tournamentView === view ? 'active' : ''}
                        onClick={() => {
                          setTournamentView(view)
                          setSelectedTournamentId(null)
                        }}
                      >
                        {label}
                      </button>
                    ))}
                  </div>

                  <button
                    type="button"
                    className="tlg-tournament-ops-run"
                    onClick={() => void runTournamentOperationsCheck()}
                    disabled={working || tournamentLoading}
                  >
                    <RefreshCw size={14} className={working ? 'spin' : ''} />
                    Run check now
                  </button>
                </div>

                <section className="tlg-tournament-ops-summary">
                  <article>
                    <span>Lifecycle window</span>
                    <strong>{tournamentOps?.counts.lifecycle_total ?? 0}</strong>
                    <small>From applications through ranking publication</small>
                  </article>
                  <article>
                    <span>Active tournaments</span>
                    <strong>{tournamentOps?.counts.active_now ?? 0}</strong>
                    <small>Currently inside tournament dates</small>
                  </article>
                  <article className={(tournamentOps?.counts.active_problems ?? 0) > 0 ? 'attention' : 'healthy'}>
                    <span>Active problems</span>
                    <strong>{tournamentOps?.counts.active_problems ?? 0}</strong>
                    <small>{(tournamentOps?.counts.active_problems ?? 0) > 0 ? 'Requires operational attention' : 'No lifecycle failures detected'}</small>
                  </article>
                  <article>
                    <span>Closed last 7 days</span>
                    <strong>{tournamentOps?.counts.completed_recent ?? 0}</strong>
                    <small>Final + results + rewards + ranking checks</small>
                  </article>
                </section>

                <section className="tlg-tournament-ops-panel">
                  <header>
                    <div>
                      <span>TOURNAMENT LIFECYCLE MONITOR</span>
                      <h3>
                        Season {tournamentOps?.game_day.season ?? '—'} · Month {tournamentOps?.game_day.month ?? '—'} Day {tournamentOps?.game_day.day ?? '—'}
                      </h3>
                    </div>
                    <small>Automatic watchdog every 5 minutes</small>
                  </header>

                  <div className="tlg-tournament-ops-table">
                    <div className="head">
                      <span>Tournament</span>
                      <span>Window</span>
                      <span>Entry</span>
                      <span>Draw</span>
                      <span>Matches</span>
                      <span>Rewards</span>
                      <span>Closure</span>
                      <span>Overall</span>
                    </div>

                    {tournamentLoading ? (
                      <div className="empty">Loading Tournament Operations…</div>
                    ) : (tournamentOps?.rows.length ?? 0) === 0 ? (
                      <div className="empty">
                        {tournamentView === 'problems'
                          ? 'No tournament lifecycle problems are active.'
                          : 'No tournaments match this operational window.'}
                      </div>
                    ) : tournamentOps?.rows.map((row) => (
                      <button
                        key={row.competition_id}
                        type="button"
                        className={`tlg-tournament-ops-row ${row.has_problem ? 'has-problem' : ''} ${selectedTournamentId === row.competition_id ? 'selected' : ''}`}
                        onClick={() => setSelectedTournamentId((current) => current === row.competition_id ? null : row.competition_id)}
                      >
                        <span className="tournament">
                          <strong>{row.tournament_name}</strong>
                          <small>{row.world} · {row.category_code.replaceAll('_', ' ')} · {row.city}</small>
                        </span>
                        <span className="window">
                          <strong>Day {row.start_absolute_day}–{row.end_absolute_day}</strong>
                          <small>Season {row.season_number}</small>
                        </span>
                        <TournamentOpsStatusPill status={row.entry_status} />
                        <TournamentOpsStatusPill status={row.draw_status} />
                        <TournamentOpsStatusPill status={row.matches_status} />
                        <TournamentOpsStatusPill status={row.rewards_status} />
                        <TournamentOpsStatusPill status={row.closure_status} />
                        <span className={`tlg-tournament-ops-overall ${row.has_problem ? 'problem' : 'ok'}`}>
                          {tournamentOverallLabel(row)}
                        </span>
                      </button>
                    ))}
                  </div>

                  {selectedTournament && (
                    <div className="tlg-tournament-ops-detail">
                      <header>
                        <div>
                          <span>{selectedTournament.world} · {selectedTournament.category_code.replaceAll('_', ' ')}</span>
                          <h3>{selectedTournament.tournament_name}</h3>
                          <p>{selectedTournament.city} · Season {selectedTournament.season_number} · Day {selectedTournament.start_absolute_day}–{selectedTournament.end_absolute_day}</p>
                        </div>
                        <a href={`/game/tournaments/${selectedTournament.competition_id}`}>Open tournament</a>
                      </header>

                      {selectedTournament.has_problem && (
                        <div className={`tlg-tournament-ops-alert severity-${selectedTournament.issue_severity ?? 'high'}`}>
                          <AlertTriangle size={16} />
                          <div>
                            <strong>{selectedTournament.issue_key?.replaceAll('_', ' ') ?? 'Tournament lifecycle problem'}</strong>
                            <span>{selectedTournament.issue_message ?? 'Tournament Operations detected an inconsistency.'}</span>
                          </div>
                        </div>
                      )}

                      <div className="tlg-tournament-ops-metrics">
                        <div><span>Applications</span><strong>{selectedTournament.application_count}</strong></div>
                        <div><span>Entries</span><strong>{selectedTournament.entry_count}</strong><small>{selectedTournament.human_entry_count} human</small></div>
                        <div><span>Matches</span><strong>{selectedTournament.match_count}</strong><small>{selectedTournament.completed_matches} completed · {selectedTournament.bye_matches} byes</small></div>
                        <div><span>Still scheduled</span><strong>{selectedTournament.scheduled_matches}</strong><small>{selectedTournament.in_progress_matches} in progress</small></div>
                        <div><span>Results</span><strong>{selectedTournament.result_rows}</strong><small>{selectedTournament.pending_ranking_rows} ranking pending</small></div>
                        <div><span>Ranking rows</span><strong>{selectedTournament.ranking_contribution_rows}</strong></div>
                        <div><span>Human prizes</span><strong>{selectedTournament.human_prize_payments}/{selectedTournament.human_prize_results}</strong><small>paid / due</small></div>
                        <div><span>Calendar cleanup</span><strong>{selectedTournament.stale_calendar_commitments}</strong><small>stale commitments</small></div>
                      </div>

                      <div className="tlg-tournament-ops-foot">
                        <span>
                          Final: <strong>{selectedTournament.main_final_completed ? 'Completed' : 'Not completed'}</strong>
                        </span>
                        <span>
                          Champion: <strong>{selectedTournament.champion_name ?? '—'}</strong>
                        </span>
                        <span>
                          Playable unresolved matches: <strong>{selectedTournament.playable_unresolved_matches}</strong>
                        </span>
                      </div>
                    </div>
                  )}
                </section>
              </div>
            )}

            {tab === 'season' && <AdminSeasonMigrationPanel />}

            {tab === 'incidents' && (
              <div className="tlg-system-health-incidents">
                <div className="incident-filter-row">
                  {(['active', 'resolved', 'all'] as IncidentFilter[]).map((filter) => (
                    <button
                      key={filter}
                      type="button"
                      className={incidentFilter === filter ? 'active' : ''}
                      onClick={() => {
                        setIncidentFilter(filter)
                        setSelectedIncidentId(null)
                      }}
                    >
                      {filter === 'active' ? 'Active' : filter === 'resolved' ? 'Resolved' : 'All'}
                    </button>
                  ))}
                </div>

                <div className="incident-layout">
                  <section className="incident-list">
                    {secondaryLoading ? (
                      <div className="empty">Loading incidents…</div>
                    ) : incidents.length === 0 ? (
                      <div className="empty">No incidents found for this filter.</div>
                    ) : incidents.map((incident) => (
                      <button
                        key={incident.id}
                        type="button"
                        className={`incident-card severity-${incident.severity} ${incident.id === selectedIncidentId ? 'selected' : ''} ${incident.is_unread ? 'unread' : ''}`}
                        onClick={() => void openIncident(incident)}
                      >
                        <span className="topline">
                          <strong>{severityLabel(incident.severity)}</strong>
                          <em>{statusLabel(incident.status)}</em>
                        </span>
                        <b>{incident.title}</b>
                        <small>{incident.process_label} · {incident.category}</small>
                        <span className="meta">{formatDate(incident.last_seen_at)} · {incident.occurrence_count} occurrence{incident.occurrence_count === 1 ? '' : 's'}</span>
                      </button>
                    ))}
                  </section>

                  <section className="incident-detail">
                    {!selectedIncident ? (
                      <div className="empty">
                        <ShieldAlert size={24} />
                        <strong>Select an incident</strong>
                        <span>Diagnostics, timestamps and admin actions will appear here.</span>
                      </div>
                    ) : (
                      <>
                        <header>
                          <div>
                            <span className={`severity-chip ${selectedIncident.severity}`}>{severityLabel(selectedIncident.severity)}</span>
                            <h3>{selectedIncident.title}</h3>
                            <p>{selectedIncident.process_label} · {selectedIncident.category}</p>
                          </div>
                          <span className="incident-state">{statusLabel(selectedIncident.status)}</span>
                        </header>

                        <div className="incident-message">{selectedIncident.message}</div>

                        <div className="incident-metrics">
                          <div><span>First detected</span><strong>{formatDate(selectedIncident.first_seen_at)}</strong></div>
                          <div><span>Last detected</span><strong>{formatDate(selectedIncident.last_seen_at)}</strong></div>
                          <div><span>Occurrences</span><strong>{selectedIncident.occurrence_count}</strong></div>
                          <div><span>Email alert</span><strong>{selectedIncident.last_emailed_at ? formatDate(selectedIncident.last_emailed_at) : 'Not sent'}</strong></div>
                        </div>

                        <div className="incident-diagnostics">
                          <span>DIAGNOSTICS</span>
                          <pre>{JSON.stringify(selectedIncident.details ?? {}, null, 2)}</pre>
                        </div>

                        {selectedIncident.resolution_note && (
                          <div className="incident-resolution">
                            <span>Resolution</span>
                            <p>{selectedIncident.resolution_note}</p>
                          </div>
                        )}

                        {selectedIncident.status !== 'resolved' && (
                          <div className="incident-actions">
                            {selectedIncident.status === 'open' && (
                              <button
                                type="button"
                                className="ack"
                                disabled={working}
                                onClick={() => void updateIncident('acknowledge')}
                              >
                                <Clock3 size={14} /> Acknowledge
                              </button>
                            )}
                            <button
                              type="button"
                              className="resolve"
                              disabled={working}
                              onClick={() => void updateIncident('resolve')}
                            >
                              <CheckCircle2 size={14} /> Resolve
                            </button>
                          </div>
                        )}
                      </>
                    )}
                  </section>
                </div>
              </div>
            )}

            {tab === 'logs' && (
              <section className="tlg-system-health-logs">
                <header>
                  <div>
                    <span>PROCESS LOGS</span>
                    <h3>Execution history</h3>
                  </div>
                  <label>
                    <span>Process</span>
                    <select
                      value={selectedProcessKey}
                      onChange={(event) => setSelectedProcessKey(event.target.value)}
                    >
                      <option value="all">All monitored processes</option>
                      {overview.processes.map((process) => (
                        <option key={process.process_key} value={process.process_key}>{process.label}</option>
                      ))}
                    </select>
                  </label>
                </header>

                <div className="log-table">
                  <div className="head">
                    <span>Timestamp</span>
                    <span>Process</span>
                    <span>Status</span>
                    <span>Duration</span>
                    <span>Result / error</span>
                  </div>
                  {secondaryLoading ? (
                    <div className="empty">Loading process logs…</div>
                  ) : runs.length === 0 ? (
                    <div className="empty">No process executions recorded yet.</div>
                  ) : runs.map((run) => (
                    <div key={run.id} className={`log-row status-${run.status}`}>
                      <span>{formatDate(run.started_at)}</span>
                      <span className="process"><strong>{run.process_label}</strong><small>{run.category}</small></span>
                      <span className="run-status"><i />{statusLabel(run.status)}</span>
                      <span>{formatDuration(run.duration_ms)}</span>
                      <span className="result">{run.error_message ?? run.summary ?? 'Completed'}</span>
                    </div>
                  ))}
                </div>
              </section>
            )}
          </>
        )}
      </div>
    </GameLayout>
  )
}
