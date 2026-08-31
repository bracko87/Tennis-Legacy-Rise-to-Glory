import {
  Bell,
  CircleHelp,
  Gift,
  Inbox,
  LifeBuoy,
  Mail,
  MessageSquare,
  Settings2,
  UserRound,
  UsersRound,
} from 'lucide-react'
import { useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'

function ManagerPageIntro({
  eyebrow,
  title,
  description,
}: {
  eyebrow: string
  title: string
  description: string
}) {
  return (
    <section className="tlg-v2-command">
      <div className="tlg-v2-command-inner">
        <div>
          <span className="tlg-v2-command-kicker">{eyebrow}</span>
          <h2>{title}</h2>
          <p>{description}</p>
        </div>
      </div>
    </section>
  )
}

function EmptyPanel({
  icon,
  title,
  text,
}: {
  icon: JSX.Element
  title: string
  text: string
}) {
  return (
    <section className="tlg-v2-panel">
      <header className="tlg-v2-panel-header">
        <div>
          <span>Manager center</span>
          <h3>{title}</h3>
        </div>
      </header>
      <div className="tlg-v2-panel-body">
        <div className="tlg-v2-empty">
          {icon}
          <strong>{title}</strong>
          <p>{text}</p>
        </div>
      </div>
    </section>
  )
}

export function NotificationsPage() {
  return (
    <GameLayout title="Notifications" subtitle="Manager alerts and game updates">
      <ManagerPageIntro
        eyebrow="Notification center"
        title="Stay informed."
        description="Important account, career, tournament and system updates will appear here in one place."
      />
      <EmptyPanel
        icon={<Bell size={26} />}
        title="No new notifications"
        text="You are up to date. New Tennis Legacy notifications will appear here when there is something that needs your attention."
      />
    </GameLayout>
  )
}

export function PlayerAccountPage() {
  const { player, user } = useAuth()
  const playerName = player ? `${player.first_name} ${player.last_name}`.trim() : 'Player not available'

  return (
    <GameLayout title="Player & account" subtitle="Identity and account information">
      <ManagerPageIntro
        eyebrow="Manager settings"
        title="Player & account"
        description="Review the identity connected to your Tennis Legacy manager account and professional career."
      />
      <section className="tlg-v2-panel">
        <header className="tlg-v2-panel-header">
          <div><span>Account</span><h3>Current identity</h3></div>
          <div className="tlg-v2-panel-icon"><UserRound size={17} /></div>
        </header>
        <div className="tlg-v2-panel-body">
          <div className="tlg-v2-checklist">
            <AccountRow label="Manager email" value={user?.email ?? 'Authenticated account'} />
            <AccountRow label="Professional player" value={playerName} />
            <AccountRow label="Competition world" value={player ? `${player.world} World` : '—'} />
            <AccountRow label="Country code" value={player?.country_code ?? '—'} />
          </div>
        </div>
      </section>
    </GameLayout>
  )
}

export function GamePreferencesPage() {
  return (
    <GameLayout title="Game preferences" subtitle="Personal game experience settings">
      <ManagerPageIntro
        eyebrow="Manager settings"
        title="Game preferences"
        description="This page is reserved for interface, communication and gameplay display preferences."
      />
      <EmptyPanel
        icon={<Settings2 size={26} />}
        title="Preferences are coming next"
        text="Preference controls will be connected here as the corresponding game systems are introduced."
      />
    </GameLayout>
  )
}

export function InboxPage() {
  return (
    <GameLayout title="Inbox" subtitle="Direct manager communication">
      <ManagerPageIntro
        eyebrow="Communication"
        title="Manager inbox"
        description="Direct game messages, competition communication and important manager correspondence will be collected here."
      />
      <EmptyPanel
        icon={<Inbox size={26} />}
        title="Your inbox is empty"
        text="There are no messages waiting for you right now."
      />
    </GameLayout>
  )
}

export function HelpPage() {
  return (
    <GameLayout title="Help" subtitle="Guides and support">
      <ManagerPageIntro
        eyebrow="Support"
        title="Tennis Legacy help"
        description="Find guidance for your account, player career and game systems as Tennis Legacy develops."
      />
      <EmptyPanel
        icon={<CircleHelp size={26} />}
        title="Help center"
        text="Game guides and frequently asked questions will be organized on this page. For direct support, use Contact Us."
      />
    </GameLayout>
  )
}

export function ForumPage() {
  return (
    <GameLayout title="Forum" subtitle="Tennis Legacy community">
      <ManagerPageIntro
        eyebrow="Community"
        title="Manager forum"
        description="The forum will be the community space for discussion, feedback, competition and shared Tennis Legacy stories."
      />
      <EmptyPanel
        icon={<MessageSquare size={26} />}
        title="Forum opening later"
        text="The community forum is not live yet. This page is ready for the forum integration when it is introduced."
      />
    </GameLayout>
  )
}

export function ContactUsPage() {
  return (
    <GameLayout title="Contact Us" subtitle="Direct Tennis Legacy support">
      <ManagerPageIntro
        eyebrow="Support"
        title="Contact Tennis Legacy"
        description="For account questions, technical problems or game feedback, contact the Tennis Legacy team directly."
      />
      <section className="tlg-v2-panel">
        <header className="tlg-v2-panel-header">
          <div><span>Contact</span><h3>Email support</h3></div>
          <div className="tlg-v2-panel-icon"><Mail size={17} /></div>
        </header>
        <div className="tlg-v2-panel-body">
          <a className="tlg-v2-quick-link" href="mailto:contact@tennislegacygame.com">
            <span className="tlg-v2-quick-icon"><LifeBuoy size={16} /></span>
            <span className="tlg-v2-quick-copy">
              <strong>contact@tennislegacygame.com</strong>
              <span>Open your email client</span>
            </span>
          </a>
        </div>
      </section>
    </GameLayout>
  )
}

export function InviteFriendsPage() {
  const [copied, setCopied] = useState(false)

  async function copyInviteLink() {
    try {
      await navigator.clipboard.writeText(`${window.location.origin}/register`)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1800)
    } catch {
      setCopied(false)
    }
  }

  return (
    <GameLayout title="Invite Friends" subtitle="Bring more managers into the world">
      <ManagerPageIntro
        eyebrow="Community"
        title="Invite friends"
        description="Invite another manager to create their own separate ATP or WTA singles career in Tennis Legacy."
      />
      <section className="tlg-v2-panel">
        <header className="tlg-v2-panel-header">
          <div><span>Invitation</span><h3>Registration link</h3></div>
          <div className="tlg-v2-panel-icon"><UsersRound size={17} /></div>
        </header>
        <div className="tlg-v2-panel-body">
          <button type="button" className="tlg-v2-quick-link" onClick={copyInviteLink}>
            <span className="tlg-v2-quick-icon"><Gift size={16} /></span>
            <span className="tlg-v2-quick-copy">
              <strong>{copied ? 'Invite link copied' : 'Copy invite link'}</strong>
              <span>{`${window.location.origin}/register`}</span>
            </span>
          </button>
        </div>
      </section>
    </GameLayout>
  )
}

function AccountRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="tlg-v2-check">
      <span className="tlg-v2-check-icon"><UserRound size={14} /></span>
      <div className="tlg-v2-check-copy">
        <strong>{label}</strong>
        <span>{value}</span>
      </div>
    </div>
  )
}
