import { useEffect, useMemo, useState } from 'react'
import {
  AlertTriangle,
  Bug,
  CheckCircle2,
  Clock3,
  ExternalLink,
  FileImage,
  MessageSquarePlus,
  RefreshCw,
  UserRound,
} from 'lucide-react'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'

type BugStatus = 'new' | 'open' | 'in_progress' | 'resolved' | 'closed'
type BugPriority = 'low' | 'medium' | 'high' | 'critical'
type BugFilter = BugStatus | 'all'

interface BugReport {
  id: string
  created_at: string
  updated_at: string
  user_id: string | null
  player_id: string | null
  reporter_email: string | null
  player_name: string | null
  world: 'ATP' | 'WTA' | null
  country_code: string | null
  page_label: string
  page_path: string
  page_url: string | null
  bug_type: string
  severity: string
  priority: BugPriority
  description: string
  expected_result: string | null
  actual_result: string | null
  steps_to_reproduce: string | null
  browser: string | null
  viewport: string | null
  screenshot_path: string | null
  reported_from: string
  status: BugStatus
  resolved_at: string | null
  is_unread: boolean
}

interface BugNote {
  id: string
  admin_user_id: string
  admin_email: string | null
  note: string
  created_at: string
}

const FILTERS: Array<{ value: BugFilter; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'new', label: 'New' },
  { value: 'open', label: 'Open' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'closed', label: 'Closed' },
]

const PRIORITIES: BugPriority[] = ['low', 'medium', 'high', 'critical']

