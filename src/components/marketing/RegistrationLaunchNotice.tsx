import { ArrowRight, CalendarDays, Clock3, ExternalLink, MessageCircle, X } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { Link } from 'react-router'

import type { AppLocale } from '../../i18n'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { useGameClock } from '../../hooks/useGameClock'
import { TENNIS_DISCORD_INVITE_URL } from '../../lib/communityLinks'
import '../../styles/registration-launch-notice.css'

interface LaunchCopy {
  eyebrow: string
  heading: string
  prelaunch: string
  paused: string
  running: string
  register: string
  discord: string
  continueLabel: string
  closeLabel: string
}

const COPY: Record<AppLocale, LaunchCopy> = {
  en: {
    eyebrow: 'REGISTRATION IS OPEN',
    heading: 'Create your account now. Official launch: 23 November 2026.',
    prelaunch: 'Registration is open to everyone. You can sign up and create your tennis player before the game officially launches.',
    paused: 'Game time is paused at Season 1, January 1, 00:00. The clock is set to run at 2× speed when the game begins.',
    running: 'Game time is running at 2× real-time speed.',
    register: 'Create Account',
    discord: 'Join Discord',
    continueLabel: "Explore website",
    closeLabel: "Close announcement",
  },
  de: {
    eyebrow: 'REGISTRIERUNG GEÖFFNET',
    heading: 'Jetzt registrieren. Offizieller Start: 23. November 2026.',
    prelaunch: 'Die Registrierung ist für alle geöffnet. Du kannst jetzt ein Konto und deinen Tennisspieler erstellen.',
    paused: 'Die Spielzeit ist bei Saison 1, 1. Januar, 00:00 Uhr angehalten. Zum Start läuft die Uhr mit 2-facher Geschwindigkeit.',
    running: 'Die Spielzeit läuft mit 2-facher Geschwindigkeit.',
    register: 'Konto erstellen',
    discord: 'Discord beitreten',
    continueLabel: "Website ansehen",
    closeLabel: "Ankündigung schließen",
  },
  sr: {
    eyebrow: 'REGISTRACIJA JE OTVORENA',
    heading: 'Napravi nalog sada. Zvanični početak: 23. novembar 2026.',
    prelaunch: 'Registracija je otvorena za sve. Već sada možeš da napraviš nalog i svog tenisera.',
    paused: 'Vreme igre je zaustavljeno na Sezoni 1, 1. januar, 00:00. Po početku igre vreme će teći 2 puta brže.',
    running: 'Vreme igre teče 2 puta brže od stvarnog vremena.',
    register: 'Napravi nalog',
    discord: 'Pridruži se Discordu',
    continueLabel: "Pogledaj sajt",
    closeLabel: "Zatvori obaveštenje",
  },
  es: {
    eyebrow: 'REGISTRO ABIERTO',
    heading: 'Crea tu cuenta ahora. Lanzamiento oficial: 23 de noviembre de 2026.',
    prelaunch: 'El registro está abierto para todos. Ya puedes crear tu cuenta y tu tenista.',
    paused: 'El tiempo del juego está pausado en la temporada 1, 1 de enero, 00:00. Al comenzar, avanzará al doble de velocidad.',
    running: 'El tiempo del juego avanza al doble de velocidad.',
    register: 'Crear cuenta',
    discord: 'Unirse a Discord',
    continueLabel: "Explorar sitio web",
    closeLabel: "Cerrar anuncio",
  },
  fr: {
    eyebrow: 'INSCRIPTIONS OUVERTES',
    heading: 'Crée ton compte dès maintenant. Lancement officiel : 23 novembre 2026.',
    prelaunch: 'Les inscriptions sont ouvertes à tous. Tu peux déjà créer ton compte et ton joueur de tennis.',
    paused: 'Le temps du jeu est en pause à la saison 1, le 1er janvier à 00 h 00. Il avancera 2 fois plus vite au lancement.',
    running: 'Le temps du jeu avance 2 fois plus vite.',
    register: 'Créer un compte',
    discord: 'Rejoindre Discord',
    continueLabel: "Découvrir le site",
    closeLabel: "Fermer l'annonce",
  },
  it: {
    eyebrow: 'REGISTRAZIONI APERTE',
    heading: 'Crea il tuo account ora. Lancio ufficiale: 23 novembre 2026.',
    prelaunch: 'Le registrazioni sono aperte a tutti. Puoi già creare il tuo account e il tuo tennista.',
    paused: 'Il tempo di gioco è fermo alla stagione 1, 1 gennaio, ore 00:00. Al lancio scorrerà a velocità 2×.',
    running: 'Il tempo di gioco scorre a velocità 2×.',
    register: 'Crea account',
    discord: 'Entra su Discord',
    continueLabel: "Esplora il sito",
    closeLabel: "Chiudi avviso",
  },
  pt: {
    eyebrow: 'REGISTOS ABERTOS',
    heading: 'Cria a tua conta agora. Lançamento oficial: 23 de novembro de 2026.',
    prelaunch: 'O registo está aberto a todos. Já podes criar a tua conta e o teu tenista.',
    paused: 'O tempo do jogo está pausado na época 1, 1 de janeiro, 00:00. No lançamento avançará a 2×.',
    running: 'O tempo do jogo avança a 2×.',
    register: 'Criar conta',
    discord: 'Entrar no Discord',
    continueLabel: "Explorar o site",
    closeLabel: "Fechar aviso",
  },
  ru: {
    eyebrow: 'РЕГИСТРАЦИЯ ОТКРЫТА',
    heading: 'Создайте аккаунт сейчас. Официальный запуск — 23 ноября 2026 года.',
    prelaunch: 'Регистрация открыта для всех. Вы уже можете создать аккаунт и своего теннисиста.',
    paused: 'Игровое время остановлено на 1 января первого сезона, 00:00. После запуска оно пойдёт со скоростью 2×.',
    running: 'Игровое время идёт со скоростью 2×.',
    register: 'Создать аккаунт',
    discord: 'Присоединиться к Discord',
    continueLabel: "Посмотреть сайт",
    closeLabel: "Закрыть объявление",
  },
}

