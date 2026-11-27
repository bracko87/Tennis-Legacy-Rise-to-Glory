import { useEffect } from 'react'
import { Link, useParams } from 'react-router'
import { ArrowLeft, ArrowRight, MessageCircle } from 'lucide-react'
import { useLocalization } from '../../i18n/LocalizationProvider'
import MarketingHeader from '../layout/MarketingHeader'
import MarketingFooter from '../layout/MarketingFooter'
import en from './why-tennis/en'
import de from './why-tennis/de'
import sr from './why-tennis/sr'
import es from './why-tennis/es'
import fr from './why-tennis/fr'
import it from './why-tennis/it'
import pt from './why-tennis/pt'
import ru from './why-tennis/ru'
import '../../styles/home-why-tennis.css'

const DISCORD_INVITE = 'https://discord.gg/RBBtXgZey2'
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

// The shared feature IDs are stable; each locale supplies the same 20 complete
// five-field entries: title, lead, mechanics, decisions and career value.
const CONTENT = { en, de, sr, es, fr, it, pt, ru } as const
const COPY = {
  "en": [
    "Why",
    "Discover the decisions that shape your professional tennis career, on and off the court.",
    "More info",
    "Back to all features",
    "How it works",
    "Your decisions",
    "Why it matters",
    "Explore more features",
    "Feature not found",
    "Official community",
    "Tennis Legacy Discord",
    "Join our official Discord community to discuss careers, tournaments and tactics, ask questions, report bugs, share ideas and follow game development.",
    "Join Tennis Legacy Discord"
  ],
  "de": [
    "Warum",
    "Entdecke die Entscheidungen, die deine professionelle Tenniskarriere auf und neben dem Platz prägen.",
    "Mehr erfahren",
    "Zurück zu allen Funktionen",
    "So funktioniert es",
    "Deine Entscheidungen",
    "Warum es wichtig ist",
    "Weitere Funktionen entdecken",
    "Funktion nicht gefunden",
    "Offizielle Community",
    "Tennis Legacy Discord",
    "Tritt unserer offiziellen Discord-Community bei, diskutiere Karrieren, Turniere und Taktiken, stelle Fragen, melde Fehler, teile Ideen und verfolge die Spielentwicklung.",
    "Tennis Legacy Discord beitreten"
  ],
  "sr": [
    "Zašto",
    "Otkrij odluke koje oblikuju tvoju profesionalnu tenisku karijeru, na terenu i van njega.",
    "Saznaj više",
    "Nazad na sve funkcije",
    "Kako funkcioniše",
    "Tvoje odluke",
    "Zašto je važno",
    "Istraži ostale funkcije",
    "Funkcija nije pronađena",
    "Zvanična zajednica",
    "Tennis Legacy Discord",
    "Pridruži se našoj zvaničnoj Discord zajednici, razgovaraj o karijerama, turnirima i taktici, postavljaj pitanja, prijavljuj greške, deli ideje i prati razvoj igre.",
    "Pridruži se Tennis Legacy Discordu"
  ],
  "es": [
    "Por qué",
    "Descubre las decisiones que definen tu carrera profesional dentro y fuera de la pista.",
    "Más información",
    "Volver a las funciones",
    "Cómo funciona",
    "Tus decisiones",
    "Por qué importa",
    "Explora más funciones",
    "Función no encontrada",
    "Comunidad oficial",
    "Discord de Tennis Legacy",
    "Únete a nuestra comunidad oficial en Discord para hablar de carreras, torneos y tácticas, hacer preguntas, informar de errores, compartir ideas y seguir el desarrollo del juego.",
    "Únete al Discord de Tennis Legacy"
  ],
  "fr": [
    "Pourquoi",
    "Découvrez les décisions qui façonnent votre carrière professionnelle sur et en dehors du court.",
    "En savoir plus",
    "Retour aux fonctionnalités",
    "Comment ça fonctionne",
    "Vos décisions",
    "Pourquoi c’est important",
    "Découvrez d’autres fonctionnalités",
    "Fonctionnalité introuvable",
    "Communauté officielle",
    "Discord de Tennis Legacy",
    "Rejoignez notre communauté officielle sur Discord pour discuter des carrières, tournois et tactiques, poser des questions, signaler des bugs, partager vos idées et suivre le développement du jeu.",
    "Rejoindre le Discord de Tennis Legacy"
  ],
  "it": [
    "Perché",
    "Scopri le decisioni che plasmano la tua carriera professionale dentro e fuori dal campo.",
    "Scopri di più",
    "Torna alle funzionalità",
    "Come funziona",
    "Le tue decisioni",
    "Perché è importante",
    "Esplora altre funzionalità",
    "Funzionalità non trovata",
    "Comunità ufficiale",
    "Discord di Tennis Legacy",
    "Unisciti alla nostra comunità ufficiale su Discord per discutere carriere, tornei e tattiche, fare domande, segnalare errori, condividere idee e seguire lo sviluppo del gioco.",
    "Unisciti al Discord di Tennis Legacy"
  ],
  "pt": [
    "Porquê",
    "Descobre as decisões que moldam a tua carreira profissional dentro e fora do court.",
    "Mais informações",
    "Voltar às funcionalidades",
    "Como funciona",
    "As tuas decisões",
    "Porque é importante",
    "Explora mais funcionalidades",
    "Funcionalidade não encontrada",
    "Comunidade oficial",
    "Discord do Tennis Legacy",
    "Junta-te à nossa comunidade oficial no Discord para discutir carreiras, torneios e táticas, fazer perguntas, comunicar erros, partilhar ideias e acompanhar o desenvolvimento do jogo.",
    "Entrar no Discord do Tennis Legacy"
  ],
  "ru": [
    "Почему",
    "Откройте для себя решения, определяющие вашу профессиональную карьеру на корте и за его пределами.",
    "Подробнее",
    "К списку возможностей",
    "Как это работает",
    "Ваши решения",
    "Почему это важно",
    "Другие возможности игры",
    "Возможность не найдена",
    "Официальное сообщество",
    "Discord Tennis Legacy",
    "Присоединяйтесь к нашему официальному сообществу в Discord: обсуждайте карьеры, турниры и тактику, задавайте вопросы, сообщайте об ошибках, делитесь идеями и следите за разработкой игры.",
    "Присоединиться к Discord Tennis Legacy"
  ]
} as const

