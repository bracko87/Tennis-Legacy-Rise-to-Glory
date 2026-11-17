import type { AppLocale } from '../i18n'

interface PrelaunchTrialCopy {
  status: string
  description: string
}

const LABELS: Record<AppLocale, PrelaunchTrialCopy> = {
  en: {
    status: 'Premium trial reserved',
    description: 'Premium preview access is available now. Your full 7-day free trial begins only when the game clock is first unpaused on or after 23 November 2026 at 07:00 German time. No trial days are used before that.',
  },
  de: {
    status: 'Premium-Testphase vorgemerkt',
    description: 'Du kannst Premium-Funktionen bereits ausprobieren. Deine vollen 7 kostenlosen Tage beginnen erst, wenn die Spieluhr am oder nach dem 23. November 2026 um 07:00 Uhr deutscher Zeit erstmals gestartet wird. Vorher geht kein Testtag verloren.',
  },
  sr: {
    status: 'Premium probni period je rezervisan',
    description: 'Premium funkcije možeš da isprobaš već sada. Punih 7 besplatnih dana počinje tek kada vreme u igri prvi put krene, najranije 23. novembra 2026. u 07:00 po nemačkom vremenu. Pre toga nijedan dan se ne troši.',
  },
  es: {
    status: 'Prueba Premium reservada',
    description: 'Ya puedes probar las funciones Premium. Tus 7 días gratuitos completos empezarán cuando se active por primera vez el reloj del juego, no antes del 23 de noviembre de 2026 a las 07:00 (hora alemana). Antes no se consume ningún día.',
  },
  fr: {
    status: 'Essai Premium réservé',
    description: 'Tu peux déjà découvrir les fonctions Premium. Tes 7 jours gratuits complets commenceront seulement lorsque le temps du jeu sera débloqué pour la première fois, au plus tôt le 23 novembre 2026 à 07 h 00 (heure allemande). Aucun jour n’est décompté avant.',
  },
  it: {
    status: 'Prova Premium prenotata',
    description: 'Puoi già provare le funzioni Premium. I tuoi 7 giorni gratuiti completi inizieranno solo al primo avvio del tempo di gioco, non prima del 23 novembre 2026 alle 07:00 (ora tedesca). Prima non perdi alcun giorno.',
  },
  pt: {
    status: 'Teste Premium reservado',
    description: 'Já podes experimentar as funções Premium. Os teus 7 dias gratuitos completos começam apenas quando o relógio do jogo for ativado pela primeira vez, não antes de 23 de novembro de 2026 às 07:00 (hora da Alemanha). Não perdes dias antes disso.',
  },
  ru: {
    status: 'Пробный Premium зарезервирован',
    description: 'Вы уже можете попробовать функции Premium. Полные 7 бесплатных дней начнутся только после первого запуска игрового времени, не ранее 23 ноября 2026 года в 07:00 по немецкому времени. До этого дни не расходуются.',
  },
}

export function premiumPrelaunchTrialCopy(locale: AppLocale): PrelaunchTrialCopy {
  return LABELS[locale] ?? LABELS.en
}