interface Props {
  compact?: boolean
  modal?: boolean
}

// 23 November 2026 at 07:00 in Germany (CET = UTC+01:00).
// The banner expires automatically; it NEVER starts the paused game clock.
export const TENNIS_LAUNCH_AT = new Date('2026-11-23T07:00:00+01:00').getTime()
const PRELAUNCH_NOTICE_DISMISSED = 'tlg-preregistration-popup-dismissed-nov23-2026'

/** Shown to visitors until the release hour; no changes to the game clock. */
export default function RegistrationLaunchNotice({ compact = false, modal = false }: Props) {
  const { locale } = useLocalization()
  const clock = useGameClock()
  const copy = COPY[locale] ?? COPY.en
  const paused = clock.loading || clock.error != null || clock.speedMultiplier === 0
  const closeButtonRef = useRef<HTMLButtonElement>(null)
  const [beforeLaunch, setBeforeLaunch] = useState(() => Date.now() < TENNIS_LAUNCH_AT)
  const [dismissed, setDismissed] = useState(() => {
    try { return window.sessionStorage.getItem(PRELAUNCH_NOTICE_DISMISSED) === '1' }
    catch { return false }
  })

  useEffect(() => {
    if (!beforeLaunch) return
    const remaining = Math.max(0, TENNIS_LAUNCH_AT - Date.now())
    const timer = window.setTimeout(() => setBeforeLaunch(false), remaining)
    return () => window.clearTimeout(timer)
  }, [beforeLaunch])

  useEffect(() => {
    if (!modal || !beforeLaunch || dismissed) return
    const lastFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    closeButtonRef.current?.focus()

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') dismiss()
    }
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.body.style.overflow = previousOverflow
      document.removeEventListener('keydown', onKeyDown)
      lastFocus?.focus()
    }
  }, [modal, beforeLaunch, dismissed])

  function dismiss() {
    setDismissed(true)
    try { window.sessionStorage.setItem(PRELAUNCH_NOTICE_DISMISSED, '1') }
    catch { /* Visitors can still close the popup without browser storage. */ }
  }

  if (!beforeLaunch) return null

  if (modal) {
    if (dismissed) return null
    return createPortal(
      <div className="tlg-registration-launch-backdrop" role="presentation">
        <section
          className="tlg-registration-launch-modal"
          role="dialog"
          aria-modal="true"
          aria-labelledby="tlg-launch-popup-heading"
          aria-describedby="tlg-launch-popup-details"
        >
          <button ref={closeButtonRef} type="button" className="tlg-registration-launch-modal-close"
            aria-label={copy.closeLabel} onClick={dismiss}>
            <X size={20} aria-hidden="true" />
          </button>
          <div className="tlg-registration-launch-modal-icon" aria-hidden="true">
            <CalendarDays size={26} />
          </div>
          <span className="tlg-registration-launch-eyebrow">{copy.eyebrow}</span>
          <h2 id="tlg-launch-popup-heading">{copy.heading}</h2>
          <p id="tlg-launch-popup-details">{copy.prelaunch}</p>
          <p className="tlg-registration-launch-modal-clock">
            <Clock3 size={16} aria-hidden="true" />
            <span>{paused ? copy.paused : copy.running}</span>
          </p>
          <div className="tlg-registration-launch-modal-actions">
            <Link to="/register" className="tlg-btn tlg-btn-primary tlg-registration-launch-button"
              onClick={dismiss}>
              {copy.register}<ArrowRight size={15} aria-hidden="true" />
            </Link>
            <a href={TENNIS_DISCORD_INVITE_URL}
              target="_blank" rel="noopener noreferrer"
              className="tlg-btn tlg-registration-launch-discord"
              onClick={dismiss}>
              <MessageCircle size={16} aria-hidden="true" />
              {copy.discord}
              <ExternalLink size={13} aria-hidden="true" />
            </a>
            <button type="button" className="tlg-btn tlg-btn-secondary tlg-registration-launch-continue"
              onClick={dismiss}>{copy.continueLabel}</button>
          </div>
        </section>
      </div>,
      document.body,
    )
  }

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
        <p className="tlg-registration-launch-clock">
          <Clock3 size={14} aria-hidden="true" />{paused ? copy.paused : copy.running}
        </p>
      </div>
      {!compact && (
        <Link to="/register" className="tlg-btn tlg-btn-primary tlg-registration-launch-button">
          {copy.register}<ArrowRight size={15} aria-hidden="true" />
        </Link>
      )}
    </section>
  )
}
