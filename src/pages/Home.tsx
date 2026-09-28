/**
 * Home.tsx
 *
 * Premium marketing homepage for Tennis Legacy: Rise to Glory.
 */

import { useEffect } from 'react'
import { Link } from 'react-router'
import {
  Activity,
  ArrowRight,
  BarChart3,
  Brain,
  CalendarDays,
  Check,
  CircleDollarSign,
  Clock3,
  Dumbbell,
  Globe2,
  MapPin,
  Package,
  ShieldCheck,
  Sparkles,
  Target,
  Trophy,
  UserRound,
  UsersRound,
  Zap,
} from 'lucide-react'

import MarketingHeader from '../components/layout/MarketingHeader'
import MarketingFooter from '../components/layout/MarketingFooter'
import StatCard from '../components/common/StatCard'
import HomepagePlayerReviews from '../components/marketing/HomepagePlayerReviews'
import { supabase } from '../lib/supabase'

const statistics = [
  {
    label: 'Active Players',
    value: '—',
    helper: 'Connecting to Supabase',
    icon: UsersRound,
  },
  {
    label: 'Total Tournaments',
    value: '—',
    helper: 'Connecting to Supabase',
    icon: Trophy,
  },
  {
    label: 'Matches Completed',
    value: '—',
    helper: 'Connecting to Supabase',
    icon: Activity,
  },
  {
    label: 'Countries Represented',
    value: '—',
    helper: 'Connecting to Supabase',
    icon: Globe2,
  },
] as const

const journeySteps = [
  {
    number: '01',
    icon: UserRound,
    title: 'Create Your Player',
    description:
      'Choose the ATP or WTA world, select your country and create a realistic professional identity.',
  },
  {
    number: '02',
    icon: Dumbbell,
    title: 'Train and Develop',
    description:
      'Improve technical, physical, tactical and mental attributes throughout the season.',
  },
  {
    number: '03',
    icon: Target,
    title: 'Compete Worldwide',
    description:
      'Enter tournaments, prepare for opponents and compete against real managers.',
  },
  {
    number: '04',
    icon: Trophy,
    title: 'Build Your Legacy',
    description:
      'Win titles, climb the rankings and create a career that becomes part of tennis history.',
  },
] as const

const managementFeatures = [
  {
    icon: Dumbbell,
    title: 'Player Development',
    description:
      'Build a balanced athlete through structured technical, physical and mental training.',
  },
  {
    icon: CalendarDays,
    title: 'Tournament Calendar',
    description:
      'Plan an entire season around tournaments, rest periods, travel and preparation.',
  },
  {
    icon: Brain,
    title: 'Match Preparation',
    description:
      'Study opponents, select tactics and prepare for different surfaces and conditions.',
  },
  {
    icon: Package,
    title: 'Equipment Management',
    description:
      'Choose rackets, shoes, apparel and accessories that support your playing style.',
  },
  {
    icon: CircleDollarSign,
    title: 'Career Finance',
    description:
      'Manage prize money, travel costs, coaching expenses and sponsorship income.',
  },
  {
    icon: BarChart3,
    title: 'Statistics and Records',
    description:
      'Track match performance, surface results, titles, rankings and career milestones.',
  },
  {
    icon: Globe2,
    title: 'Global Rankings',
    description:
      'Compete for position in a living worldwide ranking system driven by results.',
  },
  {
    icon: UsersRound,
    title: 'Multiplayer Competition',
    description:
      'Share a persistent tennis universe with players controlled by real managers.',
  },
] as const

const careerDecisions = [
  'Select tournaments and plan your season',
  'Develop technical and physical attributes',
  'Prepare tactics for specific opponents',
  'Manage equipment, travel and career finance',
  'Protect energy, condition and confidence',
  'Build rankings, records and reputation',
] as const

const seasonMonths = [
  'Janu',
  'Feb',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
] as const

