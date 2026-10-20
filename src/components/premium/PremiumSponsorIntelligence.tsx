import { useEffect, useState } from 'react'
import { ChevronDown, ChevronUp, Crown, LockKeyhole, AlertTriangle, Wallet, Scale } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'
import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { sponsorIntelligenceLabels } from '../../lib/sponsorIntelligenceI18n'
import '../../styles/sponsor-intelligence-premium.css'

type SponsorOfferComparison = {
  id:string
  name:string
  source_pool:string
  expires_absolute_day:number
  days_until_expiry:number
  guaranteed_usd:number
  weekly_usd:number
  installments:number
  conditional_bonus_pool_usd:number
  maximum_if_all_objectives_met_usd:number
  conditional_share_percent:number
  objective_count:number
}
type ObjectiveAlert = {
  id:string
  objective_code:string
  title:string
  tournament_name:string|null
  status:'active'|'upcoming'
  current_value:number
  target_value:number
  reward_amount:number
  deadline_absolute_day:number|null
  days_to_deadline:number|null
  progress_percent:number|null
  milestone_achieved:boolean|null
}
type ActiveContract = {
  id:string
  name:string
  guaranteed_total_usd:number
  guaranteed_received_usd:number
  guaranteed_remaining_usd:number
  weekly_payment_usd:number
  scheduled_installments:number
  end_absolute_day:number
  bonus_pool_usd:number
  bonus_earned_by_objectives_usd:number
  bonus_posted_usd:number
  bonus_unresolved_usd:number
  bonus_failed_or_expired_usd:number
  objectives_total:number
  objectives_completed:number
  attention_objectives:ObjectiveAlert[]
}
type SponsorReport = {
  player_id:string
  season:number
  current_absolute_day:number
  active_contract:ActiveContract|null
  offers:SponsorOfferComparison[]
  offer_count:number
}

