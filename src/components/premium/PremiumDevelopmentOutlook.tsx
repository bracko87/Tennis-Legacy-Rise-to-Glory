import { useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronUp, Crown, LockKeyhole, TrendingUp } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { developmentOutlookLabels } from '../../lib/developmentOutlookI18n'
import '../../styles/development-outlook-premium.css'

type SkillKey =
  | 'serve' | 'forehand' | 'backhand' | 'return_skill' | 'volley'
  | 'slice' | 'drop_shot' | 'lob' | 'smash'
  | 'fitness' | 'stamina' | 'recovery' | 'movement'

const technical: SkillKey[] = [
  'serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash',
]
const physical: SkillKey[] = ['fitness','stamina','recovery','movement']
const allSkills: SkillKey[] = [...technical,...physical]

type Session = {
  id: string
  season: number
  game_week: number
  gains: Record<string,number>
  level_ups: Record<string,number>
  efficiency: number | null
  progress_total: number
}
type TrainingReport = {
  player_id: string
  events: Session[]
  window_limited: boolean
  total_events: number
  whole_level_ups: number
}
type Snapshot = {
  game_season: number|null
  game_week: number|null
} & Record<SkillKey,number>
type HistoryReport = {
  player_id: string
  history: Snapshot[]
  window_limited: boolean
}

function value(value: unknown): number {
  return typeof value==='number' && Number.isFinite(value) ? value : 0
}
function average(snapshot: Snapshot,keys:SkillKey[]) {
  return keys.reduce((sum,k)=>sum+value(snapshot[k]),0)/keys.length
}

