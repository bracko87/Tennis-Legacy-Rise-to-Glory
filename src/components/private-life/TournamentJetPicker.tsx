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
 const supported = selectedJet && distanceKm>0 && distanceKm<=selectedJet.max_range_km
 const estimate = supported && selectedJet
  ? selectedJet.base_trip_cost + Math.ceil(distanceKm*selectedJet.cost_per_km) + 1000
  : null
 const staffOnBoard = selectedJet ? Math.min(Math.max(0,selectedJet.passenger_capacity-1),staffCount) : 0
 const staffCommercial = staffCount - staffOnBoard
 const quoteJet = quote?.selected_asset_id===assetId ? quote.private_jet_quote : null
 async function save() {
  if(choice==='private_jet' && !supported) return
  setBusy(true);setError(null);setNotice(null)
  const {error:saveError} = await supabase.rpc('set_private_life_tournament_travel_v1',{
   p_competition_id:competitionId,p_mode:choice,p_owned_jet_asset_id:choice==='private_jet'?assetId:null,
  })
  if(saveError){setError(saveError.message);setBusy(false);return}
  await reload()
  setNotice(choice==='private_jet' ? c.bookJet : c.bookCommercial)
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
      <div><span>{c.staffCommercial}</span><strong>{staffCommercial}</strong></div>
      <div><span>{c.travelCost}</span><strong>{estimate!==null ? money(estimate) : '—'}</strong></div>
      {quoteJet?.active && <div><span>{c.reposition}</span><strong>{money(Number(quoteJet.reposition_cost ?? 0))}</strong></div>}
      {quoteJet?.active && <div><span>{c.travelHours}</span><strong>{quoteJet.estimated_hours ?? '—'}</strong></div>}
     </div>}
     {!supported && <p className="tlg-jet-error">{c.jetNotAvailable}</p>}
     {supported && <small>{c.operating} · {c.reposition}: {c.quote} {c.selectedJet} + {c.travelCost}; final charge is calculated by the travel engine.</small>}
    </>}
    {choice === 'commercial' && <p className="tlg-jet-commercial">{c.commercial} · {money(Number(quote?.commercial_player_cost ?? 0))}</p>}
    <button type="button" className="tlg-jet-save" onClick={()=>void save()}
      disabled={busy || (choice==='private_jet' && !supported)}>{busy ? c.loading : c.save}</button>
    {notice && <p className="tlg-jet-success" role="status">{notice}</p>}
   </>}
  </div>
 )
}
