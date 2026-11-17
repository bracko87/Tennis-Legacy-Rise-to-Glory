import { ArrowRight, CalendarDays, Clock3 } from 'lucide-react'
import { Link } from 'react-router'

import type { AppLocale } from '../../i18n'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { useGameClock } from '../../hooks/useGameClock'
import '../../styles/registration-launch-notice.css'

interface LaunchCopy {
  eyebrow: string
  heading: string
  prelaunch: string
  paused: string
  running: string
  register: string
}

const COPY: Record<AppLocale, LaunchCopy> = {
  en: {
    eyebrow: 'REGISTRATION IS OPEN',
    heading: 'Create your account now. Official launch: 23 November 2026.',
    prelaunch: 'Registration is open to everyone. You can sign up and create your tennis player before the game officially launches.',
    paused: 'Game time is paused at Season 1, January 1, 00:00. The clock is set to run at 2× speed when the game begins.',
    running: 'Game time is running at 2× real-time speed.',
    register: 'Create Account',
  },
  de: {
    eyebrow: 'REGISTRIERUNG GEÖFFNET',
    heading: 'Jetzt registrieren. Offizieller Start: 23. November 2026.',
    prelaunch: 'Die Registrierung ist für alle geöffnet. Du kannst jetzt ein Konto und deinen Tennisspieler erstellen.',
    paused: 'Die Spielzeit ist bei Saison 1, 1. Januar, 00:00 Uhr angehalten. Zum Start läuft die Uhr mit 2-facher Geschwindigkeit.',
    running: 'Die Spielzeit läuft mit 2-facher Geschwindigkeit.',
    register: 'Konto erstellen',
  },
  sr: {
    eyebrow: 'REGISTRACIJA JE OTVORENA',
    heading: 'Napravi nalog sada. Zvanični početak: 23. novembar 2026.',
    prelaunch: 'Registracija je otvorena za sve. Već sada možeš da napraviš nalog i svog tenisera.',
    paused: 'Vreme igre je zaustavljeno na Sezoni 1, 1. januar, 00:00. Po početku igre vreme će teći 2 puta brže.',
    running: 'Vreme igre teče 2 puta brže od stvarnog vremena.',
    register: 'Napravi nalog',
  },
  es: {
    eyebrow: 'REGISTRO ABIERTO',
    heading: 'Crea tu cuenta ahora. Lanzamiento oficial: 23 de noviembre de 2026.',
    prelaunch: 'El registro está abierto para todos. Ya puedes crear tu cuenta y tu tenista.',
    paused: 'El tiempo del juego está pausado en la temporada 1, 1 de enero, 00:00. Al comenzar, avanzará al doble de velocidad.',
    running: 'El tiempo del juego avanza al doble de velocidad.',
    register: 'Crear cuenta',
  },
  fr: {
    eyebrow: 'INSCRIPTIONS OUVERTES',
    heading: 'Crée ton compte dès maintenant. Lancement officiel : 23 novembre 2026.',
    prelaunch: 'Les inscriptions sont ouvertes à tous. Tu peux déjà créer ton compte et ton joueur de tennis.',
    paused: 'Le temps du jeu est en pause à la saison 1, le 1er janvier à 00 h 00. Il avancera 2 fois plus vite au lancement.',
    running: 'Le temps du jeu avance 2 fois plus vite.',
    register: 'Créer un compte',
  },
  it: {
    eyebrow: 'REGISTRAZIONI APERTE',
    heading: 'Crea il tuo account ora. Lancio ufficiale: 23 novembre 2026.',
    prelaunch: 'Le registrazioni sono aperte a tutti. Puoi già creare il tuo account e il tuo tennista.',
    paused: 'Il tempo di gioco è fermo alla stagione 1, 1 gennaio, ore 00:00. Al lancio scorrerà a velocità 2×.',
    running: 'Il tempo di gioco scorre a velocità 2×.',
    register: 'Crea account',
  },
  pt: {
    eyebrow: 'REGISTOS ABERTOS',
    heading: 'Cria a tua conta agora. Lançamento oficial: 23 de novembro de 2026.',
    prelaunch: 'O registo está aberto a todos. Já podes criar a tua conta e o teu tenista.',
    paused: 'O tempo do jogo está pausado na época 1, 1 de janeiro, 00:00. No lançamento avançará a 2×.',
    running: 'O tempo do jogo avança a 2×.',
    register: 'Criar conta',
  },
  ru: {
    eyebrow: 'РЕГИСТРАЦИЯ ОТКРЫТА',
    heading: 'Создайте аккаунт сейчас. Официальный запуск — 23 ноября 2026 года.',
    prelaunch: 'Регистрация открыта для всех. Вы уже можете создать аккаунт и своего теннисиста.',
    paused: 'Игровое время остановлено на 1 января первого сезона, 00:00. После запуска оно пойдёт со скоростью 2×.',
    running: 'Игровое время идёт со скоростью 2×.',
    register: 'Создать аккаунт',
  },
}

interface Props {
  compact?: boolean
}

/** Public prelaunch disclosure, shown only when registration is open. */
export default function RegistrationLaunchNotice({ compact = false }: Props) {
  const { locale } = useLocalization()
  const clock = useGameClock()
  const copy = COPY[locale] ?? COPY.en
  const paused = clock.loading || clock.error != null || clock.speedMultiplier === 0

  return (
    <section
      className={`tlg-registration-launch-notice${compact ? ' tlg-registration-launch-notice-compact' : ''}`}
      role="status"
      aria-label={copy.eyebrow}
    >
      <div className="tlg-registration-launch-icon" aria-hidden="true">
        <CalendarDays size={21} />
      </div>
      <div className="tlg-registration-launch-copy">
        <span className="tlg-registration-launch-eyebrow">{copy.eyebrow}</span>
        <strong>{copy.heading}</strong>
        <p>{copy.prelaunch}</p>
        <p className="tlg-registration-launch-clock"><Clock3 size={14} aria-hidden="true" />{paused ? copy.paused : copy.running}</p>
      </div>
      {!compact && (
        <Link to="/register" className="tlg-btn tlg-btn-primary tlg-registration-launch-button">
          {copy.register}
          <ArrowRight size={15} aria-hidden="true" />
        </Link>
      )}
    </section>
  )
}
