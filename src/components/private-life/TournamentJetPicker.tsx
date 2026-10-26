import { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { supabase } from '../../lib/supabase'
import { lifestyleCopy } from '../../lib/lifestyleCareerI18n'
import type { LifestyleCareer, OwnedTravelJet } from './LifestyleCareerPanel'
import '../../styles/private-life-career.css'

type JetQuote = {
 active?: boolean
 reason?: string
 name?: string
 owned_asset_id?: string
 distance_km?: number
 max_range_km?: number
 passenger_capacity?: number
 cost_one_way?: number
 reposition_cost?: number
 staff_on_jet?: number
 staff_commercial?: number
 reduction_percent?: number
 estimated_hours?: number
 overnight_transfer_possible?: boolean
}
type TravelQuote = {
 selected_mode: 'default' | 'commercial' | 'private_jet'
 selected_asset_id: string | null
 private_jet_quote: JetQuote
 commercial_player_cost: number
 commercial_staff_cost: number
}
type Props = {
 competitionId: string
 staffCount: number
 distanceKm: number
 quoteRevision?: number
 money: (amount: number) => string
 onChanged: () => void
}
export default function TournamentJetPicker({
 competitionId,staffCount,distanceKm,quoteRevision = 0,money,onChanged,
}: Props) {
 const { i18n } = useTranslation()
 const c = useMemo(() => lifestyleCopy(i18n.resolvedLanguage ?? i18n.language), [i18n.resolvedLanguage,i18n.language])
 const [career,setCareer] = useState<LifestyleCareer | null>(null)
 const [choice,setChoice] = useState<'commercial' | 'private_jet'>('commercial')
 const [assetId,setAssetId] = useState('')
 const [quote,setQuote] = useState<TravelQuote | null>(null)
 const [jetPreview,setJetPreview] = useState<JetQuote | null>(null)
 const [jetPreviewLoading,setJetPreviewLoading] = useState(false)
 const [busy,setBusy] = useState(false)
 const [error,setError] = useState<string | null>(null)
 const [notice,setNotice] = useState<string | null>(null)
 const [loading,setLoading] = useState(true)
 const reload = useCallback(async () => {
  setLoading(true)
  const [careerResponse,quoteResponse] = await Promise.all([
   supabase.rpc('get_my_private_life_career_v1'),
   supabase.rpc('get_private_life_tournament_travel_v1',{p_competition_id:competitionId}),
  ])
  setLoading(false)
  if(careerResponse.error || quoteResponse.error) {
   setError(careerResponse.error?.message ?? quoteResponse.error?.message ?? 'Unable to load flight options.')
   return
  }
  const nextCareer = careerResponse.data as LifestyleCareer
  const nextQuote = quoteResponse.data as TravelQuote
  setCareer(nextCareer)
  setQuote(nextQuote)
  setChoice(nextQuote.selected_mode === 'private_jet' ? 'private_jet' : 'commercial')
  const jetList = nextCareer.eligible_jets ?? []
  setAssetId(nextQuote.selected_asset_id ?? jetList[0]?.owned_asset_id ?? '')
  setError(null)
 },[competitionId])

 useEffect(() => { void reload() },[reload])
 // Re-read the booked quote when the travel preview changes; retain unconfirmed selection in UI.
 useEffect(() => { if (quoteRevision) void reload() }, [quoteRevision,reload])
 const jets: OwnedTravelJet[] = career?.eligible_jets ?? []
 const selectedJet = jets.find(jet => jet.owned_asset_id === assetId)
 const seatCount = 1 + Math.max(0,staffCount)
 const supportedBySeats = Boolean(selectedJet && selectedJet.passenger_capacity >= seatCount)
 const supportedByRange = Boolean(selectedJet && distanceKm>0 && distanceKm<=selectedJet.max_range_km)
 useEffect(() => {
  let active = true
  if(!assetId || !supportedBySeats || !supportedByRange) {
   setJetPreview(null)
   setJetPreviewLoading(false)
   return () => { active = false }
  }
  setJetPreview(null)
  setJetPreviewLoading(true)
  void supabase.rpc('quote_my_private_life_jet_v1',{
   p_competition_id:competitionId,p_owned_jet_asset_id:assetId,p_staff_count:Math.max(0,staffCount),
  }).then(({data,error})=>{
   if(!active) return
   setJetPreview(error ? {active:false,reason:error.message} : data as JetQuote)
   setJetPreviewLoading(false)
  })
  return () => { active = false }
 },[assetId,competitionId,staffCount,quoteRevision,supportedBySeats,supportedByRange])
 const supported = supportedBySeats && supportedByRange && jetPreview?.active === true && !jetPreviewLoading
 const commercialTotal = Number(quote?.commercial_player_cost ?? 0) + Number(quote?.commercial_staff_cost ?? 0)
 const staffOnBoard = supported ? Math.max(0,staffCount) : 0
 async function save() {
  if(choice==='private_jet' && jetPreviewLoading) return
  const requestedMode = choice==='private_jet' && !supported ? 'commercial' : choice
  setBusy(true);setError(null);setNotice(null)
  const {data:saveData,error:saveError} = await supabase.rpc('set_private_life_tournament_travel_v1',{
   p_competition_id:competitionId,p_mode:requestedMode,
   p_owned_jet_asset_id:requestedMode==='private_jet'?assetId:null,
  })
  if(saveError){setError(saveError.message);setBusy(false);return}
  await reload()
  const usedCommercial = requestedMode==='commercial' || saveData?.travel_mode==='commercial'
  setNotice(choice==='private_jet' && usedCommercial ? c.commercialFallback : usedCommercial ? c.bookCommercial : c.bookJet)
  onChanged()
  setBusy(false)
 }
 return (
  <div className="tlg-jet-picker">
   <div className="tlg-jet-heading"><strong>{c.jetMode}</strong><small>{c.subtitle}</small></div>
   {loading && <p>{c.loading}</p>}
   {error && <p className="tlg-jet-error" role="alert">{error}</p>}
   {!loading && career && <>
    <div className="tlg-jet-modes">
     <label><input type="radio" name="tournament-jet-mode" checked={choice==='commercial'} onChange={()=>setChoice('commercial')}/>{c.commercial}</label>
     <label><input type="radio" name="tournament-jet-mode" checked={choice==='private_jet'} disabled={!jets.length} onChange={()=>setChoice('private_jet')}/>{c.bestOwnedJet}</label>
    </div>
    {choice === 'private_jet' && <>
     <label className="tlg-jet-select"><span>{c.selectJet}</span>
      <select value={assetId} onChange={e=>setAssetId(e.target.value)}>
       {jets.map(jet=><option key={jet.owned_asset_id} value={jet.owned_asset_id}>
        {jet.name} · {jet.max_range_km.toLocaleString()} km
       </option>)}
      </select>
     </label>
     {selectedJet && <div className="tlg-jet-details">
      <div><span>{c.range}</span><strong>{selectedJet.max_range_km.toLocaleString()} km</strong></div>
      <div><span>{c.capacity}</span><strong>{selectedJet.passenger_capacity}</strong></div>
      <div><span>{c.fatigueBenefit}</span><strong>{selectedJet.reduction_percent}%</strong></div>
      <div><span>{c.staffOnBoard}</span><strong>{staffOnBoard}</strong></div>
      <div><span>{c.staffIncluded}</span><strong>{supported ? c.includedInFare : '—'}</strong></div>
      <div><span>{c.travelCost}</span><strong>{supported ? money(Number(jetPreview?.cost_one_way ?? 0)) : '—'}</strong></div>
      {supported && <div><span>{c.reposition}</span><strong>{money(Number(jetPreview?.reposition_cost ?? 0))}</strong></div>}
      {supported && <div><span>{c.travelHours}</span><strong>{jetPreview?.estimated_hours ?? '—'}</strong></div>}
      {supported && <div><span>{c.overnightTransfer}</span><strong>{jetPreview?.overnight_transfer_possible ? c.overnightCandidate : c.overnightTooLong}</strong></div>}
     </div>}
     {jetPreviewLoading && <p>{c.loading}</p>}
     {!jetPreviewLoading && !supported && <div className="tlg-jet-commercial tlg-jet-fallback" role="status">
      <strong>{c.commercialFallback}</strong>
      <span>{c.commercialRoundTrip}: {money(commercialTotal)} ({c.playerAndStaff})</span>
      <small>{c.commercialFatigueNote}</small>
     </div>
     {supported && <small>{c.fullPartyCostNote} {c.overnightDisclaimer}</small>}
    </>}
    {choice === 'commercial' && <p className="tlg-jet-commercial">{c.commercialRoundTrip}: {money(commercialTotal)} ({c.playerAndStaff})</p>
    <button type="button" className="tlg-jet-save" onClick={()=>void save()}
      disabled={busy || (choice==='private_jet' && jetPreviewLoading)}>{busy ? c.loading : choice==='private_jet' && !supported ? c.bookCommercial : c.save}</button>
    {notice && <p className="tlg-jet-success" role="status">{notice}</p>}
   </>}
  </div>
 )
}
