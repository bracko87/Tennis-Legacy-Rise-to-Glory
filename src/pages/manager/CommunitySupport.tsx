import { CircleHelp, LifeBuoy, MessageSquare } from 'lucide-react'

import GameLayout from '../../components/layout/GameLayout'
import '../../styles/community-support.css'

const DISCORD_INVITE = 'https://discord.gg/RBBtXgZey2'

export function ForumPage() {
  return (
    <GameLayout title="Forum" subtitle="Tennis Legacy community on Discord">
      <div className="tlg-community-page">
        <section className="tlg-community-discord-hero">
          <div className="tlg-community-discord-mark" aria-hidden="true">
            <MessageSquare size={34} />
          </div>
          <div className="tlg-community-discord-copy">
            <span>Official community forum</span>
            <h2>Tennis Legacy Discord</h2>
            <p>
              Our Discord server is the official community forum for Tennis Legacy: Rise to Glory.
              Join other players to discuss careers, tournaments and strategy, ask questions, report
              bugs, share suggestions and follow development.
            </p>
            <div className="tlg-community-actions">
              <a className="tlg-community-button tlg-community-button-primary" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
                Join Tennis Legacy Discord
              </a>
              <a className="tlg-community-button" href="/game/help">Open Help Center</a>
            </div>
          </div>
        </section>

        <section className="tlg-community-panel">
          <header>
            <span>Community</span>
            <h3>What you can do on Discord</h3>
          </header>
          <div className="tlg-community-grid tlg-community-grid-three">
            <InfoCard title="Talk with players" text="Discuss ATP and WTA careers, tournaments, rankings, training plans and long-term strategy." />
            <InfoCard title="Get help" text="Ask gameplay questions, report problems and compare solutions with other Tennis Legacy players." />
            <InfoCard title="Follow development" text="See announcements, development updates and important information as new systems are introduced." />
            <InfoCard title="Share feedback" text="Post suggestions and explain what would make the game clearer, deeper or easier to use." />
            <InfoCard title="Report bugs" text="Share reproducible issues and screenshots so problems can be investigated and corrected faster." />
            <InfoCard title="Share your career" text="Post screenshots, tournament runs, ranking milestones and memorable moments from your player's story." />
          </div>
        </section>
      </div>
    </GameLayout>
  )
}

export function HelpPage() {
  return (
    <GameLayout title="Help" subtitle="Guides, quick links and support">
      <div className="tlg-community-page">
        <section className="tlg-help-hero">
          <div>
            <span>Welcome</span>
            <h2>Tennis Legacy Help Center</h2>
            <p>
              Find the most important starting points for your player career, open key game pages,
              contact support or join the Tennis Legacy Discord community when something is unclear.
            </p>
          </div>
          <div className="tlg-community-actions">
            <a className="tlg-community-button tlg-community-button-primary" href="/game/manual">
              Full Game Manual
            </a>
            <a className="tlg-community-button" href="/game/manual?download=pdf">
              Download Manual PDF
            </a>
            <a className="tlg-community-button" href="/game/contact">Contact Support</a>
            <a className="tlg-community-button tlg-community-button-discord" href={DISCORD_INVITE} target="_blank" rel="noreferrer">Join Discord</a>
          </div>
        </section>

        <section className="tlg-community-panel tlg-help-start-panel">
          <div className="tlg-help-main-column">
            <header>
              <span>Getting started</span>
              <h3>First steps for new players</h3>
            </header>
            <div className="tlg-community-grid tlg-community-grid-two">
              <HelpStep number="1" title="Start from Overview" text="Use Overview as your main career dashboard and starting point after signing in." href="/game/overview" linkLabel="Open Overview" />
              <HelpStep number="2" title="Check the Calendar" text="Review tournament weeks, surfaces and upcoming competition opportunities before planning your schedule." href="/game/calendar" linkLabel="Open Calendar" />
              <HelpStep number="3" title="Follow the Rankings" text="Every created player enters the correct ATP or WTA ranking. Open other players to view their profile." href="/game/rankings" linkLabel="Open Rankings" />
              <HelpStep number="4" title="Review Player & Account" text="See your player identity and avatar, request an avatar replacement, manage password recovery and account actions." href="/game/player-account" linkLabel="Open Player & Account" />
            </div>
          </div>

          <aside className="tlg-help-quick-links">
            <span>Quick links</span>
            <a href="/game/overview">Overview</a>
            <a href="/game/calendar">Tournament Calendar</a>
            <a href="/game/rankings">ATP / WTA Rankings</a>
            <a href="/game/inbox">Manager Inbox</a>
            <a href="/game/preferences">Game Preferences</a>
            <a href="/game/contact">Contact Us</a>
          </aside>
        </section>

        <section>
          <h3 className="tlg-community-section-title">Gameplay basics</h3>
          <div className="tlg-community-grid tlg-community-grid-three">
            <InfoCard title="ATP and WTA are separate worlds" text="ATP players compete in the ATP singles world and WTA players compete in the WTA singles world. Rankings remain separated." />
            <InfoCard title="Tournament choice matters" text="Tournament category, surface and calendar timing will shape your season. Use the calendar before committing to a schedule." />
            <InfoCard title="Your player name is permanent" text="The professional player name is fixed when the career is created. Avatar changes require a replacement request." />
            <InfoCard title="Player profiles are social" text="Ranking entries open player profile pages. From another player's profile you can start a private Manager Inbox conversation." />
            <InfoCard title="Rankings start immediately" text="Every created player receives an ATP or WTA ranking entry. Ranking points will later be driven by tournament results." />
            <InfoCard title="Use the Full Game Manual" text="The manual documents the currently implemented game page by page, including training, tournaments, rankings, travel, equipment, staff, finance, health, community systems and important limitations." />
          </div>
        </section>

        <section className="tlg-community-panel">
          <header>
            <span>Help topics</span>
            <h3>Manual sections</h3>
            <p>The complete English source manual is now available in-game with search, chapter navigation and a downloadable PDF edition.</p>
          </header>
          <div className="tlg-community-grid tlg-community-grid-three">
            <ManualCard title="Overview" status="Available" href="/game/overview" />
            <ManualCard title="Tournament Calendar" status="Available" href="/game/calendar" />
            <ManualCard title="Rankings & Player Profiles" status="Available" href="/game/rankings" />
            <ManualCard title="Manager Inbox" status="Available" href="/game/inbox" />
            <ManualCard title="Player & Account" status="Available" href="/game/player-account" />
            <ManualCard title="Training & Skills" status="Covered in Full Game Manual" href="/game/manual/regular-training" />
            <ManualCard title="Full Game Manual" status="33 detailed chapters" href="/game/manual" />
          </div>
        </section>

        <section className="tlg-help-support-banner">
          <div>
            <span>Still need help?</span>
            <h3>Ask the Tennis Legacy community or contact support.</h3>
            <p>If something looks wrong, include the page name, player name, screenshots and the steps needed to reproduce the issue.</p>
          </div>
          <div className="tlg-community-actions">
            <a className="tlg-community-button tlg-community-button-light" href="/game/contact"><LifeBuoy size={16} /> Contact Us</a>
            <a className="tlg-community-button tlg-community-button-outline-light" href={DISCORD_INVITE} target="_blank" rel="noreferrer"><CircleHelp size={16} /> Ask on Discord</a>
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
  return (
    <article className="tlg-community-info-card tlg-manual-card">
      <strong>{title}</strong>
      <p>{status}</p>
      {href ? <a href={href}>Open page</a> : <span>Coming later</span>}
    </article>
  )
}
