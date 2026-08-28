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
  LogOut,
  Shield,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'

const TENNIS_LEGACY_LOGO_PATH = 'Branding/01e18414-8243-48da-b6b7-6d758a3d59f9.png'

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
  const navigate = useNavigate()
  const { signOut } = useAuth()
  const [logoUrl, setLogoUrl] = useState<string | null>(null)

  useEffect(() => {
    let mounted = true

    async function loadLogo() {
      const { data, error } = await supabase.storage
        .from('Admin')
        .createSignedUrl(TENNIS_LEGACY_LOGO_PATH, 60 * 60)

      if (!mounted) return

      if (error) {
        console.error('Unable to load Tennis Legacy logo:', error.message)
        setLogoUrl(null)
        return
      }

      setLogoUrl(data.signedUrl)
    }

    void loadLogo()

    return () => {
      mounted = false
    }
  }, [])

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
          {logoUrl && (
            <img
              src={logoUrl}
              alt="Tennis Legacy: Rise to Glory"
              className="tlg-v4-logo-image"
            />
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

        <div className="tlg-v2-sidebar-footer tlg-v4-sidebar-footer">
          <button
            type="button"
            className="tlg-v4-signout-button"
            onClick={() => void handleSignOut()}
            title="Sign out"
          >
            <LogOut size={16} />
            {!isCollapsed && <span>Sign out</span>}
          </button>
        </div>
      </aside>
    </>
  )
}
