import clsx from 'clsx'
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
  Trophy,
} from 'lucide-react'
import { Link, useLocation } from 'react-router'

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

const items: NavItem[] = [
  { key: 'overview', label: 'Overview', description: 'Career command center', to: '/game/overview', icon: <LayoutDashboard size={17} /> },
  { key: 'skills', label: 'Skills', description: 'Development & training', to: '/game/skills', icon: <Activity size={17} /> },
  { key: 'calendar', label: 'Calendar', description: 'Season planning', to: '/game/calendar', icon: <CalendarDays size={17} /> },
  { key: 'schedule', label: 'Schedule', description: 'Events & commitments', to: '/game/schedule', icon: <Clock3 size={17} /> },
  { key: 'finance', label: 'Finance', description: 'Career economy', to: '/game/finance', icon: <CircleDollarSign size={17} /> },
  { key: 'equipment', label: 'Equipment', description: 'Performance gear', to: '/game/equipment', icon: <Shield size={17} /> },
  { key: 'statistics', label: 'Statistics', description: 'Results & analytics', to: '/game/statistics', icon: <BarChart3 size={17} /> },
]

export default function GameSidebar({
  isCollapsed,
  onToggleCollapse,
  isMobileOpen,
  onMobileClose,
}: GameSidebarProps) {
  const location = useLocation()

  return (
    <>
      <div
        className={clsx(
          'tlg-v2-mobile-backdrop',
          !isMobileOpen && 'tlg-v2-mobile-backdrop-hidden',
        )}
        onClick={onMobileClose}
        aria-hidden="true"
      />

      <aside
        className={clsx(
          'tlg-v2-sidebar',
          isCollapsed && 'tlg-v2-sidebar-collapsed',
          !isMobileOpen && 'tlg-v2-sidebar-mobile-closed',
        )}
      >
        <div className="tlg-v2-sidebar-brand">
          <span className="tlg-v2-brand-mark" aria-hidden="true">
            <Trophy size={18} />
          </span>

          {!isCollapsed && (
            <div className="tlg-v2-brand-copy">
              <strong>Tennis Legacy</strong>
              <span>Rise to Glory</span>
            </div>
          )}
        </div>

        <button
          type="button"
          className="tlg-v2-sidebar-collapse"
          onClick={onToggleCollapse}
          aria-label={isCollapsed ? 'Expand navigation' : 'Collapse navigation'}
          title={isCollapsed ? 'Expand navigation' : 'Collapse navigation'}
        >
          {isCollapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
        </button>

        {!isCollapsed && <div className="tlg-v2-nav-label">Manager center</div>}

        <nav className="tlg-v2-nav" aria-label="Game navigation">
          {items.map((item) => {
            const active = location.pathname === item.to

            return (
              <Link
                key={item.key}
                to={item.to}
                onClick={onMobileClose}
                className={clsx(
                  'tlg-v2-nav-link',
                  active && 'tlg-v2-nav-link-active',
                )}
                title={isCollapsed ? item.label : undefined}
                aria-current={active ? 'page' : undefined}
              >
                <span className="tlg-v2-nav-icon">{item.icon}</span>

                {!isCollapsed && (
                  <span className="tlg-v2-nav-copy">
                    <strong>{item.label}</strong>
                    <small>{item.description}</small>
                  </span>
                )}
              </Link>
            )
          })}
        </nav>

        <div className="tlg-v2-sidebar-footer">
          {!isCollapsed ? (
            <div className="tlg-v2-server-card">
              <div className="tlg-v2-server-line">
                <span className="tlg-v2-status-dot" />
                Career world online
              </div>
              <p>Account and player identity are synchronized with Tennis Legacy servers.</p>
            </div>
          ) : (
            <div className="flex justify-center py-2" title="Career world online">
              <span className="tlg-v2-status-dot" />
            </div>
          )}
        </div>
      </aside>
    </>
  )
}
