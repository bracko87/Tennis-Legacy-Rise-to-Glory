import { useEffect, useState } from 'react'
import { ChevronDown, ChevronUp, Crown, LockKeyhole, AlertTriangle, Scale, ShoppingBag } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { equipmentIntelligenceLabels } from '../../lib/equipmentIntelligenceI18n'
import '../../styles/equipment-intelligence-premium.css'

type OwnedItem = {
  inventory_id:string
  catalog_item_id:string
  name:string
  type:string
  accessory_kind:string|null
  surface:string|null
  product_profile:string|null
  tier:number
  condition:number
  wear_per_match:number|null
  catalog_estimated_uses:number|null
  nominal_uses_remaining:number|null
  durability:number
  purchase_price_usd:number
  resale_value_usd:number
  resell_supported:boolean
  can_sell_now:boolean
  acquisition:string
  is_equipped:boolean
  retained_purchase_value_pct:number|null
}
type Candidate = {
  id:string
  name:string
  type:string
  accessory_kind:string|null
  surface:string|null
  tier:number
  durability:number
  nominal_total_uses:number|null
  wear_per_match:number|null
  list_price_usd:number
  current_price_usd:number
  nominal_cost_per_use_usd:number|null
  free_claim_available:boolean
  availability:string
  effect_scope:string
  configured_effects:Record<string,number>
}
type Report={
  player_id:string
  world:string
  owned_count:number
  equipped_count:number
  below_40_condition:number
  owned_purchase_spend_usd:number
  owned_resale_estimate_usd:number
  resell_supported_count:number
  items:OwnedItem[]
  replacement_candidates:Candidate[]
}
const riskThreshold=40

