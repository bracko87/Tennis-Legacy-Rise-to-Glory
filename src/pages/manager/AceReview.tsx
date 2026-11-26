import { useEffect, useState } from 'react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../auth/AuthContext'
import { aceReviewEnabled } from '../../lib/aceReviewFlag'
import GameLayout from '../../components/layout/GameLayout'

const BASE = 'http://127.0.0.1:8769'
async function request(path: string, userId: string, signal: AbortSignal) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session || session.user.id !== userId) throw Error('Session changed; sign in again.')
  const response = await fetch(BASE + path, { headers: { Authorization: 'Bearer ' + session.access_token }, cache: 'no-store', redirect: 'error', signal })
  const data = await response.json()
  if (!response.ok) throw Error(data.error || 'Review worker unavailable')
  return data
}
export default function AceReviewPage() {
  const { user, isAdmin } = useAuth()
  const [draw, setDraw] = useState<any>(null)
  const [match, setMatch] = useState<any>(null)
  const [selected, setSelected] = useState('')
  const [error, setError] = useState('')
  useEffect(() => {
    setDraw(null); setMatch(null); setError('')
    if (!aceReviewEnabled || !isAdmin || !user || user.is_anonymous || location.hostname !== '127.0.0.1') return
    let cancelled = false, timer: ReturnType<typeof setTimeout>
    const abort = new AbortController()
    const id = user.id
    async function poll() {
      try {
        const data = await request('/api/draw', id, abort.signal)
        if (cancelled) return
        setDraw(data); setError('')
        if (selected) {
          const m = await request('/api/match?id=' + encodeURIComponent(selected), id, abort.signal)
          if (!cancelled) setMatch(m)
        }
      } catch (e: any) {
        if (!cancelled) { setDraw(null); setMatch(null); setError(e.message) }
      } finally { if (!cancelled) timer = setTimeout(poll, 2000) }
    }
    void poll()
    return () => { cancelled = true; abort.abort(); clearTimeout(timer) }
  }, [user?.id, isAdmin, selected])
  if (!aceReviewEnabled || !isAdmin || !user || user.is_anonymous || location.hostname !== '127.0.0.1') return null
  const names: Record<string,string> = Object.fromEntries((draw?.entrants || []).map((p:any)=>[p.id,p.name]))
  return <GameLayout title="Project Ace" subtitle="Isolated database review · read-only">
    <section>
      <h2>Private tournament</h2>
      <p>No official career effects. This page displays committed review records only.</p>
      {error && <p role="alert">{error}</p>}
      {!draw && !error && <p role="status">Connecting to review worker…</p>}
      {draw && <>
        <p>Revision {draw.revision} · {draw.phase} · {draw.results.length} matches completed</p>
        <p>Private balance: ${draw.career.balance} · Published points: {draw.career.points}</p>
        <h3>Draw and schedule</h3>
        {draw.matches.map((m:any)=><p key={m.id}><button type="button" aria-pressed={selected===m.id} onClick={()=>setSelected(m.id)}>{m.players.map((id:string)=>names[id]).join(' vs ')} · {m.status}</button>{m.winner && ' · Winner: '+names[m.winner]}</p>)}
        {match && <section><h3>{match.players.map((p:any)=>p.name).join(' vs ')}</h3><p>{match.status} · {match.completedSets?.map((s:any)=>s.games.join('–')).join(' ')} {match.games?.join('–')}</p><p>{match.managed?'Your review match':'Spectating'}</p></section>}
      </>}
    </section>
  </GameLayout>
}
