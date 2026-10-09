import { CircleHelp, GraduationCap, LifeBuoy, MessageSquare } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import GameLayout from '../../components/layout/GameLayout'
import { useTutorial } from '../../tutorial/TutorialProvider'
import '../../styles/community-support.css'

const DISCORD_INVITE = 'https://discord.gg/RBBtXgZey2'

export function ForumPage() {
  const { t } = useTranslation()
  return (
    <GameLayout title={t('supportPages.forum.title')} subtitle={t('supportPages.forum.subtitle')}>
      <div className="tlg-community-page">
        <section className="tlg-community-discord-hero">
          <div className="tlg-community-discord-mark" aria-hidden="true">
            <MessageSquare size={34} />
          </div>
          <div className="tlg-community-discord-copy">
            <span>{t('supportPages.forum.official')}</span>
            <h2>{t('supportPages.forum.name')}</h2>
            <p>
              {t('supportPages.forum.intro')}
            </p>
            <div className="tlg-community-actions">
              <a className="tlg-community-button tlg-community-button-primary" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
                {t('supportPages.forum.join')}
              </a>
              <a className="tlg-community-button" href="/game/help">{t('supportPages.forum.openHelp')}</a>
            </div>
          </div>
        </section>

        <section className="tlg-community-panel">
          <header>
            <span>{t('supportPages.forum.community')}</span>
            <h3>{t('supportPages.forum.canDo')}</h3>
          </header>
          <div className="tlg-community-grid tlg-community-grid-three">
            <InfoCard title={t('supportPages.forum.talkTitle')} text={t('supportPages.forum.talkBody')} />
            <InfoCard title={t('supportPages.forum.helpTitle')} text={t('supportPages.forum.helpBody')} />
            <InfoCard title={t('supportPages.forum.devTitle')} text={t('supportPages.forum.devBody')} />
            <InfoCard title={t('supportPages.forum.feedbackTitle')} text={t('supportPages.forum.feedbackBody')} />
            <InfoCard title={t('supportPages.forum.bugsTitle')} text={t('supportPages.forum.bugsBody')} />
            <InfoCard title={t('supportPages.forum.careerTitle')} text={t('supportPages.forum.careerBody')} />
          </div>
        </section>
      </div>
    </GameLayout>
  )
}

