import { useEffect, useState } from 'react'
import { useLocalization } from '../../i18n/LocalizationProvider'
import type { AppLocale } from '../../i18n'
import { supabase } from '../../lib/supabase'
import '../../styles/home-video-showcase.css'

// These two owner-supplied videos are intended for the public homepage.
// Request time-limited links at runtime; never publish storage bearer tokens.
const VIDEOS = [
  { key: 'intro', path: 'Branding/Tennis Legacy Rise to Glory  Official Intro Trailer.mp4' },
  { key: 'gameplay', path: 'Branding/Tennis Legacy Rise to Glory  Official Gameplay Preview.mp4' },
] as const

type VideoKey = (typeof VIDEOS)[number]['key']
type VideoText = { title: string; description: string }
type ShowcaseText = {
  eyebrow: string
  heading: string
  description: string
  intro: VideoText
  gameplay: VideoText
  loading: string
  unavailable: string
  retry: string
}

const COPY: Record<AppLocale, ShowcaseText> = {
  en: {
    eyebrow: 'OFFICIAL VIDEOS',
    heading: 'Watch Tennis Legacy in action',
    description: 'Discover Tennis Legacy: Rise to Glory through our official trailer and gameplay preview.',
    intro: { title: 'Official Intro Trailer', description: 'An introduction to the Tennis Legacy world and your journey from promising player to tennis legend.' },
    gameplay: { title: 'Official Gameplay Preview', description: 'Take a closer look at the game experience, career decisions and tennis management.' },
    loading: 'Loading video…',
    unavailable: 'This video is temporarily unavailable.',
    retry: 'Try again',
  },
  sr: {
    eyebrow: 'ZVANIČNI VIDEO-SNIMCI',
    heading: 'Pogledajte Tennis Legacy u akciji',
    description: 'Upoznajte Tennis Legacy: Rise to Glory kroz zvanični trejler i prikaz igre.',
    intro: { title: 'Zvanični uvodni trejler', description: 'Uvod u svet Tennis Legacy i vaš put od mladog igrača do teniske legende.' },
    gameplay: { title: 'Zvanični prikaz igre', description: 'Pogledajte kako izgleda igra, donošenje odluka i vođenje teniske karijere.' },
    loading: 'Učitavanje video-snimka…',
    unavailable: 'Ovaj video trenutno nije dostupan.',
    retry: 'Pokušaj ponovo',
  },
  de: {
    eyebrow: 'OFFIZIELLE VIDEOS',
    heading: 'Tennis Legacy in Aktion erleben',
    description: 'Entdecke Tennis Legacy: Rise to Glory im offiziellen Trailer und in der Gameplay-Vorschau.',
    intro: { title: 'Offizieller Intro-Trailer', description: 'Ein Einstieg in die Welt von Tennis Legacy und deinen Weg zum Tennisstar.' },
    gameplay: { title: 'Offizielle Gameplay-Vorschau', description: 'Erhalte einen Einblick in das Spielerlebnis, Karriereentscheidungen und Tennismanagement.' },
    loading: 'Video wird geladen…',
    unavailable: 'Dieses Video ist derzeit nicht verfügbar.',
    retry: 'Erneut versuchen',
  },
  es: {
    eyebrow: 'VÍDEOS OFICIALES',
    heading: 'Descubre Tennis Legacy en acción',
    description: 'Conoce Tennis Legacy: Rise to Glory con el tráiler oficial y el avance de jugabilidad.',
    intro: { title: 'Tráiler de presentación oficial', description: 'Una introducción al mundo de Tennis Legacy y a tu camino hacia la leyenda del tenis.' },
    gameplay: { title: 'Avance oficial de jugabilidad', description: 'Descubre la experiencia de juego, las decisiones de carrera y la gestión del tenis.' },
    loading: 'Cargando vídeo…',
    unavailable: 'Este vídeo no está disponible en este momento.',
    retry: 'Reintentar',
  },
  it: {
    eyebrow: 'VIDEO UFFICIALI',
    heading: 'Scopri Tennis Legacy in azione',
    description: 'Scopri Tennis Legacy: Rise to Glory con il trailer ufficiale e l’anteprima del gameplay.',
    intro: { title: 'Trailer introduttivo ufficiale', description: 'Un’introduzione al mondo di Tennis Legacy e al tuo percorso verso la gloria nel tennis.' },
    gameplay: { title: 'Anteprima ufficiale del gameplay', description: 'Uno sguardo all’esperienza di gioco, alle scelte di carriera e alla gestione del tennis.' },
    loading: 'Caricamento video…',
    unavailable: 'Questo video non è disponibile al momento.',
    retry: 'Riprova',
  },
  fr: {
    eyebrow: 'VIDÉOS OFFICIELLES',
    heading: 'Découvrez Tennis Legacy en action',
    description: 'Découvrez Tennis Legacy: Rise to Glory avec la bande-annonce officielle et l’aperçu du gameplay.',
    intro: { title: 'Bande-annonce de présentation', description: 'Une introduction à l’univers de Tennis Legacy et à votre parcours vers la légende.' },
    gameplay: { title: 'Aperçu officiel du gameplay', description: 'Découvrez l’expérience de jeu, les choix de carrière et la gestion du tennis.' },
    loading: 'Chargement de la vidéo…',
    unavailable: 'Cette vidéo est temporairement indisponible.',
    retry: 'Réessayer',
  },
  ru: {
    eyebrow: 'ОФИЦИАЛЬНЫЕ ВИДЕО',
    heading: 'Посмотрите Tennis Legacy в действии',
    description: 'Познакомьтесь с Tennis Legacy: Rise to Glory в официальном трейлере и обзоре игрового процесса.',
    intro: { title: 'Официальный вступительный трейлер', description: 'Знакомство с миром Tennis Legacy и вашим путём к вершинам тенниса.' },
    gameplay: { title: 'Официальный обзор игры', description: 'Посмотрите на игровой процесс, карьерные решения и управление теннисной карьерой.' },
    loading: 'Загрузка видео…',
    unavailable: 'Видео сейчас недоступно.',
    retry: 'Повторить',
  },
  pt: {
    eyebrow: 'VÍDEOS OFICIAIS',
    heading: 'Vê Tennis Legacy em ação',
    description: 'Descobre Tennis Legacy: Rise to Glory através do trailer oficial e da pré-visualização do jogo.',
    intro: { title: 'Trailer oficial de apresentação', description: 'Uma introdução ao mundo de Tennis Legacy e ao teu caminho até à glória no ténis.' },
    gameplay: { title: 'Pré-visualização oficial do jogo', description: 'Conhece a experiência de jogo, as decisões de carreira e a gestão do ténis.' },
    loading: 'A carregar o vídeo…',
    unavailable: 'Este vídeo não está disponível neste momento.',
    retry: 'Tentar novamente',
  },
}

