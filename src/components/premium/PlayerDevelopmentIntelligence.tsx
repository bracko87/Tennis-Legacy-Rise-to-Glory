import { useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronUp, Crown, LockKeyhole, TrendingUp } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { weeklySkillSnapshots, gameWeekText } from '../../lib/skillGameWeeks'
import { premiumToggleText } from '../../lib/premiumPanelToggleI18n'
import '../../styles/player-development-intelligence.css'

type Group = 'technical' | 'physical' | 'condition'
type SkillKey =
  | 'serve' | 'forehand' | 'backhand' | 'return_skill' | 'volley' | 'slice' | 'drop_shot' | 'lob' | 'smash'
  | 'fitness' | 'stamina' | 'recovery' | 'movement'
  | 'fatigue' | 'sharpness' | 'morale' | 'confidence' | 'focus'
type HistoryRow = {
  recorded_at: string
  game_season: number | null
  game_week: number | null
  source: string
} & Record<SkillKey, number>

type DevelopmentReport = {
  player_id: string
  total_snapshots: number
  window_limited: boolean
  game_dated_snapshots: number
  history: HistoryRow[]
}

const groups: Record<Group, SkillKey[]> = {
  technical: ['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'],
  physical: ['fitness','stamina','recovery','movement'],
  condition: ['fatigue','sharpness','morale','confidence','focus'],
}
const safeValue = (row: HistoryRow, key: SkillKey) => {
  const value = row[key]
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function Timeline({ rows, skill, label }: { rows: HistoryRow[]; skill: SkillKey; label: string }) {
  const { t } = useTranslation()
  const values = rows.map(row=>({
    value:safeValue(row,skill),
    week:(row.game_season ?? 1)*53+(row.game_week ?? 0),
    label:gameWeekText(row,t)
  })).filter((x): x is {value:number;week:number;label:string}=>x.value!==null)
  if (values.length<2) return null
  const width=940,height=260,left=70,right=70,top=18,bottom=38
  const min=values[0].week,max=values[values.length-1].week
  const x=(week:number,index:number)=>left+(max===min?index/(values.length-1):(week-min)/(max-min))*(width-left-right)
  const y=(value:number)=>top+(100-Math.max(0,Math.min(100,value)))/100*(height-top-bottom)
  const points=values.map((v,i)=>`${x(v.week,i).toFixed(1)},${y(v.value).toFixed(1)}`).join(' ')
  return (
    <div className="tlg-pdi-chart">
      <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label={label}>
        {[0,25,50,75,100].map(n=><g key={n}>
          <line x1={left} x2={width-right} y1={y(n)} y2={y(n)} className="tlg-pdi-gridline" />
          <text x={left-9} y={y(n)+4} textAnchor="end">{n}</text>
        </g>)}
        <polyline className="tlg-pdi-line" points={points} />
        {values.map((v,i)=><circle key={i} cx={x(v.week,i)} cy={y(v.value)} r="3" className="tlg-pdi-point" />)}
        <text x={left} y={height-11} textAnchor="start">{values[0].label}</text>
        <text x={width-right} y={height-11} textAnchor="end">{values[values.length-1].label}</text>
      </svg>
    </div>
  )
}

export default function PlayerDevelopmentIntelligence({ playerId }: { playerId: string | null }) {
  const { t, i18n } = useTranslation()
  const toggle = premiumToggleText(i18n.resolvedLanguage ?? i18n.language)
  const { isPremium, loading: checkingPremium } = useCommerce()
  const [expanded, setExpanded] = useState(false)
  const [report,setReport] = useState<DevelopmentReport|null>(null)
  const [loading,setLoading] = useState(false)
  const [loadError,setLoadError] = useState(false)
  const [group,setGroup] = useState<Group>('technical')
  const [skill,setSkill] = useState<SkillKey>('serve')

  useEffect(()=>{
    let cancelled=false
    setReport(null)
    setLoadError(false)
    if(!expanded || !isPremium || checkingPremium || !playerId){
      setLoading(false)
      return ()=>{cancelled=true}
    }
    setLoading(true)
    void supabase.rpc('get_premium_player_development_v1',{p_player_id:playerId})
      .then(({data,error})=>{
        if(cancelled)return
        if(error || !data){setReport(null);setLoadError(true)}
        else if((data as DevelopmentReport).player_id!==playerId){setReport(null);setLoadError(true)}
        else setReport(data as DevelopmentReport)
        setLoading(false)
      }).catch(()=>{
        if(!cancelled){setLoadError(true);setLoading(false)}
      })
    return ()=>{cancelled=true}
  },[expanded,isPremium,checkingPremium,playerId])

  const history=report?.history ?? []
  const weeklyHistory=useMemo(()=>weeklySkillSnapshots(history),[report])
  const earliest=weeklyHistory[0],latest=weeklyHistory[weeklyHistory.length-1]
  const progression=useMemo(()=>{
    if(!earliest || !latest)return []
    return groups[group].map(key=>{
      const start=safeValue(earliest,key),end=safeValue(latest,key)
      return {key,start,end,delta:start===null||end===null?null:end-start}
    })
  },[earliest,latest,group])
  const changes=progression.filter(x=>x.delta!==null)
  const sorted=[...changes].sort((a,b)=>(b.delta ?? 0)-(a.delta ?? 0))
  const biggest=sorted[0],smallest=sorted[sorted.length-1]
  const selected=progression.find(x=>x.key===skill)
  const chooseGroup=(next:Group)=>{
    setGroup(next)
    setSkill(groups[next][0])
  }
  const skillLabel=(key:SkillKey)=>t('developmentPremium.attributes.'+key)
  const signed=(n:number|null)=>n===null?'—':`${n>0?'+':''}${n.toFixed(1)}`
  return (
    <section className="tlg-pdi" aria-label={t('developmentPremium.title')}>
      <header className="tlg-pdi-head">
        <div>
          <span className="tlg-pdi-kicker"><Crown size={15} aria-hidden="true" /> {t('developmentPremium.kicker')}</span>
          <h2>{t('developmentPremium.title')}</h2>
          <p>{t('developmentPremium.intro')}</p>
        </div>
        <button type="button" className="tlg-pdi-toggle"
          aria-expanded={expanded} aria-controls="tlg-player-development-body"
          onClick={() => setExpanded(value => !value)}>
          {expanded ? toggle.hide : toggle.show}
          {expanded ? <ChevronUp size={16} aria-hidden="true"/> : <ChevronDown size={16} aria-hidden="true"/>}
        </button>
      </header>
      <div id="tlg-player-development-body" hidden={!expanded}>
        {expanded && <>
      {checkingPremium || loading ? <p className="tlg-pdi-state">{t('developmentPremium.loading')}</p>
      : !isPremium ? (
        <div className="tlg-pdi-lock">
          <LockKeyhole size={23} aria-hidden="true" />
          <p>{t('developmentPremium.locked')}</p>
          <Link to="/game/pro-packages">{t('developmentPremium.viewPlans')}</Link>
        </div>
      ) : loadError ? <p className="tlg-pdi-state" role="alert">{t('developmentPremium.error')}</p>
      : history.length===0 ? <p className="tlg-pdi-state">{t('developmentPremium.noHistory')}</p>
      : (
        <div className="tlg-pdi-body">
          <div className="tlg-pdi-overview">
            <div><span>{t('developmentPremium.snapshots')}</span><strong>{report?.total_snapshots ?? history.length}</strong></div>
            <div><span>{t('developmentPremium.weeksShown')}</span><strong>{weeklyHistory.length}</strong></div>
            <div><span>{t('developmentPremium.period')}</span><strong>{earliest ? gameWeekText(earliest,t) : '—'}</strong></div>
          </div>
          {report?.window_limited && <p className="tlg-pdi-notice">{t('developmentPremium.limited')}</p>}
          {(report?.game_dated_snapshots ?? 0) < history.length && <p className="tlg-pdi-notice">{t('developmentPremium.undatedHistory')}</p>}
          <div className="tlg-pdi-controls">
            <div className="tlg-pdi-tabs" role="group" aria-label={t('developmentPremium.chooseGroup')}>
              {(['technical','physical','condition'] as const).map(value=>(
                <button key={value} type="button" aria-pressed={group===value} className={group===value?'selected':''}
                  onClick={()=>chooseGroup(value)}>{t('developmentPremium.groups.'+value)}</button>
              ))}
            </div>
            <label>{t('developmentPremium.selectSkill')}
              <select value={skill} onChange={e=>setSkill(e.target.value as SkillKey)}>
                {groups[group].map(key=><option key={key} value={key}>{skillLabel(key)}</option>)}
              </select>
            </label>
          </div>
          {earliest && latest && weeklyHistory.length>1 ? (
            <>
              <div className="tlg-pdi-selected">
                <span>{skillLabel(skill)}</span>
                <strong>{selected?.end?.toFixed(1) ?? '—'} <small>/ 100</small></strong>
                <em className={(selected?.delta ?? 0)>=0?'positive':'negative'}>{signed(selected?.delta??null)}</em>
              </div>
              <Timeline rows={weeklyHistory} skill={skill} label={t('developmentPremium.chartAria',{skill:skillLabel(skill)})} />
              <div className="tlg-pdi-highlights">
                <div><TrendingUp size={16} aria-hidden="true"/><span>{t('developmentPremium.biggestGain')}</span><strong>{biggest ? `${skillLabel(biggest.key)} · ${signed(biggest.delta)}` : '—'}</strong></div>
                <div><span>{t('developmentPremium.slowest')}</span><strong>{smallest ? `${skillLabel(smallest.key)} · ${signed(smallest.delta)}` : '—'}</strong></div>
              </div>
              <div className="tlg-pdi-table-wrap">
                <table>
                  <thead><tr><th>{t('developmentPremium.attribute')}</th><th>{t('developmentPremium.first')}</th><th>{t('developmentPremium.latest')}</th><th>{t('developmentPremium.change')}</th></tr></thead>
                  <tbody>{progression.map(item=>(
                    <tr key={item.key}><th scope="row">{skillLabel(item.key)}</th><td>{item.start?.toFixed(1)??'—'}</td><td>{item.end?.toFixed(1)??'—'}</td><td>{signed(item.delta)}</td></tr>
                  ))}</tbody>
                </table>
              </div>
              {group!=='condition' && progression.every(item=>item.delta===0) && <p className="tlg-pdi-notice">{t('developmentPremium.noLevels')}</p>}
              <p className="tlg-pdi-note">{t('developmentPremium.disclaimer')}</p>
            </>
          ) : <p className="tlg-pdi-state">{t('developmentPremium.oneSnapshot')}</p>}
        </div>
      )}
        </>}
      </div>
    </section>
  )
}
