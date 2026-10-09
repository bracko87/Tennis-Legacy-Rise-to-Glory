/**
 * MarketingHeader.tsx
 *
 * Public navigation for Tennis Legacy. Authenticated managers are sent to
 * onboarding or their dashboard and can sign out directly from the header.
 */

import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link, useNavigate } from 'react-router'
import { ChevronDown, LogOut, Menu, X } from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import { useLocalization } from '../../i18n/LocalizationProvider'
import type { AppLocale } from '../../i18n'
import CountryFlag from '../common/CountryFlag'
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

const LANGUAGE_META: Record<AppLocale, { label: string; shortLabel: string; countryCode: string }> = {
  en: { label: 'English', shortLabel: 'EN', countryCode: 'GB' },
  sr: { label: 'Srpski', shortLabel: 'SR', countryCode: 'RS' },
  de: { label: 'Deutsch', shortLabel: 'DE', countryCode: 'DE' },
  es: { label: 'Español', shortLabel: 'ES', countryCode: 'ES' },
  it: { label: 'Italiano', shortLabel: 'IT', countryCode: 'IT' },
  fr: { label: 'Français', shortLabel: 'FR', countryCode: 'FR' },
  ru: { label: 'Русский', shortLabel: 'RU', countryCode: 'RU' },
  pt: { label: 'Português', shortLabel: 'PT', countryCode: 'PT' },
}

export default function MarketingHeader() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { user, player, authLoading, signOut } = useAuth()
  const { locale, enabledLocales, setLocale, saving: languageSaving } = useLocalization()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [languageOpen, setLanguageOpen] = useState(false)
  const [signingOut, setSigningOut] = useState(false)
  const languageRef = useRef<HTMLDivElement | null>(null)

  const dashboardPath = player ? '/game/overview' : '/create-player'
  const activeLanguage = LANGUAGE_META[locale]

  useEffect(() => {
    function handlePointerDown(event: MouseEvent) {
      if (!languageRef.current?.contains(event.target as Node)) setLanguageOpen(false)
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') setLanguageOpen(false)
    }

    document.addEventListener('mousedown', handlePointerDown)
    document.addEventListener('keydown', handleKeyDown)
    return () => {
      document.removeEventListener('mousedown', handlePointerDown)
      document.removeEventListener('keydown', handleKeyDown)
    }
  }, [])

  async function chooseLanguage(nextLocale: AppLocale) {
    if (nextLocale === locale || languageSaving) {
      setLanguageOpen(false)
      return
    }
    const changed = await setLocale(nextLocale)
    if (changed) setLanguageOpen(false)
  }

  const goToSection = (sectionId: string) => {
    setMobileMenuOpen(false)
    setLanguageOpen(false)
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

          <div className="tlg-marketing-language" ref={languageRef}>
            <button
              type="button"
              className="tlg-marketing-language-trigger"
              aria-label={t('common.language')}
              aria-haspopup="menu"
              aria-expanded={languageOpen}
              onClick={() => setLanguageOpen((current) => !current)}
              disabled={languageSaving}
            >
              <CountryFlag
                countryCode={activeLanguage.countryCode}
                countryName={activeLanguage.label}
                width={20}
                height={14}
              />
              <span>{activeLanguage.shortLabel}</span>
              <ChevronDown size={13} className={languageOpen ? 'is-open' : ''} />
            </button>

            {languageOpen && (
              <div className="tlg-marketing-language-menu" role="menu" aria-label={t('common.language')}>
                {enabledLocales.map((language) => {
                  const meta = LANGUAGE_META[language]
                  return (
                    <button
                      key={language}
                      type="button"
                      role="menuitemradio"
                      aria-checked={language === locale}
                      className={language === locale ? 'active' : ''}
                      onClick={() => void chooseLanguage(language)}
                      disabled={languageSaving}
                    >
                      <CountryFlag
                        countryCode={meta.countryCode}
                        countryName={meta.label}
                        width={22}
                        height={15}
                      />
                      <span>{meta.label}</span>
                      <small>{meta.shortLabel}</small>
                    </button>
                  )
                })}
              </div>
            )}
          </div>

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
                    {player ? t('marketing.dashboard') : t('marketing.createPlayer')}
                  </Link>
                  <button
                    type="button"
                    className="tlg-btn tlg-btn-secondary tlg-btn-full"
                    onClick={() => void handleSignOut()}
                    disabled={signingOut}
                  >
                    {signingOut ? t('marketing.signingOut') : t('marketing.signOut')}
                  </button>
                </>
              ) : (
                <>
                  <Link to="/login" className="tlg-btn tlg-btn-secondary tlg-btn-full" onClick={() => setMobileMenuOpen(false)}>{t('marketing.signIn')}</Link>
                  <Link to="/register" className="tlg-btn tlg-btn-primary tlg-btn-full" onClick={() => setMobileMenuOpen(false)}>{t('marketing.startPlaying')}</Link>
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
