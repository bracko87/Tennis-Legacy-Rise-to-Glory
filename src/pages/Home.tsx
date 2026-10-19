/**
 * Home.tsx
 *
 * Premium marketing homepage for Tennis Legacy: Rise to Glory.
 */

import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { useLocalization } from '../i18n/LocalizationProvider'
import type { AppLocale } from '../i18n'
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
  Crown,
  Dumbbell,
  Globe2,
  MapPin,
  Package,
  ShieldCheck,
  Image as ImageIcon,
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


// Fill in the three image URLs when official Tennis Legacy screenshots are supplied.
// Until then, show intentional placeholders rather than invented gameplay images.
const gameplayScreenshots: ReadonlyArray<{ id: number; url: string | null }> = [
  { id: 1, url: null },
  { id: 2, url: null },
  { id: 3, url: null },
]

const screenshotCopy: Record<AppLocale, {
  eyebrow: string; title: string; description: string; placeholder: string; views: string[]
}> = {
  "en": {
    "eyebrow": "GAME SCREENSHOTS",
    "title": "See Tennis Legacy in action",
    "description": "A closer look at the game experience. Official gameplay screenshots will be added here soon.",
    "placeholder": "Game screenshot coming soon",
    "views": [
      "Career overview",
      "Tournament preparation",
      "Player development"
    ]
  },
  "sr": {
    "eyebrow": "SLIKE IZ IGRE",
    "title": "Pogledajte Tennis Legacy u akciji",
    "description": "Detaljniji prikaz igre. Uskoro dodajemo zvanične slike ekrana.",
    "placeholder": "Slika ekrana stiže uskoro",
    "views": [
      "Pregled karijere",
      "Priprema turnira",
      "Razvoj igrača"
    ]
  },
  "de": {
    "eyebrow": "SPIEL-SCREENSHOTS",
    "title": "Tennis Legacy in Aktion",
    "description": "Ein Einblick in das Spielerlebnis. Offizielle Screenshots werden hier in Kürze ergänzt.",
    "placeholder": "Spiel-Screenshot folgt in Kürze",
    "views": [
      "Karriereübersicht",
      "Turniervorbereitung",
      "Spielerentwicklung"
    ]
  },
  "es": {
    "eyebrow": "CAPTURAS DEL JUEGO",
    "title": "Descubre Tennis Legacy en acción",
    "description": "Una mirada a la experiencia de juego. Pronto añadiremos capturas oficiales.",
    "placeholder": "Captura de juego próximamente",
    "views": [
      "Resumen de carrera",
      "Preparación de torneos",
      "Desarrollo del jugador"
    ]
  },
  "it": {
    "eyebrow": "SCHERMATE DI GIOCO",
    "title": "Scopri Tennis Legacy in azione",
    "description": "Uno sguardo all'esperienza di gioco. Presto aggiungeremo le schermate ufficiali.",
    "placeholder": "Schermata di gioco in arrivo",
    "views": [
      "Panoramica carriera",
      "Preparazione tornei",
      "Sviluppo del giocatore"
    ]
  },
  "fr": {
    "eyebrow": "CAPTURES DU JEU",
    "title": "Découvrez Tennis Legacy en action",
    "description": "Un aperçu de l'expérience de jeu. Des captures officielles seront bientôt ajoutées.",
    "placeholder": "Capture de jeu à venir",
    "views": [
      "Vue d'ensemble de carrière",
      "Préparation des tournois",
      "Développement du joueur"
    ]
  },
  "ru": {
    "eyebrow": "СКРИНШОТЫ ИГРЫ",
    "title": "Tennis Legacy в действии",
    "description": "Посмотрите, как выглядит игра. Скоро здесь появятся официальные скриншоты.",
    "placeholder": "Скриншот скоро появится",
    "views": [
      "Обзор карьеры",
      "Подготовка к турниру",
      "Развитие игрока"
    ]
  },
  "pt": {
    "eyebrow": "IMAGENS DO JOGO",
    "title": "Descobre Tennis Legacy em ação",
    "description": "Uma visão mais próxima do jogo. Em breve serão adicionadas capturas de ecrã oficiais.",
    "placeholder": "Imagem do jogo em breve",
    "views": [
      "Resumo da carreira",
      "Preparação de torneios",
      "Desenvolvimento do jogador"
    ]
  }
}

const statistics = [
  { labelKey: 'home.stats.activePlayers', value: '—', icon: UsersRound },
  { labelKey: 'home.stats.tournaments', value: '—', icon: Trophy },
  { labelKey: 'home.stats.matches', value: '—', icon: Activity },
  { labelKey: 'home.stats.countries', value: '—', icon: Globe2 },
] as const

const journeySteps = [
  { number: '01', icon: UserRound, titleKey: 'home.journey.createTitle', descriptionKey: 'home.journey.createBody' },
  { number: '02', icon: Dumbbell, titleKey: 'home.journey.trainTitle', descriptionKey: 'home.journey.trainBody' },
  { number: '03', icon: Target, titleKey: 'home.journey.competeTitle', descriptionKey: 'home.journey.competeBody' },
  { number: '04', icon: Trophy, titleKey: 'home.journey.legacyTitle', descriptionKey: 'home.journey.legacyBody' },
] as const

