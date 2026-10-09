import type { ReactNode } from 'react'
import { useEffect, useState } from 'react'

import '../../styles/dashboard-v3.css'
import '../../styles/dashboard-v4.css'
import '../../styles/dashboard-v5.css'
import '../../styles/dashboard-v6.css'
import '../../styles/commerce.css'
import '../../styles/cpx-rewards.css'
import { getReferralBrowserHash } from '../../lib/referrals'
import { supabase } from '../../lib/supabase'
import EarnCoinsDialog from '../rewards/EarnCoinsDialog'
import GameFooter from './GameFooter'
import GameHeader from './GameHeader'
import GameSidebar from './GameSidebar'

export interface GameLayoutProps {
  title: string
  subtitle?: string
  children: ReactNode
}

export default function GameLayout({ title, subtitle, children }: GameLayoutProps) {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [sidebarMobileOpen, setSidebarMobileOpen] = useState(false)
  const [earnCoinsOpen, setEarnCoinsOpen] = useState(false)

  useEffect(() => {
    const openCoins = () => setEarnCoinsOpen(true)
    window.addEventListener('tlg:open-earn-coins', openCoins)
    return () => window.removeEventListener('tlg:open-earn-coins', openCoins)
  }, [])

  useEffect(() => {
    let active = true

    async function recordReferralActivity() {
      try {
        const browserHash = await getReferralBrowserHash()
        if (!active) return
        await supabase.rpc('record_referral_activity_v1', { p_browser_hash: browserHash })
      } catch {
        // Referral activity must never interrupt normal gameplay.
      }
    }

    void recordReferralActivity()
    return () => { active = false }
  }, [])

  return (
    <div className="tlg-v2-shell">
      <GameSidebar
        isCollapsed={sidebarCollapsed}
        onToggleCollapse={() => setSidebarCollapsed((value) => !value)}
        isMobileOpen={sidebarMobileOpen}
        onMobileClose={() => setSidebarMobileOpen(false)}
      />

      <div className="tlg-v2-workspace">
        <GameHeader
          title={title}
          subtitle={subtitle}
          onToggleSidebarMobile={() => setSidebarMobileOpen((value) => !value)}
        />

        <main
          className="tlg-v2-content"
          data-tutorial-page-content
          data-tutorial-page-title={title}
        >
          {children}
        </main>

        <GameFooter />
        <EarnCoinsDialog open={earnCoinsOpen} onClose={() => setEarnCoinsOpen(false)} />
      </div>
    </div>
  )
}
