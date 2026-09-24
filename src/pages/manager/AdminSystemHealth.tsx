import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  Clock3,
  Mail,
  RefreshCw,
  ShieldAlert,
  Wrench,
} from 'lucide-react'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/admin-system-health.css'

type AdminTab = 'overview' | 'incidents' | 'logs'
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

function processHealth(process: HealthProcess) {
  if (process.open_incidents > 0) return 'problem'
  if (process.source_kind === 'cron' && process.cron_active === false) return 'problem'
  if (process.latest_status === 'error' || process.latest_status === 'stalled') return 'problem'
  if (process.latest_status === 'warning') return 'warning'
  if (process.latest_status === 'success') return 'healthy'
  return 'unknown'
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

  useEffect(() => {
    void loadOverview()
  }, [loadOverview])

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
        },
      )
      .subscribe()

    const interval = window.setInterval(() => {
      void loadOverview(true)
      if (tab === 'logs') void loadRuns(selectedProcessKey)
    }, 30000)

    const onFocus = () => {
      void loadOverview(true)
      if (tab === 'incidents') void loadIncidents(incidentFilter)
      if (tab === 'logs') void loadRuns(selectedProcessKey)
    }

    window.addEventListener('focus', onFocus)
    return () => {
      window.clearInterval(interval)
      window.removeEventListener('focus', onFocus)
      void supabase.removeChannel(channel)
    }
  }, [tab, incidentFilter, selectedProcessKey, loadOverview, loadIncidents, loadRuns])

  async function refreshAll() {
    setWorking(true)
    await loadOverview(true)
    if (tab === 'incidents') await loadIncidents(incidentFilter)
    if (tab === 'logs') await loadRuns(selectedProcessKey)
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
  const overallHealthy = summary.open_incidents === 0

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
                  <small>{summary.open_incidents} active incident{summary.open_incidents === 1 ? '' : 's'}</small>
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
                            {process.open_incidents > 0 ? 'Incident' : statusLabel(process.latest_status)}
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
