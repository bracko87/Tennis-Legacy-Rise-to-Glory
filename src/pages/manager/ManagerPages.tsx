import {
  Bell,
  CircleHelp,
  Gift,
  Inbox,
  LifeBuoy,
  LockKeyhole,
  Mail,
  MessageSquare,
  RotateCcw,
  Settings2,
  Trash2,
  TriangleAlert,
  UserRound,
  UsersRound,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import AvatarReplacementCancelControl from '../../components/player/AvatarReplacementCancelControl'
import AvatarReplacementRequestPanel from '../../components/player/AvatarReplacementRequestPanel'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import { lifestyleCopy } from '../../lib/lifestyleCareerI18n'
import type { LifestyleCareer } from '../../components/private-life/LifestyleCareerPanel'
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
  const { t, i18n } = useTranslation()
  const careerCopy = lifestyleCopy(i18n.resolvedLanguage ?? i18n.language)
  const navigate = useNavigate()
  const { player, user, refreshPlayer, signOut } = useAuth()
  const [careerState,setCareerState] = useState<LifestyleCareer | null>(null)
  useEffect(() => {
    if (!player?.id) { setCareerState(null); return }
    let active = true
    void supabase.rpc('get_my_private_life_career_v1').then(({data,error}) => {
      if (!active) return
      setCareerState(!error && data ? data as LifestyleCareer : null)
    })
    return () => { active = false }
  },[player?.id])
  const avatarUrl = usePlayerAvatarUrl(player?.image_path)
  const playerName = player ? `${player.first_name} ${player.last_name}`.trim() : t('playerAccountPage.unavailable')
  const [passwordStatus, setPasswordStatus] = useState<string | null>(null)
  const [passwordBusy, setPasswordBusy] = useState(false)
  const [dangerAction, setDangerAction] = useState<'restart' | 'delete' | null>(null)
  const [dangerConfirmation, setDangerConfirmation] = useState('')
  const [dangerBusy, setDangerBusy] = useState(false)
  const [dangerStatus, setDangerStatus] = useState<string | null>(null)

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
      setPasswordStatus(t('playerAccountPage.passwordSent'))
    }

    setPasswordBusy(false)
  }

  function openDangerAction(action: 'restart' | 'delete') {
    setDangerAction(action)
    setDangerConfirmation('')
    setDangerStatus(null)
  }

  function closeDangerAction() {
    if (dangerBusy) return
    setDangerAction(null)
    setDangerConfirmation('')
    setDangerStatus(null)
  }

  async function confirmDangerAction() {
    if (!dangerAction || dangerBusy) return

    const requiredPhrase = dangerAction === 'restart' ? 'RESTART' : 'DELETE'
    if (dangerConfirmation.trim().toUpperCase() !== requiredPhrase) {
      setDangerStatus(t('playerAccountPage.confirmPhrase', { phrase: requiredPhrase }))
      return
    }

    setDangerBusy(true)
    setDangerStatus(null)

    if (dangerAction === 'restart') {
      const { error } = await supabase.rpc('restart_tennis_legacy_account_v1')
      if (error) {
        setDangerStatus(error.message)
        setDangerBusy(false)
        return
      }

      await refreshPlayer()
      navigate('/game/overview', { replace: true })
      return
    }

    const { error } = await supabase.rpc('delete_tennis_legacy_account_v1')
    if (error) {
      setDangerStatus(error.message)
      setDangerBusy(false)
      return
    }

    try {
      await signOut()
    } finally {
      navigate('/', { replace: true })
    }
  }

  const dangerPhrase = dangerAction === 'restart' ? 'RESTART' : 'DELETE'

  return (
    <GameLayout title={t('playerAccountPage.title')} subtitle={t('playerAccountPage.subtitle')}>
      <div className="tlg-account-page">
        <section className="tlg-account-section">
          <header className="tlg-account-section-head">
            <div>
              <span>{t('playerAccountPage.profile')}</span>
              <h2>{t('playerAccountPage.heading')}</h2>
              <p>{t('playerAccountPage.intro')}</p>
            </div>
          </header>

          <div className="tlg-account-profile-layout">
            <div className="tlg-account-avatar-card" aria-label={t('playerAccountPage.avatarAria')}>
              <div className="tlg-account-avatar-frame">
                {avatarUrl ? (
                  <img src={avatarUrl} alt={t('playerAccountPage.avatarAlt', { name: playerName })} />
                ) : (
                  <UserRound size={72} aria-hidden="true" />
                )}
              </div>
            </div>

            <div className="tlg-account-fields">
              <label className="tlg-account-field">
                <span>{t('playerAccountPage.playerName')}</span>
                <input value={playerName} readOnly disabled />
                <small>{t('playerAccountPage.playerNameNote')}</small>
              </label>

              <label className="tlg-account-field">
                <span>{t('playerAccountPage.email')}</span>
                <input value={user?.email ?? ''} readOnly />
                <small>{t('playerAccountPage.emailNote')}</small>
              </label>

              <label className="tlg-account-field">
                <span>{t('playerAccountPage.world')}</span>
                <input value={player ? t('playerAccountPage.worldValue', { world: player.world }) : '—'} readOnly />
              </label>

              <label className="tlg-account-field">
                <span>{t('playerAccountPage.country')}</span>
                <input value={player?.country_code ?? '—'} readOnly />
              </label>
              <label className="tlg-account-field">
                <span>{careerCopy.homeBase}</span>
                <input readOnly value={[careerState?.home_base?.city,careerState?.home_base?.country_code].filter(Boolean).join(', ') || '—'} />
                {!careerState && <small>{careerCopy.backendPending}</small>}
              </label>
              <label className="tlg-account-field">
                <span>{careerCopy.currentLocation}</span>
                <input readOnly value={[careerState?.current_location?.city,careerState?.current_location?.country_code].filter(Boolean).join(', ') || '—'} />
              </label>
            </div>
          </div>
        </section>

        <div className="tlg-avatar-request-combined">
          <AvatarReplacementRequestPanel />
          <AvatarReplacementCancelControl />
        </div>

        <section className="tlg-account-section">
          <header className="tlg-account-section-head tlg-account-section-head-icon">
            <div>
              <span>{t('playerAccountPage.security')}</span>
              <h3>{t('playerAccountPage.changePassword')}</h3>
              <p>{t('playerAccountPage.passwordIntro')}</p>
            </div>
            <LockKeyhole size={20} />
          </header>

          <div className="tlg-account-password-body">
            <input value={user?.email ?? ''} readOnly aria-label={t('playerAccountPage.emailAria')} />
            <button
              type="button"
              className="tlg-account-secondary-button"
              onClick={sendPasswordChangeEmail}
              disabled={!user?.email || passwordBusy}
            >
              {passwordBusy ? t('playerAccountPage.sending') : t('playerAccountPage.sendReset')}
            </button>
            {passwordStatus && <p className="tlg-account-status">{passwordStatus}</p>}
            <small>{t('playerAccountPage.resetNote')}</small>
          </div>
        </section>

        <section className="tlg-account-section tlg-account-danger-zone">
          <header className="tlg-account-section-head tlg-account-danger-head">
            <div>
              <span>{t('playerAccountPage.danger')}</span>
              <h3>{t('playerAccountPage.removal')}</h3>
              <p>{t('playerAccountPage.dangerIntro')}</p>
            </div>
            <TriangleAlert size={21} />
          </header>

          <div className="tlg-account-danger-grid">
            <article className="tlg-account-danger-card">
              <div className="tlg-account-danger-copy">
                <span className="tlg-account-danger-icon"><RotateCcw size={18} /></span>
                <div>
                  <strong>{t('playerAccountPage.restart')}</strong>
                  <p>{t('playerAccountPage.restartBody')}</p>
                </div>
              </div>
              <button type="button" className="tlg-account-danger-button" onClick={() => openDangerAction('restart')}>
                {t('playerAccountPage.restart')}
              </button>
            </article>

            <article className="tlg-account-danger-card tlg-account-danger-card-critical">
              <div className="tlg-account-danger-copy">
                <span className="tlg-account-danger-icon"><Trash2 size={18} /></span>
                <div>
                  <strong>{t('playerAccountPage.delete')}</strong>
                  <p>{t('playerAccountPage.deleteBody')}</p>
                </div>
              </div>
              <button type="button" className="tlg-account-danger-button tlg-account-danger-button-critical" onClick={() => openDangerAction('delete')}>
                {t('playerAccountPage.delete')}
              </button>
            </article>
          </div>

          {dangerAction && (
            <div className="tlg-account-danger-confirm" role="group" aria-label={t('playerAccountPage.confirmAria')}>
              <div>
                <strong>{dangerAction === 'restart' ? t('playerAccountPage.confirmRestart') : t('playerAccountPage.confirmDelete')}</strong>
                <p>
                  {dangerAction === 'restart'
                    ? t('playerAccountPage.confirmRestartBody')
                    : t('playerAccountPage.confirmDeleteBody')}
                </p>
              </div>
              <label>
                <span>{t('playerAccountPage.typePhrase', { phrase: dangerPhrase })}</span>
                <input
                  value={dangerConfirmation}
                  onChange={(event) => {
                    setDangerConfirmation(event.target.value)
                    setDangerStatus(null)
                  }}
                  autoComplete="off"
                  spellCheck={false}
                />
              </label>
              {dangerStatus && <p className="tlg-account-danger-status">{dangerStatus}</p>}
              <div className="tlg-account-danger-confirm-actions">
                <button type="button" className="tlg-account-danger-cancel" onClick={closeDangerAction} disabled={dangerBusy}>
                  {t('common.cancel')}
                </button>
                <button
                  type="button"
                  className="tlg-account-danger-button tlg-account-danger-button-critical"
                  onClick={confirmDangerAction}
                  disabled={dangerBusy || dangerConfirmation.trim().toUpperCase() !== dangerPhrase}
                >
                  {dangerBusy
                    ? t('playerAccountPage.processing')
                    : dangerAction === 'restart'
                      ? t('playerAccountPage.restartNow')
                      : t('playerAccountPage.deletePermanently')}
                </button>
              </div>
            </div>
          )}
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
