/**
 * MarketingFooter.tsx
 *
 * Shared public footer.
 */

import { useEffect, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { createPortal } from 'react-dom'
import {
  Link,
  useNavigate,
} from 'react-router'
import { Clock3, X } from 'lucide-react'
import '../../styles/marketing-premium-dialog.css'

import { useGameClock } from '../../hooks/useGameClock'
import { supabase } from '../../lib/supabase'

const FOOTER_LOGO_URL =
  'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/logo%20333.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9sb2dvIDMzMy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg3OTQ1MDc5LCJleHAiOjQ5MTAwMDkwNzl9.Q7Ocay_B1kouWo_XmmgtVcGOCh0xtzhzaIm713AhU-ci-xJPY3JanaT3xhdkptAuKV5kUJGHov34fSM2TGjmcQ'

const NEXT_QUEST_STUDIO_URL = 'https://www.nextqueststudio.net/'
const PROPELOTON_URL = 'https://propelotonmanager.com/?source=tennis_legacy'
export interface MarketingFooterProps {
  readonly children?: ReactNode
}

export default function MarketingFooter({
  children,
}: MarketingFooterProps) {
  const navigate = useNavigate()
  const { t } = useTranslation()
  const clock = useGameClock()
  const [pricingOpen, setPricingOpen] = useState(false)

  useEffect(() => {
    if (!pricingOpen) return
    const handleKey = (event: KeyboardEvent) => { if (event.key === 'Escape') setPricingOpen(false) }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [pricingOpen])

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
              <button id="premium" type="button" className="tlg-footer-pricing-link" onClick={() => setPricingOpen(true)}>
                {t('home.premium.eyebrow')}
              </button>
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

        {pricingOpen && createPortal((
          <div className="tlg-pricing-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setPricingOpen(false) }}>
            <section className="tlg-pricing-dialog" role="dialog" aria-modal="true" aria-labelledby="tlg-pricing-dialog-title">
              <button className="tlg-pricing-close" type="button" aria-label={t('home.premium.close', { defaultValue: 'Close' })} onClick={() => setPricingOpen(false)}><X size={21} /></button>
              <span className="tlg-pricing-eyebrow">{t('home.premium.eyebrow')}</span>
              <h2 id="tlg-pricing-dialog-title">{t('home.premium.title')}</h2>
              <p className="tlg-pricing-description">{t('home.premium.description')}</p>
              <div className="tlg-pricing-plans">
                {[
                  { label: t('home.premium.monthly'), price: '€3.29', period: '1', note: t('home.premium.monthlyCoins') },
                  { label: t('home.premium.threeMonths'), price: '€9.49', period: '3', note: t('home.premium.threeCoins') },
                  { label: t('home.premium.annual'), price: '€33.49', period: '12', note: t('home.premium.annualCoins') },
                ].map((plan) => (
                  <article className="tlg-pricing-plan" key={plan.period}>
                    <h3>{plan.label}</h3>
                    <strong>{plan.price}</strong>
                    <span>{plan.note}</span>
                  </article>
                ))}
              </div>
              <p className="tlg-pricing-note">{t('home.premium.note')}</p>
              <div className="tlg-pricing-actions"><Link to="/register" onClick={() => setPricingOpen(false)}>{t('home.cta.create')}</Link></div>
            </section>
          </div>
        ), document.body)}

        {children && (
          <div className="tlg-footer-extra">
            {children}
          </div>
        )}

        <div
          style={{
            marginTop: 18,
            paddingTop: 14,
            borderTop: '1px solid rgba(255,255,255,.09)',
            fontSize: 12,
          }}
        >
          <span style={{ color: 'rgba(255,255,255,.55)' }}>Also from our studio: </span>
          <a
            href={PROPELOTON_URL}
            target="_blank"
            rel="noreferrer"
            onClick={recordCrossGameClick}
            style={{ color: '#8bd1f6', fontWeight: 800, textDecoration: 'none' }}
          >
            ProPeloton Manager ↗
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
