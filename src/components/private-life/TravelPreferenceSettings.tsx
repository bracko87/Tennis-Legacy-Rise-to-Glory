import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { lifestyleCopy } from '../../lib/lifestyleCareerI18n'
import { supabase } from '../../lib/supabase'
import type { LifestyleCareer } from './LifestyleCareerPanel'

export default function TravelPreferenceSettings() {
 const { i18n } = useTranslation()
 const c = lifestyleCopy(i18n.resolvedLanguage ?? i18n.language)
 const [mode,setMode] = useState<NonNullable<LifestyleCareer['preferred_travel_mode']> | null>(null)
 const [saving,setSaving] = useState(false)
 const [message,setMessage] = useState<string | null>(null)
 useEffect(()=>{
  let active=true
  void supabase.rpc('get_my_private_life_career_v1').then(({data,error})=>{
   if(active && !error && data) setMode((data as LifestyleCareer).preferred_travel_mode ?? 'ask_every_time')
  })
  return ()=>{active=false}
 },[])
 if (mode===null) return null
 async function save(value:NonNullable<LifestyleCareer['preferred_travel_mode']>) {
  if(saving)return
  setSaving(true);setMessage(null)
  const {error}=await supabase.rpc('set_private_life_travel_preference_v1',{p_mode:value})
  if(error)setMessage(error.message)
  else {setMode(value);setMessage(c.preferenceSaved)}
  setSaving(false)
 }
 return (
  <section className="tlg-preferences-section">
   <header className="tlg-preferences-section-head">
    <div><span>{c.title}</span><h3>{c.preferredTravel}</h3><p>{c.subtitle}</p></div>
   </header>
   <div className="tlg-preferences-section-body">
    <label className="tlg-career-preference">
     <span>{c.preferredTravel}</span>
     <select value={mode} disabled={saving} onChange={event=>void save(event.target.value as NonNullable<LifestyleCareer['preferred_travel_mode']>)}>
      <option value="ask_every_time">{c.askEveryTime}</option>
      <option value="cheapest">{c.cheapest}</option>
      <option value="commercial">{c.commercial}</option>
      <option value="best_owned_jet">{c.bestOwnedJet}</option>
     </select>
    </label>
    {message && <p role="status">{message}</p>}
   </div>
  </section>
 )
}
