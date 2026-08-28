/**
 * GameSidebar.tsx
 *
 * Retractable sidebar navigation for all in-game dashboard routes.
 * Uses a near-black background with white text and dark-blue active states.
 */

import { Link, useLocation } from 'react-router'
import {
  Activity,
  BarChart2,
  CalendarDays,
  Clock3,
  DollarSign,
  LayoutDashboard,
  Shield,
} from 'lucide-react'
import clsx from 'clsx'

/**
 * Props for the GameSidebar component.
 */
export interface GameSidebarProps {
  /** Whether the sidebar is collapsed to icon-only mode on desktop. */
  isCollapsed: boolean
  /** Toggle the collapsed/expanded state on desktop. */
  onToggleCollapse: () => void
  /** Whether the mobile drawer is currently visible. */
  isMobileOpen: boolean
  /** Callback to close the sidebar drawer on mobile. */
  onMobileClose: () => void
}

/**
 * Navigation item configuration for sidebar links.
 */
interface NavItem {
  key: string
  label: string
  to: string
  icon: JSX.Element
}

/**
 * Renders the retractable in-game sidebar with navigation items.
 */
export default function GameSidebar({
  isCollapsed,
  onToggleCollapse,
  isMobileOpen,
  onMobileClose,
}: GameSidebarProps) {
  const location = useLocation()

  const items: NavItem[] = [
    {
      key: 'overview',
      label: 'Overview',
      to: '/game/overview',
      icon: <LayoutDashboard className="h-4 w-4" />,
    },
    {
      key: 'skills',
      label: 'Skills',
      to: '/game/skills',
      icon: <Activity className="h-4 w-4" />,
    },
    {
      key: 'calendar',
      label: 'Calendar',
      to: '/game/calendar',
      icon: <CalendarDays className="h-4 w-4" />,
    },
    {
      key: 'schedule',
      label: 'Schedule',
      to: '/game/schedule',
      icon: <Clock3 className="h-4 w-4" />,
    },
    {
      key: 'finance',
      label: 'Finance',
      to: '/game/finance',
      icon: <DollarSign className="h-4 w-4" />,
    },
    {
      key: 'equipment',
      label: 'Equipment',
      to: '/game/equipment',
      icon: <Shield className="h-4 w-4" />,
    },
    {
      key: 'statistics',
      label: 'Statistics',
      to: '/game/statistics',
      icon: <BarChart2 className="h-4 w-4" />,
    },
  ]

  const isActive = (to: string) => location.pathname === to

  const sidebarClasses = clsx(
    'tlg-sidebar fixed inset-y-0 left-0 z-50 flex flex-col border-r border-[rgba(15,23,42,0.95)] bg-[color:var(--tlg-sidebar-bg)] transition-transform duration-200 ease-out lg:static lg:translate-x-0',
    isCollapsed && 'tlg-sidebar-collapsed',
    !isMobileOpen && 'translate-x-[-100%] lg:translate-x-0',
  )

  return (
    <>
      {/* Mobile backdrop */}
      <div
        className={clsx(
          'fixed inset-0 z-40 bg-[rgba(0,0,0,0.55)] backdrop-blur-sm transition-opacity duration-200 ease-out lg:hidden',
          isMobileOpen
            ? 'pointer-events-auto opacity-100'
            : 'pointer-events-none opacity-0',
        )}
        onClick={onMobileClose}
      />

      <aside className={sidebarClasses}>
        <div className="flex h-14 items-center justify-between border-b border-[rgba(15,23,42,0.9)] px-3">
          <div className="flex items-center gap-2">
            <div className="inline-flex h-7 w-7 items-center justify-center rounded-md border border-[rgba(51,65,85,0.9)] bg-[rgba(15,23,42,0.95)]">
              <div className="h-3 w-3 rounded-full border border-[rgba(148,163,184,0.9)]" />
            </div>
            {!isCollapsed && (
              <div className="leading-tight">
                <p className="text-[0.7rem] uppercase tracking-[0.24em] text-[rgba(148,163,184,0.9)]">
                  Tennis Legacy
                </p>
                <p className="text-xs font-semibold text-[rgba(226,232,240,0.95)]">
                  Manager Center
                </p>
              </div>
            )}
          </div>
          <button
            type="button"
            onClick={onToggleCollapse}
            className="inline-flex h-7 w-7 items-center justify-center rounded-md border border-[rgba(51,65,85,0.9)] bg-[rgba(15,23,42,0.95)] text-[rgba(226,232,240,0.85)] hover:bg-[rgba(15,23,42,1)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[rgba(191,219,254,0.9)]"
            aria-label={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            <span className="text-[0.65rem]">
              {isCollapsed ? '»' : '«'}
            </span>
          </button>
        </div>

        <nav className="flex-1 space-y-1 overflow-y-auto px-2 py-3 text-sm">
          {items.map((item) => (
            <Link
              key={item.key}
              to={item.to}
              className={clsx(
                'tlg-sidebar-nav-link',
                isActive(item.to) && 'tlg-sidebar-nav-link-active',
              )}
              onClick={onMobileClose}
            >
              <span className="inline-flex h-8 w-8 items-center justify-center rounded-md bg-[rgba(15,23,42,0.9)] text-[rgba(226,232,240,0.92)]">
                {item.icon}
              </span>
              {!isCollapsed && <span>{item.label}</span>}
            </Link>
          ))}
        </nav>

        <div className="border-t border-[rgba(15,23,42,0.9)] px-3 py-3 text-[0.75rem] text-[rgba(148,163,184,0.9)]">
          {!isCollapsed && (
            <p className="leading-snug">
              All player data, leagues and financials will be managed via
              the central Tennis Legacy servers.
            </p>
          )}
        </div>
      </aside>
    </>
  )
}