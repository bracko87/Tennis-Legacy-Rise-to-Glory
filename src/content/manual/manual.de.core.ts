import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCoreChaptersDe: ManualChapter[] = [
  {
    id: 'getting-started',
    title: 'Erste Schritte',
    summary: 'Eine praktische Einführung in den Karriereablauf von Tennis Legacy, die wichtigsten Seiten und die ersten entscheidenden Entscheidungen.',
    sections: [
      s('Was Tennis Legacy ist', { paragraphs: [
        'Tennis Legacy: Rise to Glory ist ein dauerhaftes Karrieremanagement-Spiel im professionellen Tennis. Du steuerst einen menschlichen Spieler in der ATP- oder WTA-Welt, planst seine Entwicklung, meldest Turniere, verwaltest Reisen und Ausrüstung, baust ein Betreuungsteam auf, steuerst die Finanzen und reagierst über mehrere Spielsaisons auf Gesundheit, Rangliste und Kalenderdruck.',
        'ATP und WTA sind getrennte Wettbewerbswelten für Einzel- und Doppelranglisten. Soziale Systeme wie Tennisclubs können Mitglieder aus beiden Touren umfassen, während Turniermeldungen, Ranglisten und Ergebnisse immer an die eigene Tour des Spielers gebunden bleiben.',
      ]}),
      s('Empfohlene Reihenfolge in der ersten Sitzung', { steps: [
        'Öffne Übersicht und prüfe aktuelles Spieldatum, Rangliste, Bereitschaft, Karriereguthaben, nächste Verpflichtung und persönliche Benachrichtigungen.',
        'Öffne Fähigkeiten, um das technische, körperliche und Bereitschaftsprofil des Spielers zu verstehen.',
        'Öffne Training und richte einen regulären Wochenplan ein. Neue Karrieren starten ohne konfigurierten regulären Trainingsplan.',
        'Öffne Ausrüstung. Eine neue Karriere besitzt bereits einen Startschläger, Startschuhe und Startkleidung, die ausgerüstet sind.',
        'Öffne den Turnierkalender, bevor du dich irgendwo anmeldest. Prüfe Kategorie, Belag, Zeitpunkt und Reiseauswirkungen.',
        'Öffne Zeitplan nach einer Anmeldung oder Annahme. Turnierverpflichtungen, Vorbereitung und Reisen werden dort verwaltet.',
        'Öffne Finanzen regelmäßig. Karriereguthaben ist von Coins getrennt und jede Bewegung des Karriereguthabens wird dauerhaft protokolliert.',
      ]}),
      s('Der zentrale Karriereablauf', { bullets: [
        'Plane Training, Turniere, Reisen, Ausrüstung und Team rund um den Kalender.',
        'Bereite Ermüdung, Gesundheit, Taktik, Ausrüstung und Reise vor Wettkämpfen vor.',
        'Spiele um Ergebnisse, Ranglistenbeiträge, Statistiken, Preisgeld und Sponsorfortschritt.',
        'Erhole und entwickle dich durch reguläres Training, Trainingscamps und sinnvolle Belastungssteuerung.',
        'Investiere Karriereguthaben erneut in Team, Ausrüstung, Camps, Reisen, Hotels und Käufe im Privatleben.',
        'Prüfe Ranglisten, Statistiken, Benachrichtigungen und Finanzen, um die Folgen früherer Entscheidungen zu verstehen.',
      ]}),
      s('Wenn etwas unklar ist', { paragraphs: [
        'Nutze dieses vollständige Spielhandbuch für Regeln und Ablaufbeschreibungen. Das Hilfe-Center verlinkt außerdem zum Support und zum offiziellen Tennis-Legacy-Discord. Gib bei einer Problemmeldung Seite, Spielername, Screenshots und genaue Schritte zur Reproduktion an.',
      ], links: [
        { label: 'Übersicht öffnen', href: '/game/overview' },
        { label: 'Hilfe-Center öffnen', href: '/game/help' },
      ]}),
    ],
  },
  {
    id: 'creating-a-career',
    title: 'Eine Karriere erstellen',
    summary: 'Wie die Spielererstellung funktioniert und welches genaue Startpaket jede neue menschliche Karriere am ersten Tag erhält.',
    sections: [
      s('Entscheidungen bei der Karriereerstellung', { bullets: [
        'Tour: Wähle ATP oder WTA. Das bestimmt die Wettbewerbswelt und Rangliste des Spielers.',
        'Identität: Wähle einen realistischen Vor- und Nachnamen sowie eine Nationalität. Der professionelle Spielername ist nach der Erstellung dauerhaft.',
        'Heimatstadt: Wähle eine unterstützte Stadt im ausgewählten Land. Die Heimatstadt wird für Reisen und Privatleben verwendet.',
        'Porträt: optional. Katalogporträts, die bereits von einer aktiven Karriere genutzt werden, sind nicht verfügbar.',
        'Bevorzugter Belag: Hartplatz, Sand oder Rasen.',
        'Spielstil: Aggressiver Grundlinienspieler, Defensiver Grundlinienspieler, All-Court oder Serve & Volley.',
        'Spielhand: Rechts- oder Linkshänder. Die Spielhand verändert Aufschlag-/Ballwechselgeometrie und taktische Matchups; sie gewährt keine kostenlosen Vorhand- oder Rückhandpunkte.',
      ]}),
      s('Exaktes Startpaket am ersten Tag', { table: {
        headers: ['System', 'Startzustand'],
        rows: [
          ['Karriereguthaben', '25.000 USD'], ['Coins', '20 Coins, einmalig gutgeschrieben'], ['Einzel-Ranglistenpunkte', '0'],
          ['Doppel-Ranglistenpunkte', '0'], ['Reguläres Training', 'Nicht konfiguriert'], ['Team', 'Keines'],
          ['Hauptsponsor', 'Keiner'], ['Technische Sponsoren', 'Keine'], ['Nationalverband', 'Nicht beigetreten'],
          ['Tennisclub', 'Nicht beigetreten'], ['Kalenderverpflichtungen', 'Keine'], ['Ermüdung', '0'], ['Schärfe', '50'],
          ['Moral', '50'], ['Selbstvertrauen', '50'], ['Fokus', '50'],
          ['Startschläger', 'Rosignol F-200 Carbon, 100 % Zustand, ausgerüstet'],
          ['Startschuhe', 'Antta PG 7, 100 % Zustand, ausgerüstet'],
          ['ATP-Startkleidung', 'BlokUV Guardian Court, 100 % Zustand, ausgerüstet'],
          ['WTA-Startkleidung', 'BlokUV Solar Shield 8, 100 % Zustand, ausgerüstet'],
          ['Startzubehör', 'Keines'], ['Kostenloses Privatleben', 'Keine Startimmobilie'],
          ['Premium-Privatleben', 'Eine handelgesperrte Startwohnung in der Heimatstadt'],
        ],
      }}),
      s('Einmalige Initialisierung', { paragraphs: [
        'Die Karriereinitialisierung ist idempotent. Aktualisieren, erneutes Versuchen oder erneutes Öffnen des Spiels darf weder das Startguthaben von 25.000 USD noch die 20 Coins, die Startausrüstung oder eine Premium-Startwohnung duplizieren. Das Initialisierungsprotokoll speichert die angewendete Schemaversion.',
      ]}),
      s('Karriere neu starten oder Konto löschen', { paragraphs: [
        'Spieler & Konto enthält destruktive Aktionen zum Neustart und zur endgültigen Löschung. Verwende sie nur, wenn du den aktuellen Karrierestatus wirklich entfernen möchtest. Start-Coins sind gegen einfache Wiederholungen durch Aktualisieren oder erneute Versuche geschützt und nicht als wiederholbare Farming-Methode gedacht.',
      ], links: [{ label: 'Spieler & Konto öffnen', href: '/game/player-account' }]}),
    ],
  },
  {
    id: 'overview',
    title: 'Übersicht und täglicher Karriereablauf',
    summary: 'Wie du das Karriere-Kontrollzentrum liest und als Ausgangspunkt für jeden Spieltag nutzt.',
    sections: [
      s('Was die Übersicht zeigt', { bullets: [
        'Professionelles Profil und aktueller Ranglistenkontext.',
        'Nächstes Turnier und nächstes angesetztes Match, wenn verfügbar.',
        'Ergebnis des letzten Matches.',
        'Karrierefinanz-Guthaben sowie Saisoneinnahmen, Ausgaben und Nettofluss.',
        'Nächste Verpflichtung und heutige Turnieraktivität.',
        'Statistiken zur Saisonform.',
        'Bereitschaft und aktuelle Trainingsinformationen.',
        'Schnellzugriff auf Ausrüstung, Team und Clubsysteme.',
        'Aktuelle offizielle Ergebnisse der Tour und persönliche Karrierebenachrichtigungen.',
      ]}),
      s('Premium-Ranglistenschutz', { paragraphs: [
        'Premium-Konten können Ranglistenschutz erweitern und die nächsten fünf aktiven Ranglistenpunkt-Beiträge sehen, die verfallen werden. Das sind reine Planungsinformationen: Premium verhindert den Punkteverfall nicht und verändert weder Match- noch Ranglistenergebnisse.',
      ]}),
      s('Sinnvolle tägliche Routine', { steps: [
        'Lies zuerst die persönlichen Benachrichtigungen.',
        'Prüfe die nächste Verpflichtung und das nächste Match.',
        'Prüfe Bereitschaft, Ermüdung und Gesundheit, wenn Training oder Wettkampf bevorsteht.',
        'Prüfe Zeitplan oder Kalender, bevor du dich für ein weiteres Event anmeldest.',
        'Prüfe Finanzen, bevor du Teammitglieder verpflichtest, ein Camp buchst, Ausrüstung kaufst oder teure Reisen auswählst.',
        'Nutze Ranglisten und Statistiken für längerfristige Trendanalysen.',
      ], links: [{ label: 'Übersicht öffnen', href: '/game/overview' }]}),
    ],
  },
  {
    id: 'player-profile-account',
    title: 'Spielerprofil und Konto',
    summary: 'Identität, öffentliche Profile, Avatarverwaltung, Sicherheit und destruktive Kontoaktionen.',
    sections: [
      s('Deine öffentliche Spieleridentität', { paragraphs: [
        'Das professionelle Spielerprofil repräsentiert deine Karriere in Ranglisten, Turnieren und sozialen Ansichten. Andere Manager können einen Spieler aus den Ranglisten öffnen und sein öffentliches Profil ansehen.',
      ]}),
      s('Seite Spieler & Konto', { bullets: [
        'Zeigt den festen Spielernamen, Konto-E-Mail, Wettbewerbswelt und Land.',
        'Zeigt den aktuellen Avatar und den Ablauf zum Avatarwechsel.',
        'Passwortänderungen verwenden eine bestätigte E-Mail zum Zurücksetzen des Passworts.',
        'Enthält im Gefahrenbereich Aktionen zum Neustart und zur endgültigen Löschung von Spieler/Konto.',
      ]}),
      s('Avatarwechsel', { paragraphs: [
        'Der Avatarwechsel verwendet einen Prüfprozess. Der Spieler kann ein Referenzfoto und gewünschte Trikotfarben angeben. Referenzfotos sind temporär und werden innerhalb des konfigurierten Aufbewahrungszeitraums automatisch gelöscht. Der vorbereitete Avatar wird vor der Nutzung genehmigt oder abgelehnt.',
      ]}),
      s('Private Nachrichten aus Profilen', { paragraphs: [
        'Vom Profil eines anderen menschlichen Spielers kann eine private Unterhaltung im Manager-Postfach gestartet werden. Nur die beiden beteiligten Manager können diese Unterhaltung lesen.',
      ], links: [
        { label: 'Spieler & Konto öffnen', href: '/game/player-account' },
        { label: 'Ranglisten öffnen', href: '/game/rankings' },
      ]}),
    ],
  },
  {
    id: 'skills',
    title: 'Fähigkeiten und Startidentität des Spielers',
    summary: 'Technische Fähigkeiten, körperliche Fähigkeiten, Bereitschaftsattribute und wie Belag und Stil einen neuen Spieler prägen.',
    sections: [
      s('Technische Attribute', { table: {
        headers: ['Attribut', 'Bedeutung'],
        rows: [
          ['Aufschlag', 'Kraft, Platzierung und Zuverlässigkeit beim Service'], ['Vorhand', 'Primärer offensiver Grundschlag'],
          ['Rückhand', 'Qualität, Kontrolle und Stabilität'], ['Return', 'Aufschlag neutralisieren und angreifen'],
          ['Volley', 'Netzspiel und Abschluss'], ['Slice', 'Variation und Kontrolle niedriger Bälle'],
          ['Stoppball', 'Gefühl und Variation im kurzen Feld'], ['Lob', 'Höhe, Länge und Genauigkeit über den Gegner'],
          ['Smash', 'Timing, Kraft und Abschluss über Kopf'],
        ],
      }}),
      s('Körperliche Attribute', { table: {
        headers: ['Attribut', 'Bedeutung'],
        rows: [['Fitness', 'Allgemeine athletische Bereitschaft'], ['Ausdauer', 'Qualität in langen Matches aufrechterhalten'], ['Erholung', 'Erholung zwischen Matches und Einheiten'], ['Bewegung', 'Platzabdeckung, Geschwindigkeit und Balance']],
      }}),
      s('Bereitschaft und Mentalität', { table: {
        headers: ['Attribut', 'Bedeutung'],
        rows: [['Moral', 'Motivation und emotionaler Zustand'], ['Selbstvertrauen', 'Vertrauen, geprägt durch Form und Ergebnisse'], ['Schärfe', 'Wettkampfrhythmus und Matchbereitschaft'], ['Fokus', 'Konzentration und mentale Stabilität'], ['Ermüdung', 'Angesammelte Müdigkeit; niedriger ist besser']],
      }}),
      s('Startprofile nach Belag', { paragraphs: [
        'Hartplatz, Sand und Rasen starten mit unterschiedlichen technischen Verteilungen, aber alle drei Basisprofile ergeben exakt 450 technische Punkte. Die Belagswahl schafft Identität statt eines kostenlosen Gesamtstärkevorteils.',
      ], table: {
        headers: ['Fähigkeit', 'Hartplatz', 'Sand', 'Rasen'],
        rows: [
          ['Aufschlag', '56', '48', '62'], ['Vorhand', '58', '59', '52'], ['Rückhand', '55', '57', '48'],
          ['Return', '57', '60', '46'], ['Volley', '46', '42', '57'], ['Slice', '45', '48', '54'],
          ['Stoppball', '42', '47', '38'], ['Lob', '43', '51', '38'], ['Smash', '48', '38', '55'],
          ['Basissumme', '450', '450', '450'],
        ],
      }}),
      s('Spielhand und Matchup-Geometrie', { paragraphs: [
        'Rechts- und Linkshänder verwenden dasselbe Budget für die Startstärke. Die Spielhand macht Vorhand oder Rückhand nicht automatisch stärker oder schwächer.',
        'Ihr Wert zeigt sich im Match: Aufschlagwinkel, Crosscourt-Muster und die natürliche Beziehung zwischen Vorhand eines Spielers und Rückhand des Gegners verändern sich bei gleich- und gegensinnigen Spielhand-Matchups. Die Spielhand ist öffentliche Gegnerinformation und sollte bei der Taktikwahl berücksichtigt werden.',
      ]}),
      s('Umverteilung durch Spielstil', { bullets: [
        'Aggressiver Grundlinienspieler verschiebt Punkte in Richtung Aufschlag und offensive Grundschläge.',
        'Defensiver Grundlinienspieler verschiebt Punkte in Richtung Return, Rückhandstabilität und Druckabsorption.',
        'Serve & Volley verschiebt Punkte in Richtung Aufschlag, Volley, Slice und Vorwärtsbewegung.',
        'All-Court verändert die Verteilung nicht zusätzlich; der Belag prägt den größten Teil der Identität.',
      ]}),
      s('Variation und Entwicklungsgrenze', { paragraphs: [
        'Neue menschliche Spieler erhalten eine kleine deterministische individuelle Variation und werden auf ungefähr 440–455 technische Startpunkte normalisiert. Hohe Fähigkeiten entwickeln sich schrittweise langsamer als frühe Karrierefähigkeiten.',
      ], links: [{ label: 'Fähigkeiten öffnen', href: '/game/skills' }]}),
    ],
  },
  {
    id: 'regular-training',
    title: 'Reguläres Training',
    summary: 'Wie das wöchentliche reguläre Training funktioniert, was es blockiert und wie Entwicklung verteilt wird.',
    sections: [
      s('Regel für Tage zu Hause', { paragraphs: [
        'Reguläres Training ist nur verfügbar, wenn der tägliche Kalenderstatus Zu Hause ist und der Spieler medizinisch freigegeben ist. Turnier-, Reise-, Trainingscamp- und medizinisch gesperrte Tage belegen das Datum und reguläres Training findet nicht statt.',
      ]}),
      s('Wochenplaner', { paragraphs: [
        'Mit dem Planer kannst du unterschiedliche Entscheidungen für Tage zu Hause speichern. Die automatische tägliche Engine verarbeitet den gespeicherten Plan, wenn das Spiel dieses Datum erreicht. Kalenderbelegung hat immer Vorrang vor einem gespeicherten Trainingsplan.',
      ]}),
      s('Fokusverteilung', { paragraphs: [
        'Fokussiertes Training gibt dem ausgewählten Attribut den Hauptanteil der Entwicklung und verteilt den Rest innerhalb der relevanten Kategorie. Das aktuelle Modell des regulären Trainings verwendet 85 % für den gewählten Fokus und 15 % für die restliche Kategorie.',
      ]}),
      s('Entwicklungskurve', { table: {
        headers: ['Aktueller Fähigkeitsbereich', 'Entwicklungsmultiplikator'],
        rows: [['1–59', '100 %'], ['60–69', '90 %'], ['70–79', '75 %'], ['80–89', '55 %'], ['90–94', '35 %'], ['95–99', '20 %']],
      }}),
      s('Erholung und Ergebnisse', { bullets: [
        'Ruhetag priorisiert Erholung statt dauerhafter Entwicklung.',
        'Trainingseinheiten speichern Entwicklungsgewinne, Level-Ups und Zustandswerte vor/nach der Einheit.',
        'Eine Trainingscamp-Buchung wird auch im regulären Training angezeigt; Camp- und Camp-Reisetage überschreiben den Wochenplan automatisch.',
      ], links: [{ label: 'Training öffnen', href: '/game/training' }]}),
    ],
  },
  {
    id: 'training-camps',
    title: 'Trainingscamps',
    summary: 'Buchung, Kosten, Entwicklungsvorteile, Stornierung, Reiseübergänge und Abschlussregeln.',
    sections: [
      s('Was ein Trainingscamp bewirkt', { paragraphs: [
        'Ein Trainingscamp ist ein bezahlter, ortsgebundener Entwicklungsblock. Camp-Entwicklung ist stärker als gewöhnliches Training, während längere Camps abnehmende Erträge verwenden, damit zusätzliche Wochen nicht unbegrenzt skalieren.',
      ]}),
      s('Preisstruktur des Programms', { table: {
        headers: ['Camp-Typ', 'Standard', 'Fortgeschritten', 'Elite'],
        rows: [['Erholung & Mentalität', '1.200 $/Woche', '1.800 $/Woche', '2.700 $/Woche'], ['Körperlich', '1.400 $/Woche', '2.100 $/Woche', '3.200 $/Woche'], ['Tennisfähigkeiten', '1.500 $/Woche', '2.300 $/Woche', '3.400 $/Woche']],
      }}),
      s('Qualität und Dauer', { bullets: [
        'Entwicklungsmultiplikatoren nach Qualität: Standard 1,00×, Fortgeschritten 1,15× und Elite 1,30×.',
        'Camps können ein bis vier Wochen dauern.',
        'Tennis-/Körperentwicklung verwendet über die Wochen 1–4 Multiplikatoren von 100 %, 95 %, 85 % und 75 %.',
        'Eine normale Camp-Woche besteht aus sechs Entwicklungstagen und einem Erholungstag.',
      ]}),
      s('Unterkunft', { table: {
        headers: ['Unterkunft', 'Basispreis pro Woche', 'Zweck'],
        rows: [['Budget 2 Sterne', '350 $', 'Niedrigster Preis'], ['Standard 3 Sterne', '560 $', 'Ausgewogene Standardwahl'], ['Komfort 4 Sterne', '840 $', 'Bessere Erholung/Komfort'], ['Premium 5 Sterne', '1.260 $', 'Höchster Komfort/Erholung']],
      }}),
      s('Kalkulation und Zahlung', { paragraphs: [
        'Die Kalkulation kombiniert Trainingsgebühr, an das Ziel angepasste Unterkunft, Spielerreise und Kosten ausgewählter mitreisender Teammitglieder. Das verfügbare Karriereguthaben wird vor der Buchung angezeigt. Bei unzureichenden Mitteln wird die Buchung abgelehnt, bevor eine Buchung oder Finanztransaktion gespeichert wird.',
      ]}),
      s('Konflikt- und Duplikatschutz', { bullets: [
        'Überlappende Trainingscamps sind blockiert.',
        'Turnieranmeldungen und angenommene Teilnahmen, die den Camp-Zeitraum überlappen, sind blockiert.',
        'Fest gebuchte Kalenderaktivitäten und medizinische Einschränkungen werden geprüft.',
        'Doppelte Buchungsversuche durch Doppelklick werden serialisiert.',
        'Buchung, Finanzen und Kalenderbelegung sind transaktional.',
      ]}),
      s('Stornierung', { paragraphs: [
        'Ein zukünftiges Camp, das noch nicht begonnen hat, kann mit 100 % Rückerstattung auf das Karriereguthaben storniert werden. Nach Camp-Beginn ist eine normale Stornierung vor Beginn nicht mehr möglich.',
      ]}),
      s('Camp-Reise und verkürzte Camps', { paragraphs: [
        'Übergänge vom Turnier zum Camp und vom Camp zum Turnier führen über die Heimatstadt des Spielers. Wenn nur ein Übergangstag verfügbar ist, können die erste und zweite Reisehälfte am selben Datum stattfinden. Wenn das vorherige Turnier den normalen Reisetag vor dem Camp belegt, wird der erste geplante Camp-Tag zum geteilten Reisetag, das ursprüngliche Camp-Enddatum bleibt bestehen und ein Entwicklungstag geht verloren.',
      ]}),
      s('Reisebedingtes No-Show', { paragraphs: [
        'Wenn der Spieler nach einem Camp einen geteilten Reisetag benötigt und das nächste Turnier ein Match ansetzt, bevor der Reiseplan ihn rechtzeitig bereit macht, verpasst der Spieler das Match wegen Reise-No-Show und der Gegner kommt weiter. Es entsteht kein Ausrüstungsverschleiß, weil kein Match gespielt wurde.',
      ]}),
      s('Abschluss und Überwachung', { paragraphs: [
        'Ergebnisse eines Camp-Tages sind idempotent und Entwicklung kann nicht doppelt angewendet werden. Ein Camp wechselt von Gebucht → Aktiv → Abgeschlossen. Gesundheitliche Unterbrechungen am letzten Datum lassen das Camp nicht mehr hängen. Camp-Lebenszyklus und Übergangsreisen werden im Systemzustand überwacht.',
      ], links: [{ label: 'Trainingscamps öffnen', href: '/game/training' }]}),
    ],
  },
  {
    id: 'readiness-recovery',
    title: 'Ermüdung, Schärfe, Form und Erholung',
    summary: 'Wie kurzfristiger Zustand mit Training, Reisen und Matchleistung zusammenspielt.',
    sections: [
      s('Ermüdung', { paragraphs: ['Ermüdung ist angesammelte Müdigkeit und die wichtigste Zustandszahl, bei der niedriger besser ist. Trainingsbelastung, Matches und Reisen können Ermüdung hinzufügen; Ruhe, Erholung, Unterkunftsqualität und relevante Team-Effekte können sie reduzieren oder abschwächen.']}),
      s('Schärfe', { paragraphs: ['Schärfe steht für Wettkampfrhythmus und Matchbereitschaft. Sie ist keine dauerhafte Fähigkeit: Auch ein sehr starker Spieler kann schlecht vorbereitet sein, wenn die Schärfe niedrig oder die Ermüdung hoch ist.']}),
      s('Moral, Selbstvertrauen und Fokus', { bullets: [
        'Moral ist die aktuelle Motivation bzw. der emotionale Zustand.', 'Selbstvertrauen wird durch Form und Ergebnisse geprägt.', 'Fokus steht für Konzentration und mentale Stabilität.',
      ]}),
      s('Form im Vergleich zu dauerhaften Fähigkeiten', { paragraphs: ['Fähigkeiten sind langfristige Attribute. Bereitschaftswerte sind kurzfristiger Zustand. Saisonform-Statistiken sind ergebnisbasierte Indikatoren. Keines davon ersetzt die anderen.']}),
      s('Praktische Erholungsplanung', { steps: [
        'Prüfe Gesundheit und Ermüdung vor hartem Training.', 'Lass Reisetage echte Reisetage bleiben.', 'Nutze Ruhetag oder Erholungsoptionen bei hoher Ermüdung.', 'Bei eng aufeinanderfolgenden Events können Reiseklasse, Hotel und Team genauso wichtig sein wie ein zusätzlicher Trainingstag.',
      ], links: [{ label: 'Training öffnen', href: '/game/training' }, { label: 'Gesundheit öffnen', href: '/game/injuries' }]}),
    ],
  },
  {
    id: 'health',
    title: 'Verletzungen, Erkrankungen und Verfügbarkeit',
    summary: 'Gesundheitszentrum, Risikotreiber, medizinische Einschränkungen und Rückkehrlogik.',
    sections: [
      s('Gesundheitszentrum', { paragraphs: ['Verletzungen & Gesundheit zeigt aktuellen medizinischen Status, Verletzungsrisiko, tägliches Krankheitsrisiko, Behandlungsstatus, Rückkehr zum Training, Rückkehr zu Turnieren, erwartete vollständige Genesung und aktuelle Leistungseinbuße.']}),
      s('Treiber des Verletzungsrisikos', { paragraphs: ['Das Verletzungsrisiko ist aktivitätsspezifisch und steigt durch Kombinationen aus Ermüdung, Belastung, Matchdauer, Hitze und reduzierter körperlicher Verfassung. Die Seite zeigt aktuelle Risikotreiber, statt Verletzungen vollständig undurchsichtig zu machen.']}),
      s('Krankheitsrisiko', { paragraphs: ['Krankheit wird getrennt von körperlicher Verletzung berechnet und kann durch Ermüdung, Erholungszustand, Reiseexposition und aktuellen Genesungsstatus beeinflusst werden.']}),
      s('Medizinische Verfügbarkeit', { bullets: [
        'Rückkehr zum Training und Rückkehr zu Turnieren können an unterschiedlichen Daten möglich sein.',
        'Die Kalenderverarbeitung respektiert medizinische Sperren.',
        'Trainingscamps lehnen Buchungszeiträume ab, die bekannte gesundheitliche Einschränkungen überlappen.',
        'Effekte des medizinischen Teams werden auf der Gesundheitsseite angezeigt, wenn relevant.',
      ]}),
      s('Gesundheitsakte der Karriere', { paragraphs: ['Ausgeheilte Verletzungen und Erkrankungen bleiben in der Gesundheitsakte der Karriere erhalten. Die Seite enthält außerdem Referenzinformationen zu unterstützten Verletzungen, Krankheitszeiträumen und Behandlungs-/Rehabilitationsstufen.'], links: [{ label: 'Verletzungen & Gesundheit öffnen', href: '/game/injuries' }]}),
    ],
  },
  {
    id: 'staff',
    title: 'Team und Teammarkt',
    summary: 'Einstellung, Verträge, Effekte, Gehälter, Verhandlungen und Vertragsauflösung.',
    sections: [
      s('Verfügbare Teamrollen', { table: {
        headers: ['Rolle', 'Hauptbeitrag'],
        rows: [
          ['Cheftrainer', 'Technische Entwicklung, Taktik und Matchvorbereitung'],
          ['Konditionstrainer', 'Körperliche Entwicklung, Kondition und Belastungssteuerung'],
          ['Physiotherapeut', 'Erholung von Ermüdung, Verletzungsprävention und Rehabilitation'],
          ['Sportpsychologe', 'Moral, Selbstvertrauen, Fokus und Umgang mit Druck'],
          ['Leistungsanalyst', 'Gegner-Scoutingbereiche, Sicherheit der Vorbereitung, Beobachtungen zur Spielhand und taktische Empfehlungen'],
          ['Karrieremanager', 'Sponsoring, kommerzielle Vertretung und Karrieremanagement'],
        ],
      }}),
      s('Rollen- und Qualitätsregeln', { paragraphs: [
        'Pro Rolle kann eine aktive Person eingesetzt werden. Eine neue Karriere startet ohne Team. Kandidaten werden in die Qualitätsstufen In Entwicklung, Professionell, Fortgeschritten, Elite und Weltklasse eingeteilt.',
      ]}),
      s('Verhandlungsablauf', { steps: [
        'Filtere den Teammarkt nach Rolle, Qualität, Land und Gehalt.',
        'Öffne einen Kandidaten und wähle Vertragsdauer und Gehaltsangebot.',
        'Prüfe Annahmechance, Handgeld und gesamte Vertragsverpflichtung.',
        'Ein angenommenes Angebot benötigt weiterhin eine endgültige Bestätigung, bevor das Teammitglied eingestellt wird.',
        'Das Karriereguthaben muss das Handgeld decken, und manche Kandidaten verhandeln bei zu geringem sportlichem Ruf nicht.',
      ]}),
      s('Vertragsauflösung und Reisen', { paragraphs: [
        'Aktive Verträge zeigen unbezahlte Wochen, Wert des Restgehalts, Abfindungssatz und Auflösungsgebühr. Ausgewählte Teammitglieder können zu Turnieren oder Trainingscamps mitreisen; mitreisende Mitglieder erhöhen die Kosten, und Effekte, die Anwesenheit erfordern, gelten nur, wenn diese Person mitreist.',
        'Ein Leistungsanalyst ist eine Informationsrolle und kein versteckter direkter Stärkebonus. Bessere Analysten verengen die geschätzten Fähigkeitsbereiche. Sobald der nächste Gegner bekannt ist, entwickelt sich die Vorbereitung mit der Spielzeit von schneller über teilweise und normal bis zur vollständigen Analyse, die nach 24 Spielstunden erreicht wird.',
      ], links: [{ label: 'Team öffnen', href: '/game/staff' }]}),
    ],
  },
  {
    id: 'calendar',
    title: 'Kalender und Wettkampfplanung',
    summary: 'Wie Spielerkalender und Turnierkalender zusammenspielen.',
    sections: [
      s('Zwei Kalenderansichten', { paragraphs: ['Kalender kombiniert den synchronisierten Aktivitätskalender des Spielers mit dem umfassenderen Turnierkalender. Die Spieleransicht zeigt, welches System ein Datum belegt; die Turnieransicht dient zum Durchsuchen von Wettkampfmöglichkeiten.']}),
      s('Aktivitätstypen im Spielerkalender', { bullets: ['Turnier', 'Reise', 'Trainingscamp', 'Nationalteam', 'Gesundheit / Erholung', 'Zu Hause']}),
      s('Kalenderbelegung', { paragraphs: ['Ein Datum kann nicht als Trainingszeit zu Hause behandelt werden, wenn ein anderes System es belegt. Turnier-, Reise-, Camp-, Nationalteam- oder medizinische Aktivität hat Vorrang vor gespeichertem regulärem Training.']}),
      s('Turniere durchsuchen', { paragraphs: ['Turnierkarten zeigen Datum, Ort, Kategorie, Belag, Informationen zu Feld/Punkten und Anmeldestatus. Sponsorziele können außerdem kommerziell wichtige Events markieren.']}),
      s('Automatische Reise', { paragraphs: ['Angenommene Verpflichtungen und gespeicherte Vorbereitung speisen die gemeinsame Reise-Engine. Reisetage erscheinen anschließend im Spielerkalender. Übergänge von Trainingscamps können bei engem Zeitplan zwei halbtägige Reiseabschnitte an einem Datum erzeugen.'], links: [{ label: 'Kalender öffnen', href: '/game/calendar' }]}),
    ],
  },
]