const managementFeatures = [
  { icon: Dumbbell, titleKey: 'home.features.developmentTitle', descriptionKey: 'home.features.developmentBody' },
  { icon: CalendarDays, titleKey: 'home.features.calendarTitle', descriptionKey: 'home.features.calendarBody' },
  { icon: Brain, titleKey: 'home.features.prepTitle', descriptionKey: 'home.features.prepBody' },
  { icon: Package, titleKey: 'home.features.equipmentTitle', descriptionKey: 'home.features.equipmentBody' },
  { icon: CircleDollarSign, titleKey: 'home.features.financeTitle', descriptionKey: 'home.features.financeBody' },
  { icon: BarChart3, titleKey: 'home.features.statsTitle', descriptionKey: 'home.features.statsBody' },
  { icon: Globe2, titleKey: 'home.features.rankingsTitle', descriptionKey: 'home.features.rankingsBody' },
  { icon: UsersRound, titleKey: 'home.features.multiplayerTitle', descriptionKey: 'home.features.multiplayerBody' },
] as const

export default function HomePage() {
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
                  to="/register"
                  className="tlg-btn tlg-btn-primary tlg-btn-large"
                >
                  {t('home.hero.start')}
                  <ArrowRight size={18} />
                </Link>

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
              </div>

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
                  Season 1 · March 14
                </strong>
                <small>18:00</small>
              </div>
            </div>
          </div>
        </section>

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

        <section
          id="how-it-works"
          className="tlg-content-section tlg-content-section-alt"
        >
          <div className="tlg-section">
            <div className="tlg-section-heading tlg-section-heading-centered">
              <span className="tlg-section-eyebrow">
                {t('home.journey.eyebrow')}
              </span>

              <h2 className="tlg-section-title">
                {t('home.journey.title')}
              </h2>

              <p className="tlg-section-description">
                {t('home.journey.description')}
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

                    <h3>{t(step.titleKey)}</h3>

                    <p>{t(step.descriptionKey)}</p>
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

        <section
          id="features"
          className="tlg-content-section tlg-content-section-alt"
        >
          <div className="tlg-section">
            <div className="tlg-section-heading tlg-section-heading-centered">
              <span className="tlg-section-eyebrow">
                {t('home.features.eyebrow')}
              </span>

              <h2 className="tlg-section-title">
                {t('home.features.title')}
              </h2>

              <p className="tlg-section-description">
                {t('home.features.description')}
              </p>
            </div>

            <div className="tlg-feature-grid">
              {managementFeatures.map((feature) => {
                const Icon = feature.icon

                return (
                  <article
                    key={feature.titleKey}
                    className="tlg-feature-card"
                  >
                    <span className="tlg-feature-icon">
                      <Icon size={22} />
                    </span>

                    <h3>{t(feature.titleKey)}</h3>

                    <p>{t(feature.descriptionKey)}</p>

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
                  <strong>{t('home.clock.date')}</strong>
                  <time>18:00</time>
                </div>

                <div className="tlg-season-months">
                  {seasonMonths.map((month) => (
                    <span
                      key={month}
                      className={
                        month === seasonMonths[2]
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

        <section className="tlg-home-screenshots-section" id="game-screenshots" aria-labelledby="tlg-home-screenshots-title">
          <div className="tlg-section">
            <div className="tlg-home-screenshots-heading">
              <span className="tlg-section-eyebrow">{galleryText.eyebrow}</span>
              <h2 id="tlg-home-screenshots-title">{galleryText.title}</h2>
              <p>{galleryText.description}</p>
            </div>
            <div className="tlg-home-screenshots-grid">
              {gameplayScreenshots.map((screenshot, index) => (
                <article className="tlg-home-screenshot-card" key={screenshot.id}>
                  <div className="tlg-home-screenshot-frame">
                    {screenshot.url ? (
                      <img src={screenshot.url} alt={galleryText.views[index]} loading="lazy" />
                    ) : (
                      <div className="tlg-home-screenshot-placeholder">
                        <ImageIcon size={30} aria-hidden="true" />
                        <span>{galleryText.placeholder}</span>
                      </div>
                    )}
                  </div>
                  <div className="tlg-home-screenshot-caption">
                    <span>{String(screenshot.id).padStart(2, '0')}</span>
                    <strong>{galleryText.views[index]}</strong>
                  </div>
                </article>
              ))}
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
                  {t('home.cta.eyebrow')}
                </span>

                <h2>
                  {t('home.cta.title')}
                </h2>

                <p>
                  {t('home.cta.description')}
                </p>

                <div className="tlg-final-cta-actions">
                  <Link
                    to="/register"
                    className="tlg-btn tlg-btn-primary tlg-btn-large"
                  >
                    {t('home.cta.create')}
                    <ArrowRight size={18} />
                  </Link>

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

      <MarketingFooter>
        <div className="tlg-home-footer-premium" id="premium">
          <div className="tlg-home-footer-premium-heading">
            <strong>{t('home.premium.eyebrow')}</strong>
            <p>{t('home.premium.description')}</p>
          </div>
          <div className="tlg-home-footer-premium-plans">
            <div><span>{t('home.premium.monthly')}</span><strong>€3.29</strong></div>
            <div><span>{t('home.premium.threeMonths')}</span><strong>€9.49</strong></div>
            <div><span>{t('home.premium.annual')}</span><strong>€33.49</strong></div>
          </div>
          <p className="tlg-home-footer-premium-note">{t('home.premium.note')}</p>
        </div>
      </MarketingFooter>
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