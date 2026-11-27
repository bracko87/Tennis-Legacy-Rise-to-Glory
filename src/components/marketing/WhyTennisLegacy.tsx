import { useEffect } from 'react'
import { Link, useParams } from 'react-router'
import { ArrowLeft, ArrowRight, MessageCircle } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { getGameManual } from '../../content/manual'
import MarketingHeader from '../layout/MarketingHeader'
import MarketingFooter from '../layout/MarketingFooter'
import '../../styles/home-why-tennis.css'

const DISCORD_INVITE = 'https://discord.gg/RBBtXgZey2'

// Public marketing copy, based on the existing game manual, not experimental branches.
export const TENNIS_FEATURES = [
  [
    "career",
    "Create your tennis legacy",
    "Build a professional player and shape a career from the first day.",
    "Choose your player's identity, home city, competitive world, preferred playing style and surface. Manage the career decisions that turn a new player into an established professional.",
    [
      "creating-a-career",
      "player-profile-account"
    ]
  ],
  [
    "skills",
    "Player skills & development",
    "Develop a playing style through technical and physical skills.",
    "Build on your player's strengths or improve weaknesses in serving, returning, movement and other skills. Long-term development and short-term match readiness are different parts of career management.",
    [
      "skills"
    ]
  ],
  [
    "training",
    "Weekly training",
    "Plan training around competition and recovery.",
    "Choose regular training priorities and balance improvement with tournament commitments. Training decisions shape how your player develops throughout the season.",
    [
      "regular-training"
    ]
  ],
  [
    "training-camps",
    "Training camps",
    "Invest in dedicated periods of focused development.",
    "Book a camp, choose the available arrangements and account for its cost and time away from competition. Camps are a strategic alternative to your normal training routine.",
    [
      "training-camps"
    ]
  ],
  [
    "staff",
    "Staff & contracts",
    "Build the support team behind your player.",
    "Recruit staff through the market, negotiate contracts and manage ongoing salaries. Choose the people who support your development, preparation and career objectives.",
    [
      "staff"
    ]
  ],
  [
    "calendar",
    "Tournament calendar",
    "Plan a season across surfaces and competition levels.",
    "Choose events that fit your ranking, preferred surfaces and condition. Applications and accepted entries are different, so plan around eligibility and confirmed commitments.",
    [
      "calendar",
      "tournament-selection"
    ]
  ],
  [
    "tournament-path",
    "Tournament progression",
    "Work your way up the professional competition ladder.",
    "Compete across tournament categories with different entry requirements, draws and ranking-point rewards. Choose the right level of competition as your career progresses.",
    [
      "tournament-categories"
    ]
  ],
  [
    "travel",
    "Travel & scheduling",
    "Manage journeys, hotels and competing commitments.",
    "Travel time, location and accommodation matter. Balance travel spending against recovery, and allow enough time to reach a tournament before your match.",
    [
      "schedule-travel"
    ]
  ],
  [
    "tactics",
    "Match tactics & preparation",
    "Prepare your approach for each opponent and surface.",
    "Plan tactics, equipment and preparation before a match. Follow draws, results and progression through a tournament; no single choice guarantees victory.",
    [
      "tournament-preparation",
      "matches"
    ]
  ],
  [
    "singles",
    "ATP & WTA singles",
    "Compete in separate professional tennis worlds.",
    "Develop your career in the men's ATP or women's WTA competitive environment. Follow opponents, tournament results and your position in the appropriate singles rankings.",
    [
      "singles-rankings"
    ]
  ],
  [
    "doubles",
    "Doubles competition",
    "Find a partner and pursue a separate ranking.",
    "Enter partnership-based doubles competitions and track doubles results independently of your singles career. Balance both disciplines with your other commitments.",
    [
      "doubles"
    ]
  ],
  [
    "rankings",
    "Ranking points & progression",
    "Earn points, climb the rankings and defend results.",
    "Tournament results generate ranking contributions that eventually expire. Build a sustainable schedule and follow changes in your ranking as other players compete.",
    [
      "ranking-points"
    ]
  ],
  [
    "equipment",
    "Equipment & gear",
    "Choose gear for your player, surface and match setup.",
    "Manage rackets, shoes, clothing and available accessories through the equipment center. Consider condition, wear, surface suitability and your budget when preparing for competition.",
    [
      "equipment"
    ]
  ],
  [
    "sponsors",
    "Sponsorships",
    "Manage commercial offers and sponsor objectives.",
    "Explore main sponsorship offers and tournament objectives, alongside technical sponsorships for equipment. Commercial decisions affect your career budget and equipment expenses.",
    [
      "main-sponsors",
      "technical-sponsors"
    ]
  ],
  [
    "finance",
    "Career finance",
    "Balance prize money, expenses, salaries and taxes.",
    "Follow your career cash and transaction history, plan for staff, travel and equipment costs and monitor upcoming payments. Career Cash and Coins are separate currencies.",
    [
      "finance"
    ]
  ],
  [
    "health",
    "Health, fatigue & recovery",
    "Protect your player's availability over a long season.",
    "Manage fatigue, form and sharpness alongside injuries and illness. Use the Health Center and recovery planning to avoid overloading your player and respect medical restrictions.",
    [
      "health",
      "readiness-recovery"
    ]
  ],
  [
    "private-life",
    "Private life & assets",
    "Build a life away from the court.",
    "The optional Premium Private Life system lets you manage property and other off-court assets, prestige and ownership costs. Plan purchases with your wider career finances in mind.",
    [
      "private-life"
    ]
  ],
  [
    "clubs",
    "Tennis clubs & community",
    "Connect with managers across the tennis worlds.",
    "Join community clubs, follow club rankings and communicate in private club chat. Build relationships beyond your individual tournament results.",
    [
      "tennis-club"
    ]
  ],
  [
    "national",
    "National associations",
    "Take part in national tennis governance.",
    "Join your national association, participate in its community and captain elections, and follow the national team. Association membership and leadership are distinct from your personal tour ranking.",
    [
      "national-association"
    ]
  ],
  [
    "statistics",
    "Statistics & living multiplayer world",
    "Follow career records as the shared season advances.",
    "Compare career and tournament records, follow season-by-season history and compete alongside other managers in a persistent game world. Game-time processing advances the season even when you are away.",
    [
      "statistics",
      "season-progression"
    ]
  ]
] as const

