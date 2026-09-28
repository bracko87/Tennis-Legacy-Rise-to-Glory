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
import { Clock3, ExternalLink } from 'lucide-react'

import { useGameClock } from '../../hooks/useGameClock'
import { supabase } from '../../lib/supabase'

const FOOTER_LOGO_URL =
  'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/logo%20333.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9sb2dvIDMzMy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg3OTQ1MDc5LCJleHAiOjQ5MTAwMDkwNzl9.Q7Ocay_B1kouWo_XmmgtVcGOCh0xtzhzaIm713AhU-ci-xJPY3JanaT3xhdkptAuKV5kUJGHov34fSM2TGjmcQ'

const NEXT_QUEST_STUDIO_URL = 'https://www.nextqueststudio.net/'
const PROPELOTON_URL = 'https://propelotonmanager.com/?source=tennis_legacy'
const PROPELOTON_LOGO_URL =
  'https://okuravitxocyevkexfgi.supabase.co/storage/v1/object/public/Admin%20Staff/Brend%20images/5c3417dc-3924-4423-948a-745ae5902ed0.png'

export interface MarketingFooterProps {
  readonly children?: ReactNode
}

export default function MarketingFooter({
  children,
}: MarketingFooterProps) {
  const navigate = useNavigate()
  const clock = useGameClock()

  function recordCrossGameClick() {
    void supabase.rpc('record_cross_game_referral_event_v1', {
      p_event_type: 'outgoing_click',
      p_source_game: 'tennis_legacy',
      p_destination_game: 'propeloton_manager',
      p_surface: 'marketing_footer',
    })
  }

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

        <div
          style={{
            marginTop: 22,
            paddingTop: 18,
            borderTop: '1px solid rgba(255,255,255,.09)',
          }}
        >
          <a
            href={PROPELOTON_URL}
            target="_blank"
            rel="noreferrer"
            onClick={recordCrossGameClick}
            aria-label="Play ProPeloton Manager, another game from Next Quest Studio"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              maxWidth: 520,
              padding: '12px 14px',
              border: '1px solid rgba(255,255,255,.14)',
              borderRadius: 12,
              background: 'rgba(255,255,255,.05)',
              color: '#fff',
              textDecoration: 'none',
            }}
          >
            <img
              src={PROPELOTON_LOGO_URL}
              alt=""
              aria-hidden="true"
              style={{ width: 42, height: 42, objectFit: 'contain', borderRadius: 9, background: '#081224' }}
            />
            <span style={{ display: 'grid', gap: 2, minWidth: 0 }}>
              <small style={{ color: 'rgba(255,255,255,.55)', fontSize: 9, fontWeight: 800, textTransform: 'uppercase', letterSpacing: '.06em' }}>
                Also from our studio
              </small>
              <strong style={{ fontSize: 14 }}>ProPeloton Manager</strong>
              <span style={{ color: 'rgba(255,255,255,.68)', fontSize: 11, lineHeight: 1.35 }}>
                Build and manage your own professional cycling team.
              </span>
            </span>
            <span style={{ marginLeft: 'auto', display: 'inline-flex', alignItems: 'center', gap: 5, color: '#8bd1f6', fontSize: 11, fontWeight: 800, whiteSpace: 'nowrap' }}>
              Play Now
              <ExternalLink size={14} />
            </span>
          </a>
        </div>

        <div className="tlg-footer-bottom">
          <p>
            Tennis Legacy: Rise to Glory · Online
            multiplayer tennis management simulation.
          </p>

          <div className="tlg-footer-company-credit">
            <p>
              Tennis Legacy is published and operated by{' '}
              <a
                href={NEXT_QUEST_STUDIO_URL}
                target="_blank"
                rel="noreferrer"
              >
                Next Quest Studio
              </a>.
            </p>
            <p>
              © {new Date().getFullYear()}{' '}
              <a
                href={NEXT_QUEST_STUDIO_URL}
                target="_blank"
                rel="noreferrer"
              >
                Next Quest Studio
              </a>. All rights reserved.
            </p>
          </div>
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