export default function PremiumEquipmentIntelligence({
  playerId,refreshKey,onOpenMarketplace,
}:{
  playerId:string
  refreshKey:string
  onOpenMarketplace:()=>void
}) {
  const {t,i18n}=useTranslation()
  const copy=equipmentIntelligenceLabels(i18n.resolvedLanguage??i18n.language)
  const {isPremium,loading:checkingPremium}=useCommerce()
  const [expanded,setExpanded]=useState(false)
  const [loading,setLoading]=useState(false)
  const [error,setError]=useState(false)
  const [report,setReport]=useState<Report|null>(null)
  const [selectedId,setSelectedId]=useState('')

  useEffect(()=>{
    let cancelled=false
    setReport(null)
    setError(false)
    if(!expanded||!isPremium||checkingPremium||!playerId){
      setLoading(false)
      return ()=>{cancelled=true}
    }
    setLoading(true)
    void supabase.rpc('get_premium_equipment_intelligence_v1',{p_player_id:playerId})
      .then(({data,error:rpcError})=>{
        if(cancelled)return
        const result=data as Report|null
        if(rpcError||!result||result.player_id!==playerId
          ||!Array.isArray(result.items)||!Array.isArray(result.replacement_candidates)
          ||result.owned_count!==result.items.length){
          setError(true)
        }else{
          setReport(result)
          setSelectedId(prev=>result.items.some(item=>item.inventory_id===prev)
            ?prev:(result.items[0]?.inventory_id??''))
        }
        setLoading(false)
      }).catch(()=>{if(!cancelled){setLoading(false);setError(true)}})
    return ()=>{cancelled=true}
  },[expanded,isPremium,checkingPremium,playerId,refreshKey])

  const current=report?.player_id===playerId?report:null
  const owned=current?.items??[]
  const selected=owned.find(item=>item.inventory_id===selectedId)??owned[0]??null
  const offers=(current?.replacement_candidates??[]).filter(candidate=>
    selected&&candidate.type===selected.type
      &&(candidate.type!=='accessory'||candidate.accessory_kind===selected.accessory_kind))
  const usd=(n:number)=>new Intl.NumberFormat(i18n.language??'en',{
    style:'currency',currency:'USD',maximumFractionDigits:0,
  }).format(n)
  const priceUse=(n:number|null)=>n===null?copy.unknown:
    new Intl.NumberFormat(i18n.language??'en',{
      style:'currency',currency:'USD',minimumFractionDigits:2,maximumFractionDigits:2,
    }).format(n)
  const number=(n:number)=>new Intl.NumberFormat(i18n.language??'en',{
    maximumFractionDigits:1,
  }).format(n)
  const typeName=(type:string)=>t(`equipmentPage.ui.types.${type}`,{defaultValue:type})
  return <section className="tlg-ei" aria-label={copy.title}>
    <header className="tlg-ei-head">
      <div>
        <span className="tlg-ei-kicker"><Crown size={15} aria-hidden="true"/>{copy.kicker}</span>
        <h2>{copy.title}</h2><p>{copy.intro}</p>
      </div>
      <button type="button" className="tlg-ei-toggle" aria-expanded={expanded}
        aria-controls="tlg-ei-body" onClick={()=>setExpanded(v=>!v)}>
        {expanded?copy.hide:copy.show}
        {expanded?<ChevronUp size={16} aria-hidden="true"/>:<ChevronDown size={16} aria-hidden="true"/>}
      </button>
    </header>
    <div id="tlg-ei-body" hidden={!expanded}>
      {expanded&&(checkingPremium||loading
        ?<p className="tlg-ei-status">{copy.loading}</p>
        :!isPremium?<div className="tlg-ei-locked">
          <LockKeyhole size={20} aria-hidden="true"/>
          <p>{copy.locked}</p>
          <Link to="/game/pro-packages">{copy.upgrade}</Link>
        </div>
        :error||!current?<p className="tlg-ei-status" role="alert">{copy.error}</p>
        :<div className="tlg-ei-body">
          <section className="tlg-ei-block">
            <h3>{copy.inventoryOverview}</h3>
            <div className="tlg-ei-metrics">
              {([
                [copy.count,String(current.owned_count)],
                [copy.equipped,String(current.equipped_count)],
                [copy.worn,String(current.below_40_condition)],
                [copy.ownedSpend,usd(current.owned_purchase_spend_usd)],
                [copy.resaleEstimate,usd(current.owned_resale_estimate_usd)],
              ] as [string,string][]).map(([label,value])=>
                <div key={label}><span>{label}</span><strong>{value}</strong></div>)}
            </div>
          </section>
          {owned.length===0?<p className="tlg-ei-note">{copy.empty}</p>:<>
            {current.below_40_condition>0&&<p className="tlg-ei-warning">
              <AlertTriangle size={17} aria-hidden="true"/>{copy.wearWarning}
            </p>}
            <section className="tlg-ei-block">
              <h3>{copy.inventoryOverview}</h3>
              <div className="tlg-ei-scroll">
                <table>
                  <thead><tr>
                    {[copy.ownedItem,copy.category,copy.condition,copy.paid,copy.resale,
                      copy.retention,copy.wearRate,copy.nominalMatches,copy.status].map(h=>
                      <th key={h} scope="col">{h}</th>)}
                  </tr></thead>
                  <tbody>{owned.map(item=><tr key={item.inventory_id}
                    className={item.condition<riskThreshold?'tlg-ei-risk-row':''}>
                    <th scope="row"><strong>{item.name}</strong>
                      <small>{copy.tier} {item.tier}</small></th>
                    <td>{typeName(item.type)}</td>
                    <td><span className={item.condition<riskThreshold?'tlg-ei-risk':''}>
                      {number(item.condition)}%</span>
                      <div className="tlg-ei-condition" aria-hidden="true">
                        <i style={{width:`${Math.max(0,Math.min(100,item.condition))}%`}}/>
                      </div></td>
                    <td>{item.purchase_price_usd>0?usd(item.purchase_price_usd):copy.noSpend}</td>
                    <td>{item.resell_supported?usd(item.resale_value_usd):copy.notSellable}</td>
                    <td>{item.retained_purchase_value_pct===null?copy.unknown:
                      `${number(item.retained_purchase_value_pct)}%`}</td>
                    <td>{item.wear_per_match===null?copy.unknown:
                      `${number(item.wear_per_match)}%`}</td>
                    <td>{item.nominal_uses_remaining===null?copy.unknown:
                      String(item.nominal_uses_remaining)}</td>
                    <td>{item.is_equipped?copy.equipped:copy.unknown}</td>
                  </tr>)}</tbody>
                </table>
              </div>
              <p className="tlg-ei-note">{copy.method}</p>
            </section>
            <section className="tlg-ei-block">
              <h3><Scale size={18} aria-hidden="true"/>{copy.compareTitle}</h3>
              <label className="tlg-ei-choice">{copy.selectOwned}
                <select value={selected?.inventory_id??''}
                  onChange={event=>setSelectedId(event.target.value)}>
                  {owned.map(item=><option key={item.inventory_id} value={item.inventory_id}>
                    {item.name} · {number(item.condition)}%
                  </option>)}
                </select>
              </label>
              <h4>{copy.marketOptions}</h4>
              {offers.length===0?<p className="tlg-ei-note">{copy.marketEmpty}</p>
                :<div className="tlg-ei-scroll">
                  <table className="tlg-ei-offer-table">
                    <thead><tr>
                      {[copy.ownedItem,copy.marketPrice,copy.newLife,copy.costPerUse,
                        copy.durability,copy.surface,copy.tier].map(h=>
                          <th scope="col" key={h}>{h}</th>)}
                    </tr></thead>
                    <tbody>{offers.map(candidate=><tr key={candidate.id}>
                      <th scope="row">{candidate.name}
                        {candidate.free_claim_available&&<small>{copy.freeClaim}</small>}
                      </th>
                      <td>{usd(candidate.current_price_usd)}</td>
                      <td>{candidate.nominal_total_uses??copy.unknown}</td>
                      <td>{priceUse(candidate.nominal_cost_per_use_usd)}</td>
                      <td>{candidate.durability}</td>
                      <td>{candidate.surface??copy.unknown}</td>
                      <td>{candidate.tier}</td>
                    </tr>)}</tbody>
                  </table>
                </div>}
              <button type="button" className="tlg-ei-market" onClick={onOpenMarketplace}>
                <ShoppingBag size={16} aria-hidden="true"/>{copy.goMarket}
              </button>
              <p className="tlg-ei-note">{copy.marketMethod}</p>
            </section>
          </>}
        </div>)}
    </div>
  </section>
}