export default function PremiumSponsorIntelligence({
  playerId,season,refreshKey,
}:{
  playerId:string|null
  season:number
  refreshKey:string
}) {
  const {t,i18n}=useTranslation()
  const l=sponsorIntelligenceLabels(i18n.resolvedLanguage??i18n.language)
  const {isPremium,loading:checkingPremium}=useCommerce()
  const [expanded,setExpanded]=useState(false)
  const [report,setReport]=useState<SponsorReport|null>(null)
  const [loading,setLoading]=useState(false)
  const [error,setError]=useState(false)
  useEffect(()=>{
    let cancelled=false
    setReport(null)
    setError(false)
    if(!expanded||!isPremium||checkingPremium||!playerId){
      setLoading(false)
      return ()=>{cancelled=true}
    }
    setLoading(true)
    void supabase.rpc('get_premium_sponsor_intelligence_v1',{p_player_id:playerId})
      .then(({data,error:rpcError})=>{
        if(cancelled)return
        const result=data as SponsorReport|null
        if(rpcError||!result||result.player_id!==playerId||
          result.season!==season||!Array.isArray(result.offers)){
          setError(true)
        }else setReport(result)
        setLoading(false)
      }).catch(()=>{if(!cancelled){setError(true);setLoading(false)}})
    return ()=>{cancelled=true}
  },[expanded,isPremium,checkingPremium,playerId,season,refreshKey])

  const current=report?.player_id===playerId&&report.season===season?report:null
  const active=current?.active_contract??null
  const offers=current?.offers??[]
  const money=(n:number)=>new Intl.NumberFormat(i18n.language??'en',{
    style:'currency',currency:'USD',maximumFractionDigits:0,
  }).format(n)
  const objectiveStatus=(item:ObjectiveAlert)=>
    t(`financeSponsorPage.objective.status.${item.status}`,{defaultValue:item.status})
  const attention=(active?.attention_objectives??[])
    .filter(item=>item.days_to_deadline===null||item.days_to_deadline>=0)
  const closingSoon=attention.filter(item=>item.days_to_deadline!==null&&item.days_to_deadline<=28)
  const num=(n:number)=>new Intl.NumberFormat(i18n.language??'en').format(n)

  return <section className="tlg-sint" aria-label={l.title}>
    <header className="tlg-sint-head">
      <div><span className="tlg-sint-kicker"><Crown size={15} aria-hidden="true"/>{l.kicker}</span>
        <h2>{l.title}</h2><p>{l.intro}</p>
      </div>
      <button type="button" className="tlg-sint-toggle"
        aria-expanded={expanded} aria-controls="tlg-sint-content"
        onClick={()=>setExpanded(v=>!v)}>
        {expanded?l.hide:l.show}
        {expanded?<ChevronUp size={16} aria-hidden="true"/>:<ChevronDown size={16} aria-hidden="true"/>}
      </button>
    </header>
    <div id="tlg-sint-content" hidden={!expanded}>
      {expanded&&(checkingPremium||loading
        ?<p className="tlg-sint-state">{l.loading}</p>
        :!isPremium?<div className="tlg-sint-locked">
          <LockKeyhole size={22} aria-hidden="true"/><p>{l.locked}</p>
          <Link to="/game/pro-packages">{l.upgrade}</Link>
        </div>
        :error||!current?<p className="tlg-sint-state" role="alert">{l.error}</p>
        :!active&&offers.length===0?<p className="tlg-sint-state">{l.empty}</p>
        :<div className="tlg-sint-body">
          {active&&<section className="tlg-sint-block">
            <h3><Wallet size={18} aria-hidden="true"/>{l.activeTitle} · {active.name}</h3>
            <div className="tlg-sint-metrics">
              {([
                [l.guaranteed,money(active.guaranteed_total_usd)],
                [l.guaranteedReceived,money(active.guaranteed_received_usd)],
                [l.guaranteedRemaining,money(active.guaranteed_remaining_usd)],
                [l.bonusEarned,money(active.bonus_earned_by_objectives_usd)],
                [l.bonusPaid,money(active.bonus_posted_usd)],
                [l.unresolvedBonus,money(active.bonus_unresolved_usd)],
                [l.missedBonus,money(active.bonus_failed_or_expired_usd)],
                [l.completion,`${active.objectives_completed} / ${active.objectives_total}`],
              ] as [string,string][]).map(([key,val])=>
                <div key={key}><span>{key}</span><strong>{val}</strong></div>)}
            </div>
          </section>}
          {active&&<section className="tlg-sint-block">
            <h3><AlertTriangle size={18} aria-hidden="true"/>{l.deadlines}
              {closingSoon.length>0&&<small>{closingSoon.length}</small>}
            </h3>
            {attention.length===0?<p className="tlg-sint-note">{l.noDeadlines}</p>
              :<div className="tlg-sint-objectives">{attention.map(item=>{
                const soon=item.days_to_deadline!==null&&item.days_to_deadline<=28
                return <article key={item.id} className={soon?'tlg-sint-soon':''}>
                  <div className="tlg-sint-objective-head">
                    <strong>{item.tournament_name??item.title}</strong>
                    <span>{objectiveStatus(item)}</span>
                  </div>
                  <div className="tlg-sint-objective-details">
                    <span>{l.reward}: {money(item.reward_amount)}</span>
                    {item.days_to_deadline!==null&&
                      <span>{l.daysToDeadline}: {num(item.days_to_deadline)}</span>}
                    <span>{item.progress_percent!==null
                      ? `${l.progress}: ${item.progress_percent}%`
                      : `${l.milestone}: ${item.milestone_achieved?l.achieved:l.notAchieved}`}</span>
                  </div>
                  {item.progress_percent!==null&&<div className="tlg-sint-progress" aria-hidden="true">
                    <i style={{width:`${item.progress_percent}%`}}/>
                  </div>}
                </article>
              })}</div>}
            {closingSoon.length>0&&<p className="tlg-sint-warning">{l.riskNote}</p>}
          </section>}
          <section className="tlg-sint-block">
            <h3><Scale size={18} aria-hidden="true"/>{l.offerTitle}
              <small>{offers.length}</small>
            </h3>
            {offers.length===0?<p className="tlg-sint-note">{l.noOffers}</p>
              :<div className="tlg-sint-scroll">
                <table>
                  <thead><tr>
                    <th scope="col">{l.name}</th><th scope="col">{l.guaranteed}</th>
                    <th scope="col">{l.weekly}</th><th scope="col">{l.bonusPool}</th>
                    <th scope="col">{l.maxPossible}</th><th scope="col">{l.conditionalShare}</th>
                    <th scope="col">{l.objectivesCount}</th><th scope="col">{l.expires}</th>
                  </tr></thead>
                  <tbody>{offers.map(o=><tr key={o.id}>
                    <th scope="row">{o.name}</th>
                    <td>{money(o.guaranteed_usd)}</td><td>{money(o.weekly_usd)}</td>
                    <td>{money(o.conditional_bonus_pool_usd)}</td>
                    <td>{money(o.maximum_if_all_objectives_met_usd)}</td>
                    <td>{o.conditional_share_percent.toFixed(1)}%</td>
                    <td>{o.objective_count}</td>
                    <td>{o.days_until_expiry} {l.daysLeft.toLowerCase()}</td>
                  </tr>)}</tbody>
                </table>
              </div>}
            <p className="tlg-sint-note">{l.compareNote}</p>
          </section>
          <p className="tlg-sint-disclaimer">{l.disclaimer} {l.source}</p>
        </div>)}
    </div>
  </section>
}
