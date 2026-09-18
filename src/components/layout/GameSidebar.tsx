import clsx from 'clsx'
import {
  Activity,
  BarChart3,
  Building2,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  CircleDollarSign,
  Clock3,
  Crown,
  Dumbbell,
  Gauge,
  LayoutDashboard,
  LogOut,
  MessageSquareQuote,
  Shield,
  Trophy,
  UsersRound,
} from 'lucide-react'
import { Link, useLocation, useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import BugReportButton from '../dashboard/BugReportButton'

const TENNIS_LEGACY_LOGO_URL = 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/logo%20333.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9sb2dvIDMzMy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg3OTQ1MDc5LCJleHAiOjQ5MTAwMDkwNzl9.Q7Ocay_B1kouWo_XmmgtVcGOCh0xtzhzaIm713AhU-ci-xJPY3JanaT3xhdkptAuKV5kUJGHov34fSM2TGjmcQ'

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
  premiumOnly?: boolean
}

const items: NavItem[] = [
  { key: 'overview', label: 'Overview', description: 'Career command center', to: '/game/overview', icon: <LayoutDashboard size={17} /> },
  { key: 'skills', label: 'Skills', description: 'Attributes & development', to: '/game/skills', icon: <Activity size={17} /> },
  { key: 'training', label: 'Training', description: 'Regular training & camps', to: '/game/training', icon: <Dumbbell size={17} /> },
  { key: 'staff', label: 'Staff', description: 'Coach & support team', to: '/game/staff', icon: <UsersRound size={17} /> },
  { key: 'calendar', label: 'Calendar', description: 'Season & tournaments', to: '/game/calendar', icon: <CalendarDays size={17} /> },
  { key: 'schedule', label: 'Schedule', description: 'Events & commitments', to: '/game/schedule', icon: <Clock3 size={17} /> },
  { key: 'rankings', label: 'Rankings', description: 'ATP / WTA singles', to: '/game/rankings', icon: <Trophy size={17} /> },
  { key: 'equipment', label: 'Equipment', description: 'Performance gear', to: '/game/equipment', icon: <Shield size={17} /> },
  { key: 'finance', label: 'Finance', description: 'Career economy', to: '/game/finance', icon: <CircleDollarSign size={17} /> },
  { key: 'private-life', label: 'Private Life', description: 'Premium career lifestyle', to: '/game/private-life', icon: <Crown size={17} />, premiumOnly: true },
  { key: 'tennis-club', label: 'Tennis Club', description: 'Shared club community', to: '/game/tennis-club', icon: <Building2 size={17} /> },
  { key: 'statistics', label: 'Statistics', description: 'Results & analytics', to: '/game/statistics', icon: <BarChart3 size={17} /> },
]

const adminItems: NavItem[] = [
  { key: 'admin-analytics', label: 'Analytics', description: 'Private traffic & activity', to: '/game/admin/analytics', icon: <Gauge size={17} /> },
  { key: 'admin-reviews', label: 'Player Reviews', description: 'Moderate homepage reviews', to: '/game/admin/reviews', icon: <MessageSquareQuote size={17} /> },
]

function pageLabelForPath(pathname: string) {
  const exact = [...items, ...adminItems].find((item) => item.to === pathname)
  if (exact) return exact.label
  if (pathname.startsWith('/game/players/')) return 'Player Profile'
  if (pathname.startsWith('/game/tournaments/')) return 'Tournament'
  if (pathname === '/game/inbox') return 'Manager Inbox'
  if (pathname === '/game/player-account') return 'Player & Account'
  if (pathname === '/game/preferences') return 'Game Preferences'
  if (pathname === '/game/help') return 'Help Center'
  if (pathname === '/game/forum') return 'Forum / Discord'
  if (pathname === '/game/contact') return 'Contact Us'
  if (pathname === '/game/invite-friends') return 'Invite Friends'
  if (pathname === '/game/notifications') return 'Notifications'
  if (pathname === '/game/pro-packages') return 'Pro Packages'
  return pathname.replace('/game/', '').replaceAll('-', ' ') || 'Game'
}

export default function GameSidebar({
  isCollapsed,
  onToggleCollapse,
  isMobileOpen,
  onMobileClose,
}: GameSidebarProps) {
  const location = useLocation()
  const navigate = useNavigate()
  const { signOut, isAdmin } = useAuth()
  const currentPageLabel = pageLabelForPath(location.pathname)

  async function handleSignOut() {
    try {
      await signOut()
    } finally {
      navigate('/login', { replace: true })
    }
  }

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
        <div className="tlg-v2-sidebar-brand tlg-v4-sidebar-brand">
          <img
            src={TENNIS_LEGACY_LOGO_URL}
            alt="Tennis Legacy: Rise to Glory"
            className="tlg-v4-logo-image"
            width="152"
            height="82"
            decoding="async"
          />
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
                  item.premiumOnly && 'tlg-v2-nav-link-premium',
                )}
                title={isCollapsed ? `${item.label}${item.premiumOnly ? ' · Premium' : ''}` : undefined}
                aria-current={active ? 'page' : undefined}
              >
                <span className="tlg-v2-nav-icon">{item.icon}</span>

                {!isCollapsed && (
                  <span className="tlg-v2-nav-copy">
                    <span className="tlg-v8-nav-title-line">
                      <strong>{item.label}</strong>
                      {item.premiumOnly && <em>Premium</em>}
                    </span>
                    <small>{item.description}</small>
                  </span>
                )}
              </Link>
            )
          })}
        </nav>

        {isAdmin && (
          <>
            {!isCollapsed && <div className="tlg-v2-nav-label">Administration</div>}
            <nav className="tlg-v2-nav" aria-label="Administration navigation">
              {adminItems.map((item) => {
                const active = location.pathname === item.to
                return (
                  <Link
                    key={item.key}
                    to={item.to}
                    onClick={onMobileClose}
                    className={clsx('tlg-v2-nav-link', active && 'tlg-v2-nav-link-active')}
                    title={isCollapsed ? item.label : undefined}
                    aria-current={active ? 'page' : undefined}
                  >
                    <span className="tlg-v2-nav-icon">{item.icon}</span>
                    {!isCollapsed && (
                      <span className="tlg-v2-nav-copy">
                        <span className="tlg-v8-nav-title-line"><strong>{item.label}</strong></span>
                        <small>{item.description}</small>
                      </span>
                    )}
                  </Link>
                )
              })}
            </nav>
          </>
        )}

        <div className="tlg-v2-sidebar-footer tlg-v4-sidebar-footer">
          <BugReportButton
            collapsed={isCollapsed}
            currentPageLabel={currentPageLabel}
            currentPath={location.pathname}
          />
          <button
            type="button"
            className="tlg-v4-signout-button"
            onClick={() => void handleSignOut()}
            title="Sign out"
          >
            <LogOut size={16} />
            {!isCollapsed && <span>Sign out</span>}
          </button>
          {!isCollapsed && <div className="tlg-v6-version">Version 1.0.0</div>}
        </div>
      </aside>
    </>
  )
}
