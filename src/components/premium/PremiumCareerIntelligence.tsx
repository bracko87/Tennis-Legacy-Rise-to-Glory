import { useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronUp, Crown, LockKeyhole, TrendingUp, Flag, Award } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { careerIntelligenceLabels } from '../../lib/careerIntelligenceI18n'
import '../../styles/career-intelligence-premium.css'

type RankingWeek={
  season:number
  game_week:number
  absolute_day:number
  rank:number
  points:number
}
type Season={
  season:number
  matches:number
  wins:number
  losses:number
  win_pct:number|null
  finals:number
  competitions:number
  confirmed_titles:number
  best_rank:number|null
  peak_ranking_points:number|null
  recorded_prize_usd:number
  win_rate_change_pp:number|null
  best_rank_change:number|null
}
type Surface={
  season:number
  surface:string
  matches:number
  wins:number
  losses:number
  win_pct:number|null
}
type Milestone={
  kind:'first_match'|'first_win'|'first_final'|'first_title'|
    'top_100'|'top_50'|'top_10'|'world_no_1'
  season:number
  game_week:number|null
  name?:string
  rank?:number
}
type CareerReport={
  player_id:string
  world:string
  current_season:number
  current_absolute_day:number
  season_count:number
  seasons:Season[]
  surfaces_by_season:Surface[]
  ranking_weeks:RankingWeek[]
  milestones:Milestone[]
}
type ChartMetric='rank'|'points'

function recentWeeks(gameDay:number):{season:number;week:number;id:number}[] {
  // 52 scheduled tennis weeks within each 366-day game season.
  // Weeks before season 1 are not fabricated.
  const season=Math.floor(gameDay/366)+1
  const week=Math.max(1,Math.min(52,Math.floor((gameDay%366-1)/7)+1))
  const last=(season-1)*52+week
  return Array.from({length:24},(_,i)=>last-23+i)
    .filter(ordinal=>ordinal>=1)
    .map(ordinal=>({
      season:Math.floor((ordinal-1)/52)+1,
      week:(ordinal-1)%52+1,
      id:ordinal,
    }))
}

