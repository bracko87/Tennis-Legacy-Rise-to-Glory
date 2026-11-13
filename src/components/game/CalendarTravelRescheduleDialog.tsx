import { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'
import { Plane, X } from 'lucide-react'
import { supabase } from '../../lib/supabase'
import { calendarTravelCopy } from '../../lib/calendarTravelRescheduleI18n'

export interface CalendarTransferOption {
  departure_absolute_day: number
  source_competition_id: string
  destination_competition_id: string
  source_tournament_name: string
  destination_tournament_name: string
  source_city: string
  destination_city: string
  route_choice: 'home' | 'direct'
  has_planned_flight: boolean
  has_existing_payment: boolean
  refundable_paid_cost: number
}
interface TransferQuote {
  quote_available: boolean
  source_city?: string
  destination_city?: string
  direct_distance_km?: number
  direct_flight_mode?: 'commercial' | 'private_jet'
  direct_flight_cost?: number
  extra_hotel_nights?: number
  extra_hotel_cost?: number
  direct_total_cost?: number
  arrival_fatigue?: number
  commercial_via_home_cost?: number
  potential_tight_connection?: boolean
}
interface Preparation {
  player_travel_class?: string
  staff_travel_class?: string
  hotel_tier?: string
  selected_staff_contract_ids?: string[]
}
interface SaveResult {
  saved?: boolean
  changed?: boolean
  refunded_amount?: number
}
interface Props {
  option: CalendarTransferOption
  playerId: string
  onClose: () => void
  onSaved: (route: 'home' | 'direct', refund: number) => void
}
export default function CalendarTravelRescheduleDialog({option,playerId,onClose,onSaved}:Props) {
  const { i18n } = useTranslation()
  const words = calendarTravelCopy(i18n.resolvedLanguage ?? i18n.language)
  const [choice,setChoice] = useState<'home'|'direct'>(option.route_choice)
  const [quote,setQuote] = useState<TransferQuote|null>(null)
  const [busy,setBusy] = useState(false)
  const [loading,setLoading] = useState(true)
  const [error,setError] = useState<string|null>(null)
  const currency=(n:number|undefined)=>'$'+Math.round(Number(n??0)).toLocaleString(i18n.resolvedLanguage ?? i18n.language)
  useEffect(()=>{
    let cancelled=false
    setChoice(option.route_choice)
    setQuote(null)
    setLoading(true)
    setError(null)
    async function load() {
      const {data:plan,error:planError}=await supabase.rpc('get_tournament_preparation_v1',{
        p_player_id:playerId,p_competition_id:option.destination_competition_id,
      })
      if(cancelled) return
      if(planError || !plan) {
        setError(planError?.message??'Preparation unavailable')
        setLoading(false)
        return
      }
      const data=plan as Preparation
      const {data:preview,error:previewError}=await supabase.rpc('quote_tournament_transfer_options_v1',{
        p_player_id:playerId,
        p_competition_id:option.destination_competition_id,
        p_player_travel_class:data.player_travel_class??'Economy',
        p_staff_travel_class:data.staff_travel_class??'Economy',
        p_hotel_tier:data.hotel_tier??'Standard',
        p_selected_staff_contract_ids:data.selected_staff_contract_ids??[],
      })
      if(cancelled) return
      setLoading(false)
      if(previewError || !preview || !(preview as TransferQuote).quote_available){
        setError(previewError?.message??'Direct travel quote unavailable')
      }else {
        setQuote(preview as TransferQuote)
      }
    }
    void load()
    return ()=>{cancelled=true}
  },[option.destination_competition_id,playerId,option.route_choice])

  async function save() {
    if(busy || loading || !quote) return
    setBusy(true);setError(null)
    const {data,error:saveError}=await supabase.rpc('save_tournament_transfer_preference_v1',{
      p_player_id:playerId,
      p_competition_id:option.destination_competition_id,
      p_route_choice:choice,
    })
    if(saveError || !(data as SaveResult|null)?.saved){
      setError(saveError?.message??'Unable to save travel route')
      setBusy(false)
      return
    }
    onSaved(choice,Number((data as SaveResult).refunded_amount??0))
  }
  return (
    <div className="tlg-travel-reschedule-backdrop" role="presentation" onMouseDown={(event)=>{if(event.target===event.currentTarget && !busy)onClose()}}>
      <section className="tlg-travel-reschedule-dialog" role="dialog" aria-modal="true" aria-labelledby="tlg-reschedule-title">
        <header className="tlg-travel-reschedule-head">
          <div><span>{words.rescheduleTitle}</span><h3 id="tlg-reschedule-title">{option.source_city} → {option.destination_city}</h3>
            <p>{words.subtitle.replace('{from}',option.source_tournament_name).replace('{to}',option.destination_tournament_name)}</p></div>
          <button type="button" onClick={onClose} disabled={busy} aria-label={words.cancel}><X size={18}/></button>
        </header>
        <div className="tlg-travel-reschedule-body">
          <div className="tlg-travel-reschedule-options">
            <button type="button" className={choice==='home'?'active':''} aria-pressed={choice==='home'} disabled={busy} onClick={()=>setChoice('home')}>{words.returnHome}</button>
            <button type="button" className={choice==='direct'?'active':''} aria-pressed={choice==='direct'} disabled={busy} onClick={()=>setChoice('direct')}>{words.direct}</button>
          </div>
          {loading && <p>{words.loading}</p>}
          {quote && <div className="tlg-travel-reschedule-quote">
            <strong>{words.quoteTitle}</strong>
            <dl>
              <dt>{words.route}</dt><dd>{quote.source_city} → {quote.destination_city} · {Number(quote.direct_distance_km??0).toLocaleString()} km</dd>
              <dt>{words.flight} ({quote.direct_flight_mode==='private_jet'?words.jet:words.commercial})</dt><dd>{currency(quote.direct_flight_cost)}</dd>
              <dt>{words.hotel}</dt><dd>{quote.extra_hotel_nights??0} {Number(quote.extra_hotel_nights??0)===1?words.night:words.days} · {currency(quote.extra_hotel_cost)}</dd>
              <dt>{words.fatigue}</dt><dd>+{quote.arrival_fatigue??0}</dd>
              <dt>{words.total}</dt><dd>{currency(quote.direct_total_cost)}</dd>
              <dt>{words.viaHome}</dt><dd>{currency(quote.commercial_via_home_cost)}</dd>
            </dl>
            {quote.potential_tight_connection && <p className="tlg-travel-reschedule-warning">{words.warning}</p>}
            <p>{words.costDisclaimer}</p>
          </div>}
          <p className="tlg-travel-reschedule-note">{words.morale}</p>
          <p className="tlg-travel-reschedule-note">{words.note}</p>
          <div className="tlg-travel-reschedule-refund">
            <strong>{option.refundable_paid_cost>0
              ? words.expectedRefund+': '+currency(option.refundable_paid_cost)
              : words.noRefund}</strong>
            <p>{words.refundNote}</p>
            <p>{words.savingsNote}</p>
          </div>
          {error && <p className="tlg-travel-reschedule-error" role="alert">{words.error} {error}</p>}
          <Link to={`/game/schedule?prepare=1&competition=${option.destination_competition_id}`}>{words.preparation}</Link>
        </div>
        <footer className="tlg-travel-reschedule-actions">
          <button type="button" onClick={onClose} disabled={busy}>{words.cancel}</button>
          <button type="button" className="primary" onClick={()=>void save()} disabled={busy||loading||!quote}>
            <Plane size={15}/> {busy?words.saving:words.save}
          </button>
        </footer>
      </section>
    </div>
  )
}
