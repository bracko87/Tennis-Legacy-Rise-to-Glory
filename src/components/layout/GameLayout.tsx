/**
 * GameLayout.tsx
 *
 * Shared layout wrapper for all in-game dashboard routes under /game.
 * Provides the common header, retractable sidebar and global footer
 * while enforcing the premium management UI structure.
 */

import type { ReactNode } from 'react'
import { useState } from 'react'
import GameHeader from './GameHeader'
import GameSidebar from './GameSidebar'
import GameFooter from './GameFooter'

/**
 * Props for the GameLayout component.
 */
export interface GameLayoutProps {
  /** Current page title shown in the game header. */
  title: string
  /** Optional subtitle / description for the header. */
  subtitle?: string
  /** Page content rendered within the main area. */
  children: ReactNode
}

/**
 * Renders the in-game layout with shared header, sidebar and footer.
 */
export default function GameLayout({
  title,
  subtitle,
  children,
}: GameLayoutProps) {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [sidebarMobileOpen, setSidebarMobileOpen] = useState(false)

  return (
    <div className="tlg-game-shell">
      <GameHeader
        title={title}
        subtitle={subtitle}
        onToggleSidebarMobile={() =>
          setSidebarMobileOpen((open) => !open)
        }
      />
      <div className="tlg-game-body">
        <GameSidebar
          isCollapsed={sidebarCollapsed}
          onToggleCollapse={() =>
            setSidebarCollapsed((collapsed) => !collapsed)
          }
          isMobileOpen={sidebarMobileOpen}
          onMobileClose={() => setSidebarMobileOpen(false)}
        />
        <div className="tlg-game-main">
          <main className="tlg-game-main-inner">
            {children}
          </main>
          <GameFooter />
        </div>
      </div>
    </div>
  )
}