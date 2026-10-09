/**
 * MarketingHeader.tsx
 *
 * Public navigation for Tennis Legacy. Authenticated managers are sent to
 * onboarding or their dashboard and can sign out directly from the header.
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link, useNavigate } from 'react-router'
import { LogOut, Menu, X } from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import BetaDisclaimer from '../marketing/BetaDisclaimer'

interface MarketingNavigationItem {
  readonly labelKey: string
  readonly sectionId: string
}

const navigationItems: readonly MarketingNavigationItem[] = [
  { labelKey: 'marketing.features', sectionId: 'features' },
  { labelKey: 'marketing.howItWorks', sectionId: 'how-it-works' },
  { labelKey: 'marketing.gameWorld', sectionId: 'game-world' },
]

export default function MarketingHeader() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { user, player, authLoading, signOut } = useAuth()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [signingOut, setSigningOut] = useState(false)

  const dashboardPath = player ? '/game/overview' : '/create-player'

  const goToSection = (sectionId: string) => {
    setMobileMenuOpen(false)
    navigate('/')

    window.setTimeout(() => {
      document.getElementById(sectionId)?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      })
    }, 100)
  }

  async function handleSignOut() {
    if (signingOut) return
    setSigningOut(true)

    try {
      await signOut()
      setMobileMenuOpen(false)
      navigate('/login', { replace: true })
    } finally {
      setSigningOut(false)
    }
  }

  return (
    <header className="tlg-marketing-header">
      <div className="tlg-marketing-header-inner">
        <Link
          to="/"
          className="tlg-brand"
          aria-label="Tennis Legacy home"
          onClick={() => setMobileMenuOpen(false)}
        >
          <span className="tlg-brand-mark"><TennisLogoMark /></span>
          <span className="tlg-brand-copy">
            <strong className="tlg-brand-name">Tennis Legacy</strong>
            <span className="tlg-brand-subtitle">Rise to Glory</span>
          </span>
        </Link>

        <nav className="tlg-marketing-navigation" aria-label={t('marketing.mainNavigation')}>
          <Link to="/" className="tlg-marketing-navigation-link">{t('marketing.home')}</Link>
          {navigationItems.map((item) => (
            <button
              key={item.sectionId}
              type="button"
              className="tlg-marketing-navigation-link"
              onClick={() => goToSection(item.sectionId)}
            >
              {t(item.labelKey)}
            </button>
          ))}
        </nav>

        <div className="tlg-marketing-header-actions">
          {!authLoading && user ? (
            <>
              <button
                type="button"
                className="tlg-btn tlg-btn-ghost tlg-btn-small tlg-header-signin"
                onClick={() => void handleSignOut()}
                disabled={signingOut}
              >
                <LogOut size={15} />
                {signingOut ? t('marketing.signingOut') : t('marketing.signOut')}
              </button>
              <Link to={dashboardPath} className="tlg-btn tlg-btn-primary tlg-btn-small">
                {player ? t('marketing.dashboard') : t('marketing.createPlayer')}
              </Link>
            </>
          ) : (
            <>
              <Link to="/login" className="tlg-btn tlg-btn-ghost tlg-btn-small tlg-header-signin">{t('marketing.signIn')}</Link>
              <Link to="/register" className="tlg-btn tlg-btn-primary tlg-btn-small">{t('marketing.startPlaying')}</Link>
            </>
          )}

          <button
            type="button"
            className="tlg-mobile-menu-button"
            aria-label={mobileMenuOpen ? t('marketing.closeNavigation') : t('marketing.openNavigation')}
            aria-expanded={mobileMenuOpen}
            onClick={() => setMobileMenuOpen((current) => !current)}
          >
            {mobileMenuOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </div>

      {mobileMenuOpen && (
        <div className="tlg-mobile-navigation">
          <nav className="tlg-mobile-navigation-inner" aria-label={t('marketing.mobileNavigation')}>
            <Link to="/" className="tlg-mobile-navigation-link" onClick={() => setMobileMenuOpen(false)}>{t('marketing.home')}</Link>

            {navigationItems.map((item) => (
              <button
                key={item.sectionId}
                type="button"
                className="tlg-mobile-navigation-link"
                onClick={() => goToSection(item.sectionId)}
              >
                {t(item.labelKey)}
              </button>
            ))}

            <div className="tlg-mobile-navigation-actions">
              {!authLoading && user ? (
                <>
                  <Link
                    to={dashboardPath}
                    className="tlg-btn tlg-btn-primary tlg-btn-full"
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    {player ? 'Dashboard' : 'Create Player'}
                  </Link>
                  <button
                    type="button"
                    className="tlg-btn tlg-btn-secondary tlg-btn-full"
                    onClick={() => void handleSignOut()}
                    disabled={signingOut}
                  >
                    {signingOut ? 'Signing Out…' : 'Sign Out'}
                  </button>
                </>
              ) : (
                <>
                  <Link to="/login" className="tlg-btn tlg-btn-secondary tlg-btn-full" onClick={() => setMobileMenuOpen(false)}>Sign In</Link>
                  <Link to="/register" className="tlg-btn tlg-btn-primary tlg-btn-full" onClick={() => setMobileMenuOpen(false)}>Start Playing</Link>
                </>
              )}
            </div>
          </nav>
        </div>
      )}

      <BetaDisclaimer />
    </header>
  )
}

function TennisLogoMark() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true" className="tlg-brand-logo-svg">
      <defs>
        <linearGradient id="tlgLogoBackground" x1="5" y1="4" x2="44" y2="46" gradientUnits="userSpaceOnUse">
          <stop stopColor="#0874D1" />
          <stop offset="1" stopColor="#001D3F" />
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="44" height="44" rx="12" fill="url(#tlgLogoBackground)" />
      <circle cx="24" cy="24" r="12.5" fill="none" stroke="#FFFFFF" strokeWidth="2" />
      <path d="M15.8 14.6c5.5 3.1 9.4 8.2 11.2 14.7" fill="none" stroke="#FFFFFF" strokeWidth="2" strokeLinecap="round" />
      <path d="M21 33.9c3.1-5.9 7.1-10.1 12-12.5" fill="none" stroke="#FFFFFF" strokeWidth="2" strokeLinecap="round" />
    </svg>
  )
}