export default function HomePage() {
  useEffect(() => {
    const source = new URLSearchParams(window.location.search).get('source')
    if (source !== 'propeloton_manager') return

    window.localStorage.setItem('tlg-cross-game-source', source)
    void supabase.rpc('record_cross_game_referral_event_v1', {
      p_event_type: 'landing',
      p_source_game: 'propeloton_manager',
      p_destination_game: 'tennis_legacy',
      p_surface: 'public_home',
    })
  }, [])

  return (
    <div className="tlg-marketing-page">
      <MarketingHeader />

      <main className="tlg-home-main">
        <section className="tlg-hero">
          <div className="tlg-hero-background">
            <div className="tlg-hero-grid" />
            <div className="tlg-hero-glow tlg-hero-glow-one" />
            <div className="tlg-hero-glow tlg-hero-glow-two" />
          </div>

          <div className="tlg-section tlg-hero-inner">
            <div className="tlg-hero-copy">
              <div className="tlg-hero-eyebrow">
                <span className="tlg-hero-eyebrow-icon">
                  <Sparkles size={15} />
                </span>

                Online Multiplayer Tennis Management
              </div>

              <h1 className="tlg-hero-title">
                <span>Build Your Career.</span>
                <strong>Create Your Legacy.</strong>
              </h1>

              <p className="tlg-hero-description">
                Create and develop your own
                professional tennis player, master
                every surface, compete against real
                managers and fight your way from an
                unknown prospect to a world tennis
                legend.
              </p>

              <div className="tlg-hero-actions">
                <Link
                  to="/register"
                  className="tlg-btn tlg-btn-primary tlg-btn-large"
                >
                  Start Playing
                  <ArrowRight size={18} />
                </Link>

                <Link
                  to="/login"
                  className="tlg-btn tlg-btn-secondary tlg-btn-large"
                >
                  Sign In
                </Link>

                <button
                  type="button"
                  className="tlg-btn tlg-btn-ghost tlg-btn-large"
                  onClick={() =>
                    document
                      .getElementById('how-it-works')
                      ?.scrollIntoView({
                        behavior: 'smooth',
                      })
                  }
                >
                  Explore the Game
                </button>
              </div>

              <div className="tlg-hero-assurances">
                <div>
                  <ShieldCheck size={17} />
                  Persistent multiplayer world
                </div>

                <div>
                  <Clock3 size={17} />
                  Season-based game time
                </div>

                <div>
                  <Globe2 size={17} />
                  ATP and WTA worlds
                </div>
              </div>
            </div>

            <div className="tlg-hero-visual-column">
              <HeroCourtVisual />

              <div className="tlg-hero-floating-card tlg-hero-floating-ranking">
                <span>World Ranking</span>
                <strong>#1,284</strong>
                <small>Future Supabase data</small>
              </div>

              <div className="tlg-hero-floating-card tlg-hero-floating-season">
                <span>Current Game Time</span>
                <strong>
                  Season 1 · March 14
                </strong>
                <small>18:00</small>
              </div>
            </div>
          </div>
        </section>

        <section
          className="tlg-statistics-section"
          aria-label="Live game statistics"
        >
          <div className="tlg-section">
            <div className="tlg-statistics-heading">
              <div>
                <span className="tlg-section-eyebrow">
                  Live Game World
                </span>

                <h2>
                  A shared tennis universe
                </h2>
              </div>

              <p>
                These values are prepared for direct
                Supabase integration and currently do
                not display invented live data.
              </p>
            </div>

            <div className="tlg-statistics-grid">
              {statistics.map((statistic) => {
                const Icon = statistic.icon

                return (
                  <StatCard
                    key={statistic.label}
                    label={statistic.label}
                    value={statistic.value}
                    helper={statistic.helper}
                    status="Live data"
                    icon={<Icon size={20} />}
                  />
                )
              })}
            </div>
          </div>
        </section>

        <section className="tlg-content-section">
          <div className="tlg-section tlg-fantasy-layout">
            <div className="tlg-fantasy-copy">
              <span className="tlg-section-eyebrow">
                The Career Fantasy
              </span>

              <h2 className="tlg-section-title">
                One player. One career.
                <span> One legacy.</span>
              </h2>

              <p className="tlg-section-description">
                Tennis Legacy places you in control of
                every important career decision. Your
                player is not just a collection of
                ratings. They are a developing athlete
                competing in a living online world.
              </p>

              <div className="tlg-career-decision-list">
                {careerDecisions.map((decision) => (
                  <div
                    key={decision}
                    className="tlg-career-decision"
                  >
                    <span>
                      <Check size={15} />
                    </span>

                    {decision}
                  </div>
                ))}
              </div>
            </div>

            <CareerControlPanel />
          </div>
        </section>

        <section
          id="how-it-works"
          className="tlg-content-section tlg-content-section-alt"
        >
          <div className="tlg-section">
            <div className="tlg-section-heading tlg-section-heading-centered">
              <span className="tlg-section-eyebrow">
                Your Journey
              </span>

              <h2 className="tlg-section-title">
                From prospect to champion
              </h2>

              <p className="tlg-section-description">
                Every career begins with a player and
                develops through preparation,
                competition and long-term management.
              </p>
            </div>

            <div className="tlg-journey-grid">
              {journeySteps.map((step) => {
                const Icon = step.icon

                return (
                  <article
                    key={step.number}
                    className="tlg-journey-card"
                  >
                    <div className="tlg-journey-card-top">
                      <span className="tlg-journey-number">
                        {step.number}
                      </span>

                      <span className="tlg-journey-icon">
                        <Icon size={21} />
                      </span>
                    </div>

                    <h3>{step.title}</h3>

                    <p>{step.description}</p>
                  </article>
                )
              })}
            </div>
          </div>
        </section>

        <section
          id="game-world"
          className="tlg-content-section"
        >
          <div className="tlg-section">
            <div className="tlg-section-heading">
              <span className="tlg-section-eyebrow">
                Choose Your World
              </span>

              <h2 className="tlg-section-title">
                Two worlds. One standard of
                greatness.
              </h2>

              <p className="tlg-section-description">
                Your player enters either the ATP or
                WTA professional world. The choice
                defines the player’s competition
                ecosystem and remains permanent for
                that player.
              </p>
            </div>

            <div className="tlg-world-grid">
              <WorldCard
                type="ATP"
                title="ATP World"
                subtitle="Male professional tennis world"
                description="Build a career through a complete professional tournament structure, world rankings and multiplayer competition."
                imagePosition="left"
              />

              <WorldCard
                type="WTA"
                title="WTA World"
                subtitle="Female professional tennis world"
                description="Create a player and compete through a dedicated professional ecosystem with its own rankings, tournaments and records."
                imagePosition="right"
              />
            </div>
          </div>
        </section>

        <section
          id="features"
          className="tlg-content-section tlg-content-section-alt"
        >
          <div className="tlg-section">
            <div className="tlg-section-heading tlg-section-heading-centered">
              <span className="tlg-section-eyebrow">
                Complete Career Management
              </span>

              <h2 className="tlg-section-title">
                Every part of the career matters
              </h2>

              <p className="tlg-section-description">
                A serious management simulation
                designed around interconnected
                decisions rather than isolated
                matches.
              </p>
            </div>

            <div className="tlg-feature-grid">
              {managementFeatures.map((feature) => {
                const Icon = feature.icon

                return (
                  <article
                    key={feature.title}
                    className="tlg-feature-card"
                  >
                    <span className="tlg-feature-icon">
                      <Icon size={22} />
                    </span>

                    <h3>{feature.title}</h3>

                    <p>{feature.description}</p>

                    <span className="tlg-feature-arrow">
                      <ArrowRight size={17} />
                    </span>
                  </article>
                )
              })}
            </div>
          </div>
        </section>

        <HomepagePlayerReviews />

        <section className="tlg-content-section">
          <div className="tlg-section">
            <div className="tlg-game-time-panel">
              <div className="tlg-game-time-copy">
                <span className="tlg-section-eyebrow">
                  The Game Clock
                </span>

                <h2 className="tlg-section-title">
                  A world moving faster than
                  real time
                </h2>

                <p className="tlg-section-description">
                  One real-life hour equals two
                  in-game hours. Tennis Legacy uses
                  seasons rather than real-world
                  years, allowing careers and
                  tournaments to progress continuously.
                </p>

                <div className="tlg-game-time-equation">
                  <div>
                    <strong>1</strong>
                    <span>Real hour</span>
                  </div>

                  <span className="tlg-game-time-equals">
                    =
                  </span>

                  <div>
                    <strong>2</strong>
                    <span>Game hours</span>
                  </div>
                </div>
              </div>

              <div className="tlg-game-clock-card">
                <div className="tlg-game-clock-card-header">
                  <span>
                    <Clock3 size={18} />
                    Global Game Time
                  </span>

                  <span className="tlg-game-clock-live">
                    <span />
                    Display preview
                  </span>
                </div>

                <div className="tlg-game-clock-date">
                  <span>Season 1</span>
                  <strong>March 14</strong>
                  <time>18:00</time>
                </div>

                <div className="tlg-season-months">
                  {seasonMonths.map((month) => (
                    <span
                      key={month}
                      className={
                        month === 'March'
                          ? 'tlg-season-month-active'
                          : ''
                      }
                    >
                      {month}
                    </span>
                  ))}
                </div>

                <p className="tlg-game-clock-note">
                  This is currently a visual
                  placeholder. The centralized clock
                  will later be loaded from Supabase.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="tlg-final-cta-section">
          <div className="tlg-section">
            <div className="tlg-final-cta">
              <div className="tlg-final-cta-decoration">
                <Zap size={150} />
              </div>

              <div className="tlg-final-cta-content">
                <span className="tlg-section-eyebrow">
                  Begin Your Career
                </span>

                <h2>
                  Your road to glory starts here
                </h2>

                <p>
                  Create your player, enter the
                  professional tennis world and begin
                  building a legacy that other
                  managers will remember.
                </p>

                <div className="tlg-final-cta-actions">
                  <Link
                    to="/register"
                    className="tlg-btn tlg-btn-primary tlg-btn-large"
                  >
                    Create Your Player
                    <ArrowRight size={18} />
                  </Link>

                  <Link
                    to="/login"
                    className="tlg-btn tlg-btn-secondary tlg-btn-large"
                  >
                    Sign In
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>

      <MarketingFooter />
    </div>
  )
}