export default function PremiumCareerIntelligence({
  playerId,currentSeason,currentAbsoluteDay,
}:{
  playerId:string|null
  currentSeason:number
  currentAbsoluteDay:number
}) {
  const {i18n}=useTranslation()
  const copy=careerIntelligenceLabels(i18n.resolvedLanguage??i18n.language)
  const {isPremium,loading:checkingPremium}=useCommerce()
  const [expanded,setExpanded]=useState(false)
  const [report,setReport]=useState<CareerReport|null>(null)
  const [loading,setLoading]=useState(false)
  const [error,setError]=useState(false)
  const [metric,setMetric]=useState<ChartMetric>('rank')

  useEffect(()=>{
    let cancelled=false
    setReport(null)
    setError(false)
    if(!expanded||!isPremium||checkingPremium||!playerId){
      setLoading(false)
      return ()=>{cancelled=true}
    }
    setLoading(true)
    void supabase.rpc('get_premium_career_intelligence_v1',{p_player_id:playerId})
      .then(({data,error:rpcError})=>{
        if(cancelled)return
        const result=data as CareerReport|null
        if(rpcError||!result||result.player_id!==playerId
          ||result.current_season!==currentSeason
          ||result.current_absolute_day!==currentAbsoluteDay
          ||!Array.isArray(result.ranking_weeks)
          ||!Array.isArray(result.seasons)
          ||!Array.isArray(result.surfaces_by_season)
          ||!Array.isArray(result.milestones)){
          setError(true)
        }else setReport(result)
        setLoading(false)
      }).catch(()=>{if(!cancelled){setError(true);setLoading(false)}})
    return ()=>{cancelled=true}
  },[expanded,isPremium,checkingPremium,playerId,currentSeason,currentAbsoluteDay])

  const current=report?.player_id===playerId
    &&report.current_season===currentSeason
    &&report.current_absolute_day===currentAbsoluteDay?report:null
  const fmt=(v:number)=>new Intl.NumberFormat(i18n.language??'en',{maximumFractionDigits:1}).format(v)
  const usd=(v:number)=>new Intl.NumberFormat(i18n.language??'en',{
    style:'currency',currency:'USD',maximumFractionDigits:0,
  }).format(v)
  const weeks=useMemo(()=>recentWeeks(currentAbsoluteDay),[currentAbsoluteDay])
  const history=new Map((current?.ranking_weeks??[])
    .map(x=>[(x.season-1)*52+x.game_week,x] as const))
  const observations=weeks.map(week=>({
    ...week,record:history.get(week.id),
  }))
  const values=observations.filter(x=>x.record).map(x=>
    metric==='rank'?x.record!.rank:x.record!.points)
  const min=Math.min(...values),max=Math.max(...values)
  const range=Math.max(1,max-min)
  const width=Math.max(760,weeks.length*40+70)
  const height=225,padLeft=43,padRight=20,top=22,bottom=43
  const x=(i:number)=>padLeft+i*(width-padLeft-padRight)/Math.max(1,weeks.length-1)
  const y=(v:number)=>{
    const percent=(v-min)/range
    return top+(metric==='rank'?percent:1-percent)*(height-top-bottom)
  }
  const chartSegments=observations.reduce<{path:string;key:number}[]>((segments,point,i)=>{
    if(!point.record)return segments
    const coord=`${x(i)},${y(metric==='rank'?point.record.rank:point.record.points)}`
    if(i>0&&observations[i-1].record&&segments.length){
      segments[segments.length-1].path+=` ${coord}`
    }else{
      segments.push({path:coord,key:i})
    }
    return segments
  },[])
  const bySurface=useMemo(()=>{
    const grouped=new Map<number,Surface[]>()
    for(const s of current?.surfaces_by_season??[]){
      grouped.set(s.season,[...(grouped.get(s.season)??[]),s])
    }
    return [...grouped.entries()].sort((a,b)=>b[0]-a[0])
  },[current])
  const seasonOrder=[...(current?.seasons??[])].sort((a,b)=>b.season-a.season)
  const rankMilestone=new Set(['top_100','top_50','top_10','world_no_1'])
  const showRank=(r:number|null)=>r===null?'—':`#${fmt(r)}`
  const change=(x:number|null,unit:string)=>{
    if(x===null)return copy.noPrior
    return `${x>0?'+':''}${fmt(x)} ${unit}`
  }
  return <section className="tlg-ci" aria-label={copy.title}>
    <header className="tlg-ci-head">
      <div>
        <span className="tlg-ci-kicker"><Crown size={15} aria-hidden="true"/>{copy.kicker}</span>
        <h2>{copy.title}</h2><p>{copy.intro}</p>
      </div>
      <button className="tlg-ci-toggle" type="button" aria-expanded={expanded}
        aria-controls="tlg-ci-content" onClick={()=>setExpanded(v=>!v)}>
        {expanded?copy.hide:copy.show}
        {expanded?<ChevronUp size={16} aria-hidden="true"/>:<ChevronDown size={16} aria-hidden="true"/>}
      </button>
    </header>
    <div id="tlg-ci-content" hidden={!expanded}>
      {expanded&&(checkingPremium||loading
        ?<p className="tlg-ci-state">{copy.loading}</p>
        :!isPremium?<div className="tlg-ci-locked">
          <LockKeyhole size={20} aria-hidden="true"/><p>{copy.locked}</p>
          <Link to="/game/pro-packages">{copy.upgrade}</Link>
        </div>
        :error||!current?<p className="tlg-ci-state" role="alert">{copy.error}</p>
        :<div className="tlg-ci-body">
          <section className="tlg-ci-panel">
            <header className="tlg-ci-section-head">
              <div><h3><TrendingUp size={18}/>{copy.ranking}</h3>
                <p>{copy.rankingIntro}</p></div>
              <div className="tlg-ci-choice" role="group" aria-label={copy.ranking}>
                <button type="button" aria-pressed={metric==='rank'} className={metric==='rank'?'active':''}
                  onClick={()=>setMetric('rank')}>{copy.rank}</button>
                <button type="button" aria-pressed={metric==='points'} className={metric==='points'?'active':''}
                  onClick={()=>setMetric('points')}>{copy.points}</button>
              </div>
            </header>
            {values.length===0?<p className="tlg-ci-note">{copy.noRank}</p>
              :<div className="tlg-ci-graph-scroll">
                <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}
                  role="img" aria-label={copy.ranking}>
                  {observations.map((week,i)=><g key={week.id}>
                    <line x1={x(i)} y1={top} x2={x(i)} y2={height-bottom}
                      stroke="#dfebf2" strokeWidth="1"/>
                    {(i%2===0||i===observations.length-1)&&<text
                      x={x(i)} y={height-18} textAnchor="middle" className="tlg-ci-svgtext">
                      {week.week}
                    </text>}
                    {(i===0||i>0&&observations[i-1].season!==week.season)&&<text
                      x={x(i)+2} y={height-3} textAnchor="start" className="tlg-ci-svgseason">
                      {copy.season} {week.season}
                    </text>}
                  </g>)}
                  <line x1={padLeft} x2={width-padRight} y1={height-bottom}
                    y2={height-bottom} stroke="#aec6d7"/>
                  {chartSegments.map(segment=><polyline key={segment.key}
                    fill="none" points={segment.path} stroke="#2d7eae"
                    strokeWidth={2.6} strokeLinejoin="round" strokeLinecap="round"/>)}
                  {observations.map((point,i)=>point.record&&<circle key={point.id}
                    cx={x(i)} cy={y(metric==='rank'?point.record.rank:point.record.points)}
                    r={4} fill="#2473a4" stroke="#fff" strokeWidth="1.5">
                    <title>{`${copy.season} ${point.season}, ${copy.week} ${point.week}: ${copy.rank} #${point.record.rank}, ${copy.points} ${point.record.points}`}</title>
                  </circle>)}
                </svg>
              </div>}
          </section>
          <section className="tlg-ci-panel">
            <header className="tlg-ci-section-head">
              <div><h3><Flag size={18}/>{copy.seasons}</h3><p>{copy.seasonNotes}</p></div>
            </header>
            {seasonOrder.length<=1&&<p className="tlg-ci-info">{copy.currentSeasonOnly}</p>}
            {seasonOrder.length===0?<p className="tlg-ci-note">{copy.noPrior}</p>:<>
              <div className="tlg-ci-season-grid">
                {seasonOrder.map(s=><article key={s.season}>
                  <strong>{copy.season} {s.season}</strong>
                  <div><span>{copy.winRate}</span><b>{s.matches>0&&s.win_pct!==null?`${fmt(s.win_pct)}%`:'—'}</b></div>
                  <div><span>{copy.winRateChange}</span>
                    <b>{s.matches>0?change(s.win_rate_change_pp,'pp'):copy.noPrior}</b></div>
                  <div><span>{copy.best}</span><b>{showRank(s.best_rank)}</b></div>
                  <div><span>{copy.rankingChange}</span><b>{change(s.best_rank_change,'')}</b></div>
                  <div><span>{copy.recordsTitle}</span>
                    <b>{fmt(s.wins)} / {fmt(s.matches)} · {fmt(s.confirmed_titles)} {copy.titleCount.toLowerCase()}</b></div>
                  <div><span>{copy.recordedPrize}</span><b>{usd(s.recorded_prize_usd)}</b></div>
                </article>)}
              </div>
            </>}
          </section>
          <section className="tlg-ci-panel">
            <header className="tlg-ci-section-head">
              <div><h3>{copy.surface}</h3><p>{copy.surfaceIntro}</p></div>
            </header>
            {bySurface.length===0?<p className="tlg-ci-note">{copy.noSurface}</p>
              :<div className="tlg-ci-surfaces">
                {bySurface.map(([season,items])=><div key={season} className="tlg-ci-surface-season">
                  <strong>{copy.season} {season}</strong>
                  <div className="tlg-ci-surface-row">
                    {['hard','clay','grass'].map(surface=>{
                      const value=items.find(item=>item.surface.toLowerCase()===surface)
                      return <div key={surface}>
                        <span>{copy[surface as 'hard'|'clay'|'grass']}</span>
                        <b>{value?.matches? `${fmt(value.win_pct??0)}%`:'—'}</b>
                        <small>{value? `${value.wins}–${value.losses}`:'—'}</small>
                      </div>
                    })}
                  </div>
                </div>)}
              </div>}
          </section>
          <section className="tlg-ci-panel">
            <header className="tlg-ci-section-head">
              <div><h3><Award size={18}/>{copy.firsts}</h3>
                <p>{copy.milestoneObserved}</p></div>
            </header>
            {current.milestones.length===0?<p className="tlg-ci-note">{copy.noMilestones}</p>
              :<div className="tlg-ci-milestones">
                {current.milestones.map(item=><article key={item.kind}>
                  <strong>{copy[item.kind]}</strong>
                  <span>{copy.season} {item.season}
                    {item.game_week!==null?` · ${copy.week} ${item.game_week}`:''}</span>
                  {item.name&&<small>{item.name}</small>}
                  {rankMilestone.has(item.kind)&&item.rank&&<small>{copy.rank} #{item.rank}</small>}
                </article>)}
              </div>}
          </section>
          <p className="tlg-ci-note">{copy.method}</p>
        </div>)}
    </div>
  </section>
}
