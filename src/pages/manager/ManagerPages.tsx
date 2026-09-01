import {
  Bell,
  Camera,
  CircleHelp,
  Gift,
  Inbox,
  LifeBuoy,
  LockKeyhole,
  Mail,
  MessageSquare,
  Settings2,
  UserRound,
  UsersRound,
} from 'lucide-react'
import { useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/player-account.css'

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
  const avatarUrl = usePlayerAvatarUrl(player?.image_path)
  const playerName = player ? `${player.first_name} ${player.last_name}`.trim() : 'Player not available'
  const [avatarReason, setAvatarReason] = useState('')
  const [avatarMessage, setAvatarMessage] = useState('')
  const [passwordStatus, setPasswordStatus] = useState<string | null>(null)
  const [passwordBusy, setPasswordBusy] = useState(false)

  function requestAvatarReplacement(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!player || !user?.email) return

    const subject = encodeURIComponent(`Avatar replacement request — ${playerName}`)
    const body = encodeURIComponent(
      [
        'Tennis Legacy avatar replacement request',
        '',
        `Player: ${playerName}`,
        `Player ID: ${player.id}`,
        `World: ${player.world}`,
        `Country: ${player.country_code}`,
        `Account email: ${user.email}`,
        `Reason: ${avatarReason || 'Not specified'}`,
        '',
        'Request details:',
        avatarMessage || 'No additional details provided.',
      ].join('\n'),
    )

    window.location.href = `mailto:contact@tennislegacygame.com?subject=${subject}&body=${body}`
  }

  async function sendPasswordChangeEmail() {
    if (!user?.email || passwordBusy) return
    setPasswordBusy(true)
    setPasswordStatus(null)

    const { error } = await supabase.auth.resetPasswordForEmail(user.email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })

    if (error) {
      setPasswordStatus(error.message)
    } else {
      setPasswordStatus('Password change email sent. Check your inbox.')
    }

    setPasswordBusy(false)
  }

  return (
    <GameLayout title="Player & account" subtitle="Identity and account information">
      <div className="tlg-account-page">
        <section className="tlg-account-section">
          <header className="tlg-account-section-head">
            <div>
              <span>Player profile</span>
              <h2>Player & account</h2>
              <p>Review the identity connected to your Tennis Legacy account and professional career.</p>
            </div>
          </header>

          <div className="tlg-account-profile-layout">
            <div className="tlg-account-avatar-card">
              <div className="tlg-account-avatar-frame">
                {avatarUrl ? (
                  <img src={avatarUrl} alt={`${playerName} avatar`} />
                ) : (
                  <UserRound size={58} aria-hidden="true" />
                )}
              </div>
              <strong>{playerName}</strong>
              <span>{player ? `${player.world} singles` : 'Professional player'}</span>
            </div>

            <div className="tlg-account-fields">
              <label className="tlg-account-field">
                <span>Player name</span>
                <input value={playerName} readOnly disabled />
                <small>Player name is fixed when the career is created and cannot be changed.</small>
              </label>

              <label className="tlg-account-field">
                <span>Account email</span>
                <input value={user?.email ?? ''} readOnly />
                <small>This is the email connected to your Tennis Legacy account.</small>
              </label>

              <label className="tlg-account-field">
                <span>Competition world</span>
                <input value={player ? `${player.world} World` : '—'} readOnly />
              </label>

              <label className="tlg-account-field">
                <span>Country</span>
                <input value={player?.country_code ?? '—'} readOnly />
              </label>
            </div>
          </div>
        </section>

        <section className="tlg-account-section">
          <header className="tlg-account-section-head tlg-account-section-head-icon">
            <div>
              <span>Player image</span>
              <h3>Avatar replacement request</h3>
              <p>Your avatar cannot be changed directly. Submit a request and the Tennis Legacy team can review it.</p>
            </div>
            <Camera size={20} />
          </header>

          <form className="tlg-account-avatar-form" onSubmit={requestAvatarReplacement}>
            <label className="tlg-account-field">
              <span>Reason for replacement</span>
              <select value={avatarReason} onChange={(event) => setAvatarReason(event.target.value)} required>
                <option value="">Choose a reason</option>
                <option value="I selected the wrong avatar">I selected the wrong avatar</option>
                <option value="Avatar does not fit my player">Avatar does not fit my player</option>
                <option value="Avatar display problem">Avatar display problem</option>
                <option value="Other">Other</option>
              </select>
            </label>

            <label className="tlg-account-field">
              <span>Request details</span>
              <textarea
                rows={4}
                value={avatarMessage}
                onChange={(event) => setAvatarMessage(event.target.value)}
                placeholder="Tell us why you want the avatar replaced and, if relevant, what kind of replacement you prefer."
                required
              />
            </label>

            <div className="tlg-account-form-actions">
              <button type="submit" className="tlg-account-primary-button" disabled={!player || !user?.email}>
                Request avatar replacement
              </button>
              <small>The request opens your email client with the player details already prepared. The avatar is not changed automatically.</small>
            </div>
          </form>
        </section>

        <section className="tlg-account-section">
          <header className="tlg-account-section-head tlg-account-section-head-icon">
            <div>
              <span>Security</span>
              <h3>Change password</h3>
              <p>For security, password changes are completed by email verification.</p>
            </div>
            <LockKeyhole size={20} />
          </header>

          <div className="tlg-account-password-body">
            <input value={user?.email ?? ''} readOnly aria-label="Account email for password change" />
            <button
              type="button"
              className="tlg-account-secondary-button"
              onClick={sendPasswordChangeEmail}
              disabled={!user?.email || passwordBusy}
            >
              {passwordBusy ? 'Sending…' : 'Send Password Change Email'}
            </button>
            {passwordStatus && <p className="tlg-account-status">{passwordStatus}</p>}
            <small>After opening the email link, you can choose a new password on the reset-password page.</small>
          </div>
        </section>
      </div>
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
