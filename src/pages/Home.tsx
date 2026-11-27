/**
 * Home.tsx
 *
 * Premium marketing homepage for Tennis Legacy: Rise to Glory.
 */

import { useEffect, useState, type PointerEvent as ReactPointerEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { useLocalization } from '../i18n/LocalizationProvider'
import type { AppLocale } from '../i18n'
import { Link } from 'react-router'
import {
  Activity,
  ArrowRight,
  CalendarDays,
  Check,
  Clock3,
  Dumbbell,
  Globe2,
  MapPin,
  ShieldCheck,
  Sparkles,
  Trophy,
  UserRound,
  UsersRound,
  Zap,
} from 'lucide-react'

import { useAuth } from '../auth/AuthContext'
import MarketingHeader from '../components/layout/MarketingHeader'
import BetaDisclaimer from '../components/marketing/BetaDisclaimer'
import RegistrationLaunchNotice from '../components/marketing/RegistrationLaunchNotice'
import SeasonTransitionNotice from '../components/season/SeasonTransitionNotice'
import { SeasonMaintenanceAnnouncement } from '../components/season/SeasonMaintenanceBoundary'
import MarketingFooter from '../components/layout/MarketingFooter'
import StatCard from '../components/common/StatCard'
import HomepagePlayerReviews from '../components/marketing/HomepagePlayerReviews'
import HomeScreenshotGallery from '../components/marketing/HomeScreenshotGallery'
import HomeVideoShowcase from '../components/marketing/HomeVideoShowcase'
import DesktopDownloads from '../components/marketing/DesktopDownloads'
import { WhyTennisLegacy, TennisDiscordSection } from '../components/marketing/WhyTennisLegacy'
import { supabase } from '../lib/supabase'
import usePublicRegistrationStatus from '../hooks/usePublicRegistrationStatus'
import useTennisGuestAvailability from '../hooks/useTennisGuestAvailability'


const screenshotCopy: Record<AppLocale, { eyebrow: string; title: string; description: string }> = {
  "en": {
    "eyebrow": "GAME SCREENSHOTS",
    "title": "See Tennis Legacy in action",
    "description": "Explore 20 real screenshots from the Tennis Legacy game world."
  },
  "sr": {
    "eyebrow": "SLIKE IZ IGRE",
    "title": "Pogledajte Tennis Legacy u akciji",
    "description": "Pogledajte 20 stvarnih slika ekrana iz igre Tennis Legacy."
  },
  "de": {
    "eyebrow": "SPIEL-SCREENSHOTS",
    "title": "Tennis Legacy in Aktion",
    "description": "Entdecke 20 echte Screenshots aus der Tennis Legacy Spielwelt."
  },
  "es": {
    "eyebrow": "CAPTURAS DEL JUEGO",
    "title": "Descubre Tennis Legacy en acción",
    "description": "Explora 20 capturas reales del mundo de Tennis Legacy."
  },
  "it": {
    "eyebrow": "SCHERMATE DI GIOCO",
    "title": "Scopri Tennis Legacy in azione",
    "description": "Esplora 20 vere schermate del mondo di Tennis Legacy."
  },
  "fr": {
    "eyebrow": "CAPTURES DU JEU",
    "title": "Découvrez Tennis Legacy en action",
    "description": "Découvrez 20 captures authentiques du jeu Tennis Legacy."
  },
  "ru": {
    "eyebrow": "СКРИНШОТЫ ИГРЫ",
    "title": "Tennis Legacy в действии",
    "description": "Посмотрите 20 настоящих скриншотов игры Tennis Legacy."
  },
  "pt": {
    "eyebrow": "IMAGENS DO JOGO",
    "title": "Descobre Tennis Legacy em ação",
    "description": "Explora 20 imagens reais do mundo de Tennis Legacy."
  }
}

const statistics = [
  { labelKey: 'home.stats.activePlayers', value: '—', icon: UsersRound },
  { labelKey: 'home.stats.tournaments', value: '—', icon: Trophy },
  { labelKey: 'home.stats.matches', value: '—', icon: Activity },
  { labelKey: 'home.stats.countries', value: '—', icon: Globe2 },
] as const

export default function HomePage() {
  useEffect(() => {
    if (window.location.hash === '#features') document.getElementById('features')?.scrollIntoView({ block: 'start' })
  }, [])
  const registrationAvailability = usePublicRegistrationStatus()
  const guestAvailable = useTennisGuestAvailability()
  const { user, authLoading } = useAuth()
  const returningGuest = user?.is_anonymous === true
  const [guestTrial, setGuestTrial] = useState<{ userId: string; state: string; expiresAt: number } | null>(null)
  const [guestNow, setGuestNow] = useState(Date.now)
  useEffect(() => {
    if (!returningGuest || !user?.id) return
    let cancelled = false
    const userId = user.id
    void supabase.rpc('get_my_tennis_guest_trial_v1').then(({ data, error }) => {
      if (!cancelled && !error && data) {
        const expiresAt = Date.parse(data.expires_at)
        setGuestTrial({ userId, state: data.state, expiresAt })
      }
    })
    const timer = window.setInterval(() => setGuestNow(Date.now()), 30_000)
    return () => { cancelled = true; window.clearInterval(timer) }
  }, [returningGuest, user?.id])
  const currentTrial = returningGuest && guestTrial?.userId === user?.id ? guestTrial : null
  const guestDays = currentTrial?.state === 'active' && Number.isFinite(currentTrial.expiresAt)
    ? Math.max(0, Math.min(14, Math.ceil((currentTrial.expiresAt - guestNow) / 86_400_000)))
    : null
  const { t } = useTranslation()
  const { locale } = useLocalization()
  const galleryText = screenshotCopy[locale] ?? screenshotCopy.en
  const careerDecisions = t('home.fantasy.decisions', { returnObjects: true }) as string[]
  const seasonMonths = t('home.clock.months', { returnObjects: true }) as string[]

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

  // Match the cycling hero: gentle pointer parallax on the photograph only.
  // Interactive controls stay completely separate from the decoration.
  const onHeroPointerMove = (event: ReactPointerEvent<HTMLElement>) => {
    if (event.pointerType === 'touch' || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const rect = event.currentTarget.getBoundingClientRect()
    const x = (event.clientX - rect.left) / rect.width - 0.5
    const y = (event.clientY - rect.top) / rect.height - 0.5
    event.currentTarget.style.setProperty('--tlg-hero-x', `${(x * 15).toFixed(1)}px`)
    event.currentTarget.style.setProperty('--tlg-hero-y', `${(y * 10).toFixed(1)}px`)
  }
  const onHeroPointerLeave = (event: ReactPointerEvent<HTMLElement>) => {
    event.currentTarget.style.setProperty('--tlg-hero-x', '0px')
    event.currentTarget.style.setProperty('--tlg-hero-y', '0px')
  }

  return (
    <div className="tlg-marketing-page">
      <MarketingHeader />
      {registrationAvailability === 'open' && <RegistrationLaunchNotice modal />}
      {registrationAvailability === 'closed' && <BetaDisclaimer />}
      <main className="tlg-home-main">
        <SeasonMaintenanceAnnouncement />
        <SeasonTransitionNotice variant="public" />
        <section className="tlg-hero" onPointerMove={onHeroPointerMove} onPointerLeave={onHeroPointerLeave}>
          <div className="tlg-hero-background">
            <div className="tlg-hero-grid" />
            <div className="tlg-hero-glow tlg-hero-glow-one" />
            <div className="tlg-hero-glow tlg-hero-glow-two" />

            {/* Occasional camera flashes in the stadium stands, away from the headline. */}
            <div className="tlg-hero-effect-layer" aria-hidden="true">
              <span className="tlg-hero-ambient tlg-hero-ambient--left" />
              <span className="tlg-hero-ambient tlg-hero-ambient--right" />
              <span className="tlg-hero-camera-flash tlg-hero-camera-flash--one" />
              <span className="tlg-hero-camera-flash tlg-hero-camera-flash--two" />
              <span className="tlg-hero-camera-flash tlg-hero-camera-flash--three" />
              <span className="tlg-hero-camera-flash tlg-hero-camera-flash--four" />
              <span className="tlg-hero-camera-flash tlg-hero-camera-flash--five" />
              <span className="tlg-hero-camera-flash tlg-hero-camera-flash--six" />
              <span className="tlg-hero-camera-flash tlg-hero-camera-flash--seven" />
            </div>
          </div>

          <div className="tlg-section tlg-hero-inner">
            <div className="tlg-hero-copy">
              <div className="tlg-hero-eyebrow">
                <span className="tlg-hero-eyebrow-icon">
                  <Sparkles size={15} />
                </span>

                {t('home.hero.eyebrow')}
              </div>

              <h1 className="tlg-hero-title">
                <span>{t('home.hero.line1')}</span>
                <strong>{t('home.hero.line2')}</strong>
              </h1>

              <p className="tlg-hero-description">
                {t('home.hero.description')}
              </p>

              <div className="tlg-hero-actions">
                <Link
                  to="/login"
                  className="tlg-btn tlg-btn-secondary tlg-btn-large"
                >
                  {t('home.hero.signIn')}
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
                  {t('home.hero.explore')}
                </button>

                {!authLoading && (returningGuest || (!user && guestAvailable)) && (
                  <Link to="/try-as-guest" className="tlg-btn tlg-btn-primary tlg-btn-large">
                    {returningGuest ? 'Continue as Guest' : 'Try as Guest'}
                  </Link>
                )}
                {!authLoading && (returningGuest || (!user && registrationAvailability === 'open')) && (
                  <Link to={returningGuest ? '/guest/register' : '/register'} className="tlg-btn tlg-btn-primary tlg-btn-large">
                    {returningGuest ? 'Register to keep your player' : t('authPages.login.createAccount')}
                  </Link>
                )}
              </div>

              {returningGuest && guestDays !== null && (
                <p className="tlg-prelaunch-registration-note" role="status">
                  {guestDays > 0 ? `Welcome back! ${guestDays} of 14 guest trial days remaining. Continue in this browser or register to keep your player.` : 'Your guest trial has ended.'}
                </p>
              )}

              {registrationAvailability === 'closed' && (
                <p className="tlg-prelaunch-registration-note" role="status">
                  {t('home.hero.betaNotice')}
                </p>
              )}

              <div className="tlg-hero-assurances">
                <div>
                  <ShieldCheck size={17} />
                  {t('home.hero.persistent')}
                </div>

                <div>
                  <Clock3 size={17} />
                  {t('home.hero.seasonTime')}
                </div>

                <div>
                  <Globe2 size={17} />
                  {t('home.hero.worlds')}
                </div>
              </div>
            </div>

            <div className="tlg-hero-visual-column">
              <HeroCourtVisual />

              <div className="tlg-hero-floating-card tlg-hero-floating-ranking">
                <span>{t('home.hero.ranking')}</span>
                <strong>#1,284</strong>
                <small>{t('home.hero.futureData')}</small>
              </div>

              <div className="tlg-hero-floating-card tlg-hero-floating-season">
                <span>{t('home.hero.currentTime')}</span>
                <strong>
                  Season 1 · January 1
                </strong>
                <small>00:00</small>
              </div>
            </div>
          </div>
        </section>

        <WhyTennisLegacy />

        <section
          className="tlg-statistics-section"
          aria-label={t('home.liveWorld.aria')}
        >
          <div className="tlg-section">
            <div className="tlg-statistics-heading">
              <div>
                <span className="tlg-section-eyebrow">
                  {t('home.liveWorld.eyebrow')}
                </span>

                <h2>
                  {t('home.liveWorld.title')}
                </h2>
              </div>

              <p>
                {t('home.liveWorld.description')}
              </p>
            </div>

            <div className="tlg-statistics-grid">
              {statistics.map((statistic) => (
                <StatCard
                  key={statistic.labelKey}
                  label={t(statistic.labelKey)}
                  value={statistic.value}
                  helper={t('home.stats.connecting')}
                />
              ))}
            </div>
          </div>
        </section>

        <section className="tlg-content-section">
          <div className="tlg-section tlg-fantasy-layout">
            <div className="tlg-fantasy-copy">
              <span className="tlg-section-eyebrow">
                {t('home.fantasy.eyebrow')}
              </span>

              <h2 className="tlg-section-title">
                {t('home.fantasy.title')}<span>{t('home.fantasy.titleAccent')}</span>
              </h2>

              <p className="tlg-section-description">
                {t('home.fantasy.description')}
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

        <TennisDiscordSection />

        <section
          id="game-world"
          className="tlg-content-section"
        >
          <div className="tlg-section">
            <div className="tlg-section-heading">
              <span className="tlg-section-eyebrow">
                {t('home.worlds.eyebrow')}
              </span>

              <h2 className="tlg-section-title">
                {t('home.worlds.title')}
              </h2>

              <p className="tlg-section-description">
                {t('home.worlds.description')}
              </p>
            </div>

            <div className="tlg-world-grid">
              <WorldCard
                type="ATP"
                title={t('home.worlds.atpTitle')}
                subtitle={t('home.worlds.atpSubtitle')}
                description={t('home.worlds.atpBody')}
                imagePosition="left"
              />

              <WorldCard
                type="WTA"
                title={t('home.worlds.wtaTitle')}
                subtitle={t('home.worlds.wtaSubtitle')}
                description={t('home.worlds.wtaBody')}
                imagePosition="right"
              />
            </div>
          </div>
        </section>

        <DesktopDownloads />

        <HomeVideoShowcase />

        <HomepagePlayerReviews />

        <section className="tlg-content-section">
          <div className="tlg-section">
            <div className="tlg-game-time-panel">
              <div className="tlg-game-time-copy">
                <span className="tlg-section-eyebrow">
                  {t('home.clock.eyebrow')}
                </span>

                <h2 className="tlg-section-title">
                  {t('home.clock.title')}
                </h2>

                <p className="tlg-section-description">
                  {t('home.clock.description')}
                </p>

                <div className="tlg-game-time-equation">
                  <div>
                    <strong>1</strong>
                    <span>{t('home.clock.realHour')}</span>
                  </div>

                  <span className="tlg-game-time-equals">
                    =
                  </span>

                  <div>
                    <strong>2</strong>
                    <span>{t('home.clock.gameHours')}</span>
                  </div>
                </div>
              </div>

              <div className="tlg-game-clock-card">
                <div className="tlg-game-clock-card-header">
                  <span>
                    <Clock3 size={18} />
                    {t('home.clock.global')}
                  </span>

                  <span className="tlg-game-clock-live">
                    <span />
                    {t('home.clock.preview')}
                  </span>
                </div>

                <div className="tlg-game-clock-date">
                  <span>{t('home.clock.season')}</span>
                  <strong>{seasonMonths[0]} 1</strong>
                  <time>00:00</time>
                </div>

                <div className="tlg-season-months">
                  {seasonMonths.map((month) => (
                    <span
                      key={month}
                      className={
                        month === seasonMonths[0]
                          ? 'tlg-season-month-active'
                          : ''
                      }
                    >
                      {month}
                    </span>
                  ))}
                </div>

                <p className="tlg-game-clock-note">
                  {t('home.clock.note')}
                </p>
              </div>
            </div>
          </div>
        </section>

        <HomeScreenshotGallery eyebrow={galleryText.eyebrow} title={galleryText.title} description={galleryText.description} />

        <section className="tlg-final-cta-section">
          <div className="tlg-section">
            <div className="tlg-final-cta">
              <div className="tlg-final-cta-decoration">
                <Zap size={150} />
              </div>

              <div className="tlg-final-cta-content">
                <span className="tlg-section-eyebrow">
                  {t('home.cta.eyebrow')}
                </span>

                <h2>
                  {t('home.cta.title')}
                </h2>

                <p>
                  {t('home.cta.description')}
                </p>

                <div className="tlg-final-cta-actions">
                  {registrationAvailability === 'open' ? (
                    <Link to="/register" className="tlg-btn tlg-btn-primary tlg-btn-large">
                      {t('authPages.login.createAccount')}
                    </Link>
                  ) : registrationAvailability === 'closed' ? (
                    <p className="tlg-prelaunch-registration-note" role="status">
                      {t('home.hero.betaNotice')}
                    </p>
                  ) : null}

                  <Link
                    to="/login"
                    className="tlg-btn tlg-btn-secondary tlg-btn-large"
                  >
                    {t('home.hero.signIn')}
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
  const { t } = useTranslation()
  return (
    <div className="tlg-hero-court">
      <div className="tlg-hero-court-header">
        <div>
          <span>{t('home.preview.live')}</span>
          <strong>{t('home.preview.prospect')}</strong>
        </div>

        <div className="tlg-hero-world-badges">
          <span>ATP</span>
          <span>WTA</span>
        </div>
      </div>

      <svg
        viewBox="0 0 720 470"
        role="img"
        aria-label={t('home.preview.courtAria')}
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
          {t('home.preview.globalTour')}
        </div>

        <div>
          <Activity size={16} />
          {t('home.preview.simulation')}
        </div>
      </div>
    </div>
  )
}

function CareerControlPanel() {
  const { t } = useTranslation()
  return (
    <div className="tlg-career-control-panel">
      <div className="tlg-career-control-header">
        <div>
          <span>{t('home.preview.playerOverview')}</span>
          <strong>{t('home.preview.controlCenter')}</strong>
        </div>

        <span className="tlg-career-control-status">
          <span />
          {t('home.preview.template')}
        </span>
      </div>

      <div className="tlg-career-player">
        <div className="tlg-career-player-avatar">
          <UserRound size={32} />
        </div>

        <div>
          <span>{t('home.preview.futureProfessional')}</span>
          <strong>{t('home.preview.playerName')}</strong>
          <small>{t('home.preview.worldCountry')}</small>
        </div>

        <div className="tlg-career-rank">
          <span>{t('home.preview.rank')}</span>
          <strong>—</strong>
        </div>
      </div>

      <div className="tlg-career-metrics">
        <CareerMetric
          label={t('home.preview.condition')}
          value="—"
          icon={<Activity size={16} />}
          width="72%"
        />

        <CareerMetric
          label={t('home.preview.development')}
          value="—"
          icon={<Dumbbell size={16} />}
          width="55%"
        />

        <CareerMetric
          label={t('home.preview.confidence')}
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
          <span>{t('home.preview.next')}</span>
          <strong>
            {t('home.preview.waiting')}
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
  const { t } = useTranslation()
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
            {t('home.worlds.permanent')}
          </span>

          <Link to="/create-player">
            {t('home.worlds.create')}
            <ArrowRight size={16} />
          </Link>
        </div>
      </div>
    </article>
  )
}