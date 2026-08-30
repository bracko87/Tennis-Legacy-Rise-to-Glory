/**
 * MarketingFooter.tsx
 *
 * Shared public footer.
 */

import type { ReactNode } from 'react'
import {
  Link,
  useNavigate,
} from 'react-router'
import { Clock3 } from 'lucide-react'

import { useGameClock } from '../../hooks/useGameClock'

const FOOTER_LOGO_URL =
  'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/logo%20333.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9sb2dvIDMzMy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg3OTQ1MDc5LCJleHAiOjQ5MTAwMDkwNzl9.Q7Ocay_B1kouWo_XmmgtVcGOCh0xtzhzaIm713AhU-ci-xJPY3JanaT3xhdkptAuKV5kUJGHov34fSM2TGjmcQ'

export interface MarketingFooterProps {
  readonly children?: ReactNode
}

export default function MarketingFooter({
  children,
}: MarketingFooterProps) {
  const navigate = useNavigate()
  const clock = useGameClock()

  const goToSection = (
    sectionId: string,
  ) => {
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
    <footer className="tlg-marketing-footer">
      <div className="tlg-marketing-footer-glow" />

      <div className="tlg-marketing-footer-inner">
        <div className="tlg-footer-main">
          <div className="tlg-footer-brand-column">
            <Link
              to="/"
              className="tlg-footer-brand"
            >
              <span className="tlg-footer-brand-icon">
                <img
                  src={FOOTER_LOGO_URL}
                  alt=""
                  aria-hidden="true"
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'contain',
                  }}
                />
              </span>

              <span>
                <strong>Tennis Legacy</strong>
                <small>Rise to Glory</small>
              </span>
            </Link>

            <p className="tlg-footer-description">
              A persistent multiplayer tennis
              management world where every decision
              shapes the career, reputation and legacy
              of your professional player.
            </p>

            <div
              className="tlg-footer-time"
              aria-live="polite"
            >
              <Clock3 size={17} />

              <div>
                <span>In-game time</span>
                <strong>
                  Season {clock.season} · {clock.month}{' '}
                  {clock.day} · {clock.formattedTime}
                </strong>
              </div>
            </div>
          </div>

          <div className="tlg-footer-links-grid">
            <FooterColumn title="Explore">
              <Link to="/">Home</Link>

              <button
                type="button"
                onClick={() =>
                  goToSection('features')
                }
              >
                Features
              </button>

              <button
                type="button"
                onClick={() =>
                  goToSection('game-world')
                }
              >
                Game World
              </button>

              <Link to="/login">
                Sign In
              </Link>

              <Link to="/register">
                Register
              </Link>
            </FooterColumn>

            <FooterColumn title="The Game">
              <span>ATP World</span>
              <span>WTA World</span>
              <span>Global Rankings</span>
              <span>Tournaments</span>
              <span>Career Records</span>
            </FooterColumn>

            <FooterColumn title="Support">
              <span>Help Center</span>
              <span>Community Guidelines</span>
              <span>Fair Play</span>
              <span>Privacy</span>
              <span>Terms</span>
            </FooterColumn>
          </div>
        </div>

        {children && (
          <div className="tlg-footer-extra">
            {children}
          </div>
        )}

        <div className="tlg-footer-bottom">
          <p>
            Tennis Legacy: Rise to Glory · Online
            multiplayer tennis management simulation.
          </p>

          <p>
            Tennis Legacy is published and operated by
            Next Quest Studio.
          </p>
        </div>
      </div>
    </footer>
  )
}

interface FooterColumnProps {
  readonly title: string
  readonly children: ReactNode
}

function FooterColumn({
  title,
  children,
}: FooterColumnProps) {
  return (
    <div className="tlg-footer-column">
      <h3>{title}</h3>

      <div className="tlg-footer-column-links">
        {children}
      </div>
    </div>
  )
}
