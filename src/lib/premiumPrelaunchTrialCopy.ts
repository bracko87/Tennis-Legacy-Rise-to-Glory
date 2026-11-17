import type { AppLocale } from '../i18n'

interface PrelaunchTrialCopy {
  status: string
  description: string
}

const LABELS: Record<AppLocale, PrelaunchTrialCopy> = {
  en: {
    status: 'Premium trial reserved',
    description: 'Your Premium trial is reserved. All Premium features unlock and your full 7-day free trial begins when the game clock is first unpaused on or after 23 November 2026 at 07:00 German time. No trial days are used before that.',
  },
  de: {
    status: 'Premium-Testphase vorgemerkt',
    description: 'Premium ist vorgemerkt. Die Premium-Funktionen und deine vollen 7 kostenlosen Tage beginnen erst, wenn die Spieluhr am oder nach dem 23. November 2026 um 07:00 Uhr deutscher Zeit erstmals gestartet wird. Vorher geht kein Testtag verloren.',
  },
  sr: {
    status: 'Premium probni period je rezervisan',
    description: 'Premium je rezervisan. Premium funkcije i punih 7 besplatnih dana počinju tek kada vreme u igri prvi put krene, najranije 23. novembra 2026. u 07:00 po nemačkom vremenu. Pre toga nijedan dan se ne troši.',
  },
  es: {
    status: 'Prueba Premium reservada',
    description: 'La prueba Premium está reservada. Las funciones Premium y tus 7 días gratuitos completos empezarán cuando se active por primera vez el reloj del juego, no antes del 23 de noviembre de 2026 a las 07:00 (hora alemana). Antes no se consume ningún día.',
  },
  fr: {
    status: 'Essai Premium réservé',
    description: 'Ton essai Premium est réservé. Les fonctions Premium et tes 7 jours gratuits complets commenceront seulement lorsque le temps du jeu sera débloqué pour la première fois, au plus tôt le 23 novembre 2026 à 07 h 00 (heure allemande). Aucun jour n’est décompté avant.',
  },
  it: {
    status: 'Prova Premium prenotata',
    description: 'La prova Premium è prenotata. Le funzioni Premium e i tuoi 7 giorni gratuiti completi inizieranno solo al primo avvio del tempo di gioco, non prima del 23 novembre 2026 alle 07:00 (ora tedesca). Prima non perdi alcun giorno.',
  },
  pt: {
    status: 'Teste Premium reservado',
    description: 'O teu teste Premium está reservado. As funções Premium e os teus 7 dias gratuitos completos começam apenas quando o relógio do jogo for ativado pela primeira vez, não antes de 23 de novembro de 2026 às 07:00 (hora da Alemanha). Não perdes dias antes disso.',
  },
  ru: {
    status: 'Пробный Premium зарезервирован',
    description: 'Пробный Premium зарезервирован. Доступ к функциям Premium и полные 7 бесплатных дней начнутся только после первого запуска игрового времени, не ранее 23 ноября 2026 года в 07:00 по немецкому времени. До этого дни не расходуются.',
  },
}

export function premiumPrelaunchTrialCopy(locale: AppLocale): PrelaunchTrialCopy {
  return LABELS[locale] ?? LABELS.en
}