function HeroCourtVisual() {
  return (
    <div className="tlg-hero-court">
      <div className="tlg-hero-court-header">
        <div>
          <span>Live Career Preview</span>
          <strong>Rising Prospect</strong>
        </div>

        <div className="tlg-hero-world-badges">
          <span>ATP</span>
          <span>WTA</span>
        </div>
      </div>

      <svg
        viewBox="0 0 720 470"
        role="img"
        aria-label="Stylized professional tennis court"
        className="tlg-hero-court-svg"
      >
        <defs>
          <linearGradient
            id="courtSurface"
            x1="0"
            y1="0"
            x2="1"
            y2="1"
          >
            <stop
              offset="0"
              stopColor="#0874D1"
            />
            <stop
              offset="1"
              stopColor="#001D3F"
            />
          </linearGradient>

          <linearGradient
            id="courtSurround"
            x1="0"
            y1="0"
            x2="0"
            y2="1"
          >
            <stop
              offset="0"
              stopColor="#061B34"
            />
            <stop
              offset="1"
              stopColor="#020812"
            />
          </linearGradient>

          <radialGradient
            id="courtLight"
            cx="50%"
            cy="0%"
            r="90%"
          >
            <stop
              offset="0"
              stopColor="#FFFFFF"
              stopOpacity="0.3"
            />
            <stop
              offset="1"
              stopColor="#FFFFFF"
              stopOpacity="0"
            />
          </radialGradient>

          <filter
            id="courtShadow"
            x="-30%"
            y="-30%"
            width="160%"
            height="160%"
          >
            <feDropShadow
              dx="0"
              dy="18"
              stdDeviation="20"
              floodColor="#000000"
              floodOpacity="0.5"
            />
          </filter>
        </defs>

        <rect
          width="720"
          height="470"
          rx="28"
          fill="url(#courtSurround)"
        />

        <rect
          width="720"
          height="470"
          rx="28"
          fill="url(#courtLight)"
        />

        <path
          d="M82 368 175 82h370l93 286Z"
          fill="url(#courtSurface)"
          filter="url(#courtShadow)"
        />

        <path
          d="M82 368 175 82h370l93 286Z"
          fill="none"
          stroke="#FFFFFF"
          strokeWidth="4"
          strokeOpacity="0.9"
        />

        <path
          d="M151 288h438"
          stroke="#FFFFFF"
          strokeWidth="4"
          strokeOpacity="0.9"
        />

        <path
          d="M188 153h344"
          stroke="#FFFFFF"
          strokeWidth="3"
          strokeOpacity="0.72"
        />

        <path
          d="M244 82 211 368"
          stroke="#FFFFFF"
          strokeWidth="3"
          strokeOpacity="0.58"
        />

        <path
          d="M476 82 509 368"
          stroke="#FFFFFF"
          strokeWidth="3"
          strokeOpacity="0.58"
        />

        <path
          d="M360 82v286"
          stroke="#FFFFFF"
          strokeWidth="3"
          strokeOpacity="0.6"
        />

        <path
          d="M151 286c124 11 294 11 438 0"
          fill="none"
          stroke="#DCEEFF"
          strokeWidth="6"
          strokeOpacity="0.92"
        />

        <path
          d="M151 294c124 11 294 11 438 0"
          fill="none"
          stroke="#001D3F"
          strokeWidth="2"
          strokeOpacity="0.9"
        />

        <circle
          cx="463"
          cy="161"
          r="9"
          fill="#FFFFFF"
        />

        <path
          d="M322 340C366 286 399 239 463 161"
          fill="none"
          stroke="#FFFFFF"
          strokeWidth="3"
          strokeDasharray="8 12"
          strokeLinecap="round"
          opacity="0.75"
        />

        <circle
          cx="311"
          cy="354"
          r="11"
          fill="#FFFFFF"
        />

        <path
          d="M311 365v35M311 379l-25 24M311 379l27 20M311 373l30-18"
          fill="none"
          stroke="#FFFFFF"
          strokeWidth="7"
          strokeLinecap="round"
        />

        <circle
          cx="472"
          cy="124"
          r="7"
          fill="#FFFFFF"
          fillOpacity="0.8"
        />

        <path
          d="M472 132v25M472 143l-16 15M472 143l19 13"
          fill="none"
          stroke="#FFFFFF"
          strokeWidth="5"
          strokeLinecap="round"
          opacity="0.8"
        />
      </svg>

      <div className="tlg-hero-court-footer">
        <div>
          <MapPin size={16} />
          Global Tour
        </div>

        <div>
          <Activity size={16} />
          Career simulation
        </div>
      </div>
    </div>
  )
}