const COPY = {
  en: ['Why', 'Discover the decisions that shape your professional tennis career, on and off the court.', 'More info', 'Back to all features'],
  de: ['Warum', 'Entdecke die Entscheidungen, die deine professionelle Tenniskarriere auf und neben dem Platz prägen.', 'Mehr erfahren', 'Zurück zu allen Funktionen'],
  sr: ['Zašto', 'Otkrij odluke koje oblikuju tvoju profesionalnu tenisku karijeru, na terenu i van njega.', 'Saznaj više', 'Nazad na sve funkcije'],
  es: ['Por qué', 'Descubre las decisiones que definen tu carrera profesional dentro y fuera de la pista.', 'Más información', 'Volver a las funciones'],
  fr: ['Pourquoi', 'Découvrez les décisions qui façonnent votre carrière professionnelle sur et en dehors du court.', 'En savoir plus', 'Retour aux fonctionnalités'],
  it: ['Perché', 'Scopri le decisioni che plasmano la tua carriera professionale dentro e fuori dal campo.', 'Scopri di più', 'Torna alle funzionalità'],
  pt: ['Porquê', 'Descobre as decisões que moldam a tua carreira profissional dentro e fora do court.', 'Mais informações', 'Voltar às funcionalidades'],
  ru: ['Почему', 'Откройте для себя решения, определяющие вашу профессиональную карьеру на корте и за его пределами.', 'Подробнее', 'К списку возможностей'],
} as const

type Feature = typeof TENNIS_FEATURES[number]

function featureCopy(feature: Feature, locale: keyof typeof COPY) {
  const chapter = locale === 'de' || locale === 'sr'
    ? getGameManual(locale).chapters.find(item => item.id === feature[4][0])
    : undefined
  return { title: chapter?.title ?? feature[1], summary: chapter?.summary ?? feature[2], lang: chapter ? locale : 'en' }
}

