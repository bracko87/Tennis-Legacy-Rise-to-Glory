import { useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronUp, Crown, LockKeyhole, Wallet, AlertTriangle } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { staffRoleLabel, staffQualityLabel } from '../../i18n/staffLocalization'
import { staffAdvisoryLabels } from '../../lib/staffAdvisoryI18n'
import '../../styles/staff-advisory-premium.css'

type StaffReportRow = {
  contract_id:string
  role:string
  name:string
  rating:number
  quality_tier:string
  days_remaining:number
  weeks_remaining:number
  duration_weeks:number
  weekly_salary:number
  posted_cost_all_time:number
  posted_cost_last_28_game_days:number
  estimated_remaining_salaries:number
  rating_per_1000_weekly_usd:number|null
  current_role_effects:Array<{
    label:string
    current_display:string
    maximum_display:string
    cadence:string
  }>
}
type StaffAdvisoryReport = {
  player_id:string
  absolute_game_day:number
  staff_count:number
  staff:StaffReportRow[]
  weekly_salary_run_rate_usd:number
  four_week_salary_run_rate_usd:number
  thirteen_week_salary_run_rate_usd:number
  remaining_salary_commitments_estimate_usd:number
  active_contract_posted_cost_total_usd:number
  active_contract_posted_cost_last_28_game_days_usd:number
  expiring_within_28_game_days:number
  earliest_expiry_days:number|null
}