const EMPTY_URLS: Record<VideoKey, string> = { intro: '', gameplay: '' }

export default function HomeVideoShowcase() {
  const { locale } = useLocalization()
  const copy = COPY[locale] ?? COPY.en
  const [sources, setSources] = useState<Record<VideoKey, string>>(EMPTY_URLS)
  const [failed, setFailed] = useState<VideoKey[]>([])
  const [loading, setLoading] = useState(true)
  const [retryKey, setRetryKey] = useState(0)

  useEffect(() => {
    let active = true

    async function loadVideos() {
      setLoading(true)
      setFailed([])
      setSources(EMPTY_URLS)
      try {
        // Public SELECT access is restricted to these two paths in storage.objects.
        const { data, error } = await supabase.storage.from('Admin')
          .createSignedUrls(VIDEOS.map((video) => video.path), 6 * 60 * 60)
        if (!active) return
        if (error) {
          console.warn('[Home videos] Failed to sign video links:', error.message)
          return
        }
        setSources({
          intro: data?.[0]?.error ? '' : data?.[0]?.signedUrl ?? '',
          gameplay: data?.[1]?.error ? '' : data?.[1]?.signedUrl ?? '',
        })
      } catch (error) {
        if (active) console.warn('[Home videos] Video access unavailable:', error)
      } finally {
        if (active) setLoading(false)
      }
    }

    void loadVideos()
    return () => { active = false }
  }, [retryKey])

  return (
    <section className="tlg-content-section tlg-home-video-section" id="official-videos" aria-labelledby="tlg-home-video-heading">
      <div className="tlg-section">
        <div className="tlg-home-video-heading">
          <span className="tlg-section-eyebrow">{copy.eyebrow}</span>
          <h2 id="tlg-home-video-heading">{copy.heading}</h2>
          <p>{copy.description}</p>
        </div>
        <div className="tlg-home-video-grid">
          {VIDEOS.map((video) => {
            const content = copy[video.key]
            const url = sources[video.key]
            const hasError = failed.includes(video.key)
            return (
              <article className="tlg-home-video-card" key={video.key}>
                <div className="tlg-home-video-player">
                  {loading ? (
                    <p role="status">{copy.loading}</p>
                  ) : url && !hasError ? (
                    <video
                      key={url}
                      src={url}
                      controls
                      playsInline
                      preload="metadata"
                      aria-label={content.title}
                      onError={() => setFailed((current) => current.includes(video.key) ? current : [...current, video.key])}
                    >
                      {copy.unavailable}
                    </video>
                  ) : (
                    <div className="tlg-home-video-error" role="status">
                      <p>{copy.unavailable}</p>
                      <button type="button" onClick={() => setRetryKey((current) => current + 1)}>{copy.retry}</button>
                    </div>
                  )}
                </div>
                <div className="tlg-home-video-details">
                  <h3>{content.title}</h3>
                  <p>{content.description}</p>
                </div>
              </article>
            )
          })}
        </div>
      </div>
    </section>
  )
}
