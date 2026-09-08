import { useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { MessageSquare, ShieldAlert } from 'lucide-react'

const TENNIS_LEGACY_DISCORD_INVITE = 'https://discord.gg/RBBtXgZey2'

export default function PublicBetaGate() {
  const [target, setTarget] = useState<HTMLElement | null>(null)

  useEffect(() => {
    const locate = () => {
      const next = document.querySelector<HTMLElement>('.tlg-hero-actions')
      setTarget((current) => current === next ? current : next)
    }

    locate()
    const observer = new MutationObserver(locate)
    observer.observe(document.body, { childList: true, subtree: true })
    return () => observer.disconnect()
  }, [])

  if (!target) return null

  return createPortal(
    <section className="tlg-public-beta-notice" aria-label="Tennis Legacy beta status">
      <div className="tlg-public-beta-icon" aria-hidden="true">
        <ShieldAlert size={22} />
      </div>
      <div className="tlg-public-beta-copy">
        <span>BETA DEVELOPMENT</span>
        <strong>Tennis Legacy is still in active development.</strong>
        <p>
          New account registration is temporarily closed while we finish the beta version.
          We expect to open the game to new players soon.
        </p>
      </div>
      <a
        className="tlg-public-beta-discord"
        href={TENNIS_LEGACY_DISCORD_INVITE}
        target="_blank"
        rel="noreferrer"
      >
        <MessageSquare size={17} />
        Join our Discord
      </a>
    </section>,
    target,
  )
}
