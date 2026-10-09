import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCareerChaptersDe: ManualChapter[] = [
  {
    id: 'notifications-inbox',
    title: 'Benachrichtigungen und Manager-Postfach',
    summary: 'Karrierehinweise, Benachrichtigungsaktionen und private Nachrichten zwischen Managern.',
    sections: [
      s('Benachrichtigungszentrale', { paragraphs: [
        'Benachrichtigungen sind strukturierte Karriereereignisse mit Kategorie, Typ, Priorität, Status, vollständiger Beschreibung und Erstellungszeit. Viele Benachrichtigungen enthalten eine direkte Aktion wie Turnier ansehen, Zeitplan öffnen, Training öffnen, Gesundheit öffnen, Ausrüstung ansehen oder Jetzt abstimmen.',
      ]}),
      s('Typische Kategorien', { bullets: ['Turnier und Reise', 'Training und Spielerentwicklung', 'Gesundheit und Verletzungen', 'Ausrüstung', 'Finanzen', 'Team', 'Privatleben', 'Nationalteam', 'Konto'] }),
      s('Ungelesen- und Wichtig-Zähler', { paragraphs: [
        'Die Benachrichtigungszentrale unterscheidet zwischen ungelesenen, wichtigen und gesamten Meldungen. Das Ausblenden einer Benachrichtigung entfernt sie aus der aktiven Aufmerksamkeit, macht aber das Spielereignis, das sie erzeugt hat, nicht rückgängig.',
      ]}),
      s('Manager-Postfach', { paragraphs: [
        'Das Manager-Postfach dient der privaten Kommunikation zwischen Spielern. Unterhaltungen werden normalerweise vom öffentlichen Profil eines anderen menschlichen Spielers gestartet. Nur die beiden beteiligten Manager können die Unterhaltung lesen.',
      ]}),
      s('Systemwarnungen sind etwas anderes', { paragraphs: [
        'Administrator-Warnungen aus System Health sind operative Werkzeuge und keine normalen Karrierebenachrichtigungen für Spieler. Spieler erhalten Karriereereignisse, die ihren eigenen Spielzustand betreffen.',
      ], links: [{ label: 'Benachrichtigungen öffnen', href: '/game/notifications' }, { label: 'Manager-Postfach öffnen', href: '/game/inbox' }]}),
    ],
  },
  {
    id: 'premium-coins',
    title: 'Premium-Funktionen, Coins und Abrechnung',
    summary: 'Optionale Premium-Mitgliedschaft, Coin-Pakete und was bezahlte Funktionen verändern – und was nicht.',
    sections: [
      s('Kostenloses Kern-Gameplay', { paragraphs: [
        'Normales Karriere-Gameplay ist kostenlos. Premium ergänzt optionale Analysen, Komfort und ausgewählte Premium-Systeme; es ist nicht erforderlich, um einen Spieler zu erstellen, zu trainieren, Turniere zu spielen oder den Kern-Karriereablauf zu nutzen.',
      ]}),
      s('Aktuelle Premium-Pläne', { table: {
        headers: ['Plan', 'Preis', 'Coin-Belohnung nach erfolgreicher Zahlung'],
        rows: [
          ['Monatlich', '3,29 EUR pro realem Monat', '30 Coins'],
          ['3 Monate · Hauptangebot', '9,49 EUR alle 3 realen Monate', '90 Coins'],
          ['12 Monate · 15 % Ersparnis', '33,49 EUR pro Jahr', '360 Coins'],
        ],
      }}),
      s('Aktuelle Coin-Pakete', { table: {
        headers: ['Paket', 'Preis'],
        rows: [['70 Coins', '2,99 EUR'], ['130 Coins', '4,99 EUR'], ['270 Coins', '9,99 EUR'], ['390 Coins', '13,99 EUR'], ['570 Coins', '19,99 EUR'], ['900 Coins', '29,99 EUR']],
      }}),
      s('Start-Coins', { paragraphs: [
        'Eine neue menschliche Karriere erhält einmalig 20 Start-Coins. Coins haben eine eigene Wallet/ein eigenes Ledger und sind vom Karriereguthaben getrennt.',
      ]}),
      s('Aktuell implementierte Premium-Beispiele', { bullets: [
        'Ranglistenschutz-Ansicht für bevorstehenden Verfall von Einzel-/Doppel-Ranglistenpunkten.',
        'Zugang zum Privatleben und einmaliger Anspruch auf eine Premium-Startwohnung.',
        'Premium-Coin-Belohnung von 30 Coins pro abgedecktem Monat: 30 monatlich, 90 alle 3 Monate oder 360 jährlich.',
      ]}),
      s('Abrechnungsverlauf', { paragraphs: [
        'Premium-Rechnungen, Coin-Paketkäufe und Coin-Ledger-Aktivität werden getrennt angezeigt. Sicherer Checkout und wiederkehrende Abrechnung laufen über Stripe.',
      ], links: [{ label: 'Premium & Abrechnung öffnen', href: '/game/pro-packages' }]}),
    ],
  },
  {
    id: 'private-life',
    title: 'Privatleben',
    summary: 'Premium-Off-Court-Vermögenswerte, Immobilienmärkte, Prestige, Investments und laufende Besitzkosten.',
    sections: [
      s('Nur mit Premium', { paragraphs: [
        'Privatleben ist Premium-only. Eine Premium-Karriere erhält eine Startwohnung in der Heimatstadt des Spielers. Die Startwohnung ist handelgesperrt, damit dieser Anspruch nicht direkt in Karriereguthaben umgewandelt werden kann.',
      ]}),
      s('Physische Vermögenswerte und Prestige', { paragraphs: [
        'Eigene physische Vermögenswerte tragen zu Marktwert, Prestige und bei manchen Klassen zu monatlichen laufenden Kosten bei. Das Dashboard trennt Karriereguthaben, physische Vermögenswerte, Investments, aktuellen Nettowert und monatliche Besitzkosten.',
      ]}),
      s('Laufende Kosten', { paragraphs: [
        'Fahrzeuge, Häuser, Yachten und Privatjets verursachen laufende Besitz-/Lebenskosten. Uhren, Schmuck, Kunst und Sammlerstücke verwenden nicht dasselbe laufende Kostenmodell.',
      ]}),
      s('Immobilienpreise', { paragraphs: [
        'Immobilienwerte verwenden für Heimatstädte ohne eigenen Marktpreis eine 10-stufige Länderbasis. Explizite Märkte großer Städte überschreiben die Länderbasis, sodass New York und eine günstigere Stadt nicht denselben Immobilienwert erhalten.',
      ]}),
      s('Wohnsitzregel', { paragraphs: [
        'Der Spieler benötigt möglicherweise einen weiteren qualifizierenden Wohnsitz, bevor der aktuelle Hauptwohnsitz verkauft werden kann. Das Premium-Starterhaus selbst ist handelgesperrt und kann nicht verkauft werden.',
      ]}),
      s('Marktplatz und Transaktionsverlauf', { paragraphs: [
        'Käufe, Verkäufe und Besitzkosten laufen über Karrierefinanzen und werden im Transaktionsverlauf des Privatlebens erfasst. Aktive Verkaufsangebote können storniert werden, solange sie offen sind.',
      ], links: [{ label: 'Privatleben öffnen', href: '/game/private-life' }]}),
    ],
  },
  {
    id: 'tennis-club',
    title: 'Tennisclub und Community-Clubs',
    summary: 'Tourübergreifende soziale Clubs, Mitgliedsanträge, Clubranglisten und privater Clubchat.',
    sections: [
      s('Tourübergreifende Mitgliedschaft', { paragraphs: [
        'Tennisclubs sind gemeinsame soziale Organisationen, die menschliche ATP- und WTA-Spieler umfassen können. Ein Spieler kann durch Gründung, Antrag oder Einladung Mitglied eines Clubs werden.',
      ]}),
      s('Einen Club erstellen', { paragraphs: [
        'Das Erstellen eines Tennisclubs kostet 50 Coins. Der Ersteller wird Clubbesitzer. Der Clubname muss die aktuellen Validierungsregeln erfüllen und eindeutig sein.',
      ]}),
      s('Einem Club beitreten', { paragraphs: [
        'Nutze Weltclubs, um dich bei einem bestehenden Club zu bewerben, oder nimm eine Einladung eines Clubbesitzers an. Offene Anträge und Einladungen bleiben sichtbar, bis sie entschieden sind.',
      ]}),
      s('Clubpunkte und Rangliste', { paragraphs: [
        'Clubpunkte sind die aktuelle Summe der offiziellen Ranglistenpunkte aller Mitglieder über ATP und WTA. Die Weltclub-Rangliste zeigt die Top 50 Clubs.',
      ]}),
      s('Clubchat', { paragraphs: [
        'Der Clubchat ist nur für Mitglieder. Das konfigurierte Fenster für aktuelle Chatnachrichten beträgt 14 Spieltage.',
      ], links: [{ label: 'Tennisclub öffnen', href: '/game/tennis-club' }]}),
    ],
  },
  {
    id: 'national-association',
    title: 'Nationalverband und Nationalteam',
    summary: 'Mitgliedschaft, Verbandsfinanzierung, Kapitänswahlen und Community-Governance.',
    sections: [
      s('Mitgliedschaft', { paragraphs: [
        'Die Mitgliedschaft im Nationalverband ist freiwillig. Ein neuer Spieler ist nicht automatisch Mitglied. Ein Beitritt nimmt den Spieler in den Pool für mögliche Nationalteam-Nominierungen auf und ermöglicht Governance-Teilnahme, soweit berechtigt.',
      ]}),
      s('Grundprinzipien der Community-Governance', { bullets: [
        'Ein Mitglied hat eine Stimme.',
        'Die Höhe einer Spende erhöht niemals das Stimmgewicht.',
        'Gründungs-/Aktivierungsstatus ist kosmetisch und erzeugt kein dauerhaftes Eigentum.',
        'Der Nationalkapitän ist ein aktiver Spieler und belegt einen normalen Kaderplatz.',
        'Das Kapitänsamt umgeht keine Ermüdungs-, Gesundheits- oder Kalenderregeln.',
      ]}),
      s('Jährliche Verlängerung', { paragraphs: [
        'Die Verbandsverlängerung öffnet im Januar und muss bis 31. Januar abgeschlossen sein. Ein nicht bezahlter Verband wird ab 1. Februar inaktiv.',
      ]}),
      s('Zeitplan der Kapitänswahl', { table: {
        headers: ['Datum / Zeitraum', 'Aktion'],
        rows: [
          ['1. Januar', 'Jährliche Verlängerung und Kandidatenregistrierung öffnen'],
          ['10. Januar', 'Hauptwahl für den Kapitän öffnet'],
          ['20. Januar', 'Hauptwahlrunde endet'],
          ['21.–27. Januar', 'Erste Stichwahl, falls kein eindeutiger Gewinner'],
          ['Danach alle 7 Tage', 'Weitere Stichwahlen, solange nötig'],
          ['31. Januar', 'Verlängerungsfrist'],
          ['1. Februar', 'Nicht bezahlter Verband wird inaktiv'],
        ],
      }}),
      s('Gewinnerregel', { paragraphs: [
        'Ein Kandidat gewinnt nur, wenn er mindestens eine Stimme und strikt mehr Stimmen als jeder andere Kandidat hat. Gibt es keinen eindeutigen Gewinner, wird eine Stichwahl erstellt.',
      ]}),
      s('Rücktritt des Kapitäns', { paragraphs: [
        'Der aktuelle Kapitän kann zurücktreten. Danach kann eine Ersatzwahl eröffnet werden, statt das Amt dauerhaft an den bisherigen Gewinner zu binden.',
      ], links: [{ label: 'Nationalverband öffnen', href: '/game/national-team' }]}),
    ],
  },
  {
    id: 'statistics',
    title: 'Statistiken und Karrierehistorie',
    summary: 'Weltranglisten, Turnierstatistiken, Spielerrekorde und saisonweiser Verlauf.',
    sections: [
      s('Statistikbereiche', { bullets: ['Weltstatistiken', 'Spielerstatistiken', 'Turnierstatistiken', 'Karriererekorde'] }),
      s('Weltweite Bestenliste', { paragraphs: [
        'Weltstatistiken zeigt führende Spieler mit abgeschlossenen offiziellen Matches im gewählten Zeitraum, einschließlich Rang, Punkten, Siegquote, Titeln und Produktionswerten aus Matches, soweit verfügbar.',
      ]}),
      s('Turnierdatenbank', { paragraphs: [
        'Turnierstatistiken aggregieren offizielle abgeschlossene Matches, Teilnahme, Schlagproduktion und Informationen zu Topspielern pro Event.',
      ]}),
      s('Karrierestatistiken des Spielers', { paragraphs: [
        'Spielerstatistiken umfassen aktuellen Rang, Karrierebestwert, Matchbilanz, Titel/Finals, Preisgeld, Bilanz nach Belag, Schlagproduktion und Leistung nach Turnierkategorie.',
      ]}),
      s('Karriere-Zeitleiste', { paragraphs: [
        'Die saisonweise Zeitleiste wird mit fortschreitender Karriere zum langfristigen historischen Datensatz und hält die Leistung der aktuellen Saison getrennt von Gesamtwerten.',
      ], links: [{ label: 'Statistiken öffnen', href: '/game/statistics' }]}),
    ],
  },
  {
    id: 'preferences-support',
    title: 'Spieleinstellungen, Hilfe, Community und Support',
    summary: 'Managerbezogene Einstellungen und Support-Werkzeuge außerhalb des Wettkampf-Karriereablaufs.',
    sections: [
      s('Spieleinstellungen', { paragraphs: [
        'Spieleinstellungen ist die zentrale Seite für persönliche Interface- und Kommunikationseinstellungen. Einzelne Kontrollen für Benachrichtigungskategorien sind dort noch nicht konfiguriert, daher beschreibt das Handbuch nicht verfügbare Schalter nicht als aktiv.',
      ]}),
      s('Hilfe-Center', { paragraphs: [
        'Das Hilfe-Center bietet Schnellstart-Links, Supportkontakt, Discord und dieses vollständige Spielhandbuch. Das Handbuch bleibt innerhalb von Tennis Legacy und besitzt außerdem eine herunterladbare PDF-Ausgabe.',
      ]}),
      s('Forum / Discord', { paragraphs: [
        'Der offizielle Tennis-Legacy-Discord ist das Community-Forum für Strategie, Screenshots, Fragen, Bug-Meldungen, Vorschläge und Entwicklungsankündigungen.',
      ]}),
      s('Support kontaktieren', { paragraphs: [
        'Kontakt ist der direkte Supportweg. Gib bei technischen Problemen Seitenname, Spielername, Screenshots und genaue Schritte zur Reproduktion an.',
      ]}),
      s('Freunde einladen', { paragraphs: [
        'Freunde einladen stellt einen Registrierungs-/Empfehlungslink bereit, über den ein anderer Manager eine separate ATP- oder WTA-Karriere erstellen kann.',
      ], links: [
        { label: 'Spieleinstellungen öffnen', href: '/game/preferences' },
        { label: 'Hilfe-Center öffnen', href: '/game/help' },
        { label: 'Support kontaktieren', href: '/game/contact' },
        { label: 'Forum öffnen', href: '/game/forum' },
      ]}),
    ],
  },
  {
    id: 'season-progression',
    title: 'Saisonfortschritt und Spielzeit-Verarbeitung',
    summary: 'Wie Tennis Legacy durch Spieltage fortschreitet und warum viele Systeme automatisch aktualisiert werden.',
    sections: [
      s('Spielzeit statt realer Zeit', { paragraphs: [
        'Tennis Legacy verwendet einen eigenen Spielkalender. Turniere, Ranglistenveröffentlichung, Verträge, Steuern, Gesundheit, Training, Reisen und Verbandsfenster richten sich nach Spieldaten statt nach dem realen Datum des Managers.',
      ]}),
      s('Automatische tägliche Verarbeitung', { paragraphs: [
        'Viele Systeme aktualisieren sich automatisch mit fortschreitenden Spieltagen: reguläres Training, Trainingscamp-Tage, Reiseabschnitte, Gesundheitsprüfungen, Finanzabrechnungen, Sponsorzahlungen, Ranglistenveröffentlichung und Turnier-Lebenszyklusaktionen. Spieler sollten nicht jeden Hintergrundübergang manuell verarbeiten müssen.',
      ]}),
      s('Saisonreset vs. Karrierekontinuität', { paragraphs: [
        'Eine neue Spielsaison verändert Saisonpläne, Kontext der Ranglistenpunkt-Verteidigung, Sponsorzyklen, Verbandsverlängerungs-/Wahlfenster und Saisonstatistiken. Die langfristige Karriere läuft mit derselben Identität, denselben Fähigkeiten, eigener Ausrüstung und historischen Datensätzen weiter, sofern ein System nichts anderes festlegt.',
      ]}),
      s('System Health', { paragraphs: [
        'Kritische Hintergrundprozesse werden von System Health und dem administrativen Control Center überwacht. Diese operative Ebene erkennt festgefahrene/fehlerhafte Lebenszyklus-Jobs und Integritätsprobleme, damit technische Fehler nicht unbemerkt zu normalem Gameplay werden.',
      ]}),
    ],
  },
  {
    id: 'important-rules',
    title: 'Wichtige Spielregeln und Einschränkungen',
    summary: 'Regeln, die häufige Missverständnisse darüber verhindern, was das aktuelle Spiel tut.',
    sections: [
      s('Identität und Welten', { bullets: [
        'Der professionelle Spielername ist nach der Karriereerstellung fest.',
        'Die Spielhand ist ein Kernteil der Spieleridentität. Links- und Rechtshänder erhalten keine automatischen dauerhaften Vorhand-/Rückhandboni; die Spielhand beeinflusst Matchgeometrie und taktische Eignung.',
        'ATP- und WTA-Wettkampfranglisten sind getrennt.',
        'Einzel- und Doppelranglisten sind getrennte Disziplinen.',
        'Tennisclubs können Mitglieder aus ATP und WTA enthalten.',
      ]}),
      s('Kalenderbelegung', { bullets: [
        'Ein Turnier-, Reise-, Trainingscamp-, Nationalteam- oder Gesundheitstag ist kein normaler Trainingstag zu Hause.',
        'Ein gespeicherter regulärer Trainingsplan überschreibt niemals stärkere Kalenderbelegung.',
        'Unmögliche Reisezeiten können dazu führen, dass der Spieler ein Match verpasst.',
      ]}),
      s('Geld und Coins', { bullets: [
        'Karriereguthaben und Coins sind getrennte Währungen.',
        'Premium entfernt nicht die Notwendigkeit, Karriereguthaben zu verwalten.',
        'Coins zu kaufen erzeugt kein Karriereguthaben.',
        'Finanzwertbewegungen sind idempotent ausgelegt, damit ein erneuter Versuch keine Belastung oder Belohnung dupliziert.',
      ]}),
      s('Gegnerwissen und Taktik', { bullets: [
        'Spielhand, bevorzugter Belag und Spielstil sind öffentliche Gegnerinformationen.',
        'Exakte Gegnerfähigkeiten bleiben privat. Ein Leistungsanalyst liefert Schätzungen, deren Bereich mit Analystenqualität und Vorbereitungszeit enger wird.',
        'Die Qualität des Leistungsanalysten verbessert die Informationssicherheit, nicht direkt die versteckte Spielerstärke.',
        'Taktische Konter sind moderate Matchup-Effekte, keine garantierten Siegknöpfe. Eigene Fähigkeiten, Gegnerfähigkeiten, Belag, Zustand und Risiko bleiben wichtig.',
      ]}),
      s('Entwicklung', { bullets: [
        'Bevorzugter Belag/Stil verändert die Startverteilung, nicht die gesamte Startstärke.',
        'Hohe Fähigkeiten entwickeln sich langsamer als niedrigere.',
        'Trainingscamps sind stärker als gewöhnliches Training, verwenden aber abnehmende Erträge über mehrere Wochen.',
        'Bereitschaftswerte sind keine dauerhaften Fähigkeiten.',
      ]}),
      s('Premium-Grenzen', { bullets: [
        'Das Kern-Karriere-Gameplay ist für kostenlose Spieler verfügbar.',
        'Privatleben ist Premium-only.',
        'Ranglistenschutz ist Planungsinformation, kein Schutz vor Punkteverlust.',
        'Die Premium-Startwohnung ist handelgesperrt.',
      ]}),
      s('Unfertige Ideen werden nicht als aktiv dokumentiert', { paragraphs: [
        'Wenn eine aktuelle Spielseite angibt, dass eine Kontrolle noch nicht konfiguriert ist, beschreibt dieses Handbuch sie als nicht verfügbar, statt eine zukünftige Idee als bereits implementiert darzustellen.',
      ]}),
    ],
  },
  {
    id: 'faq',
    title: 'Häufig gestellte Fragen',
    summary: 'Antworten auf häufige Fragen zum Karrieremanagement.',
    sections: [
      s('Warum kann ich heute nicht trainieren?', { paragraphs: [
        'Prüfe aktuelle Kalenderaktivität und Gesundheit. Reguläres Training benötigt einen Tag zu Hause und medizinische Freigabe. Turnier-, Reise-, Trainingscamp-, Nationalteam- oder Verletzungs-/Erholungsbelegung blockiert normales Training.',
      ]}),
      s('Warum ist mein Rang gefallen, obwohl ich heute nicht verloren habe?', { paragraphs: [
        'Der Rang ist relativ zu allen Spielern, und aktive Ranglistenbeiträge können verfallen. Andere Spieler können ebenfalls Punkte gewinnen. Premium-Ranglistenschutz kann kommende Verfallsdaten zeigen, stoppt sie aber nicht.',
      ]}),
      s('Warum wurde ein Trainingscamp kürzer?', { paragraphs: [
        'Wenn ein Turnier unmittelbar vor dem Camp das normale Reisedatum belegt, kann der erste Camp-Tag zu einem geteilten Reisetag über die Heimatstadt werden. Das ursprüngliche Camp-Enddatum bleibt, daher geht ein Entwicklungstag verloren.',
      ]}),
      s('Kann ich während eines Trainingscamps reguläres Training geplant lassen?', { paragraphs: [
        'Ja. Der gespeicherte Wochenplan kann bestehen bleiben, aber Camp- und Camp-Reisetage überschreiben ihn automatisch. Reguläres Training zeigt das gebuchte Camp, sodass der Konflikt sichtbar ist.',
      ]}),
      s('Warum habe ich ein Turnier-Match verpasst?', { paragraphs: [
        'Ein unterstützter Grund ist Reise-No-Show: Wenn der Reiseplan den Spieler nicht rechtzeitig vor dem angesetzten Match einsatzbereit machen kann, kommt der Gegner ohne gespieltes Match weiter. Gesundheitsbeschränkungen können ebenfalls zu nicht gespielten Ergebnissen führen.',
      ]}),
      s('Bekomme ich zu Beginn Teammitglieder oder Sponsoren?', { paragraphs: [
        'Nein. Eine neue Karriere beginnt ohne Team, Hauptsponsor und technischen Sponsor. Diese Systeme werden im Verlauf der Karriere aufgebaut.',
      ]}),
      s('Wofür sollte ich die ersten 25.000 $ ausgeben?', { paragraphs: [
        'Es gibt keine einzig richtige Antwort. Die Startausrüstung reicht zum Spielen, daher können frühe Ausgaben auf Training, Turnierreisen/-hotels, sorgfältig ausgewählte Teammitglieder oder gezielte Ausrüstungsupgrades konzentriert werden. Prüfe kommende Kosten, bevor du zu viel Geld bindest.',
      ]}),
      s('Wofür sind die ersten 20 Coins?', { paragraphs: [
        'Sie führen die Coin-Wallet ein und können für optionale Coin-basierte Systeme gespart werden. Einen Tennisclub zu erstellen kostet derzeit 50 Coins, daher reicht die Startgutschrift bewusst nicht für eine sofortige Clubgründung.',
      ]}),
      s('Kann ich die Premium-Startwohnung verkaufen?', { paragraphs: [
        'Nein. Sie ist handelgesperrt, damit der Premium-Anspruch nicht zu einem Karriereguthaben-Exploit wird.',
      ]}),
      s('Ist Premium nötig, um konkurrenzfähig zu sein?', { paragraphs: [
        'Kern-Wettkampfsysteme sind ohne Premium verfügbar. Premium ergänzt optionale Analysen/Komfort und Privatleben, garantiert aber kein Turnier- oder Ranglistenergebnis.',
      ]}),
      s('Wo melde ich einen Bug?', { paragraphs: [
        'Nutze Supportkontakt oder den offiziellen Discord. Gib Screenshots, Spielername, Spielseite und genaue Schritte zur Reproduktion an.',
      ], links: [{ label: 'Hilfe-Center öffnen', href: '/game/help' }, { label: 'Support kontaktieren', href: '/game/contact' }]}),
    ],
  },
]
