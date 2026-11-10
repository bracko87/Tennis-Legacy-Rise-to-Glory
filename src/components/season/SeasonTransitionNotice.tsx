import * as Dialog from '@radix-ui/react-dialog'
import { AlertTriangle, CalendarClock, CheckCircle2, Clock3, X } from 'lucide-react'
import { useEffect, useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import { useLocalization } from '../../i18n/LocalizationProvider'
import type { AppLocale } from '../../i18n'
import { supabase } from '../../lib/supabase'
import '../../styles/season-transition-notice.css'

type Phase = 'preparing' | 'running' | 'delayed' | 'completed'
type Notice = { phase: Phase; source_season: number; target_season: number }
type PhaseText = [title: string, description: string, status: string]
type Copy = Record<Phase, PhaseText> & { reassurance: string; acknowledge: string; close: string; heading: string }

const messages: Record<AppLocale, Copy> = {
  en: {
    preparing: ['Season {target} is coming!', 'Season {source} has ended. Game time is paused while we prepare the next season and complete safety checks.', 'Preparing Season {target}'],
    running: ['Season transition in progress', 'The official move from Season {source} to Season {target} is underway. Game time may remain paused until the checks finish.', 'Migration in progress'],
    delayed: ['Season transition temporarily delayed', 'The move to Season {target} needs additional checks. Game time remains paused until the transition can safely continue.', 'Transition delayed'],
    completed: ['Welcome to Season {target}!', 'The transition from Season {source} is complete. Your tennis career continues in the new season.', 'Season {target} started'],
    reassurance: 'Your existing career progress remains saved. No action is required.',
    acknowledge: 'Got it',
    close: 'Close announcement',
    heading: 'Season transition announcement',
  },
  sr: {
    preparing: ['Stiže sezona {target}!', 'Sezona {source} je završena. Vreme u igri je pauzirano dok pripremamo novu sezonu i završavamo bezbednosne provere.', 'Priprema sezone {target}'],
    running: ['Prelazak u novu sezonu je u toku', 'Zvanični prelazak iz sezone {source} u sezonu {target} je u toku. Vreme u igri može ostati pauzirano do završetka provera.', 'Prelazak u toku'],
    delayed: ['Prelazak u novu sezonu je odložen', 'Za prelazak u sezonu {target} potrebne su dodatne provere. Vreme u igri ostaje pauzirano.', 'Prelazak odložen'],
    completed: ['Dobro došli u sezonu {target}!', 'Prelazak iz sezone {source} je završen. Vaša teniska karijera se nastavlja u novoj sezoni.', 'Sezona {target} je počela'],
    reassurance: 'Dosadašnji napredak u karijeri je sačuvan. Ne morate ništa da radite.',
    acknowledge: 'Razumem',
    close: 'Zatvori obaveštenje',
    heading: 'Obaveštenje o novoj sezoni',
  },
  de: {
    preparing: ['Saison {target} kommt!', 'Saison {source} ist beendet. Die Spielzeit ist pausiert, während wir die neue Saison vorbereiten und Sicherheitsprüfungen abschließen.', 'Saison {target} wird vorbereitet'],
    running: ['Saisonwechsel läuft', 'Der offizielle Übergang von Saison {source} zu Saison {target} läuft. Die Spielzeit kann bis zum Abschluss der Prüfungen pausiert bleiben.', 'Umstellung läuft'],
    delayed: ['Saisonwechsel verzögert sich', 'Für den Übergang zu Saison {target} sind weitere Prüfungen nötig. Die Spielzeit bleibt vorerst pausiert.', 'Umstellung verzögert'],
    completed: ['Willkommen in Saison {target}!', 'Der Wechsel von Saison {source} ist abgeschlossen. Deine Tenniskarriere geht in der neuen Saison weiter.', 'Saison {target} gestartet'],
    reassurance: 'Dein bisheriger Karrierefortschritt bleibt gespeichert. Du musst nichts tun.',
    acknowledge: 'Verstanden',
    close: 'Ankündigung schließen',
    heading: 'Information zum Saisonwechsel',
  },
  es: {
    preparing: ['¡Se acerca la temporada {target}!', 'La temporada {source} ha terminado. El tiempo del juego está pausado mientras preparamos la nueva temporada y realizamos las comprobaciones.', 'Preparando temporada {target}'],
    running: ['Cambio de temporada en curso', 'El cambio oficial de la temporada {source} a la {target} está en marcha. El tiempo del juego puede seguir pausado hasta terminar las comprobaciones.', 'Migración en curso'],
    delayed: ['Cambio de temporada retrasado', 'El paso a la temporada {target} requiere más comprobaciones. El tiempo del juego permanece pausado.', 'Cambio retrasado'],
    completed: ['¡Bienvenido a la temporada {target}!', 'El cambio desde la temporada {source} ha terminado. Tu carrera de tenis continúa en la nueva temporada.', 'Temporada {target} iniciada'],
    reassurance: 'Tu progreso de carrera está guardado. No necesitas hacer nada.',
    acknowledge: 'Entendido',
    close: 'Cerrar aviso',
    heading: 'Aviso del cambio de temporada',
  },
  it: {
    preparing: ['Sta arrivando la stagione {target}!', 'La stagione {source} è terminata. Il tempo di gioco è in pausa mentre prepariamo la nuova stagione e completiamo i controlli.', 'Preparazione stagione {target}'],
    running: ['Cambio di stagione in corso', 'Il passaggio ufficiale dalla stagione {source} alla {target} è in corso. Il tempo di gioco potrebbe rimanere in pausa fino al termine dei controlli.', 'Migrazione in corso'],
    delayed: ['Cambio di stagione in ritardo', 'Il passaggio alla stagione {target} richiede altri controlli. Il tempo di gioco rimane in pausa.', 'Passaggio ritardato'],
    completed: ['Benvenuto nella stagione {target}!', 'Il passaggio dalla stagione {source} è completato. La tua carriera tennistica continua nella nuova stagione.', 'Stagione {target} iniziata'],
    reassurance: 'I progressi della tua carriera sono salvati. Non devi fare nulla.',
    acknowledge: 'Ho capito',
    close: 'Chiudi avviso',
    heading: 'Avviso sul cambio di stagione',
  },
  fr: {
    preparing: ['La saison {target} arrive !', 'La saison {source} est terminée. Le temps de jeu est en pause pendant la préparation de la nouvelle saison et les vérifications.', 'Préparation de la saison {target}'],
    running: ['Transition de saison en cours', 'Le passage officiel de la saison {source} à la saison {target} est en cours. Le temps de jeu peut rester en pause pendant les vérifications.', 'Migration en cours'],
    delayed: ['Transition de saison retardée', 'Le passage à la saison {target} nécessite des vérifications supplémentaires. Le temps de jeu reste en pause.', 'Transition retardée'],
    completed: ['Bienvenue dans la saison {target} !', 'Le passage depuis la saison {source} est terminé. Votre carrière de tennis continue dans la nouvelle saison.', 'Saison {target} commencée'],
    reassurance: 'Votre progression de carrière reste enregistrée. Aucune action n’est requise.',
    acknowledge: 'Compris',
    close: 'Fermer l’annonce',
    heading: 'Annonce du changement de saison',
  },
  ru: {
    preparing: ['Скоро сезон {target}!', 'Сезон {source} завершён. Игровое время приостановлено, пока мы готовим новый сезон и проводим проверки.', 'Подготовка сезона {target}'],
    running: ['Переход между сезонами', 'Официальный переход от сезона {source} к сезону {target} выполняется. Игровое время может оставаться на паузе до завершения проверок.', 'Переход выполняется'],
    delayed: ['Переход между сезонами задерживается', 'Перед началом сезона {target} нужны дополнительные проверки. Игровое время остаётся на паузе.', 'Переход задержан'],
    completed: ['Добро пожаловать в сезон {target}!', 'Переход из сезона {source} завершён. Ваша теннисная карьера продолжается в новом сезоне.', 'Сезон {target} начался'],
    reassurance: 'Ваш прогресс сохранён. Дополнительных действий не требуется.',
    acknowledge: 'Понятно',
    close: 'Закрыть уведомление',
    heading: 'Уведомление о смене сезона',
  },
  pt: {
    preparing: ['A temporada {target} está chegando!', 'A temporada {source} terminou. O tempo do jogo está pausado enquanto preparamos a nova temporada e concluímos as verificações.', 'Preparando temporada {target}'],
    running: ['Transição de temporada em andamento', 'A mudança oficial da temporada {source} para a {target} está em andamento. O tempo do jogo pode continuar pausado até o fim das verificações.', 'Migração em andamento'],
    delayed: ['Transição de temporada atrasada', 'A passagem para a temporada {target} precisa de mais verificações. O tempo do jogo continua pausado.', 'Transição atrasada'],
    completed: ['Bem-vindo à temporada {target}!', 'A transição da temporada {source} foi concluída. Sua carreira no tênis continua na nova temporada.', 'Temporada {target} iniciada'],
    reassurance: 'Seu progresso na carreira está salvo. Você não precisa fazer nada.',
    acknowledge: 'Entendi',
    close: 'Fechar aviso',
    heading: 'Aviso de transição de temporada',
  },
}

const phases: readonly Phase[] = ['preparing', 'running', 'delayed', 'completed']

function isNotice(value: unknown): value is Notice {
  if (!value || typeof value !== 'object') return false
  const row = value as Partial<Notice>
  return phases.includes(row.phase as Phase)
    && typeof row.source_season === 'number' && Number.isInteger(row.source_season) && row.source_season > 0
    && typeof row.target_season === 'number' && Number.isInteger(row.target_season) && row.target_season === row.source_season + 1
}

function formatCopy(value: string, notice: Notice) {
  return value.replace(/\{source\}/g, String(notice.source_season)).replace(/\{target\}/g, String(notice.target_season))
}

export default function SeasonTransitionNotice({ variant }: { variant: 'public' | 'dashboard' }) {
  const { locale } = useLocalization()
  const { user } = useAuth()
  const [notice, setNotice] = useState<Notice | null>(null)
  const [popupOpen, setPopupOpen] = useState(false)

  useEffect(() => {
    let active = true
    const refresh = async () => {
      const { data, error } = await supabase.rpc('get_season_transition_notice_v1')
      if (!active) return
      // Fail closed: never tell players a migration started/finished without server evidence.
      setNotice(!error && isNotice(data) ? data : null)
    }

    void refresh()
    const interval = window.setInterval(() => void refresh(), 60000)
    const onVisibilityChange = () => {
      if (document.visibilityState === 'visible') void refresh()
    }
    document.addEventListener('visibilitychange', onVisibilityChange)
    return () => {
      active = false
      window.clearInterval(interval)
      document.removeEventListener('visibilitychange', onVisibilityChange)
    }
  }, [])

  const popupKey = variant === 'dashboard' && notice && user?.id
    ? ['tlg:season-transition', user.id, notice.source_season, notice.target_season, notice.phase].join(':')
    : null

  useEffect(() => {
    if (!popupKey) {
      setPopupOpen(false)
      return
    }
    setPopupOpen(window.localStorage.getItem(popupKey) !== 'dismissed')
  }, [popupKey])

  if (!notice) return null

  const copy = messages[locale] ?? messages.en
  const [heading, description, status] = copy[notice.phase]
  const title = formatCopy(heading, notice)
  const body = formatCopy(description, notice)
  const statusLabel = formatCopy(status, notice)
  const Icon = notice.phase === 'completed' ? CheckCircle2 : notice.phase === 'delayed' ? AlertTriangle : notice.phase === 'running' ? Clock3 : CalendarClock

  const dismissPopup = () => {
    if (popupKey) window.localStorage.setItem(popupKey, 'dismissed')
    setPopupOpen(false)
  }

  return (
    <>
      <section className={'tlg-season-notice tlg-season-notice--' + variant + ' tlg-season-notice--' + notice.phase} role="status">
        <span className="tlg-season-notice__icon"><Icon size={22} aria-hidden="true" /></span>
        <div className="tlg-season-notice__content">
          <strong>{title}</strong>
          <p>{body}</p>
          {variant === 'dashboard' && <small>{copy.reassurance}</small>}
        </div>
        <span className="tlg-season-notice__status">{statusLabel}</span>
      </section>

      {variant === 'dashboard' && (
        <Dialog.Root open={popupOpen} onOpenChange={(open) => { if (!open) dismissPopup() }}>
          <Dialog.Portal>
            <Dialog.Overlay className="tlg-season-dialog__overlay" />
            <Dialog.Content className="tlg-season-dialog__content" aria-describedby="tlg-season-dialog-description">
              <button type="button" className="tlg-season-dialog__close" aria-label={copy.close} onClick={dismissPopup}>
                <X size={20} aria-hidden="true" />
              </button>
              <span className="tlg-season-dialog__eyebrow">{copy.heading}</span>
              <span className="tlg-season-dialog__icon"><Icon size={26} aria-hidden="true" /></span>
              <Dialog.Title className="tlg-season-dialog__title">{title}</Dialog.Title>
              <Dialog.Description id="tlg-season-dialog-description" className="tlg-season-dialog__description">{body}</Dialog.Description>
              <p className="tlg-season-dialog__reassurance">{copy.reassurance}</p>
              <button type="button" className="tlg-season-dialog__action" onClick={dismissPopup}>{copy.acknowledge}</button>
            </Dialog.Content>
          </Dialog.Portal>
        </Dialog.Root>
      )}
    </>
  )
}