export function WhyTennisLegacy() {
  const { locale } = useLocalization()
  const copy = COPY[locale] ?? COPY.en
  const features = CONTENT[locale] ?? CONTENT.en
  return (
    <section id="features" className="tlg-why-tennis" aria-labelledby="tlg-why-title" lang={locale}>
      <div className="tlg-section">
        <div id="how-it-works" className="tlg-why-heading">
          <span className="tlg-section-eyebrow">{copy[0]} Tennis Legacy</span>
          <h2 id="tlg-why-title" className="tlg-section-title">{copy[0]} Tennis Legacy: Rise to Glory</h2>
          <p className="tlg-section-description">{copy[1]}</p>
        </div>
        <div className="tlg-why-grid">
          {TENNIS_FEATURES.map((feature, index) => {
            const item = features[index]
            return (
              <Link key={feature[0]} to={`/features/${feature[0]}`} className="tlg-why-card" aria-label={`${copy[2]}: ${item[0]}`}>
                <span className="tlg-why-card-copy"><strong>{item[0]}</strong><span>{item[1]}</span></span>
                <span className="tlg-why-card-action" aria-hidden="true"><ArrowRight size={19} /><span>{copy[2]}</span></span>
              </Link>
            )
          })}
        </div>
      </div>
    </section>
  )
}

export function TennisDiscordSection() {
  const { locale } = useLocalization()
  const copy = COPY[locale] ?? COPY.en
  return (
    <section id="discord" className="tlg-discord-section" aria-labelledby="tlg-discord-title" lang={locale}>
      <div className="tlg-section">
        <div className="tlg-discord-card">
          <span className="tlg-discord-mark" aria-hidden="true"><MessageCircle size={38} /></span>
          <div className="tlg-discord-copy">
            <span className="tlg-section-eyebrow">{copy[9]}</span>
            <h2 id="tlg-discord-title" className="tlg-section-title">{copy[10]}</h2>
            <p className="tlg-section-description">{copy[11]}</p>
          </div>
          <a className="tlg-discord-button" href={DISCORD_INVITE} target="_blank" rel="noopener noreferrer">
            {copy[12]} <ArrowRight size={18} aria-hidden="true" />
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
  const features = CONTENT[locale] ?? CONTENT.en
  const index = TENNIS_FEATURES.findIndex(item => item[0] === featureId)
  const item = features[index]
  useEffect(() => { window.scrollTo({ top: 0, behavior: 'auto' }) }, [featureId])
  return (
    <div className="tlg-marketing-page">
      <MarketingHeader />
      <main className="tlg-home-main tlg-why-detail-main" lang={locale}>
        <section className="tlg-why-detail">
          <div className="tlg-section">
            <a className="tlg-why-back" href="/#features"><ArrowLeft size={18} aria-hidden="true" /> {copy[3]}</a>
            {item ? (
              <div className="tlg-why-detail-layout">
                <article className="tlg-why-detail-panel">
                  <header className="tlg-why-detail-header">
                    <span className="tlg-section-eyebrow">Tennis Legacy: Rise to Glory · {String(index + 1).padStart(2, '0')} / {TENNIS_FEATURES.length}</span>
                    <h1 className="tlg-section-title">{item[0]}</h1>
                    <p className="tlg-section-description">{item[1]}</p>
                  </header>
                  {([4, 5, 6] as const).map((labelIndex, sectionIndex) => (
                    <section className="tlg-why-detail-topic" key={labelIndex}>
                      <span className="tlg-why-topic-number" aria-hidden="true">{String(sectionIndex + 1).padStart(2, '0')}</span>
                      <div><h2>{copy[labelIndex]}</h2><p>{item[sectionIndex + 2]}</p></div>
                    </section>
                  ))}
                  <nav className="tlg-why-detail-pagination" aria-label={copy[7]}>
                    {index > 0 && <Link to={`/features/${TENNIS_FEATURES[index - 1][0]}`}><ArrowLeft size={17} aria-hidden="true" /> {features[index - 1][0]}</Link>}
                    {index < TENNIS_FEATURES.length - 1 && <Link to={`/features/${TENNIS_FEATURES[index + 1][0]}`}>{features[index + 1][0]} <ArrowRight size={17} aria-hidden="true" /></Link>}
                  </nav>
                </article>
                <aside className="tlg-why-related">
                  <h2>{copy[7]}</h2>
                  <nav aria-label={copy[7]}>
                    {TENNIS_FEATURES.map((feature, i) => (
                      <Link key={feature[0]} to={`/features/${feature[0]}`} aria-current={i === index ? 'page' : undefined}>{features[i][0]}<ArrowRight size={15} aria-hidden="true" /></Link>
                    ))}
                  </nav>
                </aside>
              </div>
            ) : <h1 className="tlg-section-title">{copy[8]}</h1>}
          </div>
        </section>
      </main>
      <MarketingFooter />
    </div>
  )
}
