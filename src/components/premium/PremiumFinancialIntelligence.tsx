import { useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronUp, Crown, LockKeyhole, ChartNoAxesCombined, RotateCcw, AlertTriangle } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'
import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { financialIntelligenceLabels } from '../../lib/financialIntelligenceI18n'
import '../../styles/financial-intelligence-premium.css'

type HistoryWeek={week:number;from_day:number;through_day:number;income:number;expenses:number;net:number}
type FutureWeek={
  week:number
  from_day:number
  through_day:number
  scheduled_sponsor_income:number
  contracted_staff_cost:number
  planned_travel_cost:number
  known_net:number
}
type FinanceReport={
  player_id:string
  current_absolute_day:number
  season:number
  opening_cash:number
  currency:string
  historic_13_week_income:number
  historic_13_week_expenses:number
  historic_weeks:HistoryWeek[]
  future_weeks:FutureWeek[]
  scheduled_13_week_sponsor_income:number
  contracted_13_week_staff_cost:number
  planned_13_week_travel_cost:number
}
type ScenarioWeek=FutureWeek&{baseline:number;custom:number}
const horizons=[4,8,13] as const
type Horizon=typeof horizons[number]

function boundedAmount(raw:string):number {
  const value=Number(raw)
  return Number.isFinite(value)?Math.max(0,Math.min(1000000,Math.round(value))):0
}