export function WhyTennisLegacy() {
  const { locale } = useLocalization()
  const copy = COPY[locale] ?? COPY.en
  return (
    <section id="features" className="tlg-why-tennis" aria-labelledby="tlg-why-title">
      <div className="tlg-section">
        <div id="how-it-works" className="tlg-why-heading">
          <span className="tlg-section-eyebrow">{copy[0]} Tennis Legacy</span>
          <h2 id="tlg-why-title" className="tlg-section-title">{copy[0]} Tennis Legacy: Rise to Glory</h2>
          <p className="tlg-section-description">{copy[1]}</p>
        </div>
        <div className="tlg-why-grid">
          {TENNIS_FEATURES.map(feature => {
            const item = featureCopy(feature, locale)
            return (
              <Link key={feature[0]} to={`/features/${feature[0]}`} className="tlg-why-card" aria-label={`${copy[2]}: ${item.title}`}>
                <span className="tlg-why-card-copy" lang={item.lang}>
                  <strong>{item.title}</strong>
                  <span>{item.summary}</span>
                </span>
                <span className="tlg-why-card-action" aria-hidden="true">
                  <ArrowRight size={19} />
                  <span>{copy[2]}</span>
                </span>
              </Link>
            )
          })}
        </div>
      </div>
    </section>
  )
}

export function TennisDiscordSection() {
  const { t } = useTranslation()
  return (
    <section id="discord" className="tlg-content-section tlg-content-section-alt" aria-labelledby="tlg-discord-title">
      <div className="tlg-section">
        <div className="tlg-discord-card">
          <span className="tlg-discord-mark" aria-hidden="true"><MessageCircle size={34} /></span>
          <div className="tlg-discord-copy">
            <span className="tlg-section-eyebrow">{t('supportPages.forum.official')}</span>
            <h2 id="tlg-discord-title" className="tlg-section-title">{t('supportPages.forum.name')}</h2>
            <p className="tlg-section-description">{t('supportPages.forum.intro')}</p>
          </div>
          <a className="tlg-discord-button" href={DISCORD_INVITE} target="_blank" rel="noopener noreferrer">
            {t('supportPages.forum.join')} <ArrowRight size={18} aria-hidden="true" />
          </a>
        </div>
      </div>
    </section>
  )
}

export function TennisFeatureDetail() {
  const { featureId } = useParams()
  const { locale } = useLocalization()
  const copy = COPY[locale] ?? COPY.en
  const feature = TENNIS_FEATURES.find(item => item[0] === featureId)
  useEffect(() => { window.scrollTo({ top: 0, behavior: 'auto' }) }, [featureId])
  const item = feature ? featureCopy(feature, locale) : undefined
  const chapters = feature ? feature[4].map(id => getGameManual(locale).chapters.find(chapter => chapter.id === id)).filter(Boolean) : []
  return (
    <div className="tlg-marketing-page">
      <MarketingHeader />
      <main className="tlg-home-main">
        <section className="tlg-content-section tlg-why-detail">
          <div className="tlg-section">
            <a className="tlg-why-back" href="/#features"><ArrowLeft size={18} aria-hidden="true" /> {copy[3]}</a>
            {feature && item ? (
              <article className="tlg-why-detail-panel">
                <span className="tlg-section-eyebrow">Tennis Legacy: Rise to Glory</span>
                <h1 lang={item.lang} className="tlg-section-title">{item.title}</h1>
                <p lang={item.lang} className="tlg-section-description">{item.summary}</p>
                <p lang="en" className="tlg-why-detail-body">{feature[3]}</p>
                {chapters.map(chapter => chapter && (
                  <div className="tlg-why-detail-topic" key={chapter.id} lang={locale === 'de' || locale === 'sr' ? locale : 'en'}>
                    <h2>{chapter.title}</h2><p>{chapter.summary}</p>
                  </div>
                ))}
              </article>
            ) : <h1 className="tlg-section-title" lang="en">Feature not found</h1>}
          </div>
        </section>
        <WhyTennisLegacy />
      </main>
      <MarketingFooter />
    </div>
  )
}
