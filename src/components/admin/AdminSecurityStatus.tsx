import { useCallback, useEffect, useState } from 'react'
import { RefreshCw, ShieldCheck } from 'lucide-react'
import { supabase } from '../../lib/supabase'

type SecurityStatus = {
  checked_at: string
  active_admin_records: number
  verified_active_admins: number
  unlinked_active_records: number
  analytics_anon_execute: boolean
  history_anon_execute: boolean
  economy_anon_execute: boolean
  definition: string
}

export default function AdminSecurityStatus() {
  const [report, setReport] = useState<SecurityStatus | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const load = useCallback(async (active?: () => boolean) => {
    setLoading(true)
    try {
      const { data, error: rpcError } = await supabase.rpc('get_admin_tennis_security_status_v1')
      if (active && !active()) return
      if (rpcError || !data) throw new Error(rpcError?.message || 'Could not check admin security')
      setReport(data as SecurityStatus)
      setError(null)
    } catch (reason) {
      if (active && !active()) return
      setError(reason instanceof Error ? reason.message : 'Security status unavailable')
    } finally {
      if (!active || active()) setLoading(false)
    }
  }, [])

  useEffect(() => {
    let active = true
    void load(() => active)
    return () => { active = false }
  }, [load])

  const statusOk = report !== null &&
    report.unlinked_active_records === 0 &&
    report.active_admin_records === report.verified_active_admins &&
    !report.analytics_anon_execute &&
    !report.history_anon_execute &&
    !report.economy_anon_execute

  return (
    <section className="tlg-admin-analytics-panel" aria-label="Administration security checks">
      <div style={{ display:'flex',alignItems:'center',justifyContent:'space-between',gap:12,flexWrap:'wrap' }}>
        <h2 style={{display:'flex',alignItems:'center',gap:8,marginBottom:8}}>
          <ShieldCheck size={19} /> Administrator security
        </h2>
        <button type="button" disabled={loading} onClick={()=>void load()}>
          <RefreshCw size={14} /> Refresh security checks
        </button>
      </div>
      {error && <p className="tlg-admin-analytics-error" role="alert">{error}</p>}
      {report && (
        <>
          <p style={{fontSize:13,marginBottom:10}}>
            {statusOk
              ? 'Configured administrator access and selected private analytics permissions passed these checks.'
              : 'Security configuration needs review. Inspect the indicators below.'}
          </p>
          <div className="tlg-admin-analytics-summary">
            <article><ShieldCheck size={18}/><div><span>Verified active administrators</span><strong>{report.verified_active_admins}</strong></div></article>
            <article><ShieldCheck size={18}/><div><span>Unlinked active admin grants</span><strong>{report.unlinked_active_records}</strong></div></article>
            <article><ShieldCheck size={18}/><div><span>Anonymous analytics access</span><strong>{report.analytics_anon_execute?'Allowed':'Blocked'}</strong></div></article>
            <article><ShieldCheck size={18}/><div><span>Anonymous economy access</span><strong>{report.economy_anon_execute?'Allowed':'Blocked'}</strong></div></article>
            <article><ShieldCheck size={18}/><div><span>Anonymous audit history access</span><strong>{report.history_anon_execute?'Allowed':'Blocked'}</strong></div></article>
          </div>
          <p style={{fontSize:12,color:'#667085',marginTop:12}}>
            Checked: {new Date(report.checked_at).toLocaleString()}.
            {' '}{report.definition}
          </p>
        </>
      )}
      {!report && !error && <p>Checking administrator permissions…</p>}
    </section>
  )
}
