import { ExternalLink, MessageCircle, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useLocation } from 'react-router'

import '../../styles/beta-disclaimer.css'

const BETA_NOTICE_SESSION_KEY = 'tlg-beta-disclaimer-seen-v1'
const DISCORD_INVITE_URL = 'https://discord.gg/RBBtXgZey2'

export default function BetaDisclaimer() {
  const location = useLocation()
  const [open, setOpen] = useState(false)

  useEffect(() => {
    if (location.pathname !== '/') return

    try {
      if (window.sessionStorage.getItem(BETA_NOTICE_SESSION_KEY) !== '1') {
        setOpen(true)
      }
    } catch {
      setOpen(true)
    }
  }, [location.pathname])

  useEffect(() => {
    const page = document.querySelector('.tlg-marketing-page')
    if (!page) return

    const registerLinks = Array.from(page.querySelectorAll<HTMLAnchorElement>('a[href="/register"]'))
    const explainRegistrationLock = (event: Event) => {
      event.preventDefault()
      event.stopPropagation()
      setOpen(true)
    }

    registerLinks.forEach((link) => {
      link.classList.add('tlg-beta-registration-disabled')
      link.setAttribute('aria-disabled', 'true')
      link.setAttribute('tabindex', '-1')
      link.setAttribute('title', 'New registrations are temporarily closed during beta testing.')
      link.addEventListener('click', explainRegistrationLock)
    })

    return () => {
      registerLinks.forEach((link) => {
        link.classList.remove('tlg-beta-registration-disabled')
        link.removeAttribute('aria-disabled')
        link.removeAttribute('tabindex')
        link.removeAttribute('title')
        link.removeEventListener('click', explainRegistrationLock)
      })
    }
  }, [location.pathname])

  useEffect(() => {
    if (!open) return
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = previousOverflow
    }
  }, [open])

  function acknowledge() {
    try {
      window.sessionStorage.setItem(BETA_NOTICE_SESSION_KEY, '1')
    } catch {
      // The notice can still be dismissed when browser storage is unavailable.
    }
    setOpen(false)
  }

  if (!open) return null

  return (
    <div className="tlg-beta-modal-backdrop" role="presentation">
      <section
        className="tlg-beta-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="tlg-beta-modal-title"
        aria-describedby="tlg-beta-modal-description"
      >
        <button
          type="button"
          className="tlg-beta-modal-close"
          aria-label="Continue to website"
          onClick={acknowledge}
        >
          <X size={19} />
        </button>

        <span className="tlg-beta-modal-eyebrow">Early beta testing</span>
        <h2 id="tlg-beta-modal-title">Tennis Legacy is still under active development</h2>
        <p id="tlg-beta-modal-description">
          Tennis Legacy: Rise to Glory is currently an early beta version used for testing and development. We are still building, balancing and preparing the game for a future launch, and we are not close to the final release yet.
        </p>
        <p>
          Features, game data and systems may change while testing continues. New registrations are temporarily closed during this phase, but existing testers can continue to sign in normally.
        </p>

        <div className="tlg-beta-modal-community">
          <MessageCircle size={18} />
          <div>
            <strong>Follow the development on Discord</strong>
            <span>Join the community for development updates, testing discussion and feedback.</span>
          </div>
        </div>

        <div className="tlg-beta-modal-actions">
          <a
            href={DISCORD_INVITE_URL}
            target="_blank"
            rel="noreferrer"
            className="tlg-btn tlg-btn-primary tlg-btn-large"
            onClick={acknowledge}
          >
            Join Discord
            <ExternalLink size={17} />
          </a>
          <button
            type="button"
            className="tlg-btn tlg-btn-secondary tlg-btn-large"
            onClick={acknowledge}
          >
            Continue to website
          </button>
        </div>
      </section>
    </div>
  )
}
