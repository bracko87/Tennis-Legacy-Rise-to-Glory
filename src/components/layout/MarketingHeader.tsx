/**
 * MarketingHeader.tsx
 *
 * Public navigation for Tennis Legacy: Rise to Glory.
 */

import { useState } from 'react'
import {
  Link,
  useNavigate,
} from 'react-router'
import {
  Menu,
  X,
} from 'lucide-react'

interface MarketingNavigationItem {
  readonly label: string
  readonly sectionId: string
}

const navigationItems: readonly MarketingNavigationItem[] = [
  {
    label: 'Features',
    sectionId: 'features',
  },
  {
    label: 'How It Works',
    sectionId: 'how-it-works',
  },
  {
    label: 'Game World',
    sectionId: 'game-world',
  },
]

export default function MarketingHeader() {
  const navigate = useNavigate()
  const [mobileMenuOpen, setMobileMenuOpen] =
    useState(false)

  const goToSection = (
    sectionId: string,
  ) => {
    setMobileMenuOpen(false)
    navigate('/')

    window.setTimeout(() => {
      document
        .getElementById(sectionId)
        ?.scrollIntoView({
          behavior: 'smooth',
          block: 'start',
        })
    }, 100)
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
          <span className="tlg-brand-mark">
            <TennisLogoMark />
          </span>

          <span className="tlg-brand-copy">
            <strong className="tlg-brand-name">
              Tennis Legacy
            </strong>

            <span className="tlg-brand-subtitle">
              Rise to Glory
            </span>
          </span>
        </Link>

        <nav
          className="tlg-marketing-navigation"
          aria-label="Main navigation"
        >
          <Link
            to="/"
            className="tlg-marketing-navigation-link"
          >
            Home
          </Link>

          {navigationItems.map((item) => (
            <button
              key={item.sectionId}
              type="button"
              className="tlg-marketing-navigation-link"
              onClick={() =>
                goToSection(item.sectionId)
              }
            >
              {item.label}
            </button>
          ))}
        </nav>

        <div className="tlg-marketing-header-actions">
          <Link
            to="/login"
            className="tlg-btn tlg-btn-ghost tlg-btn-small tlg-header-signin"
          >
            Sign In
          </Link>

          <Link
            to="/register"
            className="tlg-btn tlg-btn-primary tlg-btn-small"
          >
            Start Playing
          </Link>

          <button
            type="button"
            className="tlg-mobile-menu-button"
            aria-label={
              mobileMenuOpen
                ? 'Close navigation'
                : 'Open navigation'
            }
            aria-expanded={mobileMenuOpen}
            onClick={() =>
              setMobileMenuOpen(
                (current) => !current,
              )
            }
          >
            {mobileMenuOpen ? (
              <X size={20} />
            ) : (
              <Menu size={20} />
            )}
          </button>
        </div>
      </div>

      {mobileMenuOpen && (
        <div className="tlg-mobile-navigation">
          <nav
            className="tlg-mobile-navigation-inner"
            aria-label="Mobile navigation"
          >
            <Link
              to="/"
              className="tlg-mobile-navigation-link"
              onClick={() =>
                setMobileMenuOpen(false)
              }
            >
              Home
            </Link>

            {navigationItems.map((item) => (
              <button
                key={item.sectionId}
                type="button"
                className="tlg-mobile-navigation-link"
                onClick={() =>
                  goToSection(item.sectionId)
                }
              >
                {item.label}
              </button>
            ))}

            <div className="tlg-mobile-navigation-actions">
              <Link
                to="/login"
                className="tlg-btn tlg-btn-secondary tlg-btn-full"
                onClick={() =>
                  setMobileMenuOpen(false)
                }
              >
                Sign In
              </Link>

              <Link
                to="/register"
                className="tlg-btn tlg-btn-primary tlg-btn-full"
                onClick={() =>
                  setMobileMenuOpen(false)
                }
              >
                Start Playing
              </Link>
            </div>
          </nav>
        </div>
      )}
    </header>
  )
}

function TennisLogoMark() {
  return (
    <svg
      viewBox="0 0 48 48"
      aria-hidden="true"
      className="tlg-brand-logo-svg"
    >
      <defs>
        <linearGradient
          id="tlgLogoBackground"
          x1="5"
          y1="4"
          x2="44"
          y2="46"
          gradientUnits="userSpaceOnUse"
        >
          <stop stopColor="#0874D1" />
          <stop
            offset="1"
            stopColor="#001D3F"
          />
        </linearGradient>
      </defs>

      <rect
        x="2"
        y="2"
        width="44"
        height="44"
        rx="12"
        fill="url(#tlgLogoBackground)"
      />

      <circle
        cx="24"
        cy="24"
        r="12.5"
        fill="none"
        stroke="#FFFFFF"
        strokeWidth="2"
      />

      <path
        d="M15.8 14.6c5.5 3.1 9.4 8.2 11.2 14.7"
        fill="none"
        stroke="#FFFFFF"
        strokeWidth="2"
        strokeLinecap="round"
      />

      <path
        d="M21 33.9c3.1-5.9 7.1-10.1 12-12.5"
        fill="none"
        stroke="#FFFFFF"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  )
}