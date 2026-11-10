import { Link } from 'react-router'

import MarketingFooter from '../../components/layout/MarketingFooter'
import MarketingHeader from '../../components/layout/MarketingHeader'
import { useLocalization } from '../../i18n/LocalizationProvider'

const SUPPORT_EMAIL = 'contact@tennislegacygame.com'

const copy = {
  en: {
    eyebrow: 'Legal information',
    title: 'Refund & Cancellation Policy',
    updated: 'Last updated: 10 November 2026',
    intro: 'This policy explains how paid Premium access and purchased Coins work in Tennis Legacy: Rise to Glory. It does not limit consumer rights that cannot legally be excluded.',
    sections: [
      {
        title: 'Premium memberships',
        paragraphs: [
          'Premium benefits are made available after a successful purchase. The available paid plans have one-, three-, or twelve-month billing periods, as shown at purchase. Your exact paid period, price and any automatic renewal are shown in the checkout and in your membership information.',
          'If a Premium subscription renews automatically, you can stop future renewals through the Manage Subscription option. Cancelling renewal normally leaves Premium access active until the already-paid period ends. Cancellation does not automatically refund a paid period; mandatory legal rights remain unaffected.',
        ],
      },
      {
        title: 'Purchased Coins',
        paragraphs: [
          'Purchased Coins are credited to your game wallet after payment confirmation and may be used for eligible in-game features. Purchased Coins do not have a scheduled expiry date and remain in your wallet until spent, subject to lawful account corrections and the game rules.',
          'Coins have no cash value outside the game and cannot ordinarily be exchanged back into money, sold or transferred. Spending Coins on an in-game feature is not ordinarily reversible. This does not exclude statutory rights if paid Coins were not supplied correctly.',
        ],
      },
      {
        title: 'Refunds for correctly delivered purchases',
        paragraphs: [
          'We generally do not offer voluntary or goodwill refunds for correctly delivered and activated Premium access or Coins credited to the wallet, including simply because you changed your mind, stopped playing or did not use all of the purchased benefits.',
          'This policy never overrides applicable mandatory withdrawal rights, consumer remedies for faulty or missing digital content or services, or other rights provided by law.',
        ],
      },
      {
        title: 'Statutory right of withdrawal',
        paragraphs: [
          'Consumers may have a statutory 14-day right of withdrawal for online purchases. For some immediately supplied digital content not provided on a physical medium, this right may end when supply begins, but only if all applicable legal conditions are met, including express consent, acknowledgment and the required confirmation.',
          'Rules for ongoing services, including Premium subscriptions, can differ. Immediate activation alone does not automatically remove the right of withdrawal. Where the right still applies, we will honor it in accordance with applicable law.',
        ],
      },
      {
        title: 'Problems, payments and support',
        paragraphs: [
          'If Premium access or paid Coins were not delivered, are defective, or a payment appears incorrect or unauthorized, contact us with the purchase date, product and your payment receipt or transaction reference. Do not send payment card numbers.',
          'We will review the problem and provide any repair, restoration, refund or other remedy required by applicable law. Payment disputes or chargebacks are handled under applicable law and the payment provider’s rules.',
        ],
      },
    ],
    contactTitle: 'Contact for purchase questions',
    contactBody: 'For billing questions, withdrawal requests or legally required refunds, write to',
    home: 'Back to the game',
    store: 'Premium & Coins',
  },
  de: {
    eyebrow: 'Rechtliche Informationen',
    title: 'Erstattungs- und Kündigungsrichtlinie',
    updated: 'Stand: 10. November 2026',
    intro: 'Diese Richtlinie erklärt kostenpflichtige Premium-Zugänge und gekaufte Coins in Tennis Legacy: Rise to Glory. Gesetzlich zwingende Verbraucherrechte bleiben uneingeschränkt bestehen.',
    sections: [
      {
        title: 'Premium-Mitgliedschaften',
        paragraphs: [
          'Premium-Vorteile werden nach erfolgreicher Zahlung freigeschaltet. Es gibt kostenpflichtige Zeiträume von einem, drei oder zwölf Monaten. Der konkrete Preis, die Laufzeit und eine mögliche automatische Verlängerung werden vor dem Kauf und in den Mitgliedschaftsdaten angezeigt.',
          'Bei einer automatisch verlängerten Mitgliedschaft können zukünftige Verlängerungen über „Abonnement verwalten“ beendet werden. Der bereits bezahlte Premium-Zugang bleibt in der Regel bis zum Ende des laufenden Zeitraums aktiv. Eine Kündigung führt nicht automatisch zur Erstattung des bereits bezahlten Zeitraums. Zwingende gesetzliche Ansprüche bleiben unberührt.',
        ],
      },
      {
        title: 'Gekaufte Coins',
        paragraphs: [
          'Gekaufte Coins werden nach bestätigter Zahlung dem Spielkonto gutgeschrieben und können für dafür vorgesehene Spielfunktionen ausgegeben werden. Gekaufte Coins haben kein festgelegtes Ablaufdatum und bleiben grundsätzlich verfügbar, bis sie ausgegeben sind. Rechtmäßige Kontokorrekturen und Spielregeln bleiben unberührt.',
          'Coins haben außerhalb des Spiels keinen Geldwert und können normalerweise weder gegen Geld zurückgetauscht noch verkauft oder übertragen werden. Die Ausgabe von Coins für eine Spielfunktion ist normalerweise nicht rückgängig zu machen. Gesetzliche Ansprüche bei fehlerhafter Bereitstellung bleiben bestehen.',
        ],
      },
      {
        title: 'Erstattung bei ordnungsgemäßer Bereitstellung',
        paragraphs: [
          'Für ordnungsgemäß bereitgestellte und aktivierte Premium-Leistungen oder korrekt gutgeschriebene Coins bieten wir grundsätzlich keine freiwillige Erstattung an, beispielsweise bei bloßem Meinungswechsel, Spielabbruch oder Nichtnutzung.',
          'Zwingende Widerrufsrechte, gesetzliche Mängelrechte und Ansprüche bei nicht erbrachten digitalen Leistungen werden dadurch nicht eingeschränkt.',
        ],
      },
      {
        title: 'Gesetzliches Widerrufsrecht',
        paragraphs: [
          'Bei Online-Käufen können Verbraucher grundsätzlich ein gesetzliches Widerrufsrecht von 14 Tagen haben. Bei bestimmten sofort bereitgestellten digitalen Inhalten ohne körperlichen Datenträger kann das Widerrufsrecht mit Beginn der Bereitstellung erlöschen, aber nur wenn sämtliche gesetzlichen Voraussetzungen erfüllt sind, insbesondere ausdrückliche Zustimmung, Kenntnisbestätigung und die erforderliche Vertragsbestätigung.',
          'Für laufende Dienstleistungen wie Premium-Mitgliedschaften können andere Regeln gelten. Die sofortige Freischaltung allein beseitigt das Widerrufsrecht nicht automatisch. Bestehende gesetzliche Widerrufsrechte werden beachtet.',
        ],
      },
      {
        title: 'Probleme, Zahlungen und Support',
        paragraphs: [
          'Wenn Premium-Zugang oder bezahlte Coins fehlen, fehlerhaft sind oder eine Zahlung falsch beziehungsweise nicht autorisiert erscheint, kontaktiere uns mit Kaufdatum, Produkt und Zahlungsbeleg oder Transaktionsreferenz. Bitte keine vollständigen Kartendaten senden.',
          'Wir prüfen das Problem und erfüllen gesetzlich vorgeschriebene Ansprüche auf Nachbesserung, Bereitstellung, Erstattung oder andere Abhilfe. Zahlungsstreitigkeiten richten sich nach dem geltenden Recht und den Regeln des Zahlungsdienstleisters.',
        ],
      },
    ],
    contactTitle: 'Kontakt für Käufe und Erstattungen',
    contactBody: 'Bei Fragen zu Zahlungen, Widerruf oder gesetzlicher Erstattung erreichst du uns unter',
    home: 'Zurück zum Spiel',
    store: 'Premium & Coins',
  },
} as const

export default function RefundPolicyPage() {
  const { locale } = useLocalization()
  const t = locale === 'de' ? copy.de : copy.en

  return (
    <div className="tlg-marketing-page">
      <MarketingHeader />
      <main className="tlg-legal-main" id="main-content">
        <div className="tlg-legal-wrap">
          <header className="tlg-legal-intro">
            <span className="tlg-legal-eyebrow">{t.eyebrow}</span>
            <h1>{t.title}</h1>
            <p className="tlg-legal-updated">{t.updated}</p>
            <p>{t.intro}</p>
          </header>

          <div className="tlg-legal-sections">
            {t.sections.map((section) => (
              <section key={section.title} className="tlg-legal-section">
                <h2>{section.title}</h2>
                {section.paragraphs.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
              </section>
            ))}
            <section className="tlg-legal-section">
              <h2>{t.contactTitle}</h2>
              <p>{t.contactBody}{' '}<a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.</p>
            </section>
          </div>

          <nav className="tlg-legal-navigation" aria-label={t.eyebrow}>
            <Link to="/">{t.home}</Link>
            <Link to="/game/pro-packages">{t.store}</Link>
          </nav>
        </div>
      </main>
      <MarketingFooter />
    </div>
  )
}
