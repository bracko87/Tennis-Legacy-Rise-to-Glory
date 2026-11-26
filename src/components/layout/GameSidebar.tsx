import clsx from 'clsx'
import {
  Activity,
  BarChart3,
  Bug,
  Building2,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  CircleDollarSign,
  Clock3,
  Crown,
  Dumbbell,
  Flag,
  Gauge,
  LayoutDashboard,
  LogOut,
  MessageSquareQuote,
  Shield,
  Trophy,
  UsersRound,
  UserPlus,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { Link, useLocation, useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { aceReviewEnabled } from '../../lib/aceReviewFlag'
import { useGuestTrialDisplay } from '../../hooks/useGuestTrialDisplay'
import BugReportButton from '../dashboard/BugReportButton'
import { useTennisClubAlerts } from '../../hooks/useTennisClubAlerts'
import './tennis-club-alerts.css'

const TENNIS_LEGACY_LOGO_URL = 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/logo%20333.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9sb2dvIDMzMy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg3OTQ1MDc5LCJleHAiOjQ5MTAwMDkwNzl9.Q7Ocay_B1kouWo_XmmgtVcGOCh0xtzhzaIm713AhU-ci-xJPY3JanaT3xhdkptAuKV5kUJGHov34fSM2TGjmcQ'

export interface GameSidebarProps {
  isCollapsed: boolean
  onToggleCollapse: () => void
  isMobileOpen: boolean
  onMobileClose: () => void
}

interface NavItem {
  key: string
  labelKey: string
  descriptionKey: string
  to: string
  icon: JSX.Element
  premiumOnly?: boolean
}

const items: NavItem[] = [
  { key: 'overview', labelKey: 'nav.overview', descriptionKey: 'nav.overviewDesc', to: '/game/overview', icon: <LayoutDashboard size={17} /> },
  { key: 'skills', labelKey: 'nav.skills', descriptionKey: 'nav.skillsDesc', to: '/game/skills', icon: <Activity size={17} /> },
  { key: 'training', labelKey: 'nav.training', descriptionKey: 'nav.trainingDesc', to: '/game/training', icon: <Dumbbell size={17} /> },
  { key: 'staff', labelKey: 'nav.staff', descriptionKey: 'nav.staffDesc', to: '/game/staff', icon: <UsersRound size={17} /> },
  { key: 'calendar', labelKey: 'nav.calendar', descriptionKey: 'nav.calendarDesc', to: '/game/calendar', icon: <CalendarDays size={17} /> },
  { key: 'schedule', labelKey: 'nav.schedule', descriptionKey: 'nav.scheduleDesc', to: '/game/schedule', icon: <Clock3 size={17} /> },
  { key: 'rankings', labelKey: 'nav.rankings', descriptionKey: 'nav.rankingsDesc', to: '/game/rankings', icon: <Trophy size={17} /> },
  { key: 'equipment', labelKey: 'nav.equipment', descriptionKey: 'nav.equipmentDesc', to: '/game/equipment', icon: <Shield size={17} /> },
  { key: 'finance', labelKey: 'nav.finance', descriptionKey: 'nav.financeDesc', to: '/game/finance', icon: <CircleDollarSign size={17} /> },
  { key: 'national-team', labelKey: 'nav.nationalTeam', descriptionKey: 'nav.nationalTeamDesc', to: '/game/national-team', icon: <Flag size={17} /> },
  { key: 'private-life', labelKey: 'nav.privateLife', descriptionKey: 'nav.privateLifeDesc', to: '/game/private-life', icon: <Crown size={17} />, premiumOnly: true },
  { key: 'tennis-club', labelKey: 'nav.tennisClub', descriptionKey: 'nav.tennisClubDesc', to: '/game/tennis-club', icon: <Building2 size={17} /> },
  { key: 'statistics', labelKey: 'nav.statistics', descriptionKey: 'nav.statisticsDesc', to: '/game/statistics', icon: <BarChart3 size={17} /> },
]

const adminItems: NavItem[] = [
  { key: 'admin-system-health', labelKey: 'System Health', descriptionKey: 'Processes, incidents & logs', to: '/game/admin/system-health', icon: <Activity size={17} /> },
  { key: 'admin-analytics', labelKey: 'Analytics', descriptionKey: 'Private traffic & activity', to: '/game/admin/analytics', icon: <Gauge size={17} /> },
  { key: 'admin-bug-reports', labelKey: 'Bug Reports', descriptionKey: 'Player-reported issues', to: '/game/admin/bug-reports', icon: <Bug size={17} /> },
  { key: 'admin-reviews', labelKey: 'Player Reviews', descriptionKey: 'Moderate homepage reviews', to: '/game/admin/reviews', icon: <MessageSquareQuote size={17} /> },
]

export default function GameSidebar({
  isCollapsed,
  onToggleCollapse,
  isMobileOpen,
  onMobileClose,
}: GameSidebarProps) {
  const { t } = useTranslation()
  const location = useLocation()
  const navigate = useNavigate()
  const { user, signOut, isAdmin } = useAuth()
  const guestTrial = useGuestTrialDisplay()
  const { alerts: clubAlerts } = useTennisClubAlerts()
  // The desktop collapse preference must not reduce the open phone drawer to icons.
  const collapseNav = isCollapsed && !isMobileOpen
  const currentPageLabel = (() => {
    const exact = items.find((item) => item.to === location.pathname)
    if (exact) return t(exact.labelKey)
    if (location.pathname.startsWith('/game/players/')) return t('nav.playerProfile')
    if (location.pathname.startsWith('/game/tournaments/')) return t('nav.tournament')
    if (location.pathname === '/game/inbox') return t('nav.managerInbox')
    if (location.pathname === '/game/player-account') return t('nav.playerAccount')
    if (location.pathname === '/game/preferences') return t('nav.gamePreferences')
    if (location.pathname === '/game/help') return t('nav.helpCenter')
    if (location.pathname === '/game/forum') return t('nav.forumDiscord')
    if (location.pathname === '/game/contact') return t('nav.contactUs')
    if (location.pathname === '/game/invite-friends') return t('nav.inviteFriends')
    if (location.pathname === '/game/notifications') return t('nav.notifications')
    if (location.pathname === '/game/pro-packages') return t('nav.proPackages')
    const admin = adminItems.find((item) => item.to === location.pathname)
    if (admin) return admin.labelKey
    return location.pathname.replace('/game/', '').replaceAll('-', ' ') || 'Game'
  })()
  async function handleSignOut() {
    if (user?.is_anonymous) return
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
        id="tlg-game-sidebar"
        aria-label={t('nav.gameNavigation')}
        className={clsx(
          'tlg-v2-sidebar',
          collapseNav && 'tlg-v2-sidebar-collapsed',
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
          aria-label={isCollapsed ? t('nav.expandNavigation') : t('nav.collapseNavigation')}
          title={isCollapsed ? t('nav.expandNavigation') : t('nav.collapseNavigation')}
        >
          {isCollapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
        </button>

        {!collapseNav && <div className="tlg-v2-nav-label">{t('nav.managerCenter')}</div>}

        <nav className="tlg-v2-nav tlg-v2-nav-main" aria-label={t('nav.gameNavigation')}>
          {items.map((item) => {
            const active = location.pathname === item.to
            const isClub = item.key === 'tennis-club'
            const badgeCount = isClub ? clubAlerts.total : 0
            const clubAlertLabel = isClub && badgeCount > 0
              ? t('clubAlerts.sidebarSummary', { count: badgeCount })
              : ''

            return (
              <Link
                key={item.key}
                to={item.to}
                data-tutorial-id={`nav-${item.key}`}
                onClick={onMobileClose}
                className={clsx(
                  'tlg-v2-nav-link',
                  active && 'tlg-v2-nav-link-active',
                  item.premiumOnly && 'tlg-v2-nav-link-premium',
                )}
                title={collapseNav ? `${t(item.labelKey)}${item.premiumOnly ? ` · ${t('header.premium')}` : ''}${clubAlertLabel ? ` · ${clubAlertLabel}` : ''}` : undefined}
                aria-label={clubAlertLabel ? `${t(item.labelKey)} · ${clubAlertLabel}` : undefined}
                aria-current={active ? 'page' : undefined}
              >
                <span className="tlg-v2-nav-icon">{item.icon}</span>

                {!collapseNav && (
                  <span className="tlg-v2-nav-copy">
                    <span className="tlg-v8-nav-title-line">
                      <strong>{t(item.labelKey)}</strong>
                      {item.premiumOnly && <em>{t('header.premium')}</em>}
                    </span>
                    <small>{t(item.descriptionKey)}</small>
                  </span>
                )}
                {badgeCount > 0 && (
                  <span className="tlg-club-sidebar-badge" aria-hidden="true">{badgeCount > 99 ? '99+' : badgeCount}</span>
                )}
              </Link>
            )
          })}
        </nav>

        {isAdmin && (
          <>
            {!collapseNav && <div className="tlg-v2-nav-label">Administration</div>}
            <nav className="tlg-v2-nav tlg-v2-nav-admin" aria-label="Administration">
              {aceReviewEnabled && <Link to="/game/admin/project-ace" onClick={onMobileClose} className={clsx('tlg-v2-nav-link', location.pathname==='/game/admin/project-ace' && 'tlg-v2-nav-link-active')} title="Project Ace review"><span className="tlg-v2-nav-icon"><Activity size={17}/></span>{!collapseNav&&<span className="tlg-v2-nav-copy"><strong>Project Ace</strong><small>Isolated review only</small></span>}</Link>}
              {adminItems.filter((item) => item.key === 'admin-analytics').map((item) => {
                const active = location.pathname === item.to
                return (
                  <Link
                    key={item.key}
                    to={item.to}
                    onClick={onMobileClose}
                    className={clsx('tlg-v2-nav-link', active && 'tlg-v2-nav-link-active')}
                    aria-current={active ? 'page' : undefined}
                    title={collapseNav ? 'Admin Analytics' : undefined}
                  >
                    <span className="tlg-v2-nav-icon">{item.icon}</span>
                    {!collapseNav && (
                      <span className="tlg-v2-nav-copy">
                        <strong>Admin Analytics</strong>
                        <small>Live website &amp; player metrics</small>
                      </span>
                    )}
                  </Link>
                )
              })}
            </nav>
          </>
        )}

        <div className="tlg-v2-sidebar-footer tlg-v4-sidebar-footer">
          {user?.is_anonymous && (
            <Link to="/guest/register" className="tlg-v2-nav-link tlg-guest-sidebar-register"
              onClick={onMobileClose} title="Register to save your guest player">
              <span className="tlg-v2-nav-icon"><UserPlus size={17}/></span>
              {!collapseNav && <span className="tlg-v2-nav-copy">
                <strong>Register · Save Progress</strong>
                <small>{guestTrial.state === 'active' ? `${guestTrial.daysLeft} days remaining` : guestTrial.state === 'expired' ? 'Trial ended · Register now' : 'Keep your tennis player'}</small>
              </span>}
            </Link>
          )}

          <BugReportButton
            collapsed={collapseNav}
            currentPageLabel={currentPageLabel}
            currentPath={location.pathname}
          />
          <button
            type="button"
            className="tlg-v4-signout-button"
            onClick={() => void handleSignOut()}
            disabled={user?.is_anonymous === true}
            style={user?.is_anonymous ? { opacity: 0.5, cursor: 'not-allowed' } : undefined}
            title={user?.is_anonymous ? 'Logout disabled during guest trial. Close your browser or register to keep your player.' : t('nav.signOut')}
          >
            <LogOut size={16} />
            {!collapseNav && <span>{t('nav.signOut')}</span>}
          </button>
          {!collapseNav && <div className="tlg-v6-version">{t('nav.version', { version: '1.1.9' })}</div>}
        </div>
      </aside>
    </>
  )
}
