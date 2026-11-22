import { useCallback, useEffect, useRef, useState } from 'react'
import { Activity, RefreshCw, UsersRound } from 'lucide-react'

import { supabase } from '../../lib/supabase'

interface LivePageRow {
  path: string
  visitors: number
  registered: number
  anonymous: number
  guests?: number
  signed_out?: number
}

interface LivePagesReport {
  generated_at: string
  window_seconds: number
  active_visitors: number
  registered: number
  anonymous: number
  guests?: number
  signed_out?: number
  pages: LivePageRow[]
  definition: string
}

function safeCount(value: unknown): number {
  const n = Number(value)
  return Number.isFinite(n) ? Math.max(0, Math.trunc(n)) : 0
}

function readReport(raw: LivePagesReport): LivePagesReport {
  return {
    ...raw,
    active_visitors: safeCount(raw.active_visitors),
    registered: safeCount(raw.registered),
    anonymous: safeCount(raw.anonymous),
    guests: raw.guests == null ? undefined : safeCount(raw.guests),
    signed_out: raw.signed_out == null ? undefined : safeCount(raw.signed_out),
    window_seconds: safeCount(raw.window_seconds),
    pages: Array.isArray(raw.pages)
      ? raw.pages.map((row) => ({
          path: String(row.path || '/'),
          visitors: safeCount(row.visitors),
          registered: safeCount(row.registered),
          anonymous: safeCount(row.anonymous),
          guests: row.guests == null ? undefined : safeCount(row.guests),
          signed_out: row.signed_out == null ? undefined : safeCount(row.signed_out),
        }))
      : [],
  }
}

export default function AdminLivePageActivity({
  formatPath,
}: {
  readonly formatPath: (path: string) => string
}) {
  const [report, setReport] = useState<LivePagesReport | null>(null)
  const [lastLoaded, setLastLoaded] = useState<Date | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const sequence = useRef(0)

  const refresh = useCallback(async () => {
    const current = ++sequence.current
    setLoading(true)
    try {
      const { data, error: rpcError } = await supabase.rpc('get_admin_live_page_activity_v1')
      if (current !== sequence.current) return
      if (rpcError || !data) throw new Error(rpcError?.message || 'Live page activity is unavailable.')
      setReport(readReport(data as LivePagesReport))
      setLastLoaded(new Date())
      setError(null)
    } catch (err) {
      if (current !== sequence.current) return
      // Never turn a failed refresh into fake zero activity.
      setError(err instanceof Error ? err.message : 'Live page activity is unavailable.')
    } finally {
      if (current === sequence.current) setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
    const refreshIfVisible = () => {
      if (document.visibilityState === 'visible') void refresh()
    }
    const interval = window.setInterval(refreshIfVisible, 30_000)
    window.addEventListener('focus', refreshIfVisible)
    return () => {
      sequence.current += 1
      window.clearInterval(interval)
      window.removeEventListener('focus', refreshIfVisible)
    }
  }, [refresh])

  const maxVisitors = Math.max(1, ...(report?.pages ?? []).map((row) => row.visitors))

  return (
    <section className="tlg-admin-analytics-panel" aria-label="Live page activity">
      <header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
        <div>
          <span style={{ color: '#116b9b', fontSize: 11, fontWeight: 750, letterSpacing: '.12em' }}>
            LIVE PAGE ACTIVITY
          </span>
          <h2 style={{ margin: '3px 0 0' }}>Where visitors are now</h2>
        </div>
        <button type="button" onClick={() => void refresh()} disabled={loading} aria-label="Refresh live page activity">
          <RefreshCw size={15} className={loading ? 'is-spinning' : undefined} /> Refresh
        </button>
      </header>

      <p style={{ fontSize: 12, color: '#667085', margin: '10px 0 16px' }}>
        Recently active visible browsers during the last 2 minutes, grouped by their latest page.
        Updates automatically every 30 seconds while this report is visible. Not a websocket connection count.
        Administrator pages and localhost are excluded.
      </p>
      {error && <p role="alert" className="tlg-admin-analytics-error">
        Live report could not refresh: {error}. {report ? 'Showing the last successful report.' : 'No live data is available yet.'}
      </p>}
      {lastLoaded && (
        <p style={{ fontSize: 12, color: '#667085', marginBottom: 10 }}>
          Last verified: {lastLoaded.toLocaleTimeString()}
          {report?.generated_at ? ` · Server: ${new Date(report.generated_at).toLocaleTimeString()}` : ''}
        </p>
      )}
      {report ? (
        <>
          <div className="tlg-admin-analytics-summary" style={{ marginBottom: 16 }}>
            <article>
              <Activity size={18} />
              <div><span>Active visitors</span><strong>{report.active_visitors.toLocaleString()}</strong></div>
            </article>
            <article>
              <UsersRound size={18} />
              <div><span>Registered browsers</span><strong>{report.registered.toLocaleString()}</strong></div>
            </article>
            <article>
              <UsersRound size={18} />
              <div><span>{report.signed_out == null ? 'Guests / anonymous' : 'Signed-out browsers'}</span><strong>{(report.signed_out ?? report.anonymous).toLocaleString()}</strong></div>
            </article>
          </div>
          {report.guests != null && <p style={{ fontSize: 13, marginBottom: 12 }}><strong>Guest browsers: {report.guests.toLocaleString()}</strong></p>}
          {report.pages.length ? (
            <div style={{ display: 'grid', gap: 10 }}>
              <div style={{
                display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) 100px',
                gap: 16, fontSize: 12, fontWeight: 700, color: '#667085',
              }}>
                <span>Current page</span><span style={{ textAlign: 'right' }}>Visitors</span>
              </div>
              {report.pages.map((row) => (
                <div key={row.path} style={{
                  display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) 100px',
                  alignItems: 'center', gap: 16,
                  padding: '10px 12px', border: '1px solid #dfebf4', borderRadius: 7,
                }}>
                  <div style={{ minWidth: 0 }}>
                    <strong style={{ display: 'block', fontSize: 13 }}>{formatPath(row.path)}</strong>
                    <small style={{ color: '#667085', overflowWrap: 'anywhere' }}>{row.path}</small>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <strong>{row.visitors.toLocaleString()}</strong>
                    {row.guests != null && <small style={{ display: 'block' }}>Registered {row.registered} · Guest {row.guests} · Signed out {row.signed_out ?? 0}</small>}
                    <div style={{ height: 5, marginTop: 6, background: '#edf3f9', borderRadius: 8, overflow: 'hidden' }}>
                      <div style={{ width: `${(100 * row.visitors) / maxVisitors}%`, height: '100%', background: '#238bca' }} />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p style={{ color: '#667085', fontSize: 13, marginBottom: 0 }}>
              No recently active visitors recorded. New page activity appears after the updated website is deployed.
            </p>
          )}
        </>
      ) : !error ? (
        <p style={{ color: '#667085', fontSize: 13 }}>Loading recent page activity…</p>
      ) : null}
    </section>
  )
}
