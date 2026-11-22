import { useCallback, useEffect, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import { RefreshCw, Search } from 'lucide-react'
import { supabase } from '../../lib/supabase'

type HistoryEvent = {
  id: string
  category: string
  type: string
  entity_id: string | null
  subject_id: string | null
  occurred_at: string
  summary: string
  status: string
}
type HistoryData = {
  generated_at: string
  total: number
  offset: number
  limit: number
  events: HistoryEvent[]
  definition: string
  retention: string
}
const CATEGORIES = ['all','system','admin','account','premium','coins','billing','career','training','tournament','staff','sponsor'] as const
const PAGE_SIZE = 25

export default function AdminEventHistory({ period }: { readonly period: number }) {
  const [category, setCategory] = useState<string>('all')
  const [draftSearch, setDraftSearch] = useState('')
  const [appliedSearch, setAppliedSearch] = useState('')
  const [offset, setOffset] = useState(0)
  const [report, setReport] = useState<HistoryData | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const sequence = useRef(0)

  const load = useCallback(async () => {
    const request = ++sequence.current
    setLoading(true)
    try {
      const result = await supabase.rpc('get_admin_tennis_event_history_v1', {
        p_days: period,
        p_category: category,
        p_search: appliedSearch || null,
        p_limit: PAGE_SIZE,
        p_offset: offset,
      })
      if (request !== sequence.current) return
      if (result.error || !result.data) throw result.error ?? new Error('History unavailable')
      setReport(result.data as HistoryData)
      setError(null)
    } catch (reason) {
      if (request !== sequence.current) return
      setError(reason instanceof Error ? reason.message : 'Unable to load event history')
      // Do not erase the last successfully retrieved history on a network error.
    } finally {
      if (request === sequence.current) setLoading(false)
    }
  }, [period, category, appliedSearch, offset])

  useEffect(() => {
    void load()
    return () => { sequence.current += 1 }
  }, [load])

  function runSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setOffset(0)
    setAppliedSearch(draftSearch.trim().slice(0,80))
  }

  return (
    <section className="tlg-admin-analytics-panel" aria-label="Searchable administrator event history">
      <h2 style={{ marginBottom: 8 }}>Event &amp; Audit History</h2>
      <p style={{ marginBottom: 12, fontSize: 12, color: '#667085' }}>
        Search recorded administrative, account lifecycle, Premium, gameplay and economy events.
        The history uses the reporting period selected above. Only administrators can access these records.
      </p>
      <form onSubmit={runSearch} style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 8, marginBottom: 12 }}>
        <label htmlFor="helios-history-category" style={{ fontSize: 12 }}>Category</label>
        <select
          id="helios-history-category"
          value={category}
          onChange={event => { setCategory(event.target.value); setOffset(0) }}
          style={{ minHeight: 34 }}
        >
          {CATEGORIES.map(item => <option key={item} value={item}>{item === 'all' ? 'All events' : item[0].toUpperCase()+item.slice(1)}</option>)}
        </select>
        <label htmlFor="helios-history-query" style={{ fontSize: 12 }}>Search ID or description</label>
        <input
          id="helios-history-query"
          type="search"
          maxLength={80}
          value={draftSearch}
          onChange={event=>setDraftSearch(event.target.value)}
          placeholder="Event / entity ID, action, status"
          style={{ minHeight: 34, minWidth: 180, flex: '1 1 180px' }}
        />
        <button type="submit" disabled={loading}><Search size={14}/> Search</button>
        <button type="button" disabled={loading} onClick={()=>void load()} aria-label="Refresh event history">
          <RefreshCw size={14}/> Refresh
        </button>
      </form>
      {error && <p className="tlg-admin-analytics-error" role="alert">Event history: {error}</p>}
      {report && (
        <>
          <p style={{ fontSize: 12, marginBottom: 10, color: '#667085' }}>
            {report.total.toLocaleString()} matching events · showing {report.events.length ? report.offset+1 : 0}–
            {report.offset+report.events.length} · Last checked {new Date(report.generated_at).toLocaleTimeString()}
          </p>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr>
                  <th scope="col" style={{ textAlign: 'left', padding: 8 }}>Recorded at</th>
                  <th scope="col" style={{ textAlign: 'left', padding: 8 }}>Category</th>
                  <th scope="col" style={{ textAlign: 'left', padding: 8 }}>Event</th>
                  <th scope="col" style={{ textAlign: 'left', padding: 8 }}>Status</th>
                  <th scope="col" style={{ textAlign: 'left', padding: 8 }}>Reference</th>
                </tr>
              </thead>
              <tbody>
                {report.events.map(event => (
                  <tr key={event.id} style={{ borderTop: '1px solid rgba(125,125,125,.2)' }}>
                    <td style={{ padding: 8, whiteSpace: 'nowrap' }}>{new Date(event.occurred_at).toLocaleString()}</td>
                    <td style={{ padding: 8 }}>{event.category}</td>
                    <td style={{ padding: 8 }}>{event.summary}</td>
                    <td style={{ padding: 8 }}>{event.status}</td>
                    <td style={{ padding: 8, overflowWrap: 'anywhere', fontFamily: 'monospace', fontSize: 11 }}>{event.id}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {report.events.length===0 && <p style={{ padding: 12 }}>No matching events for this search and period.</p>}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 12 }}>
            <button type="button" disabled={loading || offset===0} onClick={()=>setOffset(Math.max(0,offset-PAGE_SIZE))}>Previous</button>
            <span style={{ fontSize: 12 }}>Page {Math.floor(offset/PAGE_SIZE)+1}</span>
            <button type="button" disabled={loading || offset+PAGE_SIZE>=report.total || offset>=5000} onClick={()=>setOffset(offset+PAGE_SIZE)}>Next</button>
          </div>
          <p style={{ fontSize: 12, color: '#667085', marginTop: 12 }}>{report.definition}</p>
          <p style={{ fontSize: 12, color: '#667085' }}>{report.retention}</p>
        </>
      )}
      {!report && !error && <p>Loading recorded events…</p>}
    </section>
  )
}
