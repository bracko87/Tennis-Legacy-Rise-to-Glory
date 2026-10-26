import { Bell, BookOpen, Check, ChevronRight, GraduationCap, Languages, LayoutGrid, RotateCcw, ShieldCheck, SlidersHorizontal } from 'lucide-react'
import { notificationTemplateKey } from '../../i18n/notificationLocalization'
import { useCallback, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import TravelPreferenceSettings from '../../components/private-life/TravelPreferenceSettings'
import '../../styles/private-life-career.css'
import CountryFlag from '../../components/common/CountryFlag'
import { ENABLED_LOCALES, type AppLocale } from '../../i18n'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { useGamePreferences, type TableDensity } from '../../preferences/GamePreferencesProvider'
import { useTutorial } from '../../tutorial/TutorialProvider'
import { supabase } from '../../lib/supabase'
import '../../styles/game-preferences.css'

const LANGUAGE_LABEL_KEYS: Record<AppLocale,string> = {
  en:'common.english',sr:'settings.serbianLatin',de:'common.german',
  es:'common.spanish',it:'common.italian',fr:'common.french',
  ru:'common.russian',pt:'common.portuguese',
}
const LANGUAGE_FLAG_CODES: Record<AppLocale,string> = {
  en:'GB',sr:'RS',de:'DE',es:'ES',it:'IT',fr:'FR',ru:'RU',pt:'PT',
}
type Notice = {kind:'success'|'error';message:string}
type NotificationType = {
  code:string
  label:string
  description:string
  trigger:string
  condition:string
  mechanism:string
  severity:'info'|'success'|'warning'|'error'
  configurable:boolean
  enabled:boolean
  default_enabled:boolean
}
type NotificationGroup = {
  category:string
  total:number
  optional_count:number
  required_count:number
  enabled_count:number
  all_optional_enabled:boolean
  mixed:boolean
  items:NotificationType[]
}

const CATEGORY_ORDER = [
  'account','tournament','training','player_development','player_condition','player_health','equipment',
  'private_life','national_team','travel','club',
]

export default function GamePreferencesPage() {
  const {t}=useTranslation()
  const {user}=useAuth()
  const {locale,setLocale,saving:languageSaving,loading:languageLoading}=useLocalization()
  const {preferences,save:saveDisplay,loading:displayLoading,saving:displaySaving,error:displayError}=useGamePreferences()
  const {status:tutorialStatus,restartTutorial}=useTutorial()
  const [groups,setGroups]=useState<NotificationGroup[]>([])
  const [notificationsLoading,setNotificationsLoading]=useState(true)
  const [notificationError,setNotificationError]=useState<string|null>(null)
  const [savingCategory,setSavingCategory]=useState<string|null>(null)
  const [restoringDefaults,setRestoringDefaults]=useState(false)
  const [notice,setNotice]=useState<Notice|null>(null)

  const reloadNotifications=useCallback(async()=>{
    if(!user?.id){setGroups([]);setNotificationsLoading(false);return}
    const {data,error}=await supabase.rpc('get_my_notification_inventory_v2')
    if(error){setNotificationError(error.message);setNotificationsLoading(false);return}
    setGroups(Array.isArray(data)?data as NotificationGroup[]:[])
    setNotificationError(null)
    setNotificationsLoading(false)
  },[user?.id])

  useEffect(()=>{
    setNotificationsLoading(true)
    setNotificationError(null)
    void reloadNotifications()
  },[reloadNotifications])

  async function changeLanguage(next:AppLocale){
    if(next===locale||languageSaving||languageLoading) return
    setNotice(null)
    const saved=await setLocale(next)
    setNotice({kind:saved?'success':'error',message:t(saved?'preferencesCenter.saved':'preferencesCenter.saveError')})
  }

  async function changeDisplay(patch:{table_density?:TableDensity;reduce_animations?:boolean}){
    if(displaySaving||displayLoading)return
    setNotice(null)
    const saved=await saveDisplay(patch)
    setNotice({kind:saved?'success':'error',message:t(saved?'preferencesCenter.saved':'preferencesCenter.saveError')})
  }

  async function toggleCategory(row:NotificationGroup){
    if(savingCategory||notificationsLoading||restoringDefaults||row.optional_count===0)return
    const enabled=!row.all_optional_enabled
    setSavingCategory(row.category)
    setNotice(null)
    const {error}=await supabase.rpc('set_my_notification_category_enabled_v1',{
      p_category:row.category,p_enabled:enabled,
    })
    if(error){
      setNotice({kind:'error',message:t('preferencesCenter.saveError')})
      setNotificationError(error.message)
    }else{
      await reloadNotifications()
      setNotice({kind:'success',message:t('preferencesCenter.saved')})
    }
    setSavingCategory(null)
  }

  async function toggleType(item:NotificationType){
    if(savingCategory||notificationsLoading||restoringDefaults||!item.configurable)return
    setSavingCategory(item.code)
    setNotice(null)
    const {error}=await supabase.rpc('set_my_notification_type_enabled_v1',{
      p_code:item.code,p_enabled:!item.enabled,
    })
    if(error){
      setNotice({kind:'error',message:t('preferencesCenter.saveError')})
      setNotificationError(error.message)
    }else{
      await reloadNotifications()
      setNotice({kind:'success',message:t('preferencesCenter.saved')})
    }
    setSavingCategory(null)
  }

  async function restoreNotificationDefaults(){
    if(savingCategory||restoringDefaults||notificationsLoading)return
    setRestoringDefaults(true)
    setNotice(null)
    const {error}=await supabase.rpc('restore_my_notification_defaults_v1')
    if(error){
      setNotice({kind:'error',message:t('preferencesCenter.saveError')})
      setNotificationError(error.message)
    }else{
      await reloadNotifications()
      setNotice({kind:'success',message:t('preferencesCenter.restored')})
    }
    setRestoringDefaults(false)
  }

  function localizedNotificationName(item:NotificationType){
    const template=t('notifications.templates.'+notificationTemplateKey(item.code)+'.title',{defaultValue:''})
    return template && !template.includes('{{') ? template : item.label
  }

  function localizedNotificationDescription(item:NotificationType){
    const translated=t('notifications.templates.'+notificationTemplateKey(item.code)+'.message',{defaultValue:''})
    return translated && !translated.includes('{{') ? translated : item.description
  }

  const orderedGroups=[...groups].sort((a,b)=>{
    const ia=CATEGORY_ORDER.indexOf(a.category)
    const ib=CATEGORY_ORDER.indexOf(b.category)
    return (ia<0?100:ia)-(ib<0?100:ib)||a.category.localeCompare(b.category)
  })

  return (
    <GameLayout title={t('preferencesCenter.title')} subtitle={t('preferencesCenter.subtitle')}>
      <div className="tlg-preferences-page">
        <header className="tlg-preferences-intro">
          <span>{t('preferencesCenter.eyebrow')}</span>
          <h2>{t('preferencesCenter.heading')}</h2>
          <p>{t('preferencesCenter.intro')}</p>
          {notice && <div className={`tlg-language-message ${notice.kind}`} role="status">
            {notice.kind==='success'&&<Check size={15} aria-hidden="true"/>}{notice.message}
          </div>}
        </header>

        <TravelPreferenceSettings />

        <section className="tlg-preferences-section">
          <header className="tlg-preferences-section-head">
            <div>
              <span>{t('preferencesCenter.general')}</span>
              <h3>{t('preferencesCenter.language')}</h3>
              <p>{t('preferencesCenter.languageDescription')}</p>
            </div>
            <Languages size={21} aria-hidden="true"/>
          </header>
          <div className="tlg-language-grid" role="radiogroup" aria-label={t('preferencesCenter.language')}>
            {ENABLED_LOCALES.map(code=>(
              <button key={code} type="button" role="radio" aria-checked={locale===code}
                className={`tlg-language-option ${locale===code?'active':''}`}
                disabled={languageLoading||languageSaving}
                onClick={()=>void changeLanguage(code)}>
                <CountryFlag countryCode={LANGUAGE_FLAG_CODES[code]} countryName={t(LANGUAGE_LABEL_KEYS[code])} />
                <span><strong>{t(LANGUAGE_LABEL_KEYS[code])}</strong>
                  <small>{locale===code?t('preferencesCenter.selected'):t('preferencesCenter.available')}</small></span>
                <em>{code.toUpperCase()}</em>
              </button>
            ))}
          </div>
          <p className="tlg-language-note">{t('preferencesCenter.localeTimeNote')}</p>
        </section>

        <section className="tlg-preferences-section">
          <header className="tlg-preferences-section-head">
            <div>
              <span>{t('preferencesCenter.notifications')}</span>
              <h3>{t('preferencesCenter.inGame')}</h3>
              <p>{t('preferencesCenter.notificationsIntro')}</p>
            </div>
            <Bell size={21} aria-hidden="true"/>
          </header>
          <div className="tlg-preferences-section-body">
            <div className="tlg-preferences-channel">
              <span className="tlg-preferences-channel-dot" aria-hidden="true"/>
              <div><strong>{t('preferencesCenter.inGameActive')}</strong>
                <small>{t('preferencesCenter.deliveryNote')}</small></div>
            </div>
            {notificationsLoading?<p className="tlg-pref-help">{t('preferencesCenter.loading')}</p>
            :orderedGroups.length===0?<p className="tlg-pref-help">{t('preferencesCenter.noGroups')}</p>
            :<div className="tlg-pref-notification-groups">
              <div className="tlg-pref-notification-actions">
                <p>{t('preferencesCenter.notificationInventory',{count:orderedGroups.reduce((sum,group)=>sum+group.total,0)})}</p>
                <button className="tlg-pref-action" type="button"
                  disabled={savingCategory!==null||restoringDefaults}
                  onClick={()=>void restoreNotificationDefaults()}>
                  <RotateCcw size={16} aria-hidden="true"/>{t('preferencesCenter.restoreDefaults')}
                </button>
              </div>
              {orderedGroups.map(group=>(
                <div className="tlg-pref-notification-group" key={group.category}>
                  <div className="tlg-pref-notification-group-header">
                    <div className="tlg-pref-option-copy">
                      <strong>{t(`preferencesCenter.categories.${group.category}`,{defaultValue:group.category.replaceAll('_',' ')})}</strong>
                      <small>{t('preferencesCenter.optionalsCount',{count:group.optional_count})}
                        {' · '}{t('preferencesCenter.requiredCount',{count:group.required_count})}
                        {group.mixed?` · ${t('preferencesCenter.mixed')}`:''}</small>
                    </div>
                    {group.optional_count>0 ? (
                      <button type="button" role="switch"
                        className={`tlg-pref-switch ${group.all_optional_enabled?'on':''}`}
                        aria-checked={group.all_optional_enabled}
                        aria-label={t('preferencesCenter.toggleCategory',{category:t(`preferencesCenter.categories.${group.category}`,{defaultValue:group.category})})}
                        disabled={savingCategory!==null||restoringDefaults}
                        onClick={()=>void toggleCategory(group)}><span aria-hidden="true"/></button>
                    ):(
                      <span className="tlg-pref-required-chip"><ShieldCheck size={14}/>{t('preferencesCenter.required')}</span>
                    )}
                  </div>
                  <details className="tlg-pref-notification-details">
                    <summary>{t('preferencesCenter.reviewTypes',{count:group.total})}</summary>
                    <div className="tlg-pref-notification-types">
                      {group.items.map(item=>(
                        <div className="tlg-pref-notification-type" key={item.code}>
                          <div className="tlg-pref-option-copy">
                            <strong>{localizedNotificationName(item)}</strong>
                            <small>{localizedNotificationDescription(item)}</small>
                            <small className="tlg-pref-event-trigger">{t('preferencesCenter.trigger')}: {item.trigger}</small>
                            <span className="tlg-pref-severity">{t('notifications.severity.'+item.severity,{defaultValue:item.severity})}
                              {' · '}{item.configurable?t('preferencesCenter.optional'):t('preferencesCenter.required')}</span>
                          </div>
                          {item.configurable ? (
                            <button type="button" role="switch"
                              className={`tlg-pref-switch ${item.enabled?'on':''}`}
                              aria-checked={item.enabled}
                              aria-label={t('preferencesCenter.toggleType',{name:localizedNotificationName(item)})}
                              disabled={savingCategory!==null||restoringDefaults}
                              onClick={()=>void toggleType(item)}><span aria-hidden="true"/></button>
                          ):(
                            <span className="tlg-pref-required-chip"><ShieldCheck size={14}/>{t('preferencesCenter.required')}</span>
                          )}
                        </div>
                      ))}
                    </div>
                  </details>
                </div>
              ))}
            </div>}
            {notificationError&&<p className="tlg-pref-error" role="alert">{t('preferencesCenter.notificationError')} {notificationError}</p>}
            <div className="tlg-preferences-essential">
              <ShieldCheck size={20} aria-hidden="true"/>
              <p><strong>{t('preferencesCenter.essentialTitle')}</strong> {t('preferencesCenter.essentialDescription')}</p>
            </div>
          </div>
        </section>

        <section className="tlg-preferences-section">
          <header className="tlg-preferences-section-head">
            <div><span>{t('preferencesCenter.interface')}</span>
              <h3>{t('preferencesCenter.display')}</h3>
              <p>{t('preferencesCenter.displayDescription')}</p></div>
            <LayoutGrid size={21} aria-hidden="true"/>
          </header>
          <div className="tlg-preferences-section-body">
            <div className="tlg-pref-group-title">{t('preferencesCenter.tableDensity')}</div>
            <div className="tlg-pref-choice-grid" role="radiogroup" aria-label={t('preferencesCenter.tableDensity')}>
              {(['comfortable','compact'] as const).map(value=>(
                <button key={value} type="button" role="radio" aria-checked={preferences.table_density===value}
                  className={`tlg-pref-choice ${preferences.table_density===value?'active':''}`}
                  disabled={displaySaving||displayLoading}
                  onClick={()=>void changeDisplay({table_density:value})}>
                  <strong>{t(`preferencesCenter.${value}`)}</strong>
                  <small>{t(`preferencesCenter.${value}Detail`)}</small>
                </button>
              ))}
            </div>
            <div className="tlg-pref-option-row motion">
              <div className="tlg-pref-option-copy">
                <strong>{t('preferencesCenter.reduceAnimations')}</strong>
                <small>{t('preferencesCenter.reduceAnimationsDescription')}</small>
              </div>
              <button type="button" role="switch" aria-checked={preferences.reduce_animations}
                aria-label={t('preferencesCenter.reduceAnimations')}
                className={`tlg-pref-switch ${preferences.reduce_animations?'on':''}`}
                disabled={displaySaving||displayLoading}
                onClick={()=>void changeDisplay({reduce_animations:!preferences.reduce_animations})}><span aria-hidden="true"/></button>
            </div>
            {displayError&&<p className="tlg-pref-error" role="alert">{displayError}</p>}
          </div>
        </section>

        <section className="tlg-preferences-section">
          <header className="tlg-preferences-section-head">
            <div><span>{t('preferencesCenter.tutorialHelp')}</span>
              <h3>{t('preferencesCenter.tutorialTitle')}</h3>
              <p>{t('preferencesCenter.tutorialIntro')}</p></div>
            <GraduationCap size={21} aria-hidden="true"/>
          </header>
          <div className="tlg-preferences-section-body">
            <div className="tlg-pref-actions">
              <button type="button" className="tlg-pref-action primary"
                disabled={tutorialStatus==='loading'}
                onClick={()=>void restartTutorial()}>
                <GraduationCap size={18}/>{t('preferencesCenter.restartTutorial')}
              </button>
              <Link className="tlg-pref-action" to="/game/help">
                <BookOpen size={18}/>{t('preferencesCenter.openHelp')}<ChevronRight size={16}/>
              </Link>
              <Link className="tlg-pref-action" to="/game/manual">
                <SlidersHorizontal size={18}/>{t('preferencesCenter.openManual')}<ChevronRight size={16}/>
              </Link>
            </div>
            <p className="tlg-pref-help">{t('preferencesCenter.tutorialNote')}</p>
          </div>
        </section>
        <p className="tlg-preferences-footnote">{t('preferencesCenter.accountSync')}</p>
      </div>
    </GameLayout>
  )
}
