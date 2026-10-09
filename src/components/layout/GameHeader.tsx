import {
  Bell,
  ChevronDown,
  Crown,
  Menu,
  Settings,
} from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { useCommerce } from '../../hooks/useCommerce'
import useUnreadNotificationCount from '../../hooks/useUnreadNotificationCount'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { supabase } from '../../lib/supabase'
import CountryFlag from '../common/CountryFlag'

export interface GameHeaderProps {
  title: string
  subtitle?: string
  onToggleSidebarMobile?: () => void
}

function getCountryName(code: string | undefined, localeTag: string, fallback: string) {
  if (!code) return fallback
  try {
    return new Intl.DisplayNames([localeTag], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

export default function GameHeader({
  onToggleSidebarMobile,
}: GameHeaderProps) {
  const { t } = useTranslation()
  const { localeTag, formatNumber } = useLocalization()
  const navigate = useNavigate()
  const { player, signOut } = useAuth()
  const { isPremium } = useCommerce()
  const { unreadCount } = useUnreadNotificationCount()
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [currentRank, setCurrentRank] = useState<number | null>(null)
  const settingsRef = useRef<HTMLDivElement | null>(null)

  const displayName = player
    ? `${player.first_name} ${player.last_name}`.trim()
    : t('header.playerFallback')
  const countryName = getCountryName(player?.country_code, localeTag, t('header.countryNotSet'))

  useEffect(() => {
    let active = true

    async function loadCurrentRank() {
      if (!player?.id) {
        setCurrentRank(null)
        return
      }

      const { data, error } = await supabase.rpc('player_current_rank_position_v1', {
        p_player_id: player.id,
      })

      if (!active) return

      if (error || data === null || data === undefined) {
        setCurrentRank(null)
        return
      }

      const rank = Number(data)
      setCurrentRank(Number.isFinite(rank) && rank > 0 ? rank : null)
    }

    void loadCurrentRank()

    return () => {
      active = false
    }
  }, [player?.id])

  useEffect(() => {
    function handlePointerDown(event: MouseEvent) {
      if (!settingsRef.current?.contains(event.target as Node)) {
        setSettingsOpen(false)
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') setSettingsOpen(false)
    }

    document.addEventListener('mousedown', handlePointerDown)
    document.addEventListener('keydown', handleKeyDown)

    return () => {
      document.removeEventListener('mousedown', handlePointerDown)
      document.removeEventListener('keydown', handleKeyDown)
    }
  }, [])

  function openManagerPage(path: string) {
    setSettingsOpen(false)
    navigate(path)
  }

  async function handleLogout() {
    setSettingsOpen(false)
    await signOut()
    navigate('/', { replace: true })
  }

  return (
    <header className="tlg-v2-header tlg-v4-header">
      <div className="tlg-v2-header-left tlg-v4-player-identity">
        <button
          type="button"
          className="tlg-v2-mobile-menu"
          onClick={onToggleSidebarMobile}
          aria-label={t('header.openNavigation')}
        >
          <Menu size={18} />
        </button>

        {player && (
          <>
            <div className="tlg-v6-header-rank" data-tutorial-id="header-rank" aria-label={currentRank ? t('header.worldRankAria', { rank: formatNumber(currentRank) }) : t('header.worldRankUnavailable')}>
              {currentRank ? `#${formatNumber(currentRank)}` : '—'}
            </div>
            <span className="tlg-v6-header-identity-divider" aria-hidden="true" />
          </>
        )}

        <div className="min-w-0">
          <strong className="tlg-v4-player-name">{displayName}</strong>
          <span className="tlg-v4-player-country">
            <CountryFlag
              countryCode={player?.country_code}
              countryName={countryName}
              width={22}
              height={16}
            />
            <span>{countryName}</span>
          </span>
        </div>
      </div>

      <div className="tlg-v4-header-actions">
        <button
          type="button"
          className="tlg-v4-header-action tlg-v4-notification-button"
          data-tutorial-id="header-notifications"
          aria-label={unreadCount > 0 ? t('header.notificationsUnread', { count: unreadCount }) : t('header.notifications')}
          onClick={() => navigate('/game/notifications')}
        >
          <Bell size={16} />
          <span>{t('header.notifications')}</span>
          {unreadCount > 0 && (
            <span className="tlg-v4-notification-badge" aria-hidden="true">
              {unreadCount > 99 ? '99+' : unreadCount}
            </span>
          )}
        </button>

        {isPremium && (
          <button
            type="button"
            className="tlg-v4-header-action tlg-commerce-premium-tab"
            data-tutorial-id="header-premium"
            aria-label={t('header.premium')}
            onClick={() => navigate('/game/pro-packages')}
          >
            <Crown size={16} />
            <span>{t('header.premium')}</span>
          </button>
        )}

        <div className="tlg-v4-settings" ref={settingsRef}>
          <button
            type="button"
            className="tlg-v4-header-action"
            data-tutorial-id="header-settings"
            aria-haspopup="menu"
            aria-expanded={settingsOpen}
            onClick={() => setSettingsOpen((value) => !value)}
          >
            <Settings size={16} />
            <span>{t('header.settings')}</span>
            <ChevronDown size={13} className={settingsOpen ? 'tlg-v4-chevron-open' : ''} />
          </button>

          {settingsOpen && (
            <div className="tlg-v4-settings-menu" role="menu">
              <div className="tlg-v4-settings-heading">{t('header.managerSettings')}</div>

              <button type="button" className="tlg-v4-settings-row" onClick={() => openManagerPage('/game/player-account')}>
                <span><strong>{t('header.playerAccount')}</strong><small>{t('header.playerAccountDesc')}</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" onClick={() => openManagerPage('/game/preferences')}>
                <span><strong>{t('header.gamePreferences')}</strong><small>{t('header.gamePreferencesDesc')}</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" onClick={() => openManagerPage('/game/inbox')}>
                <span><strong>{t('header.inbox')}</strong><small>{t('header.inboxDesc')}</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" onClick={() => openManagerPage('/game/help')}>
                <span><strong>{t('header.help')}</strong><small>{t('header.helpDesc')}</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" onClick={() => openManagerPage('/game/forum')}>
                <span><strong>{t('header.forum')}</strong><small>{t('header.forumDesc')}</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" onClick={() => openManagerPage('/game/pro-packages')}>
                <span><strong>{t('header.proPackages')}</strong><small>{t('header.proPackagesDesc')}</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" onClick={() => openManagerPage('/game/contact')}>
                <span><strong>{t('header.contactUs')}</strong><small>{t('header.contactUsDesc')}</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" onClick={() => openManagerPage('/game/invite-friends')}>
                <span><strong>{t('header.inviteFriends')}</strong><small>{t('header.inviteFriendsDesc')}</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" onClick={handleLogout}>
                <span><strong>{t('header.logout')}</strong><small>{t('header.logoutDesc')}</small></span>
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}
