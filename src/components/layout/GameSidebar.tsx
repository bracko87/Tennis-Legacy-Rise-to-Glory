/**
 * GameSidebar.tsx
 *
 * Premium retractable navigation for the Tennis Legacy manager center.
 */

import { Link, useLocation } from 'react-router'
import {
  Activity,
  BarChart3,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  CircleDollarSign,
  Clock3,
  LayoutDashboard,
  Shield,
  Sparkles,
} from 'lucide-react'
import clsx from 'clsx'

export interface GameSidebarProps {
  isCollapsed: boolean
  onToggleCollapse: () => void
  isMobileOpen: boolean
  onMobileClose: () => void
}

interface NavItem {
  key: string
  label: string
  description: string
  to: string
  icon: JSX.Element
}

export default function GameSidebar({
  isCollapsed,
  onToggleCollapse,
  isMobileOpen,
  onMobileClose,
}: GameSidebarProps) {
  const location = useLocation()

  const items: NavItem[] = [
    { key: 'overview', label: 'Overview', description: 'Career command center', to: '/game/overview', icon: <LayoutDashboard className="h-4 w-4" /> },
    { key: 'skills', label: 'Skills', description: 'Player development', to: '/game/skills', icon: <Activity className="h-4 w-4" /> },
    { key: 'calendar', label: 'Calendar', description: 'Season planning', to: '/game/calendar', icon: <CalendarDays className="h-4 w-4" /> },
    { key: 'schedule', label: 'Schedule', description: 'Events and commitments', to: '/game/schedule', icon: <Clock3 className="h-4 w-4" /> },
    { key: 'finance', label: 'Finance', description: 'Career economy', to: '/game/finance', icon: <CircleDollarSign className="h-4 w-4" /> },
    { key: 'equipment', label: 'Equipment', description: 'Performance gear', to: '/game/equipment', icon: <Shield className="h-4 w-4" /> },
    { key: 'statistics', label: 'Statistics', description: 'Career analytics', to: '/game/statistics', icon: <BarChart3 className="h-4 w-4" /> },
  ]

  const sidebarClasses = clsx(
    'tlg-sidebar fixed inset-y-0 left-0 z-50 flex flex-col transition-all duration-200 ease-out lg:static lg:translate-x-0',
    isCollapsed && 'tlg-sidebar-collapsed',
    !isMobileOpen && 'translate-x-[-100%] lg:translate-x-0',
  )

  return (
    <>
      <div
        className={clsx(
          'fixed inset-0 z-40 bg-[rgba(0,0,0,.62)] backdrop-blur-sm transition-opacity duration-200 lg:hidden',
          isMobileOpen ? 'pointer-events-auto opacity-100' : 'pointer-events-none opacity-0',
        )}
        onClick={onMobileClose}
      />

      <aside className={sidebarClasses}>
        <div className="flex min-h-[72px] items-center justify-between border-b border-[rgba(112,168,213,.08)] px-3">
          <div className="flex min-w-0 items-center gap-2.5">
            <span className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl border border-[rgba(94,177,235,.15)] bg-[linear-gradient(145deg,#0a69bb,#053663)] text-white shadow-[0_10px_24px_rgba(3,78,144,.22)]">
              <Sparkles size={16} />
            </span>
            {!isCollapsed && (
              <div className="min-w-0 leading-tight">
                <p className="truncate text-[0.72rem] font-bold text-[color:#d9e8f5]">Tennis Legacy</p>
                <p className="mt-0.5 truncate text-[0.56rem] uppercase tracking-[.12em] text-[color:#536f86]">Manager Center</p>
              </div>
            )}
          </div>

          <button
            type="button"
            onClick={onToggleCollapse}
            className="hidden h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-[rgba(112,168,213,.09)] bg-[rgba(8,25,42,.72)] text-[color:#607d94] transition hover:border-[rgba(82,172,237,.22)] hover:text-white lg:inline-flex"
            aria-label={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            {isCollapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
          </button>
        </div>

        {!isCollapsed && (
          <div className="px-3 pb-1 pt-4">
            <span className="text-[0.56rem] font-extrabold uppercase tracking-[.15em] text-[color:#46647c]">Career operations</span>
          </div>
        )}

        <nav className="flex-1 space-y-1 overflow-y-auto px-2 py-2">
          {items.map((item) => {
            const active = location.pathname === item.to
            return (
              <Link
                key={item.key}
                to={item.to}
                onClick={onMobileClose}
                className={clsx('tlg-sidebar-nav-link', active && 'tlg-sidebar-nav-link-active')}
                title={isCollapsed ? item.label : undefined}
              >
                <span className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg">{item.icon}</span>
                {!isCollapsed && (
                  <span className="min-w-0 flex-1 leading-tight">
                    <strong className="block truncate text-[0.74rem] font-semibold">{item.label}</strong>
                    <small className="mt-0.5 block truncate text-[0.57rem] font-normal text-[color:#526e84]">{item.description}</small>
                  </span>
                )}
              </Link>
            )
          })}
        </nav>

        <div className="border-t border-[rgba(112,168,213,.08)] p-3">
          {!isCollapsed ? (
            <div className="rounded-xl border border-[rgba(90,162,217,.09)] bg-[rgba(7,28,47,.48)] p-3">
              <div className="flex items-center gap-2 text-[0.61rem] font-semibold text-[color:#83badf]">
                <span className="h-1.5 w-1.5 rounded-full bg-[color:#42c779] shadow-[0_0_0_4px_rgba(66,199,121,.08)]" />
                Career world online
              </div>
              <p className="mt-1.5 text-[0.57rem] leading-relaxed text-[color:#526e84]">
                Player identity and account data are synchronized with Tennis Legacy servers.
              </p>
            </div>
          ) : (
            <div className="mx-auto h-2 w-2 rounded-full bg-[color:#42c779] shadow-[0_0_0_4px_rgba(66,199,121,.08)]" title="Career world online" />
          )}
        </div>
      </aside>
    </>
  )
}
