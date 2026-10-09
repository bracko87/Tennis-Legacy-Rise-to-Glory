import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useNavigate, useParams } from 'react-router'

import { supabase } from '../lib/supabase'
import { getReferralBrowserHash, storeReferralCode } from '../lib/referrals'

export default function ReferralLandingPage() {
  const { t } = useTranslation()
  const { code } = useParams()
  const navigate = useNavigate()
  const [message, setMessage] = useState(() => t('referralLanding.saving'))

  useEffect(() => {
    let active = true

    async function captureReferral() {
      const normalizedCode = (code ?? '').trim().toUpperCase()
      if (!normalizedCode) {
        navigate('/', { replace: true })
        return
      }

      const browserHash = await getReferralBrowserHash()
      const { data, error } = await supabase.rpc('register_referral_click_v1', {
        p_code: normalizedCode,
        p_browser_hash: browserHash,
      })

      if (!active) return

      if (!error && data === true) {
        storeReferralCode(normalizedCode)
        setMessage(t('referralLanding.saved'))
        window.setTimeout(() => navigate('/register', { replace: true }), 650)
        return
      }

      setMessage(t('referralLanding.invalid'))
      window.setTimeout(() => navigate('/', { replace: true }), 650)
    }

    void captureReferral()
    return () => { active = false }
  }, [code, navigate, t])

  return (
    <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', background: '#07192a', color: '#fff', padding: 24 }}>
      <div style={{ textAlign: 'center' }}>
        <strong style={{ display: 'block', fontSize: '1.1rem', marginBottom: 8 }}>Tennis Legacy</strong>
        <span style={{ color: '#9fbbd0', fontSize: '0.86rem' }}>{message}</span>
      </div>
    </div>
  )
}