export default function PremiumStaffAdvisory({playerId}:{playerId:string|null}) {
  const {t,i18n}=useTranslation()
  const l=staffAdvisoryLabels(i18n.resolvedLanguage??i18n.language)
  const {isPremium,loading:checkingPremium}=useCommerce()
  const [expanded,setExpanded]=useState(false)
  const [loading,setLoading]=useState(false)
  const [error,setError]=useState(false)
  const [report,setReport]=useState<StaffAdvisoryReport|null>(null)

  useEffect(()=>{
    let cancelled=false
    setReport(null)
    setError(false)
    if(!expanded||!isPremium||checkingPremium||!playerId){
      setLoading(false)
      return ()=>{cancelled=true}
    }
    setLoading(true)
    void supabase.rpc('get_premium_staff_advisory_v1',{p_player_id:playerId})
      .then(({data,error:rpcError})=>{
        if(cancelled)return
        const result=data as StaffAdvisoryReport|null
        if(rpcError||!result||result.player_id!==playerId||!Array.isArray(result.staff)){
          setError(true)
        }else setReport(result)
        setLoading(false)
      }).catch(()=>{
        if(!cancelled){setError(true);setLoading(false)}
      })
    return ()=>{cancelled=true}
  },[expanded,isPremium,checkingPremium,playerId])

  const validReport=report?.player_id===playerId?report:null
  const staff=useMemo(()=>validReport?.staff??[],[validReport])
  const money=(n:number)=>new Intl.NumberFormat(i18n.language??'en',{
    style:'currency',currency:'USD',maximumFractionDigits:0,
  }).format(n)
  const metrics=validReport?[
    {label:l.teamSpend,value:money(validReport.weekly_salary_run_rate_usd)},
    {label:l.spend4,value:money(validReport.four_week_salary_run_rate_usd)},
    {label:l.spend13,value:money(validReport.thirteen_week_salary_run_rate_usd)},
    {label:l.remaining,value:money(validReport.remaining_salary_commitments_estimate_usd)},
    {label:l.recorded28,value:money(validReport.active_contract_posted_cost_last_28_game_days_usd)},
    {label:l.recordedTotal,value:money(validReport.active_contract_posted_cost_total_usd)},
  ]:[]
  const anySoon=staff.filter(item=>item.days_remaining<=28)
  const fmtWeeks=(v:number)=>`${v} ${l.inGameWeeks}`
  const share=(v:number)=>validReport?.weekly_salary_run_rate_usd
    ?(v/validReport.weekly_salary_run_rate_usd)*100:0

  return <section className="tlg-staffa" aria-label={l.title}>
    <header className="tlg-staffa-head">
      <div>
        <span className="tlg-staffa-kicker"><Crown size={15} aria-hidden="true"/>{l.kicker}</span>
        <h2>{l.title}</h2>
        <p>{l.intro}</p>
      </div>
      <button type="button" className="tlg-staffa-toggle"
        aria-expanded={expanded} aria-controls="tlg-staffa-body"
        onClick={()=>setExpanded(v=>!v)}>
        {expanded?l.hide:l.show}
        {expanded?<ChevronUp size={16} aria-hidden="true"/>:<ChevronDown size={16} aria-hidden="true"/>}
      </button>
    </header>
    <div id="tlg-staffa-body" hidden={!expanded}>
      {expanded&&(checkingPremium||loading
        ?<p className="tlg-staffa-state">{l.loading}</p>
        :!isPremium?<div className="tlg-staffa-locked">
          <LockKeyhole size={20} aria-hidden="true"/>
          <p>{l.locked}</p><Link to="/game/pro-packages">{l.upgrade}</Link>
        </div>
        :error||!validReport?<p className="tlg-staffa-state" role="alert">{l.error}</p>
        :staff.length===0?<p className="tlg-staffa-state">{l.empty}</p>
        :<div className="tlg-staffa-body">
          <div className="tlg-staffa-metrics">
            {metrics.map(m=><div key={m.label}><span>{m.label}</span><strong>{m.value}</strong></div>)}
          </div>
          <p className="tlg-staffa-note">{l.provenance}</p>
          <section className="tlg-staffa-panel">
            <header className="tlg-staffa-section-heading">
              <h3><AlertTriangle size={17} aria-hidden="true"/>{l.attention}</h3>
              <span>{anySoon.length} / {staff.length} {l.activeContracts.toLowerCase()}</span>
            </header>
            {anySoon.length>0?<div className="tlg-staffa-expiry">
              {anySoon.map(member=><div key={member.contract_id}>
                <strong>{member.name}</strong>
                <span>{staffRoleLabel(t,member.role)} · {fmtWeeks(member.weeks_remaining)}</span>
              </div>)}
            </div>:<p className="tlg-staffa-note">{l.noneSoon}</p>}
          </section>
          <section className="tlg-staffa-panel">
            <header className="tlg-staffa-section-heading">
              <h3><Wallet size={17} aria-hidden="true"/>{l.staffOverview}</h3>
              <span>{staff.length} {l.activeContracts.toLowerCase()}</span>
            </header>
            <div className="tlg-staffa-table-wrap">
              <table>
                <thead><tr>
                  <th scope="col">{l.staffMember}</th>
                  <th scope="col">{l.weekly}</th>
                  <th scope="col">{l.salaryShare}</th>
                  <th scope="col">{l.remainingWeeks}</th>
                  <th scope="col">{l.remainingCost}</th>
                  <th scope="col">{l.postedCosts}</th>
                  <th scope="col">{l.costIndex}</th>
                </tr></thead>
                <tbody>{staff.map(member=>{
                  const portion=share(member.weekly_salary)
                  return <tr key={member.contract_id}>
                    <th scope="row">
                      <strong>{member.name}</strong>
                      <small>{staffRoleLabel(t,member.role)} · {staffQualityLabel(t,member.quality_tier)}</small>
                    </th>
                    <td>{money(member.weekly_salary)}</td>
                    <td>
                      <div className="tlg-staffa-share">
                        <span>{portion.toFixed(1)}%</span>
                        <div className="tlg-staffa-track" aria-hidden="true"><i style={{width:`${Math.min(100,portion)}%`}}/></div>
                      </div>
                    </td>
                    <td className={member.days_remaining<=28?'tlg-staffa-caution':''}>{member.weeks_remaining}</td>
                    <td>{money(member.estimated_remaining_salaries)}</td>
                    <td>{money(member.posted_cost_all_time)}</td>
                    <td>{member.rating_per_1000_weekly_usd===null?'—':member.rating_per_1000_weekly_usd.toFixed(2)}</td>
                  </tr>
                })}</tbody>
              </table>
            </div>
            <p className="tlg-staffa-note">{l.indexHelp}</p>
          </section>
          <p className="tlg-staffa-note">{l.effectsNote} {l.noMeasuredImpact} {l.dateNote}</p>
        </div>)}
    </div>
  </section>
}