function CareerControlPanel() {
  return (
    <div className="tlg-career-control-panel">
      <div className="tlg-career-control-header">
        <div>
          <span>Player Overview</span>
          <strong>Career Control Center</strong>
        </div>

        <span className="tlg-career-control-status">
          <span />
          Template
        </span>
      </div>

      <div className="tlg-career-player">
        <div className="tlg-career-player-avatar">
          <UserRound size={32} />
        </div>

        <div>
          <span>Future Professional</span>
          <strong>Your Player Name</strong>
          <small>ATP or WTA · Country</small>
        </div>

        <div className="tlg-career-rank">
          <span>Rank</span>
          <strong>—</strong>
        </div>
      </div>

      <div className="tlg-career-metrics">
        <CareerMetric
          label="Condition"
          value="—"
          icon={<Activity size={16} />}
          width="72%"
        />

        <CareerMetric
          label="Development"
          value="—"
          icon={<Dumbbell size={16} />}
          width="55%"
        />

        <CareerMetric
          label="Confidence"
          value="—"
          icon={<Zap size={16} />}
          width="64%"
        />
      </div>

      <div className="tlg-career-next-event">
        <div className="tlg-career-next-event-icon">
          <CalendarDays size={19} />
        </div>

        <div>
          <span>Next scheduled activity</span>
          <strong>
            Waiting for Supabase data
          </strong>
        </div>

        <ArrowRight size={18} />
      </div>
    </div>
  )
}

