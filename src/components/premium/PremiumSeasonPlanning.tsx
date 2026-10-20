import { useEffect, useMemo, useState } from 'react'
import { CalendarRange, ChevronDown, ChevronUp, Crown, LockKeyhole, AlertTriangle, Check, ExternalLink } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'
import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { seasonPlanningLabels } from '../../lib/seasonPlanningI18n'
import '../../styles/season-planning-premium.css'

type Stage = 'winner' | 'runner_up' | 'quarterfinal'
type SeasonEvent = {
  competition_id: string
  name: string
  city: string
  country_code: string
  category_code: string
  category_label: string
  surface: string
  start_week: number
  end_week: number
  start_day: number
  status: string
  winner_points: number
  finalist_points: number | null
  quarterfinal_points: number | null
  prize_pool_usd: number | null
  winner_prize_usd: number | null
  finalist_prize_usd: number | null
  quarterfinal_prize_usd: number | null
  planned_stage: Stage | null
  planned_priority: number | null
  accepted_entry: boolean
  pending_entry: boolean
  accepted_week_conflict: boolean
  pending_week_conflict: boolean
}
type SeasonReport = {
  player_id: string
  world: string
  season: number
  today_absolute_day: number
  tournament_count: number
  tournaments: SeasonEvent[]
  limit: number
}
const stages: Stage[] = ['quarterfinal','runner_up','winner']
const stagePoints = (t: SeasonEvent,stage: Stage) =>
  stage==='winner'?t.winner_points:stage==='runner_up'?t.finalist_points:t.quarterfinal_points
const stagePrize = (t: SeasonEvent,stage: Stage) =>
  stage==='winner'?t.winner_prize_usd:stage==='runner_up'?t.finalist_prize_usd:t.quarterfinal_prize_usd
const overlap = (a: SeasonEvent,b: SeasonEvent) =>
  a.start_week<=b.end_week && b.start_week<=a.end_week
const nextWeek = (today: number) => {
  const day = today % 366
  return day<2?1:Math.max(1,Math.min(52,Math.floor((day-2)/7)+1))
}

