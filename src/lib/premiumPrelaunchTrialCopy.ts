import type { AppLocale } from '../i18n'

interface PrelaunchTrialCopy {
  status: string
  description: string
}

const LABELS: Record<AppLocale, PrelaunchTrialCopy> = {
  en: {
    status: 'Premium preview active',
    description: 'Premium features are available now, including Private Life. Your full seven-day free trial starts only when the game is first unpaused on or after 23 November 2026 at 07:00 German time. Preview access does not use trial days or start billing.',
  },
  de: {
    status: 'Premium-Vorschau aktiv',
    description: 'Premium-Funktionen einschließlich Privatleben sind bereits freigeschaltet. Deine vollständigen 7 kostenlosen Testtage beginnen erst beim ersten Start der Spieluhr, frühestens am 23. November 2026 um 07:00 Uhr deutscher Zeit. Die Vorschau verbraucht keine Testtage und startet keine Zahlung.',
  },
  sr: {
    status: 'Premium pregled je aktivan',
    description: 'Premium funkcije, uključujući Privatni život, dostupne su već sada. Punih 7 dana besplatnog probnog perioda počinje tek kada se sat igre prvi put pokrene, najranije 23. novembra 2026. u 07:00 po nemačkom vremenu. Pregled ne troši dane i ne pokreće naplatu.',
  },
  es: {
    status: 'Vista previa Premium activa',
    description: 'Las funciones Premium, incluida la vida privada, ya están disponibles. Los siete días completos de prueba gratis comenzarán cuando se active por primera vez el reloj del juego, nunca antes del 23 de noviembre de 2026 a las 07:00 (hora alemana). La vista previa no consume días ni inicia cobros.',
  },
  fr: {
    status: 'Aperçu Premium actif',
    description: 'Les fonctions Premium, y compris la vie privée, sont déjà accessibles. Les sept jours complets d\'essai gratuit commenceront au premier démarrage de l\'horloge du jeu, au plus tôt le 23 novembre 2026 à 07 h 00 (heure allemande). L\'aperçu ne décompte aucun jour et ne déclenche aucun paiement.',
  },
  it: {
    status: 'Anteprima Premium attiva',
    description: 'Le funzioni Premium, inclusa la vita privata, sono già disponibili. I sette giorni completi di prova gratuita inizieranno solo al primo avvio dell\'orologio di gioco, non prima del 23 novembre 2026 alle 07:00 (ora tedesca). L\'anteprima non consuma giorni né avvia pagamenti.',
  },
  pt: {
    status: 'Pré-visualização Premium ativa',
    description: 'As funcionalidades Premium, incluindo a Vida Privada, já estão disponíveis. Os sete dias completos de teste gratuito começam apenas quando o relógio do jogo arrancar pela primeira vez, nunca antes de 23 de novembro de 2026 às 07:00 (hora da Alemanha). A pré-visualização não consome dias nem inicia pagamentos.',
  },
  ru: {
    status: 'Предпросмотр Premium активен',
    description: 'Функции Premium, включая личную жизнь, уже доступны. Полные семь дней бесплатного пробного периода начнутся только при первом запуске игровых часов, не ранее 23 ноября 2026 года в 07:00 по немецкому времени. Предпросмотр не расходует дни и не запускает оплату.',
  },
}

export function premiumPrelaunchTrialCopy(locale: AppLocale): PrelaunchTrialCopy {
  return LABELS[locale] ?? LABELS.en
}
