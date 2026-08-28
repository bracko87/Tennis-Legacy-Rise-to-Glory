import type { ReactNode } from 'react'
import { useState } from 'react'

import '../../styles/dashboard-v3.css'
import '../../styles/dashboard-v4.css'
import '../../styles/dashboard-v5.css'
import '../../styles/dashboard-v6.css'
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

        <main className="tlg-v2-content">
          {children}
        </main>

        <GameFooter />
      </div>
    </div>
  )
}
