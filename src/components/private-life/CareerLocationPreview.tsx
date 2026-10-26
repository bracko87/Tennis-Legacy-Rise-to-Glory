import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'
import { supabase } from '../../lib/supabase'
import { lifestyleCopy } from '../../lib/lifestyleCareerI18n'
import { LifestyleFacts, type LifestyleCareer } from './LifestyleCareerPanel'
import '../../styles/private-life-career.css'

export default function CareerLocationPreview() {
 const {i18n} = useTranslation()
 const c = lifestyleCopy(i18n.resolvedLanguage ?? i18n.language)
 const [data,setData] = useState<LifestyleCareer | null>(null)
 useEffect(() => {
  let mounted=true
  void supabase.rpc('get_my_private_life_career_v1').then(({data:career,error}) => {
    if(mounted && !error && career) setData(career as LifestyleCareer)
  })
  return ()=>{mounted=false}
 },[])
 if(!data) return null
 return (
  <section className="tlg-career-preview">
   <h3>{c.title}</h3>
   <p>{c.subtitle}</p>
   <LifestyleFacts data={data} compact />
   <Link to="/game/private-life">{c.selectedResidence} / {c.ownedJets}</Link>
  </section>
 )
}
