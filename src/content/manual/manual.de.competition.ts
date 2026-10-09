import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCompetitionChaptersDe: ManualChapter[] = [
  {
    id: 'tournament-selection',
    title: 'Turnierauswahl und Anmeldungen',
    summary: 'Wie du Events auswählst, dich anmeldest und den Unterschied zwischen Anmeldung und angenommener Teilnahme verstehst.',
    sections: [
      s('Vor der Anmeldung', { steps: [
        'Prüfe die Turnierkategorie und das erwartete Wettbewerbsniveau.',
        'Vergleiche den Belag mit den Fähigkeiten und dem aktuellen Zustand deines Spielers.',
        'Prüfe den vollständigen Turnierzeitraum, nicht nur das Startdatum.',
        'Prüfe bestehende Turniere, Trainingscamps, Nationalteam-Aktivität und Reisen.',
        'Berücksichtige Reise- und Hotelkosten, die bei einer Annahme entstehen.',
      ]}),
      s('Lebenszyklus einer Anmeldung', { paragraphs: [
        'Eine Turnieranmeldung ist eine Anfrage auf Teilnahme, noch kein angenommener Turnierplatz. Der Teilnahmeprozess verarbeitet Anmeldungen anhand von Berechtigung, Rangliste und Feldkapazität. Der Zeitplan zeigt Anmeldeverlauf und angenommene Ergebnisse, sodass zwischen Angemeldet, Hauptfeld, Qualifikation und abgeschlossenen Teilnahmeergebnissen unterschieden werden kann.',
      ]}),
      s('Qualifikation und Hauptfeld', { paragraphs: [
        'Abhängig von Kategorie und Feldverteilung kann ein Spieler direkt ins Hauptfeld oder in die Qualifikation gesetzt werden. Qualifikanten, die weiterkommen, können die konfigurierten Qualifikantenplätze im Hauptfeld erhalten.',
      ]}),
      s('Kalenderkonflikte', { paragraphs: [
        'Das Spiel verhindert unterstützte unmögliche Überschneidungen. Trainingscamps können beispielsweise nicht über eine bestehende Turnieranmeldung oder angenommene Turnierteilnahme gebucht werden. Reise- und Gesundheitssysteme beeinflussen ebenfalls die Verfügbarkeit.',
      ]}),
      s('Benachrichtigungen zur Teilnahme', { paragraphs: [
        'Wichtige Ereignisse zu Anmeldung, angenommener Teilnahme, Auslosung und Turniervorbereitung können Karrierebenachrichtigungen mit direkter Aktion zum relevanten Turnier oder zur Zeitplanseite erzeugen.',
      ], links: [
        { label: 'Turnierkalender öffnen', href: '/game/calendar' },
        { label: 'Zeitplan öffnen', href: '/game/schedule' },
      ]}),
    ],
  },
  {
    id: 'tournament-categories',
    title: 'Turnierkategorien und Teilnahmeregeln',
    summary: 'Die aktuelle Einzel-Wettbewerbsleiter, Feldgrößen und Ranglistenpunkte für Sieger.',
    sections: [
      s('Aktuelle Kategorien', { table: {
        headers: ['Kategorie', 'Siegerpunkte', 'Hauptfeld', 'Max. Qualifikation', 'Qualifikantenplätze', 'Wochen'],
        rows: [
          ['Grand Slam 2000', '2000', '128', '128', '16', '2'],
          ['Masters 1000', '1000', '64', '32', '8', '2'],
          ['Tour 500', '500', '32', '16', '4', '1'],
          ['Tour 250', '250', '32', '16', '4', '1'],
          ['Challenger 125', '125', '32', '24', '6', '1'],
          ['Challenger 100', '100', '32', '24', '6', '1'],
          ['Challenger 75', '75', '32', '24', '6', '1'],
          ['Challenger 50', '50', '32', '24', '6', '1'],
          ['Futures 25', '25', '32', '32', '8', '1'],
          ['Futures 15', '15', '32', '32', '8', '1'],
        ],
      }}),
      s('Terminregeln', { bullets: [
        'Standard-Profi-Kategorien verwenden ein Match pro Spieler und Spieltag.',
        'Die Qualifikation findet in derselben Turnierstadt statt.',
        'Grand Slams und Masters erstrecken sich über zwei Wettkampfwochen; niedrigere Kategorien normalerweise über eine.',
        'Grand Slams können bis zu drei Qualifikationsrunden verwenden; die anderen aufgeführten Kategorien bis zu zwei.',
      ]}),
      s('Das richtige Niveau wählen', { paragraphs: [
        'Höhere Kategorien bieten größere Chancen auf Ranglistenpunkte, aber stärkere Felder und schwierigeren Zugang. Futures- und Challenger-Events sind wichtige Entwicklungswege in der frühen Karriere und keine bloßen Füllturniere.',
      ]}),
      s('Nationalteam-Kategorie', { paragraphs: [
        'Nationalteam-Wettbewerbe werden vom Nationalverbands-System geregelt und sollten nicht als normale individuelle Tour-Ranglistenkategorie verstanden werden.',
      ]}),
    ],
  },
  {
    id: 'schedule-travel',
    title: 'Zeitplan, Verpflichtungen und Reisen',
    summary: 'Die Zeitplanseite, Vorbereitung, Reiseklassen, Hotels und automatische Reiseplanung.',
    sections: [
      s('Zeitplanseite', { paragraphs: [
        'Der Zeitplan zeigt das nächste Turnier, spätere Turnierverpflichtungen, den Anmeldeverlauf und Vorbereitungskontrollen. In der Liste erscheinen nur Wettbewerbe, die zum aktuellen Spieler gehören.',
      ]}),
      s('Automatische Reiseplanung', { paragraphs: [
        'Die gemeinsame Reise-Engine erstellt geplante Reisen aus Turnier-/Camp-Verpflichtungen, Geografie und Matchzeiten. Sie speichert Start und Ziel, Abreise-/Ankunftstag, Reisekosten, erwartete Ermüdung und Zeitpunkt der Einsatzbereitschaft.',
      ]}),
      s('Reiseklassen', { table: {
        headers: ['Klasse', 'Gameplay-Zweck'],
        rows: [['Economy', 'Standard-Reiseermüdung'], ['Premium Economy', 'Etwa 15 % weniger Reiseermüdung'], ['Business', 'Etwa 35 % weniger Reiseermüdung'], ['First Class', 'Etwa 50 % weniger Reiseermüdung']],
      }}),
      s('Turnierhotels', { table: {
        headers: ['Hotel', 'Positionierung'],
        rows: [['Budget Hotel 2 Sterne', 'Niedrigste Kosten'], ['Standard Hotel 3 Sterne', 'Ausgewogene Option'], ['Premium Hotel 4 Sterne', 'Mehr Komfort'], ['Luxury Hotel 5 Sterne', 'Maximaler Komfort']],
      }}),
      s('Reisegruppe', { paragraphs: [
        'Aktive Teammitglieder können für die Reise ausgewählt werden. Sie erhöhen Reise- und Unterkunftskosten, aber Anwesenheitseffekte gelten nur, wenn das Teammitglied tatsächlich mit dem Spieler reist.',
      ]}),
      s('Enge Reiseplanung und No-Show-Risiko', { paragraphs: [
        'Reisezeiten sind nicht nur kosmetisch. Wenn ein Reiseplan den Spieler nicht rechtzeitig vor einem angesetzten Match einsatzbereit macht, kann er das Match verpassen. Trainingscamp-Übergänge verwenden spezielle über die Heimatstadt geführte Reisehälften, wenn die Termine extrem eng sind.',
      ], links: [{ label: 'Zeitplan öffnen', href: '/game/schedule' }]}),
    ],
  },
  {
    id: 'tournament-preparation',
    title: 'Turniervorbereitung',
    summary: 'Reise, Hotel, Team, Ausrüstung und taktische Vorbereitung vor einem Wettkampf.',
    sections: [
      s('Ablauf der Vorbereitung', { steps: [
        'Öffne Zeitplan und wähle Turnier vorbereiten für das nächste Event.',
        'Wähle Reiseklasse und Hotelkategorie.',
        'Wähle, welche unter Vertrag stehenden Teammitglieder mitreisen.',
        'Prüfe die Reisekalkulation und den Kompromiss zwischen Kosten und Ermüdung.',
        'Speichere die Turnier-Standardtaktik oder behalte die aktuelle Vorgabe. Taktiken umfassen Spielansatz, Ballwechsellänge, Aufschlagstrategie und Platzierung, Return-Strategie und Position, Platzposition, Gegnerziel und Risiko.',
        'Speichere die Vorbereitung; die gemeinsame Reise-Engine berechnet den geplanten Reiseablauf neu.',
      ]}),
      s('Turnier-Standardtaktik', { paragraphs: [
        'Die Turnier-Standardtaktik wird für Matches dieses Turniers verwendet, sofern ein konkretes kommendes Match keine eigene Überschreibung hat. Dadurch musst du nicht für jede Runde einen komplett neuen taktischen Plan erstellen.',
      ]}),
      s('Gegneranalyse und matchspezifische Überschreibungen', { paragraphs: [
        'Wenn ein Gegner bekannt ist, zeigt die Matchseite immer öffentliche Identität wie Spielhand, Spielstil und bevorzugten Belag. Wenn ein Leistungsanalyst beschäftigt ist, ergänzt die Gegneranalyse ungefähre Fähigkeitsbereiche, Berichtssicherheit, beobachtete Tendenzen und taktische Hinweise.',
        'Die Matchdetails können einen gegnerspezifischen Plan speichern. Beim Löschen der Überschreibung kehrt das Match zur Turnier-Standardtaktik zurück. Ein taktischer Plan wird gegen beide Spieler bewertet: Das Ausnutzen einer echten Schwäche kann helfen, während ein Konter, der nicht zu den eigenen Fähigkeiten passt, wirkungslos oder schädlich sein kann.',
      ]}),
      s('Ausrüstungsbereitschaft', { paragraphs: [
        'Turniervorbereitung sollte zusammen mit dem Ausrüstungszentrum geprüft werden. Der maßgebliche Ausrüstungseffekt im Match verwendet die aktuell ausgerüsteten Gegenstände, ihren Zustand und relevante Übereinstimmung mit dem Platzbelag.',
      ]}),
      s('Vorbereitung umgeht keine Reisephysik', { paragraphs: [
        'Eine bessere Reiseklasse kann die Ermüdungsbelastung reduzieren, teleportiert den Spieler aber nicht. Geografie und Matchzeit bleiben relevant, und unmögliche Einsatzbereitschaft kann zu einem Reise-No-Show führen.',
      ], links: [{ label: 'Zeitplan öffnen', href: '/game/schedule' }, { label: 'Ausrüstung öffnen', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'matches',
    title: 'Matchtaktik und Turnierverlauf',
    summary: 'Auslosungen, Matchfenster, taktische Einstellungen, Ergebnisse und Fortschritt durch ein Turnier.',
    sections: [
      s('Auslosung und Turnierbaum', { paragraphs: [
        'Nach der Veröffentlichung zeigt die Turnierseite den K.-o.-Baum, den Rundenfortschritt, Freilose und den Weg des Spielers durch das Event. Matchzustände unterscheiden Geplant, Live, Beendet und Abgesagt.',
      ]}),
      s('Matchdetails', { paragraphs: [
        'Matchdetails zeigen Spieler, Turnierkontext, Termin, Ergebnis und – wenn erfasst – Matchstatistiken wie Asse, Doppelfehler, Quote des ersten Aufschlags, verwandelte Breakbälle, Winner, Unforced Errors und gewonnene Gesamtpunkte.',
      ]}),
      s('Taktische Einstellungen', { paragraphs: [
        'Taktische Einstellungen beeinflussen Angriffsabsicht, Winner-Versuche, Aufschlag-/Returndruck, Aufschlagplatzierung (Automatisch, Außen, Körper oder T), Return-Position (Normal, Näher oder Tiefer), Ballwechsellänge, Platzposition, Gegnerziel und Fehlerrisiko.',
        'Gegnerziele können Vorhand, Rückhand, Bewegung, Ausdauer oder zweiten Aufschlag fokussieren. Die Spielhand verändert die Geometrie dieser Muster, ist aber kein angeborener Stärkebonus. Aggressivere Entscheidungen können Vorteile schaffen, erhöhen aber taktisches und körperliches Risiko.',
      ]}),
      s('Fortschritt nach Ergebnissen', { paragraphs: [
        'Ein abgeschlossenes Match speichert einen Sieger und lässt den Turnierbaum fortschreiten. Turnierergebnisse fließen anschließend in Ranglistenbeiträge, Statistiken, Preisgeld und relevante Sponsor-/Zielsysteme ein.',
      ]}),
      s('Nicht gespielte Ergebnisse', { paragraphs: [
        'Ein Match kann aus unterstützten gesundheitlichen oder Reisegründen ohne normales Spiel abgeschlossen werden. Ein Reise-No-Show tritt ein, wenn der Reiseplan den Spieler zum Matchzeitpunkt unmöglich einsatzbereit macht. Ausrüstungszustand wird nicht reduziert, wenn tatsächlich kein Match gespielt wurde.',
      ]}),
      s('Head-to-Head und Weg zum Match', { paragraphs: [
        'Wenn Historie existiert, können Matchdetails frühere Begegnungen, Ergebnisse vorheriger Runden und den Weg des Spielers zur aktuellen Runde zeigen. Bei einer ersten Begegnung gibt es naturgemäß keine H2H-Historie.',
      ]}),
    ],
  },
  {
    id: 'singles-rankings',
    title: 'ATP- und WTA-Einzelranglisten',
    summary: 'Wie die Weltranglistenseite aufgebaut ist und Rangänderungen dargestellt werden.',
    sections: [
      s('Getrennte Welten', { paragraphs: [
        'ATP- und WTA-Einzelranglisten sind getrennt. Ein Spieler erscheint nur in seiner richtigen Tourwelt. Ranglisten sind paginiert und platzierte menschliche/AI-Spieler können als Spielerprofile geöffnet werden.',
      ]}),
      s('Ranglistenspalten', { bullets: ['Rang', 'Rangänderung', 'Spieler', 'Land', 'Punkte', 'Punkteänderung'] }),
      s('Neue Karrieren', { paragraphs: [
        'Eine neue Karriere beginnt mit 0 offiziellen Einzel-Ranglistenpunkten, erhält aber sofort einen Ranglistendatensatz. Turnierergebnisse erzeugen aktive Ranglistenbeiträge.',
      ]}),
      s('Warum sich der Rang ohne neues Ergebnis ändern kann', { paragraphs: [
        'Der Rang ist relativ zu allen anderen. Ein Spieler kann sich bewegen, weil ein anderer Spieler Punkte gewinnt, ein alter Beitrag verfällt oder ein früherer Ranglisten-Snapshot mit dem neu veröffentlichten verglichen wird.',
      ]}),
      s('Premium-Ranglistenschutz', { paragraphs: [
        'Premium zeigt bis zu fünf nächste aktive Einzelbeiträge, deren Punkte verfallen werden. Das ist nur eine Planungsansicht und bewahrt die Punkte nicht.',
      ], links: [{ label: 'Ranglisten öffnen', href: '/game/rankings' }]}),
    ],
  },
  {
    id: 'doubles',
    title: 'Doppel und Doppelranglisten',
    summary: 'Die separate Doppeldisziplin, partnerschaftsbasierte Turnierteilnahme und Ranglistenverfolgung.',
    sections: [
      s('Separate Disziplin', { paragraphs: [
        'Einzel und Doppel werden getrennt erfasst. Doppel besitzt eigene Anmeldungen, Turnierergebnisse, Ranglistenpunkte, Rang und verfallende Beiträge. Eine Einzelrangliste wird nicht zur Doppelrangliste.',
      ]}),
      s('Partnerschaft', { paragraphs: [
        'Doppelteilnahme benötigt einen Partner, wenn der Anmeldeablauf dies verlangt. Der Zeitplan zeigt Doppelanmeldungen und Partnerschaftsstatus getrennt von Einzelanmeldungen.',
      ]}),
      s('Doppelrangliste', { paragraphs: [
        'Auf der Ranglistenseite kann zur Doppel-Weltrangliste gewechselt werden. Einzelne Spieler erhalten Doppel-Ranglistenbeiträge aus Ergebnissen ihrer Partnerschaften.',
      ]}),
      s('Doppelbenachrichtigungen', { paragraphs: [
        'Auslosung, Matchvorbereitung, Ergebnis und Partnerschaftsfrist können in Benachrichtigungen mit direkten Links zur relevanten Doppel-Turnieransicht erscheinen.',
      ], links: [{ label: 'Ranglisten öffnen', href: '/game/rankings' }, { label: 'Zeitplan öffnen', href: '/game/schedule' }]}),
    ],
  },
  {
    id: 'ranking-points',
    title: 'Ranglistenpunkte, Beiträge und Verfall',
    summary: 'Wie Turnierergebnisse zu aktiven Ranglistenbeiträgen werden und später die Summe verlassen.',
    sections: [
      s('Beitragsmodell', { paragraphs: [
        'Ranglistenpunkte werden als Ergebnisbeiträge statt als unerklärte dauerhafte Zahl gespeichert. Die aktuelle Ranglistensumme ist die Summe aktiver Beiträge für Spieler und Tour.',
      ]}),
      s('Punktelimit nach Kategorie', { paragraphs: [
        'Die Turnierkategorie bestimmt die maximale Siegerpunkteskala: 15/25 bei Futures, 50–125 auf Challenger-Niveau, 250/500 auf Tour-Niveau, 1000 bei Masters und 2000 bei Grand Slams. Werte früherer Runden folgen den Ergebnisregeln der Kategorie.',
      ]}),
      s('Verfall und Verteidigungszyklen', { paragraphs: [
        'Jeder aktive Beitrag speichert den Vergabe-Spieltag und den Verfalls-Spieltag. Wenn er verfällt oder im Ranglisten-Verteidigungszyklus ersetzt wird, wird er deaktiviert und die Ranglistensumme neu berechnet.',
      ]}),
      s('Punkte verteidigen', { paragraphs: [
        'Punkte verteidigen bedeutet, Wert zu ersetzen, der die aktive Summe verlassen wird. Dass eine zukünftige Turnierausgabe geplant ist, garantiert keinen Ersatz; der Spieler benötigt weiterhin ein entsprechendes Ergebnis.',
      ]}),
      s('Premium-Planung', { paragraphs: [
        'Premium zeigt die nächsten fünf verfallenden Einzel- oder Doppelbeiträge mit Turnier, Quellergebnis, Punkten, Verfallsdatum und verbleibenden Tagen. Der Verfall selbst ist für kostenlose und Premium-Spieler identisch.',
      ]}),
    ],
  },
  {
    id: 'equipment',
    title: 'Ausrüstungszentrum und Ausrüstungseffekte',
    summary: 'Gear Room, Inventar, Markt, Zustand, Verschleiß, Belagspassung und aktive Zubehörplätze.',
    sections: [
      s('Aktive Ausrüstungsfamilien', { paragraphs: [
        'Der aktuelle Katalog enthält Schläger, Schuhe, Kleidung und Zubehör. Aktive Zubehörarten sind Taschen, Flaschen, Caps, Handtücher und Schweißbänder. Overgrips und Dämpfer sind keine aktiven Kategorien.',
      ]}),
      s('Gear Room', { paragraphs: [
        'Schläger, Schuhe und Kleidung verwenden jeweils einen aktiven Platz. Zubehör verwendet einen aktiven Platz pro Zubehörart. Das aktuelle Match-Setup ist die maßgebliche ausgerüstete Konfiguration für Matchsysteme.',
      ]}),
      s('Inventar', { paragraphs: [
        'Eigene Gegenstände zeigen zustandsangepasste Boni, Haltbarkeit, Verschleiß pro Match, Markenidentität und Wiederverkaufswert. Startausrüstung, Käufe und andere erhaltene Gegenstände bleiben im Inventar, bis sie verkauft oder verworfen werden.',
      ]}),
      s('Markt', { paragraphs: [
        'Käufe im Ausrüstungsmarkt verwenden Karriereguthaben und gelangen mit 100 % Zustand ins Inventar. Ein aktiver passender technischer Sponsor kann den Spielerpreis reduzieren.',
      ]}),
      s('Zustand und Verschleiß', { paragraphs: [
        'Gameplay-Modifikatoren verwenden den aktuellen Zustand und nicht immer den Katalogwert bei 100 %. Matchverschleiß reduziert den Zustand gemäß Haltbarkeits-/Verschleißregeln. Walkovers/No-Shows ohne gespieltes Match reduzieren die Ausrüstungshaltbarkeit nicht.',
      ]}),
      s('Belagspassung und Produktprofil', { paragraphs: [
        'Einige Produkte besitzen Belags-/Wettermerkmale oder Kompromisse. Das endgültige Ausrüstungsprofil kombiniert Gegenstandsboni, Zustand und Platzbelagspassung, statt blind alle Katalogwerte zu addieren.',
      ]}),
      s('Verkaufen und Verwerfen', { paragraphs: [
        'Berechtigte Ausrüstung kann zum aktuellen Wiederverkaufswert verkauft oder verworfen werden. Ein aktuell ausgerüsteter Gegenstand muss ersetzt/abgelegt werden, bevor er entfernt wird, wenn der Platz nicht in einem ungültigen Zustand verbleiben darf.',
      ], links: [{ label: 'Ausrüstungszentrum öffnen', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'technical-sponsors',
    title: 'Technische Sponsoren',
    summary: 'Markensponsoring für Schläger, Schuhe und Kleidung und wie es Ausrüstungspreise verändert.',
    sections: [
      s('Getrennt vom Hauptsponsor', { paragraphs: [
        'Technisches Sponsoring befindet sich unter Ausrüstung und ist vom Haupt-Karrieresponsor in Finanzen getrennt. Technische Verträge sind kategoriespezifisch: Schläger, Schuhe und Kleidung.',
      ]}),
      s('Berechtigung für Angebote', { paragraphs: [
        'Technische Angebote werden aus der aktuellen Ranglistengruppe des Spielers erzeugt. Ranglistenbereiche beeinflussen verfügbare Markenstufen, Anzahl der Angebote, Rabattspanne und mögliches Handgeld.',
      ]}),
      s('Aktuelles Vorteilsmodell', { paragraphs: [
        'Der implementierte Ausrüstungsvorteil basiert auf Rabatten. Aktive technische Sponsoren reduzieren den Karriereguthaben-Preis passender Ausrüstung. Das aktuelle Modell bietet weder unbegrenzt kostenlose Ausrüstung noch automatische Gratis-Ersatzprodukte.',
      ]}),
      s('Vertragszeitpunkt', { paragraphs: [
        'Ohne aktuellen Vertrag in einer Kategorie kann ein unterschriebenes Angebot sofort beginnen. Wenn ein aktiver Vertrag seine letzten 28 Tage erreicht, kann der Spieler einen Ersatzvertrag für diese Kategorie unterschreiben; der neue Vertrag beginnt nach Ende des aktuellen.',
      ]}),
      s('Handgeld und Vertragsbenachrichtigungen', { paragraphs: [
        'Technische Verträge können ein Handgeld in Karriereguthaben enthalten. Auslaufende, beginnende und abgeschlossene technische Verträge erzeugen Benachrichtigungen; Rabatte enden, sobald der relevante Vertrag nicht mehr aktiv ist.',
      ], links: [{ label: 'Technische Sponsoren öffnen', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'finance',
    title: 'Finanzen und Karriereökonomie',
    summary: 'Karriereguthaben, permanentes Ledger, Steuern, kommende Kosten und der Unterschied zwischen Geld und Coins.',
    sections: [
      s('Karriereguthaben', { paragraphs: [
        'Karriereguthaben ist die professionelle Karriereökonomie für Team, Ausrüstung, Trainingscamps, Turnierreisen/-hotels, Privatleben und andere Karrieretransaktionen. Eine neue Karriere beginnt mit 25.000 USD.',
      ]}),
      s('Permanentes Ledger', { paragraphs: [
        'Jede Bewegung des Karriereguthabens wird mit Spieldatum, Kategorie, Quelle, Grund, Betrag und resultierendem Saldo gespeichert. Die Finanzseite zeigt daher nicht nur den Saldo, sondern auch, wie er entstanden ist.',
      ]}),
      s('Einnahmen und Ausgaben', { paragraphs: [
        'Finanzanalysen trennen Einnahmen und Ausgaben. Typische Einnahmen sind Preisgeld, Sponsoring und Boni; häufige Ausgaben sind Reisen, Hotels, Team, Training und Käufe.',
      ]}),
      s('Monatliche Einkommensteuer', { paragraphs: [
        'Die aktuelle universelle Steuerversion verwendet einen pauschalen Satz von 18 % auf steuerpflichtiges monatliches Einkommen. Ausgaben sind in dieser Version keine Abzüge. Am ersten Spieltag des nächsten Monats wird der abgeschlossene Monat einmalig über einen idempotenten Transaktionsschlüssel abgerechnet.',
      ]}),
      s('Kommende Verpflichtungen', { paragraphs: [
        'Finanzen zeigt kommenden Kostendruck über die nächsten 60 Spieltage. Prüfe ihn, bevor du dich für ein teures Camp, einen Teamvertrag, ein Ausrüstungsupgrade oder einen Luxuskauf entscheidest.',
      ]}),
      s('Karriereguthaben ist nicht Coins', { paragraphs: [
        'Coins sind eine optionale Spiel-/Premium-Währung für ausgewählte optionale Systeme. Karriereguthaben und Coins können sich nicht gegenseitig ersetzen.',
      ], links: [{ label: 'Finanzzentrum öffnen', href: '/game/finance' }]}),
    ],
  },
  {
    id: 'main-sponsors',
    title: 'Hauptsponsoren und Sponsorziele',
    summary: 'Saisonale Sponsorangebote, wöchentliche Zahlungen und Turnierziele.',
    sections: [
      s('Kein Sponsor bei Karriereerstellung', { paragraphs: ['Ein neuer Spieler startet ohne Hauptsponsor und muss im Laufe der Karriere ein Angebot unterschreiben.']}),
      s('Wie Angebote erzeugt werden', { paragraphs: [
        'Hauptsponsorangebote reagieren auf die Ranglistenposition und verwenden die nationale Sponsorenmarktgruppe des Spielers. Höher platzierte Spieler können außerdem Chancen bei weltweiten Marken erhalten. Anzahl und Vertragswert der Angebote verändern sich mit dem Rang.',
      ]}),
      s('Wöchentliches Angebotsfenster', { paragraphs: [
        'Offene Sponsorangebote gehören zu einem Angebotsfenster der Spielwoche und können verfallen. Sobald ein Hauptsponsor für die Saison unterschrieben ist, werden andere offene Hauptsponsorangebote dieser Saison geschlossen.',
      ]}),
      s('Vertragszahlungen', { paragraphs: [
        'Ein unterschriebener Hauptsponsor zahlt planmäßige wöchentliche Beträge in Karriereguthaben über die Saison. Sponsortransaktionen verwenden dasselbe permanente Finanz-Ledger wie anderes Karrieregeld.',
      ]}),
      s('Ziele', { paragraphs: [
        'Aktive Sponsorziele können Zielturniere oder Leistungsanforderungen benennen. Relevante Turnierziele erscheinen im Kalender, damit der Spieler kommerzielle Verpflichtungen zusammen mit Ranglistenzielen planen kann.',
      ], links: [{ label: 'Finanzen / Sponsoring öffnen', href: '/game/finance' }, { label: 'Kalender öffnen', href: '/game/calendar' }]}),
    ],
  },
]
