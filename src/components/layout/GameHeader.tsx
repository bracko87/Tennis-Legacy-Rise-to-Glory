import { Bell, ChevronDown, Home, LifeBuoy, Menu, Settings, SlidersHorizontal, UserRound } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'

export interface GameHeaderProps {
  title: string
  subtitle?: string
  onToggleSidebarMobile?: () => void
}

function getCountryName(code?: string) {
  if (!code) return 'Country not set'

  try {
    return new Intl.DisplayNames(['en'], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

function getCountryFlagUrl(code?: string) {
  if (!code || code.length !== 2) return null
  return `https://flagcdn.com/24x18/${code.toLowerCase()}.png`
}

export default function GameHeader({
  onToggleSidebarMobile,
}: GameHeaderProps) {
  const navigate = useNavigate()
  const { player } = useAuth()
  const [settingsOpen, setSettingsOpen] = useState(false)
  const settingsRef = useRef<HTMLDivElement | null>(null)

  const displayName = player
    ? `${player.first_name} ${player.last_name}`.trim()
    : 'Tennis Legacy Player'
  const countryName = getCountryName(player?.country_code)
  const countryFlagUrl = getCountryFlagUrl(player?.country_code)

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

  return (
    <header className="tlg-v2-header tlg-v4-header">
      <div className="tlg-v2-header-left tlg-v4-player-identity">
        <button
          type="button"
          className="tlg-v2-mobile-menu"
          onClick={onToggleSidebarMobile}
          aria-label="Open navigation"
        >
          <Menu size={18} />
        </button>

        <div className="min-w-0">
          <strong className="tlg-v4-player-name">{displayName}</strong>
          <span className="tlg-v4-player-country">
            {countryFlagUrl && (
              <img
                src={countryFlagUrl}
                alt=""
                className="tlg-v6-country-flag"
                aria-hidden="true"
              />
            )}
            <span>{countryName}</span>
          </span>
        </div>
      </div>

      <div className="tlg-v4-header-actions">
        <button type="button" className="tlg-v4-header-action" aria-label="Notifications">
          <Bell size={16} />
          <span>Notifications</span>
        </button>

        <div className="tlg-v4-settings" ref={settingsRef}>
          <button
            type="button"
            className="tlg-v4-header-action"
            aria-haspopup="menu"
            aria-expanded={settingsOpen}
            onClick={() => setSettingsOpen((value) => !value)}
          >
            <Settings size={16} />
            <span>Settings</span>
            <ChevronDown size={13} className={settingsOpen ? 'tlg-v4-chevron-open' : ''} />
          </button>

          {settingsOpen && (
            <div className="tlg-v4-settings-menu" role="menu">
              <div className="tlg-v4-settings-heading">Manager settings</div>

              <button type="button" className="tlg-v4-settings-row" disabled>
                <UserRound size={15} />
                <span><strong>Player & account</strong><small>Coming soon</small></span>
              </button>

              <button type="button" className="tlg-v4-settings-row" disabled>
                <SlidersHorizontal size={15} />
                <span><strong>Game preferences</strong><small>Coming soon</small></span>
              </button>

              <button
                type="button"
                className="tlg-v4-settings-row"
                onClick={() => navigate('/')}
              >
                <Home size={15} />
                <span><strong>Homepage</strong><small>Return to Tennis Legacy</small></span>
              </button>

              <a
                className="tlg-v4-settings-row"
                href="mailto:contact@tennislegacygame.com"
                role="menuitem"
              >
                <LifeBuoy size={15} />
                <span><strong>Help & support</strong><small>Contact Tennis Legacy</small></span>
              </a>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}
