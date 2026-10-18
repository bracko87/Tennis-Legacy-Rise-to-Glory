import { useEffect, useState } from 'react'
import { Check, Clock3, Crown, Gift, LockKeyhole, X } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useNavigate } from 'react-router'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'

/**
 * One-time, persisted across browsers/devices. The server owns both the
 * entitlement and the dismissed flags. Never infer Premium from localStorage.
 */
export default function WelcomePremiumTrial() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { trial, isPaidPremium, refresh } = useCommerce()
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    // Also processes the final-24-hour reminder when the tab stays open.
    const timer = window.setInterval(() => { void refresh() }, 15 * 60 * 1000)
    return () => window.clearInterval(timer)
  }, [refresh])

  if (isPaidPremium || (!trial?.show_welcome && !trial?.show_expired)) return null
  const welcome = trial.show_welcome === true
  const expires = trial.expires_at ? new Date(trial.expires_at) : null
  const expiryText = expires && Number.isFinite(expires.getTime())
    ? new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(expires)
    : '—'

  async function dismiss(goToPlans: boolean) {
    if (busy) return
    setBusy(true)
    const { error } = await supabase.rpc('get_my_tennis_premium_trial_v1', {
      p_action: welcome ? 'dismiss_welcome' : 'dismiss_expired',
    })
    setBusy(false)
    if (error) {
      console.error('Could not acknowledge Premium trial notice:', error.message)
      return
    }
    await refresh()
    if (goToPlans) navigate('/game/pro-packages')
  }

  return (
    <div role="presentation" className="fixed inset-0 z-[210] flex items-center justify-center bg-slate-950/70 p-3 sm:p-5">
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby="tlg-premium-trial-title"
        aria-describedby="tlg-premium-trial-description"
        className="w-full max-w-lg overflow-hidden rounded-2xl bg-white text-slate-900 shadow-2xl"
      >
        <div className="relative bg-amber-400 px-5 py-5 text-center sm:px-7">
          <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-white/85">
            {welcome ? <Gift size={26} aria-hidden="true" /> : <Clock3 size={26} aria-hidden="true" />}
          </div>
          <h2 id="tlg-premium-trial-title" className="text-xl font-bold">
            {t(welcome ? 'premiumTrial.welcomeTitle' : 'premiumTrial.expiredTitle')}
          </h2>
          <button
            type="button"
            aria-label={t('premiumTrial.close')}
            disabled={busy}
            onClick={() => { void dismiss(false) }}
            className="absolute right-3 top-3 rounded-md p-1 hover:bg-amber-300 disabled:opacity-50"
          ><X size={20} /></button>
        </div>
        <div className="max-h-[72vh] space-y-4 overflow-y-auto px-5 py-5 sm:px-7">
          <p id="tlg-premium-trial-description" className="text-sm leading-6 text-slate-700">
            {t(welcome ? 'premiumTrial.welcomeBody' : 'premiumTrial.expiredBody')}
          </p>
          {welcome && (
            <div className="flex items-center justify-between rounded-xl border border-amber-200 bg-amber-50 px-4 py-3">
              <span className="flex items-center gap-2 text-sm font-semibold"><Crown size={18} /> {t('premiumTrial.duration')}</span>
              <strong className="text-sm">{t('premiumTrial.until', { date: expiryText })}</strong>
            </div>
          )}
          <div className="space-y-3">
            <h3 className="text-sm font-bold">{t('premiumTrial.includesTitle')}</h3>
            <div className="flex gap-3 text-sm">
              <Check size={18} className="mt-0.5 shrink-0 text-emerald-700" aria-hidden="true" />
              <p>{t('premiumTrial.privateLife')}</p>
            </div>
            <div className="flex gap-3 text-sm">
              <Check size={18} className="mt-0.5 shrink-0 text-emerald-700" aria-hidden="true" />
              <p>{t('premiumTrial.rankingProtection')}</p>
            </div>
            <div className="flex gap-3 text-sm">
              <LockKeyhole size={18} className="mt-0.5 shrink-0 text-slate-500" aria-hidden="true" />
              <p>{t('premiumTrial.extraFeatures')}</p>
            </div>
          </div>
          <p className="rounded-lg bg-slate-100 px-4 py-3 text-xs leading-5 text-slate-700">
            {t('premiumTrial.noBilling')}
          </p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            <button
              type="button"
              disabled={busy}
              onClick={() => { void dismiss(true) }}
              className="rounded-lg border border-amber-500 bg-amber-400 px-4 py-3 text-sm font-semibold text-slate-900 hover:bg-amber-300 disabled:opacity-50"
            >{t(welcome ? 'premiumTrial.seeBenefits' : 'premiumTrial.viewPlans')}</button>
            <button
              type="button"
              disabled={busy}
              onClick={() => { void dismiss(false) }}
              className="rounded-lg bg-slate-900 px-4 py-3 text-sm font-semibold text-white hover:bg-slate-800 disabled:opacity-50"
            >{t(welcome ? 'premiumTrial.startPlaying' : 'premiumTrial.continueFree')}</button>
          </div>
        </div>
      </section>
    </div>
  )
}