export default function PremiumFinancialIntelligence({
  playerId,asOfDay,balance,
}:{
  playerId:string
  asOfDay:number
  balance:number
}) {
  const {i18n}=useTranslation()
  const l=financialIntelligenceLabels(i18n.resolvedLanguage??i18n.language)
  const {isPremium,loading:checkingPremium}=useCommerce()
  const [expanded,setExpanded]=useState(false)
  const [loading,setLoading]=useState(false)
  const [error,setError]=useState(false)
  const [report,setReport]=useState<FinanceReport|null>(null)
  const [horizon,setHorizon]=useState<Horizon>(8)
  const [extraExpenses,setExtraExpenses]=useState(0)
  const [extraIncome,setExtraIncome]=useState(0)
  const [oneTimeExpense,setOneTimeExpense]=useState(0)

  useEffect(()=>{
    let cancelled=false
    setReport(null)
    setError(false)
    if(!expanded||!isPremium||checkingPremium||!playerId) {
      setLoading(false)
      return ()=>{cancelled=true}
    }
    setLoading(true)
    void supabase.rpc('get_premium_financial_intelligence_v1',{p_player_id:playerId})
      .then(({data,error:rpcError})=>{
        if(cancelled)return
        const incoming=data as FinanceReport|null
        if(rpcError||!incoming||incoming.player_id!==playerId
          ||!Array.isArray(incoming.future_weeks)
          ||incoming.future_weeks.length!==13
          ||!Array.isArray(incoming.historic_weeks)
          ||incoming.historic_weeks.length!==13) {
          setError(true)
        } else {
          setReport(incoming)
        }
        setLoading(false)
      }).catch(()=>{if(!cancelled){setError(true);setLoading(false)}})
    return ()=>{cancelled=true}
  },[expanded,isPremium,checkingPremium,playerId,asOfDay,balance])

  // Do not show an obsolete snapshot after refreshing the Free Finance dashboard.
  const valid=report?.player_id===playerId
    &&report.current_absolute_day===asOfDay
    &&report.opening_cash===balance?report:null
  const cash=(amount:number)=>new Intl.NumberFormat(i18n.language??'en',{
    style:'currency',currency:'USD',maximumFractionDigits:0,
  }).format(Math.round(amount))
  const scenario=useMemo(()=>{
    if(!valid)return [] as ScenarioWeek[]
    let baseline=valid.opening_cash
    let custom=valid.opening_cash
    return valid.future_weeks.slice(0,horizon).map((week,i)=>{
      baseline+=week.known_net
      custom+=week.known_net+extraIncome-extraExpenses-(i===0?oneTimeExpense:0)
      return {...week,baseline,custom}
    })
  },[valid,horizon,extraIncome,extraExpenses,oneTimeExpense])
  const finalWeek=scenario[scenario.length-1]
  const totalIncome=scenario.reduce((sum,w)=>sum+w.scheduled_sponsor_income,0)
  const totalStaff=scenario.reduce((sum,w)=>sum+w.contracted_staff_cost,0)
  const totalTravel=scenario.reduce((sum,w)=>sum+w.planned_travel_cost,0)
  const lowCash=scenario.some(w=>w.custom<0)
  const historyNet=(valid?.historic_13_week_income??0)-(valid?.historic_13_week_expenses??0)

  const chart=(()=>{
    if(!valid||!scenario.length)return null
    const width=800,height=205,left=65,right=24,top=16,bottom=40
    const values=[valid.opening_cash,...scenario.flatMap(w=>[w.baseline,w.custom])]
    const min=Math.min(0,...values),max=Math.max(1,...values)
    const gap=max===min?1:max-min
    const xx=(index:number)=>left+index*(width-left-right)/scenario.length
    const yy=(value:number)=>top+(max-value)/gap*(height-top-bottom)
    const baselinePoints=[valid.opening_cash,...scenario.map(w=>w.baseline)]
      .map((value,index)=>`${xx(index)},${yy(value)}`).join(' ')
    const customPoints=[valid.opening_cash,...scenario.map(w=>w.custom)]
      .map((value,index)=>`${xx(index)},${yy(value)}`).join(' ')
    return <svg className="tlg-fi-chart" viewBox={`0 0 ${width} ${height}`}
        role="img" aria-label={l.outlook}>
      {scenario.map(w=><g key={w.week}>
        <line x1={xx(w.week)} x2={xx(w.week)} y1={top} y2={height-bottom}
          stroke="#dce8ef" strokeDasharray="3 5"/>
        <text x={xx(w.week)} y={height-18} textAnchor="middle" className="tlg-fi-axis">
          {w.week}
        </text>
      </g>)}
      <line x1={left} x2={width-right} y1={yy(0)} y2={yy(0)}
        stroke="#c8d3da" strokeWidth="1"/>
      <text x={left-8} y={yy(max)+5} textAnchor="end" className="tlg-fi-axis">
        {cash(max)}
      </text>
      <text x={left-8} y={yy(min)+5} textAnchor="end" className="tlg-fi-axis">
        {cash(min)}
      </text>
      <polyline points={baselinePoints} fill="none" stroke="#2d78b5"
        strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
      <polyline points={customPoints} fill="none" stroke="#bb7939"
        strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
      {scenario.map(w=><g key={`point-${w.week}`}>
        <circle cx={xx(w.week)} cy={yy(w.custom)} r="3.5" fill="#bb7939">
          <title>{`${l.tableWeek} ${w.week}: ${cash(w.custom)}`}</title>
        </circle>
      </g>)}
    </svg>
  })()

  return <section className="tlg-fi" aria-label={l.title}>
    <header className="tlg-fi-head">
      <div>
        <span className="tlg-fi-kicker"><Crown size={15} aria-hidden="true"/>{l.kicker}</span>
        <h2>{l.title}</h2>
        <p>{l.intro}</p>
      </div>
      <button type="button" className="tlg-fi-toggle" aria-expanded={expanded}
        aria-controls="tlg-fi-content" onClick={()=>setExpanded(v=>!v)}>
        {expanded?l.hide:l.show}
        {expanded?<ChevronUp size={16} aria-hidden="true"/>:<ChevronDown size={16} aria-hidden="true"/>}
      </button>
    </header>
    <div id="tlg-fi-content" hidden={!expanded}>
      {expanded&&(checkingPremium||loading
        ?<p className="tlg-fi-state">{l.loading}</p>
        :!isPremium?<div className="tlg-fi-locked">
          <LockKeyhole size={20} aria-hidden="true"/><p>{l.locked}</p>
          <Link to="/game/pro-packages">{l.upgrade}</Link>
        </div>
        :error||!valid?<p className="tlg-fi-state" role="alert">{l.error}</p>
        :<div className="tlg-fi-body">
          <section className="tlg-fi-history">
            <header><h3>{l.historical}</h3><small>{l.last13}</small></header>
            <div className="tlg-fi-stats">
              <div><span>{l.historicalIncome}</span><strong>{cash(valid.historic_13_week_income)}</strong></div>
              <div><span>{l.historicalCosts}</span><strong>{cash(valid.historic_13_week_expenses)}</strong></div>
              <div><span>{l.historicalNet}</span><strong>{cash(historyNet)}</strong></div>
            </div>
            <p className="tlg-fi-note">{l.historicalNote}</p>
          </section>
          <section className="tlg-fi-budget">
            <header><h3><ChartNoAxesCombined size={18} aria-hidden="true"/>{l.outlook}</h3>
              <div className="tlg-fi-horizon" role="group" aria-label={l.horizon}>
                {horizons.map(n=><button key={n} type="button" aria-pressed={horizon===n}
                  className={horizon===n?'active':''}
                  onClick={()=>setHorizon(n)}>{n} {l.gameWeeks}</button>)}
              </div>
            </header>
            <div className="tlg-fi-stats tlg-fi-outlook">
              <div><span>{l.startingCash}</span><strong>{cash(valid.opening_cash)}</strong></div>
              <div><span>{l.sponsorFixed}</span><strong>{cash(totalIncome)}</strong></div>
              <div><span>{l.staffContracted}</span><strong>{cash(totalStaff)}</strong></div>
              <div><span>{l.travelPlanned}</span><strong>{cash(totalTravel)}</strong></div>
              <div><span>{l.baselineEnd}</span><strong>{cash(finalWeek?.baseline??0)}</strong></div>
              <div><span>{l.customEnd}</span><strong>{cash(finalWeek?.custom??0)}</strong></div>
            </div>
            <h4>{l.scenario}</h4>
            <div className="tlg-fi-controls">
              <label>{l.weeklyExtraExpense}
                <input type="number" min="0" max="1000000" step="100"
                  value={extraExpenses} onChange={ev=>setExtraExpenses(boundedAmount(ev.target.value))}/>
              </label>
              <label>{l.weeklyExtraIncome}
                <input type="number" min="0" max="1000000" step="100"
                  value={extraIncome} onChange={ev=>setExtraIncome(boundedAmount(ev.target.value))}/>
              </label>
              <label>{l.oneTimeExpense}
                <input type="number" min="0" max="1000000" step="100"
                  value={oneTimeExpense} onChange={ev=>setOneTimeExpense(boundedAmount(ev.target.value))}/>
              </label>
              <button type="button" className="tlg-fi-reset"
                onClick={()=>{setExtraExpenses(0);setExtraIncome(0);setOneTimeExpense(0)}}>
                <RotateCcw size={15} aria-hidden="true"/>{l.reset}
              </button>
            </div>
            <p className="tlg-fi-note">{l.illustrative}</p>
            <div className="tlg-fi-legend">
              <span><i className="base"/>{l.baseline}</span>
              <span><i className="custom"/>{l.custom}</span>
            </div>
            <div className="tlg-fi-chart-wrap">{chart}</div>
            <p className={`tlg-fi-alert ${lowCash?'danger':'safe'}`}>
              {lowCash?<AlertTriangle size={17} aria-hidden="true"/>:null}
              <strong>{lowCash?l.risk:l.safe}</strong>
              {lowCash&&<span>{l.cashShortfall}</span>}
            </p>
            <div className="tlg-fi-table-wrap">
              <table>
                <thead><tr>
                  {[l.tableWeek,l.tableSponsor,l.tableStaff,l.tableTravel,l.tableBaseline,l.tableScenario].map(value=>
                    <th scope="col" key={value}>{value}</th>)}
                </tr></thead>
                <tbody>{scenario.map(w=><tr key={w.week}>
                  <th scope="row">{w.week}</th>
                  <td>{cash(w.scheduled_sponsor_income)}</td>
                  <td>{cash(w.contracted_staff_cost)}</td>
                  <td>{cash(w.planned_travel_cost)}</td>
                  <td>{cash(w.baseline)}</td>
                  <td className={w.custom<0?'negative':''}>{cash(w.custom)}</td>
                </tr>)}</tbody>
              </table>
            </div>
          </section>
          <p className="tlg-fi-note">{l.projectionNote} {l.noIncomeGuarantee}</p>
          <p className="tlg-fi-note">{l.excluded}</p>
        </div>)}
    </div>
  </section>
}
