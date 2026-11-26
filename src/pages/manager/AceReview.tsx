import { useEffect, useRef, useState } from 'react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../auth/AuthContext'
import { aceReviewEnabled } from '../../lib/aceReviewFlag'
import GameLayout from '../../components/layout/GameLayout'
import '../../styles/tournament-match-replay-score-v2.css'

const BASE = 'http://127.0.0.1:8769'
const choices:Record<string,string[]>={approach:['Defensive','Balanced','Aggressive'],rally:['Shorten points','Balanced rallies','Extend rallies'],serve:['Safe first serve','Balanced','Power serving'],returnGame:['Safe return','Balanced','Attack second serve'],target:['Automatic','Backhand','Forehand','Movement','Stamina']}
const defaults={approach:'Balanced',rally:'Balanced rallies',serve:'Balanced',returnGame:'Balanced',target:'Automatic'}
const labels:Record<string,string>={approach:'Approach',rally:'Rally length',serve:'Serve',returnGame:'Return',target:'Target'}
async function request(path:string,userId:string,signal:AbortSignal,body?:any){
 const {data:{session}}=await supabase.auth.getSession()
 if(!session||session.user.id!==userId)throw Error('Session changed; sign in again.')
 const response=await fetch(BASE+path,{method:body===undefined?'GET':'POST',headers:{Authorization:'Bearer '+session.access_token,...(body===undefined?{}:{'Content-Type':'application/json'})},body:body===undefined?undefined:JSON.stringify(body),cache:'no-store',redirect:'error',signal})
 const data=await response.json()
 if(!response.ok)throw Error(data.error||'Review worker unavailable')
 return data
}
function point(a:number,b:number,tb:boolean){return tb?String(a):a>=3&&b>=3?a>b?'AD':'40':['0','15','30','40'][Math.min(a,3)]}
export default function AceReviewPage(){
 const {user,isAdmin}=useAuth()
 const [draw,setDraw]=useState<any>(null),[match,setMatch]=useState<any>(null),[selected,setSelected]=useState(''),[error,setError]=useState(''),[notice,setNotice]=useState(''),[draft,setDraft]=useState<Record<string,string>>({...defaults}),[dirty,setDirty]=useState(false),[busy,setBusy]=useState(false)
 const generation=useRef(0),pending=useRef<AbortController|null>(null),locked=useRef(false),heartbeat=useRef({id:'',at:0}),revision=useRef(-1)
 function select(id:string){generation.current++;pending.current?.abort();setSelected(id);setMatch(null);setDirty(false);setDraft({...defaults});setNotice('');setError('');revision.current=-1}
 useEffect(()=>{generation.current++;pending.current?.abort();setDraw(null);setMatch(null);setSelected('');setDirty(false);setNotice('');revision.current=-1;heartbeat.current={id:'',at:0};return()=>{generation.current++;pending.current?.abort()}},[user?.id,isAdmin])
 useEffect(()=>{
  if(!aceReviewEnabled||!isAdmin||!user||user.is_anonymous||location.hostname!=='127.0.0.1')return
  let cancelled=false,timer:ReturnType<typeof setTimeout>;const abort=new AbortController(),id=user.id
  async function poll(){
   try{
    if(locked.current)return
    const data=await request('/api/draw',id,abort.signal)
    if(cancelled)return;setDraw(data)
    if(selected){
     let m=await request('/api/match?id='+encodeURIComponent(selected),id,abort.signal)
     if(cancelled||locked.current)return
     if(data.coachingEnabled&&m.managed&&m.status==='live'&&(heartbeat.current.id!==selected||Date.now()-heartbeat.current.at>=10000)){
      try{m=await request('/api/heartbeat?id='+encodeURIComponent(selected),id,abort.signal,{});heartbeat.current={id:selected,at:Date.now()}}catch{/* A concurrent background tick may win; next poll refreshes. */}
     }
     if(!cancelled&&!locked.current&&m.revision>=revision.current){revision.current=m.revision;setMatch(m);if(!dirty)setDraft({...defaults,...m.activeTactics,...m.ownPending})}
    }
   }catch(e:any){if(!cancelled&&e.name!=='AbortError'){setDraw(null);setMatch(null);setError(e.message)}}
   finally{if(!cancelled)timer=setTimeout(poll,2000)}
  }
  void poll();return()=>{cancelled=true;abort.abort();clearTimeout(timer)}
 },[user?.id,isAdmin,selected,dirty])
 async function coach(){
  if(locked.current||!user||!match?.managed||match.status!=='live'||!draw?.coachingEnabled||match.coachingMode==='auto')return
  const g=generation.current,id=selected,target=match.nextCoachingGame,abort=new AbortController()
  pending.current=abort;locked.current=true;setBusy(true);setError('');setNotice('')
  try{
   const m=await request('/api/coach?id='+encodeURIComponent(id),user.id,abort.signal,{targetGame:target,tactics:draft})
   if(g===generation.current){revision.current=m.revision;setMatch(m);setDirty(false);setNotice('Instructions accepted for game '+target)}
  }catch(e:any){if(g===generation.current&&e.name!=='AbortError')setError(e.message)}
  finally{locked.current=false;setBusy(false);pending.current=null}
 }
 if(!aceReviewEnabled||!isAdmin||!user||user.is_anonymous||location.hostname!=='127.0.0.1')return null
 const names:Record<string,string>=Object.fromEntries((draw?.entrants||[]).map((p:any)=>[p.id,p.name]))
 const count=match?.bestOf||3,grid={gridTemplateColumns:'minmax(150px,1fr) repeat('+(count+2)+', minmax(44px,70px))'}
 const playable=draw?.coachingEnabled&&match?.managed&&match.status==='live'&&match.coachingMode!=='auto'
 return <GameLayout title="Project Ace" subtitle="Isolated database review">
 <section><h2>Private tournament</h2><p>No official career effects. {draw?.coachingEnabled?'Private coaching enabled.':'Read-only review.'}</p>
 {error&&<p role="alert">{error}</p>}{notice&&<p role="status">{notice}</p>}
 {!draw&&!error&&<p role="status">Connecting to review worker…</p>}
 {draw&&<><p>Revision {draw.revision} · {draw.phase} · {draw.results.length} matches completed</p><p>Private balance: ${draw.career.balance} · Published points: {draw.career.points}</p>
 {(draw.career.healthNotices||[]).map((n:any)=><article key={n.key}><strong>Medical walkover</strong><p>{n.advanced?'You advanced under the double-unavailability rule.':'You were medically unavailable and the opponent advanced.'}</p></article>)}
 <h3>Draw and schedule</h3>{draw.matches.some((m:any)=>m.players.includes(draw.managedPlayer)&&m.status!=='completed')&&<button type="button" onClick={()=>select(draw.matches.find((m:any)=>m.players.includes(draw.managedPlayer)&&m.status!=='completed').id)}>Go to my next match</button>}
 {draw.matches.map((m:any)=><p key={m.id}><button type="button" aria-pressed={selected===m.id} onClick={()=>select(m.id)}>{m.players.map((id:string)=>names[id]).join(' vs ')} · {m.completionReason==='health_walkover'?'W/O':m.status}{m.players.includes(draw.managedPlayer)?' · Your match':''}</button>{m.winner&&' · Winner: '+names[m.winner]}</p>)}
 {match&&<section><h3>{match.players.map((p:any)=>p.name).join(' vs ')}</h3><p>{match.managed?'Your review match':'Spectating'} · {match.status}</p>
 {match.completionReason==='health_walkover'?<article><h4>Medical walkover (W/O)</h4><p>Winner: {match.players[match.winner]?.name}</p><p>No match was played. No playing statistics or coaching are available.</p></article>:match.status==='scheduled'?<p>Waiting for scheduled game time.</p>:<>
 <div className="tlg-replay-score-table-wrap"><div className="tlg-replay-score-table"><div className="tlg-replay-score-header" style={grid}><span>Player</span>{Array.from({length:count},(_,i)=><span key={i}>Set {i+1}</span>)}<span>Games</span><span>Point</span></div>{match.players.map((p:any,i:number)=><div key={i} className="tlg-replay-score-row" style={grid}><strong>{p.name}{match.server===i?' · Serving':''}</strong>{Array.from({length:count},(_,n)=><span key={n}>{match.completedSets[n]?.games[i]??'—'}</span>)}<span>{match.status==='completed'?'—':match.games[i]}</span><span>{match.status==='completed'?'—':point(match.points[i],match.points[1-i],match.tiebreak)}</span></div>)}</div></div>
 <h4>Player conditions</h4>{match.players.map((p:any,i:number)=><article key={i}><strong>{p.name}</strong>{['energy','fatigue','focus','confidence','movement','serve','rally','momentum'].map(k=><p key={k}>{k} <progress max={100} value={p[k]}/> {Math.round(p[k])}</p>)}</article>)}
 <h4>Statistics</h4>{match.stats.map((p:any,i:number)=><p key={i}>{match.players[i].name}: {p.points} points · {p.aces} aces · {p.doubleFaults} double faults · {p.unforcedErrors} unforced errors</p>)}
 <h4>Live coaching</h4>{playable?<><p>Next coaching game: {match.nextCoachingGame}</p><p>Active: {Object.entries(match.activeTactics||{}).map(([k,v])=>(labels[k]||k)+': '+v).join(' · ')}</p>{match.ownPending&&<p>Queued: {Object.values(match.ownPending).join(' · ')}</p>}
 {(match.recommendations||[]).map((a:any)=><article key={a.title}><strong>{a.title}</strong><p>{a.reason}</p><button type="button" disabled={busy} onClick={()=>{setDirty(true);setDraft(v=>({...v,...a.patch}))}}>Use suggestion</button></article>)}
 <form onSubmit={e=>{e.preventDefault();void coach()}}>{Object.entries(choices).map(([k,opts])=><label key={k}>{labels[k]} <select aria-label={labels[k]} value={draft[k]} disabled={busy} onChange={e=>{setDirty(true);setDraft(v=>({...v,[k]:e.target.value}))}}>{opts.map(v=><option key={v}>{v}</option>)}</select></label>)}<button disabled={busy}>Send next-game instructions</button></form></>:<p>Coaching unavailable for this match or mode.</p>}</>}
 </section>}</>}
 </section></GameLayout>
}