interface CareerMetricProps {
  readonly label: string
  readonly value: string
  readonly width: string
  readonly icon: React.ReactNode
}

function CareerMetric({
  label,
  value,
  width,
  icon,
}: CareerMetricProps) {
  return (
    <div className="tlg-career-metric">
      <div className="tlg-career-metric-header">
        <span>
          {icon}
          {label}
        </span>

        <strong>{value}</strong>
      </div>

      <div className="tlg-career-metric-track">
        <span style={{ width }} />
      </div>
    </div>
  )
}

interface WorldCardProps {
  readonly type: 'ATP' | 'WTA'
  readonly title: string
  readonly subtitle: string
  readonly description: string
  readonly imagePosition: 'left' | 'right'
}

function WorldCard({
  type,
  title,
  subtitle,
  description,
  imagePosition,
}: WorldCardProps) {
  return (
    <article
      className={`tlg-world-card tlg-world-card-${imagePosition}`}
    >
      <div className="tlg-world-card-background">
        <div className="tlg-world-court-lines" />
      </div>

      <div className="tlg-world-card-content">
        <span className="tlg-world-type">
          {type}
        </span>

        <h3>{title}</h3>
        <strong>{subtitle}</strong>
        <p>{description}</p>

        <div className="tlg-world-card-footer">
          <span>
            <ShieldCheck size={16} />
            Permanent player choice
          </span>

          <Link to="/create-player">
            Create Player
            <ArrowRight size={16} />
          </Link>
        </div>
      </div>
    </article>
  )
}