export default function PremiumSeasonPlanning({ playerId, season, clockLoading }: {
  playerId:string|null
  season:number
  clockLoading:boolean
}) {
  const { t, i18n } = useTranslation()
  const l=seasonPlanningLabels(i18n.resolvedLanguage ?? i18n.language)
  const { isPremium, loading: entitlementLoading } = useCommerce()
  const [expanded,setExpanded]=useState(false)
  const [report,setReport]=useState<SeasonReport|null>(null)
  const [loading,setLoading]=useState(false)
  const [error,setError]=useState('')
  const [saving,setSaving]=useState('')
  const [selectedWeek,setSelectedWeek]=useState(1)
  const [surface,setSurface]=useState('all')
  const [category,setCategory]=useState('all')
  const [search,setSearch]=useState('')

  useEffect(()=>{
    let cancelled=false
    setReport(null)
    setError('')
    if(!expanded || !isPremium || entitlementLoading || clockLoading || !playerId){
      setLoading(false)
      return ()=>{cancelled=true}
    }
    setLoading(true)
    void supabase.rpc('get_premium_season_planning_v1',{p_player_id:playerId})
      .then(({data,error:rpcError})=>{
        if(cancelled)return
        const fresh=data as SeasonReport|null
        if(rpcError || !fresh || fresh.player_id!==playerId || fresh.season!==season
          || !Array.isArray(fresh.tournaments)){
          setError(l.error)
        }else{
          setReport(fresh)
          setSelectedWeek(nextWeek(fresh.today_absolute_day))
        }
        setLoading(false)
      }).catch(()=>{if(!cancelled){setError(l.error);setLoading(false)}})
    return ()=>{cancelled=true}
  },[expanded,isPremium,entitlementLoading,clockLoading,playerId,season])

  const validReport=report?.player_id===playerId && report?.season===season ? report:null
  const events=useMemo(()=>validReport?.tournaments??[],[validReport])
  const planned=useMemo(()=>events.filter(x=>x.planned_stage!==null),[events])
  const collisionIds=useMemo(()=>new Set(planned.filter((event,i)=>
    planned.some((other,j)=>i!==j && overlap(event,other)))
    .map(event=>event.competition_id)),[planned])
  const weeks=useMemo(()=>Array.from({length:52},(_,i)=>{
    const week=i+1
    return {week,events:events.filter(e=>e.start_week<=week&&e.end_week>=week)}
  }),[events])
  const categories=useMemo(()=>[...new Set(events.map(e=>e.category_code))].sort(),[events])
  const surfaces=useMemo(()=>[...new Set(events.map(e=>e.surface))].sort(),[events])
  const list=useMemo(()=>events.filter(event=>
    event.start_week<=selectedWeek&&event.end_week>=selectedWeek
    &&(surface==='all'||event.surface===surface)
    &&(category==='all'||event.category_code===category)
    &&(!search||`${event.name} ${event.city} ${event.category_label}`.toLowerCase().includes(search.toLowerCase().trim())))
    .sort((a,b)=>b.winner_points-a.winner_points||a.name.localeCompare(b.name)),
    [events,selectedWeek,surface,category,search])
  const grossPoints=planned.reduce((sum,event)=>sum+(stagePoints(event,event.planned_stage as Stage)??0),0)
  const grossPrize=planned.reduce((sum,event)=>sum+(stagePrize(event,event.planned_stage as Stage)??0),0)
  const currency=(n:number|null)=>n===null?'—':new Intl.NumberFormat(i18n.language??'en',{
    style:'currency',currency:'USD',maximumFractionDigits:0,
  }).format(n)
  const formatWeek=(item:SeasonEvent)=>item.start_week===item.end_week
    ?String(item.start_week):`${item.start_week}–${item.end_week}`
  const stageLabel=(stage:Stage)=>l[stage]

  async function persist(item:SeasonEvent,stage:Stage|null,priority:number) {
    if(saving||!playerId||!validReport)return
    setSaving(item.competition_id)
    setError('')
    try {
      const result=await supabase.rpc('save_premium_season_target_v1',{
        p_player_id:playerId,p_competition_id:item.competition_id,
        p_stage:stage??'quarterfinal',p_priority:priority,p_remove:stage===null,
      })
      if(result.error)throw result.error
      const fresh=await supabase.rpc('get_premium_season_planning_v1',{p_player_id:playerId})
      if(fresh.error || !fresh.data)throw fresh.error??new Error(l.saveError)
      const newReport=fresh.data as SeasonReport
      if(newReport.player_id!==playerId||newReport.season!==season)throw new Error(l.saveError)
      setReport(newReport)
    } catch {
      setError(l.saveError)
    } finally {
      setSaving('')
    }
  }

  const control=(item:SeasonEvent)=> {
    const selected=!!item.planned_stage
    const locked=item.start_day<=(validReport?.today_absolute_day??0)
    const priority=item.planned_priority??2
    const availableStages=stages.filter(stage=>stagePoints(item,stage)!==null)
    return <div className="tlg-sp-controls">
      {selected&&<label>{l.targetStage}
        <select disabled={!!saving||locked}
          value={item.planned_stage??'quarterfinal'}
          onChange={ev=>void persist(item,ev.target.value as Stage,priority)}>
          {availableStages.map(stage=><option key={stage} value={stage}>{stageLabel(stage)}</option>)}
        </select>
      </label>}
      {selected&&<label>{l.priority}
        <select disabled={!!saving||locked}
          value={priority}
          onChange={ev=>void persist(item,item.planned_stage,Number(ev.target.value))}>
          <option value="1">{l.high}</option>
          <option value="2">{l.medium}</option>
          <option value="3">{l.low}</option>
        </select>
      </label>}
      <button type="button" disabled={!!saving || (!selected&&locked) ||
        (!selected&&planned.length>=(validReport?.limit??20))}
        onClick={()=>void persist(item,selected?null:availableStages[0]??'winner',priority)}>
        {saving===item.competition_id?l.saving:selected?l.remove:l.add}
      </button>
    </div>
  }

  return <section className="tlg-sp" aria-label={l.title}>
    <header className="tlg-sp-head">
      <div>
        <span className="tlg-sp-kicker"><Crown size={14} aria-hidden="true"/>{l.kicker}</span>
        <h3>{l.title}</h3>
        <p>{l.intro}</p>
      </div>
      <button type="button" className="tlg-sp-toggle"
        aria-expanded={expanded} aria-controls="tlg-sp-content"
        onClick={()=>setExpanded(v=>!v)}>
        {expanded?l.hide:l.show}
        {expanded?<ChevronUp size={16}/>:<ChevronDown size={16}/>}
      </button>
    </header>
    <div id="tlg-sp-content" hidden={!expanded}>
      {expanded&&(clockLoading||entitlementLoading||loading
        ?<p className="tlg-sp-message">{l.loading}</p>
        :!isPremium?<div className="tlg-sp-locked">
          <LockKeyhole size={21} aria-hidden="true"/>
          <p>{l.locked}</p><Link to="/game/pro-packages">{l.upgrade}</Link>
        </div>
        :!validReport?<p className="tlg-sp-message" role="alert">{error||l.error}</p>
        :<div className="tlg-sp-body">
          <div className="tlg-sp-metrics">
            <div><span>{l.season}</span><strong>{season} · {validReport.world}</strong></div>
            <div><span>{l.planCount}</span><strong>{planned.length}/{validReport.limit}</strong></div>
            <div><span>{l.scenarioPoints}</span><strong>{grossPoints.toLocaleString()}</strong></div>
            <div><span>{l.scenarioPrize}</span><strong>{currency(grossPrize)}</strong></div>
            <div><span>{l.conflicts}</span><strong>{collisionIds.size}</strong></div>
          </div>
          <p className="tlg-sp-disclaimer">{l.disclaimer}</p>
          {collisionIds.size>0&&<p className="tlg-sp-warning"><AlertTriangle size={15}/>{l.planWarning}</p>}
          {error&&<p className="tlg-sp-warning" role="alert">{error}</p>}
          <div className="tlg-sp-section-head">
            <h4><CalendarRange size={17} aria-hidden="true"/>{l.weeks}</h4>
            <span>{l.season} {season}</span>
          </div>
          <div className="tlg-sp-weeks" aria-label={l.weeks}>
            {weeks.map(({week,events:weekEvents})=>{
              const count=weekEvents.filter(e=>e.planned_stage!==null).length
              const active=week===selectedWeek
              const current=week===nextWeek(validReport.today_absolute_day)
              return <button key={week} type="button"
                aria-pressed={active}
                title={`${l.weekPrefix} ${week} · ${weekEvents.length} ${l.eventCount}`}
                className={`tlg-sp-week${active?' selected':''}${count?' planned':''}${current?' current':''}`}
                onClick={()=>setSelectedWeek(week)}>
                <strong>{week}</strong>
                {count>0&&<span className="tlg-sp-week-count">{count}</span>}
              </button>
            })}
          </div>
          <div className="tlg-sp-section-head">
            <h4>{l.plannedTargets}</h4>
            <span>{planned.length}/{validReport.limit}</span>
          </div>
          {planned.length===0?<p className="tlg-sp-empty">{l.empty}</p>
          :<div className="tlg-sp-targets">
            {[...planned].sort((a,b)=>(a.planned_priority??2)-(b.planned_priority??2)||a.start_week-b.start_week).map(item=>
              <article className="tlg-sp-target" key={item.competition_id}>
                <div>
                  <strong>{item.name}</strong>
                  <small>{l.weekPrefix} {formatWeek(item)} · {item.category_label} · {item.surface}</small>
                  <span>{stageLabel(item.planned_stage as Stage)}:
                    {' '}{stagePoints(item,item.planned_stage as Stage)??'—'} {l.rewardPoints.toLowerCase()}
                    {' · '}{currency(stagePrize(item,item.planned_stage as Stage))}
                  </span>
                  {(collisionIds.has(item.competition_id)||item.accepted_week_conflict||item.pending_week_conflict)&&
                    <small className="tlg-sp-conflict">{l.clash}</small>}
                </div>
                {control(item)}
              </article>)}
          </div>}
          <div className="tlg-sp-section-head">
            <h4>{l.candidateList} — {l.weekPrefix} {selectedWeek}</h4>
            <span>{list.length} {l.eventCount.toLowerCase()}</span>
          </div>
          <div className="tlg-sp-filters">
            <label>{l.search}
              <input value={search} onChange={ev=>setSearch(ev.target.value)}
                placeholder={l.tournament}/>
            </label>
            <label>{l.filterSurface}
              <select value={surface} onChange={ev=>setSurface(ev.target.value)}>
                <option value="all">{l.allSurfaces}</option>
                {surfaces.map(item=><option key={item} value={item}>{item}</option>)}
              </select>
            </label>
            <label>{l.filterCategory}
              <select value={category} onChange={ev=>setCategory(ev.target.value)}>
                <option value="all">{l.allCategories}</option>
                {categories.map(item=><option key={item} value={item}>{item}</option>)}
              </select>
            </label>
          </div>
          {list.length===0?<p className="tlg-sp-empty">{l.noCandidates}</p>
          :<div className="tlg-sp-candidates">
            {list.map(item=><article key={item.competition_id}>
              <div className="tlg-sp-event-main">
                <strong>{item.name}</strong>
                <small>{item.city} · {item.category_label} · {item.surface} · {l.weekPrefix} {formatWeek(item)}</small>
                <span>{l.winner} {item.winner_points} {l.rewardPoints.toLowerCase()}
                  {' · '}{currency(item.winner_prize_usd)}
                </span>
                <div className="tlg-sp-tags">
                  {item.accepted_entry&&<span><Check size={12}/>{l.accepted}</span>}
                  {item.pending_entry&&<span>{l.pending}</span>}
                  {(item.accepted_week_conflict||item.pending_week_conflict)&&
                    <span className="warn">{l.clash}</span>}
                  {item.start_day<=validReport.today_absolute_day&&<span>{l.past}</span>}
                </div>
              </div>
              <div className="tlg-sp-actions">
                <Link to={`/game/tournaments/${item.competition_id}`}>
                  {l.open}<ExternalLink size={13} aria-hidden="true"/></Link>
                {control(item)}
              </div>
            </article>)}
          </div>}
          <p className="tlg-sp-disclaimer">{l.netDisclaimer}</p>
        </div>)}
    </div>
  </section>
}