function formatDate(value: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('en', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}

function flagForCountry(code: string | null) {
  const upper = String(code || '').toUpperCase()
  if (!/^[A-Z]{2}$/.test(upper)) return '🌐'
  return String.fromCodePoint(...upper.split('').map((char) => 127397 + char.charCodeAt(0)))
}

export default function AdminBugReportsPage() {
  const [filter, setFilter] = useState<BugFilter>('all')
  const [reports, setReports] = useState<BugReport[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [notes, setNotes] = useState<BugNote[]>([])
  const [noteText, setNoteText] = useState('')
  const [screenshotUrl, setScreenshotUrl] = useState<string | null>(null)
  const [draftStatus, setDraftStatus] = useState<BugStatus>('open')
  const [draftPriority, setDraftPriority] = useState<BugPriority>('medium')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const selected = useMemo(
    () => reports.find((report) => report.id === selectedId) ?? null,
    [reports, selectedId],
  )

  async function loadReports(nextFilter = filter) {
    setLoading(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc('get_admin_bug_reports_v1', {
      p_status: nextFilter,
    })

    if (rpcError) {
      setReports([])
      setError(rpcError.message)
    } else {
      const rows = (data ?? []) as BugReport[]
      setReports(rows)
      if (selectedId && !rows.some((row) => row.id === selectedId)) {
        setSelectedId(null)
      }
    }

    setLoading(false)
  }

  async function loadNotes(reportId: string) {
    const { data, error: rpcError } = await supabase.rpc('get_admin_bug_report_notes_v1', {
      p_bug_report_id: reportId,
    })
    if (rpcError) {
      setError(rpcError.message)
      setNotes([])
      return
    }
    setNotes((data ?? []) as BugNote[])
  }

  async function openReport(report: BugReport) {
    setSelectedId(report.id)
    setDraftStatus(report.status)
    setDraftPriority(report.priority)
    setScreenshotUrl(null)
    setError(null)

    if (report.is_unread) {
      const { error: readError } = await supabase.rpc('mark_admin_bug_report_read_v1', {
        p_bug_report_id: report.id,
      })

      if (!readError) {
        setReports((current) => current.map((item) => (
          item.id === report.id ? { ...item, is_unread: false } : item
        )))
        window.dispatchEvent(new Event('tlg-admin-notifications-refresh'))
      }
    }

    void loadNotes(report.id)

    if (report.screenshot_path) {
      const { data, error: imageError } = await supabase.storage
        .from('bug-report-screenshots')
        .createSignedUrl(report.screenshot_path, 300)

      if (!imageError) setScreenshotUrl(data.signedUrl)
    }
  }

  useEffect(() => {
    void loadReports(filter)
  }, [filter])

  useEffect(() => {
    const channel = supabase
      .channel('tlg-admin-bug-report-page')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'bug_reports' },
        () => void loadReports(filter),
      )
      .subscribe()

    const interval = window.setInterval(() => void loadReports(filter), 30000)
    const onFocus = () => void loadReports(filter)

    window.addEventListener('focus', onFocus)
    return () => {
      window.clearInterval(interval)
      window.removeEventListener('focus', onFocus)
      void supabase.removeChannel(channel)
    }
  }, [filter])

  async function saveReportState() {
    if (!selected) return
    setSaving(true)
    setError(null)

    const { error: rpcError } = await supabase.rpc('admin_update_bug_report_v1', {
      p_bug_report_id: selected.id,
      p_status: draftStatus,
      p_priority: draftPriority,
    })

    setSaving(false)
    if (rpcError) {
      setError(rpcError.message)
      return
    }

    await loadReports(filter)
  }

  async function addNote() {
    if (!selected || !noteText.trim()) return
    setSaving(true)
    setError(null)

    const { error: rpcError } = await supabase.rpc('admin_add_bug_report_note_v1', {
      p_bug_report_id: selected.id,
      p_note: noteText.trim(),
    })

    setSaving(false)
    if (rpcError) {
      setError(rpcError.message)
      return
    }

    setNoteText('')
    await loadNotes(selected.id)
  }

  return (
    <GameLayout title="Bug Reports" subtitle="Review player-reported issues, screenshots, status and internal notes">
      <div className="tlg-admin-bugs">
        <div className="tlg-admin-bugs-toolbar">
          <div className="tlg-admin-bug-tabs">
            {FILTERS.map((option) => (
              <button
                key={option.value}
                type="button"
                className={filter === option.value ? 'is-active' : undefined}
                onClick={() => setFilter(option.value)}
              >
                {option.label}
              </button>
            ))}
          </div>

          <button type="button" className="tlg-admin-bug-refresh" onClick={() => void loadReports()} disabled={loading}>
            <RefreshCw size={15} className={loading ? 'is-spinning' : undefined} />
            Refresh
          </button>
        </div>

        {error && <div className="tlg-admin-bug-error">{error}</div>}

        <div className="tlg-admin-bug-layout">
          <section className="tlg-admin-bug-list">
            {loading ? (
              <div className="tlg-admin-bug-empty">Loading bug reports…</div>
            ) : reports.length === 0 ? (
              <div className="tlg-admin-bug-empty">No bug reports found for this filter.</div>
            ) : (
              reports.map((report) => (
                <button
                  type="button"
                  key={report.id}
                  className={'tlg-admin-bug-row ' + (selectedId === report.id ? 'is-selected ' : '') + (report.is_unread ? 'is-unread' : '')}
                  onClick={() => void openReport(report)}
                >
                  <span className="tlg-admin-bug-row-icon"><Bug size={17} /></span>
                  <span className="tlg-admin-bug-row-copy">
                    <span className="tlg-admin-bug-row-title">
                      <strong>{report.page_label}</strong>
                      {report.is_unread && <i>NEW</i>}
                    </span>
                    <span>{report.description}</span>
                    <small>{formatDate(report.created_at)} · {report.bug_type} · {report.severity}</small>
                  </span>
                  <span className={'tlg-admin-bug-status is-' + report.status}>{report.status.replace('_', ' ')}</span>
                </button>
              ))
            )}
          </section>

          <section className="tlg-admin-bug-detail">
            {!selected ? (
              <div className="tlg-admin-bug-detail-empty">
                <Bug size={30} />
                <strong>Select a bug report</strong>
                <span>Opening a report marks it as read only for your administrator account.</span>
              </div>
            ) : (
              <>
                <header className="tlg-admin-bug-detail-header">
                  <div>
                    <span>BUG REPORT</span>
                    <h2>{selected.page_label}</h2>
                    <p>{selected.page_path}</p>
                  </div>
                  <span className={'tlg-admin-bug-status is-' + selected.status}>{selected.status.replace('_', ' ')}</span>
                </header>

                <div className="tlg-admin-bug-reporter">
                  <UserRound size={17} />
                  <div>
                    <strong>{selected.player_name || 'Unknown player'}</strong>
                    <span>{flagForCountry(selected.country_code)} {selected.world || '—'} · {selected.reporter_email || 'No email available'}</span>
                    <small>User ID: {selected.user_id || '—'}</small>
                  </div>
                </div>

                <div className="tlg-admin-bug-summary-grid">
                  <div><span>Type</span><strong>{selected.bug_type}</strong></div>
                  <div><span>Severity</span><strong>{selected.severity}</strong></div>
                  <div><span>Viewport</span><strong>{selected.viewport || '—'}</strong></div>
                  <div><span>Submitted</span><strong>{formatDate(selected.created_at)}</strong></div>
                </div>

                <div className="tlg-admin-bug-copy-block">
                  <span>Description</span>
                  <p>{selected.description}</p>
                </div>

                {selected.expected_result && (
                  <div className="tlg-admin-bug-copy-block">
                    <span>Expected result</span>
                    <p>{selected.expected_result}</p>
                  </div>
                )}

                {selected.actual_result && (
                  <div className="tlg-admin-bug-copy-block">
                    <span>Actual result</span>
                    <p>{selected.actual_result}</p>
                  </div>
                )}

                {selected.steps_to_reproduce && (
                  <div className="tlg-admin-bug-copy-block">
                    <span>Steps to reproduce</span>
                    <p>{selected.steps_to_reproduce}</p>
                  </div>
                )}

                {selected.page_url && (
                  <a className="tlg-admin-bug-link" href={selected.page_url} target="_blank" rel="noreferrer">
                    <ExternalLink size={14} />
                    Open reported page
                  </a>
                )}

                {selected.screenshot_path && (
                  <div className="tlg-admin-bug-screenshot">
                    <span><FileImage size={15} /> Private screenshot</span>
                    {screenshotUrl ? (
                      <a href={screenshotUrl} target="_blank" rel="noreferrer">
                        <img src={screenshotUrl} alt="Bug report screenshot" />
                      </a>
                    ) : (
                      <small>Unable to create a temporary screenshot link.</small>
                    )}
                  </div>
                )}

                <div className="tlg-admin-bug-controls">
                  <label>
                    <span>Status</span>
                    <select value={draftStatus} onChange={(event) => setDraftStatus(event.target.value as BugStatus)}>
                      <option value="new">New</option>
                      <option value="open">Open</option>
                      <option value="in_progress">In Progress</option>
                      <option value="resolved">Resolved</option>
                      <option value="closed">Closed</option>
                    </select>
                  </label>

                  <label>
                    <span>Priority</span>
                    <select value={draftPriority} onChange={(event) => setDraftPriority(event.target.value as BugPriority)}>
                      {PRIORITIES.map((priority) => (
                        <option key={priority} value={priority}>{priority}</option>
                      ))}
                    </select>
                  </label>

                  <button type="button" onClick={() => void saveReportState()} disabled={saving}>
                    <CheckCircle2 size={15} />
                    Save
                  </button>
                </div>

                <div className="tlg-admin-bug-notes">
                  <div className="tlg-admin-bug-notes-title">
                    <MessageSquarePlus size={16} />
                    <strong>Internal admin notes</strong>
                  </div>

                  {notes.length === 0 && <p className="tlg-admin-bug-note-empty">No internal notes yet.</p>}
                  {notes.map((note) => (
                    <article key={note.id}>
                      <p>{note.note}</p>
                      <small>{note.admin_email || 'Administrator'} · {formatDate(note.created_at)}</small>
                    </article>
                  ))}

                  <textarea
                    value={noteText}
                    onChange={(event) => setNoteText(event.target.value)}
                    rows={3}
                    maxLength={4000}
                    placeholder="Add a private note for administrators…"
                  />
                  <button type="button" onClick={() => void addNote()} disabled={saving || !noteText.trim()}>
                    Add note
                  </button>
                </div>

                <div className="tlg-admin-bug-browser">
                  <AlertTriangle size={14} />
                  <span>{selected.browser || 'Browser information unavailable.'}</span>
                </div>
              </>
            )}
          </section>
        </div>
      </div>
    </GameLayout>
  )
}