export function HelpPage() {
  const { t } = useTranslation()
  const { status: tutorialStatus, restartTutorial } = useTutorial()

  return (
    <GameLayout title={t('supportPages.help.title')} subtitle={t('supportPages.help.subtitle')}>
      <div className="tlg-community-page">
        <section className="tlg-help-hero">
          <div>
            <span>{t('supportPages.help.welcome')}</span>
            <h2>{t('supportPages.help.center')}</h2>
            <p>
              {t('supportPages.help.intro')}
            </p>
          </div>
          <div className="tlg-community-actions">
            <button
              type="button"
              className="tlg-community-button tlg-community-button-primary"
              onClick={() => void restartTutorial()}
            >
              <GraduationCap size={15} aria-hidden="true" />
              {tutorialStatus === 'completed' || tutorialStatus === 'skipped' ? t('supportPages.help.restartTutorial') : t('supportPages.help.startTutorial')}
            </button>
            <a className="tlg-community-button" href="/game/manual">
              {t('supportPages.help.fullManual')}
            </a>
            <a className="tlg-community-button" href="/game/manual?download=pdf">
              {t('supportPages.help.downloadManual')}
            </a>
            <a className="tlg-community-button" href="/game/contact">{t('supportPages.help.contactSupport')}</a>
            <a className="tlg-community-button tlg-community-button-discord" href={DISCORD_INVITE} target="_blank" rel="noreferrer">{t('supportPages.help.joinDiscord')}</a>
          </div>
        </section>

        <section className="tlg-community-panel tlg-help-start-panel">
          <div className="tlg-help-main-column">
            <header>
              <span>{t('supportPages.help.gettingStarted')}</span>
              <h3>{t('supportPages.help.firstSteps')}</h3>
            </header>
            <div className="tlg-community-grid tlg-community-grid-two">
              <HelpStep number="1" title={t('supportPages.help.step1Title')} text={t('supportPages.help.step1Body')} href="/game/overview" linkLabel={t('supportPages.help.step1Link')} />
              <HelpStep number="2" title={t('supportPages.help.step2Title')} text={t('supportPages.help.step2Body')} href="/game/calendar" linkLabel={t('supportPages.help.step2Link')} />
              <HelpStep number="3" title={t('supportPages.help.step3Title')} text={t('supportPages.help.step3Body')} href="/game/rankings" linkLabel={t('supportPages.help.step3Link')} />
              <HelpStep number="4" title={t('supportPages.help.step4Title')} text={t('supportPages.help.step4Body')} href="/game/player-account" linkLabel={t('supportPages.help.step4Link')} />
            </div>
          </div>

          <aside className="tlg-help-quick-links">
            <span>{t('supportPages.help.quickLinks')}</span>
            <a href="/game/overview">{t('supportPages.help.overview')}</a>
            <a href="/game/calendar">{t('supportPages.help.tournamentCalendar')}</a>
            <a href="/game/rankings">{t('supportPages.help.rankings')}</a>
            <a href="/game/inbox">{t('supportPages.help.inbox')}</a>
            <a href="/game/preferences">{t('supportPages.help.preferences')}</a>
            <a href="/game/contact">{t('supportPages.help.contactUs')}</a>
          </aside>
        </section>

        <section>
          <h3 className="tlg-community-section-title">{t('supportPages.help.gameplayBasics')}</h3>
          <div className="tlg-community-grid tlg-community-grid-three">
            <InfoCard title={t('supportPages.help.worldsTitle')} text={t('supportPages.help.worldsBody')} />
            <InfoCard title={t('supportPages.help.tournamentTitle')} text={t('supportPages.help.tournamentBody')} />
            <InfoCard title={t('supportPages.help.nameTitle')} text={t('supportPages.help.nameBody')} />
            <InfoCard title={t('supportPages.help.profilesTitle')} text={t('supportPages.help.profilesBody')} />
            <InfoCard title={t('supportPages.help.rankTitle')} text={t('supportPages.help.rankBody')} />
            <InfoCard title={t('supportPages.help.manualTitle')} text={t('supportPages.help.manualBody')} />
          </div>
        </section>

        <section className="tlg-community-panel">
          <header>
            <span>{t('supportPages.help.helpTopics')}</span>
            <h3>{t('supportPages.help.manualSections')}</h3>
            <p>{t('supportPages.help.manualIntro')}</p>
          </header>
          <div className="tlg-community-grid tlg-community-grid-three">
            <ManualCard title={t('supportPages.help.overview')} status={t('supportPages.help.available')} href="/game/overview" />
            <ManualCard title={t('supportPages.help.tournamentCalendar')} status={t('supportPages.help.available')} href="/game/calendar" />
            <ManualCard title={t('supportPages.help.rankingsProfiles')} status={t('supportPages.help.available')} href="/game/rankings" />
            <ManualCard title={t('supportPages.help.inbox')} status={t('supportPages.help.available')} href="/game/inbox" />
            <ManualCard title={t('supportPages.help.playerAccount')} status={t('supportPages.help.available')} href="/game/player-account" />
            <ManualCard title={t('supportPages.help.trainingSkills')} status={t('supportPages.help.coveredManual')} href="/game/manual/regular-training" />
            <ManualCard title={t('supportPages.help.fullManual')} status={t('supportPages.help.detailedChapters', { count: 33 })} href="/game/manual" />
          </div>
        </section>

        <section className="tlg-help-support-banner">
          <div>
            <span>{t('supportPages.help.stillNeed')}</span>
            <h3>{t('supportPages.help.askSupport')}</h3>
            <p>{t('supportPages.help.reportTip')}</p>
          </div>
          <div className="tlg-community-actions">
            <a className="tlg-community-button tlg-community-button-light" href="/game/contact"><LifeBuoy size={16} /> {t('supportPages.help.contact')}</a>
            <a className="tlg-community-button tlg-community-button-outline-light" href={DISCORD_INVITE} target="_blank" rel="noreferrer"><CircleHelp size={16} /> {t('supportPages.help.askDiscord')}</a>
          </div>
        </section>
      </div>
    </GameLayout>
  )
}

function InfoCard({ title, text }: { title: string; text: string }) {
  return <article className="tlg-community-info-card"><strong>{title}</strong><p>{text}</p></article>
}

function HelpStep({ number, title, text, href, linkLabel }: { number: string; title: string; text: string; href: string; linkLabel: string }) {
  return (
    <article className="tlg-community-info-card tlg-help-step">
      <strong>{number}. {title}</strong>
      <p>{text}</p>
      <a href={href}>{linkLabel}</a>
    </article>
  )
}

function ManualCard({ title, status, href }: { title: string; status: string; href?: string }) {
  const { t } = useTranslation()
  return (
    <article className="tlg-community-info-card tlg-manual-card">
      <strong>{title}</strong>
      <p>{status}</p>
      {href ? <a href={href}>{t('supportPages.help.openPage')}</a> : <span>{t('supportPages.help.comingLater')}</span>}
    </article>
  )
}