export default function PremiumDevelopmentOutlook({playerId}:{playerId:string|null}) {
  const {t,i18n}=useTranslation()
  const l=developmentOutlookLabels(i18n.resolvedLanguage ?? i18n.language)
  const {isPremium,loading:premiumLoading}=useCommerce()
  const [expanded,setExpanded]=useState(false)
  const [loading,setLoading]=useState(false)
  const [error,setError]=useState(false)
  const [training,setTraining]=useState<TrainingReport|null>(null)
  const [history,setHistory]=useState<HistoryReport|null>(null)

  useEffect(()=>{
    let cancelled=false
    setTraining(null)
    setHistory(null)
    setError(false)
    if(!expanded || !isPremium || premiumLoading || !playerId){
      setLoading(false)
      return ()=>{cancelled=true}
    }
    setLoading(true)
    void Promise.all([
      supabase.rpc('get_premium_training_effectiveness_v1',{p_player_id:playerId}),
      supabase.rpc('get_premium_player_development_v1',{p_player_id:playerId}),
    ]).then(([trainingResult,historyResult])=>{
      if(cancelled)return
      const tr=trainingResult.data as TrainingReport|null
      const hr=historyResult.data as HistoryReport|null
      if(trainingResult.error || historyResult.error || !tr || !hr ||
         tr.player_id!==playerId || hr.player_id!==playerId){
        setError(true)
      } else {
        setTraining(tr)
        setHistory(hr)
      }
      setLoading(false)
    }).catch(()=>{
      if(!cancelled){setError(true);setLoading(false)}
    })
    return ()=>{cancelled=true}
  },[expanded,isPremium,premiumLoading,playerId])

  const analysis=useMemo(()=>{
    if(!training || !history) return null
    const sessions=training.events ?? []
    const totals=new Map<SkillKey,number>()
    for(const key of allSkills)totals.set(key,0)
    for(const event of sessions){
      for(const key of allSkills){
        totals.set(key,(totals.get(key) ?? 0)+value(event.gains?.[key]))
      }
    }
    const ranking=allSkills.map(key=>({key,gain:totals.get(key)??0}))
      .filter(row=>row.gain>0)
      .sort((a,b)=>b.gain-a.gain || a.key.localeCompare(b.key))
    const technicalGain=technical.reduce((sum,k)=>sum+(totals.get(k)??0),0)
    const physicalGain=physical.reduce((sum,k)=>sum+(totals.get(k)??0),0)

    // Session-to-session comparison: two equal-sized groups of four to six
    // completed sessions. We deliberately do not project a future rate.
    const gameWeeks=new Set(sessions.map(s=>`${s.season}:${s.game_week}`))
    const trendAvailable=sessions.length>=8 && gameWeeks.size>=3
    const sampleSize=Math.min(6,Math.floor(sessions.length/2))
    const first=trendAvailable?sessions.slice(0,sampleSize):[]
    const older=trendAvailable?sessions.slice(sampleSize,sampleSize*2):[]
    const mean=(events:Session[])=>events.length
      ? events.reduce((sum,e)=>sum+value(e.progress_total),0)/events.length:0
    const recent=mean(first)
    const previous=mean(older)
    const trend=(!trendAvailable || previous<=0) ? null
      : recent>previous*1.08 ? 'higher'
      : recent<previous*0.92 ? 'lower' : 'similar'

    // Only verified game-week snapshots are used. Multiple condition-only
    // changes in the same week are reduced to the last stored snapshot.
    const byWeek=new Map<string,Snapshot>()
    for(const row of history.history ?? []){
      if(!Number.isInteger(row.game_season) || !Number.isInteger(row.game_week))continue
      if((row.game_season ?? 0)<1 || (row.game_week ?? -1)<0 || (row.game_week ?? 99)>52)continue
      byWeek.set(`${row.game_season}:${row.game_week}`,row)
    }
    const dated=[...byWeek.values()].sort((a,b)=>
      (a.game_season??0)-(b.game_season??0) || (a.game_week??0)-(b.game_week??0))
    const from=dated[0],to=dated[dated.length-1]
    const hasHistory=dated.length>=2 && (from.game_season!==to.game_season || from.game_week!==to.game_week)
    const technicalChange=hasHistory ? average(to,technical)-average(from,technical):null
    const physicalChange=hasHistory ? average(to,physical)-average(from,physical):null

    // A modest focus suggestion ONLY if a skill snapshot and multiple
    // completed sessions exist. Lowest rating among skills with actual
    // recorded training, not a claim about future potential or causation.
    const trained=ranking.filter(r=>r.gain>0)
    const lowestRated=to && sessions.length>=4 && trained.length
      ? [...trained].sort((a,b)=>value(to[a.key])-value(to[b.key]))[0] : null
    return {
      sessions:sessions.length,top:ranking[0]??null,
      bottom:ranking.length>1?ranking[ranking.length-1]:null,
      technicalGain,physicalGain,trend,trendAvailable,
      recent,previous,efficiency:first.length
        ? first.reduce((s,e)=>s+value(e.efficiency),0)/first.length
        : sessions.length ? sessions.slice(0,6).reduce((s,e)=>s+value(e.efficiency),0)/Math.min(6,sessions.length)
        : null,
      technicalChange,physicalChange,hasHistory,lowestRated,
      latestWeek:to?{season:to.game_season,week:to.game_week}:null,
    }
  },[training,history])

  const skillLabel=(key:SkillKey)=>t('developmentPremium.attributes.'+key)
  const signed=(n:number)=>`${n>=0?'+':''}${n.toFixed(2)}`
  const trendText=analysis?.trend==='higher'?l.higher:analysis?.trend==='lower'?l.lower:l.similar
  const balance=analysis && analysis.technicalGain+analysis.physicalGain>0
    ? analysis.technicalGain>analysis.physicalGain*1.2?l.techLead
      :analysis.physicalGain>analysis.technicalGain*1.2?l.physicalLead:l.balanced
    :null

  return (
    <section className="tlg-outlook" aria-label={l.title}>
      <header className="tlg-outlook-header">
        <div>
          <span className="tlg-outlook-kicker"><Crown size={15} aria-hidden="true" /> PREMIUM · {l.title}</span>
          <h2>{l.title}</h2>
          <p>{l.intro}</p>
        </div>
        <button type="button" className="tlg-outlook-toggle"
          aria-expanded={expanded} aria-controls="tlg-development-outlook-body"
          onClick={()=>setExpanded(open=>!open)}>
          {expanded?l.hide:l.show}
          {expanded?<ChevronUp size={16} aria-hidden="true"/>:<ChevronDown size={16} aria-hidden="true"/>}
        </button>
      </header>
      {expanded && <div id="tlg-development-outlook-body">
        {premiumLoading||loading?<p className="tlg-outlook-state">{l.loading}</p>
        :!isPremium?<div className="tlg-outlook-locked">
          <LockKeyhole size={22} aria-hidden="true"/>
          <span>{l.locked}</span>
          <Link to="/game/pro-packages">{l.viewPlans}</Link>
        </div>
        :error || !analysis?<p className="tlg-outlook-state" role="alert">{l.error}</p>
        :analysis.sessions===0?<p className="tlg-outlook-state">{l.insufficient}</p>
        :<div className="tlg-outlook-body">
          <div className="tlg-outlook-summary">
            <div><span>{l.days}</span><strong>{analysis.sessions}</strong></div>
            <div><span>{l.top}</span><strong>{analysis.top?skillLabel(analysis.top.key):'—'}</strong></div>
            <div><span>{l.lowest}</span><strong>{analysis.bottom?skillLabel(analysis.bottom.key):'—'}</strong></div>
            <div><span>{l.levels}</span><strong>{training?.whole_level_ups ?? 0}</strong></div>
          </div>
          <div className="tlg-outlook-grid">
            <article className="tlg-outlook-panel">
              <h3><TrendingUp size={17} aria-hidden="true"/>{l.focus}</h3>
              <p>{balance??l.insufficient}</p>
              <div className="tlg-outlook-pairs">
                <div><span>{l.technicalChange}</span><strong>{analysis.hasHistory && analysis.technicalChange!==null?signed(analysis.technicalChange):'—'}</strong></div>
                <div><span>{l.physicalChange}</span><strong>{analysis.hasHistory && analysis.physicalChange!==null?signed(analysis.physicalChange):'—'}</strong></div>
              </div>
              {!analysis.hasHistory&&<small>{l.notEnoughWeeks}</small>}
              {analysis.lowestRated&&<p className="tlg-outlook-advice">
                <strong>{skillLabel(analysis.lowestRated.key)}</strong> — {l.advice}
              </p>}
            </article>
            <article className="tlg-outlook-panel">
              <h3>{l.recentTrend}</h3>
              {analysis.trendAvailable&&analysis.trend?<>
                <strong className="tlg-outlook-trend">{trendText}</strong>
                <div className="tlg-outlook-pairs">
                  <div><span>{l.avgGain}</span><strong>{signed(analysis.recent)}</strong></div>
                  <div><span>{l.efficiency}</span><strong>{analysis.efficiency===null?'—':`${(analysis.efficiency*100).toFixed(1)}%`}</strong></div>
                </div>
              </>:<>
                <p>{l.notEnough}</p>
                <small>{l.trendGuard}</small>
              </>}
              {training?.whole_level_ups===0&&<p className="tlg-outlook-advice">{l.noLevels}</p>}
            </article>
          </div>
          <p className="tlg-outlook-disclaimer">{l.disclaimer}</p>
          {(training?.window_limited || history?.window_limited)&&<p className="tlg-outlook-disclaimer">{l.scope}</p>}
        </div>}
      </div>}
    </section>
  )
}
