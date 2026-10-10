import type { ManualChapter } from './types'

export const manualCoreChaptersIt: ManualChapter[] = [
  {
    "id": "getting-started",
    "title": "Per iniziare",
    "summary": "Introduzione pratica alla carriera, alle pagine principali e alle prime decisioni importanti.",
    "sections": [
      {
        "title": "Che cos'è Tennis Legacy",
        "paragraphs": [
          "Tennis Legacy: Rise to Glory è un gioco persistente di gestione della carriera nel tennis professionistico. Controlli un giocatore umano nel circuito ATP oppure WTA, pianifichi lo sviluppo, partecipi ai tornei, organizzi viaggi e attrezzatura, assumi lo staff, gestisci le finanze e affronti salute, classifiche e calendario per più stagioni di gioco.",
          "ATP e WTA sono mondi competitivi separati per le classifiche di singolare e doppio. Sistemi sociali come i Tennis Club possono unire giocatori di entrambi i circuiti, mentre iscrizioni, classifiche e risultati rimangono legati al proprio circuito."
        ]
      },
      {
        "title": "Ordine consigliato per la prima sessione",
        "steps": [
          "Apri Panoramica e controlla data di gioco, classifica, prontezza, saldo della carriera, prossimo impegno e notifiche.",
          "Apri Abilità per conoscere il profilo tecnico, fisico e di prontezza del giocatore.",
          "Apri Allenamento e configura un piano settimanale: le nuove carriere non ne hanno uno preimpostato.",
          "Apri Attrezzatura. All'inizio hai già una racchetta, scarpe e abbigliamento di base equipaggiati.",
          "Controlla il Calendario tornei prima di iscriverti. Valuta categoria, superficie, date e viaggio.",
          "Dopo una richiesta o un'ammissione, apri Programma per preparazione, impegni e viaggi.",
          "Controlla regolarmente le Finanze. Il denaro della carriera è separato dai Coins e ogni movimento viene registrato permanentemente."
        ]
      },
      {
        "title": "Il ciclo principale della carriera",
        "bullets": [
          "Pianifica allenamenti, tornei, viaggi, attrezzatura e staff intorno al calendario.",
          "Prepara stanchezza, salute, tattiche, attrezzatura e viaggio prima delle partite.",
          "Competi per risultati, punti classifica, statistiche, premi in denaro e obiettivi degli sponsor.",
          "Recupera e sviluppa il giocatore tramite allenamenti regolari, ritiri e una gestione ragionevole del carico.",
          "Reinvesti il denaro della carriera in staff, attrezzatura, ritiri, viaggi, hotel e acquisti della Vita privata.",
          "Controlla Classifiche, Statistiche, Notifiche e Finanze per comprendere gli effetti delle decisioni."
        ]
      },
      {
        "title": "Dove trovare spiegazioni",
        "paragraphs": [
          "Consulta questo Manuale completo per regole e procedure. Il Centro assistenza collega anche i Contatti e il Discord ufficiale. Quando segnali un problema, includi pagina, nome del giocatore, schermate e passaggi esatti per riprodurlo."
        ],
        "links": [
          {
            "label": "Apri Panoramica",
            "href": "/game/overview"
          },
          {
            "label": "Apri il Centro assistenza",
            "href": "/game/help"
          }
        ]
      }
    ]
  },
  {
    "id": "creating-a-career",
    "title": "Creare una carriera",
    "summary": "Come creare il giocatore e quale pacchetto esatto riceve ogni nuova carriera umana al giorno 1.",
    "sections": [
      {
        "title": "Scelte alla creazione",
        "bullets": [
          "Circuito: ATP o WTA. Determina il mondo competitivo e la classifica.",
          "Identità: nome, cognome e nazionalità realistici. Il nome professionale è permanente dopo la creazione.",
          "Città di residenza: scegli una città disponibile nel Paese selezionato; viene usata per i viaggi e la Vita privata.",
          "Ritratto: facoltativo; quelli già usati da carriere attive non sono disponibili.",
          "Superficie preferita: cemento, terra battuta o erba.",
          "Stile: fondocampista aggressivo, fondocampista difensivo, a tutto campo o servizio e volée.",
          "Mano dominante: destrimane o mancino. Modifica la geometria del servizio e degli scambi, non regala punti a diritto o rovescio."
        ]
      },
      {
        "title": "Pacchetto esatto del giorno 1",
        "table": {
          "headers": [
            "Sistema",
            "Stato iniziale"
          ],
          "rows": [
            [
              "Denaro della carriera",
              "25.000 USD"
            ],
            [
              "Coins",
              "20 Coins, una sola volta"
            ],
            [
              "Punti classifica singolare",
              "0"
            ],
            [
              "Punti classifica doppio",
              "0"
            ],
            [
              "Allenamento regolare",
              "Non configurato"
            ],
            [
              "Staff",
              "Nessuno"
            ],
            [
              "Sponsor principale",
              "Nessuno"
            ],
            [
              "Sponsor tecnici",
              "Nessuno"
            ],
            [
              "Federazione nazionale",
              "Non iscritto"
            ],
            [
              "Tennis Club",
              "Non iscritto"
            ],
            [
              "Impegni nel calendario",
              "Nessuno"
            ],
            [
              "Stanchezza",
              "0"
            ],
            [
              "Brillantezza",
              "50"
            ],
            [
              "Morale",
              "50"
            ],
            [
              "Fiducia",
              "50"
            ],
            [
              "Concentrazione",
              "50"
            ],
            [
              "Racchetta iniziale",
              "Rosignol F-200 Carbon, condizione 100%, equipaggiata"
            ],
            [
              "Scarpe iniziali",
              "Antta PG 7, condizione 100%, equipaggiate"
            ],
            [
              "Abbigliamento ATP iniziale",
              "BlokUV Guardian Court, condizione 100%, equipaggiato"
            ],
            [
              "Abbigliamento WTA iniziale",
              "BlokUV Solar Shield 8, condizione 100%, equipaggiato"
            ],
            [
              "Accessori iniziali",
              "Nessuno"
            ],
            [
              "Vita privata Free",
              "Nessuna proprietà iniziale"
            ],
            [
              "Vita privata Premium",
              "Un appartamento iniziale nella città di residenza, bloccato per la compravendita"
            ]
          ]
        }
      },
      {
        "title": "Inizializzazione una tantum",
        "paragraphs": [
          "L'inizializzazione della carriera è idempotente. Aggiornamenti della pagina, nuovi tentativi o riaperture non duplicano i 25.000 USD, i 20 Coins, l'attrezzatura iniziale o l'appartamento Premium. Un controllo registra la versione dello schema applicato."
        ]
      },
      {
        "title": "Riavvio o eliminazione dell'account",
        "paragraphs": [
          "In Giocatore e account sono presenti azioni irreversibili per il riavvio e l'eliminazione definitiva. Usale soltanto se intendi rimuovere lo stato corrente della carriera. I Coins iniziali non si possono ottenere più volte semplicemente aggiornando la pagina."
        ],
        "links": [
          {
            "label": "Apri Giocatore e account",
            "href": "/game/player-account"
          }
        ]
      }
    ]
  },
  {
    "id": "overview",
    "title": "Panoramica e routine quotidiana",
    "summary": "Come leggere il centro di comando della carriera e usarlo all'inizio di ogni giorno di gioco.",
    "sections": [
      {
        "title": "Cosa mostra la Panoramica",
        "bullets": [
          "Profilo professionale e posizione nella classifica attuale.",
          "Prossimo torneo e prossima partita prevista, quando disponibili.",
          "Risultato della partita precedente.",
          "Saldo delle Finanze e entrate, spese e netto stagionali.",
          "Prossimo impegno e tornei attivi oggi.",
          "Statistiche della forma stagionale.",
          "Prontezza e informazioni sull'allenamento corrente.",
          "Accesso rapido ad attrezzatura, staff e club.",
          "Ultimi risultati ufficiali del circuito e notifiche personali."
        ]
      },
      {
        "title": "Pannello Premium di Protezione classifica",
        "paragraphs": [
          "Gli abbonati Premium possono espandere Protezione classifica per vedere i cinque contributi ai punti classifica più vicini alla scadenza. È uno strumento di pianificazione: Premium non impedisce la scadenza dei punti e non altera risultati o classifiche."
        ]
      },
      {
        "title": "Routine quotidiana utile",
        "steps": [
          "Leggi prima le notifiche personali.",
          "Controlla il prossimo impegno e la prossima partita.",
          "Esamina prontezza, stanchezza e salute prima di allenamenti o competizioni.",
          "Controlla Programma o Calendario prima di iscriverti a un altro evento.",
          "Verifica le Finanze prima di assumere staff, prenotare ritiri, acquistare attrezzatura o scegliere viaggi costosi.",
          "Usa Classifiche e Statistiche per valutazioni a lungo termine."
        ],
        "links": [
          {
            "label": "Apri Panoramica",
            "href": "/game/overview"
          }
        ]
      }
    ]
  },
  {
    "id": "player-profile-account",
    "title": "Profilo del giocatore e account",
    "summary": "Identità, profili pubblici, avatar, sicurezza e azioni irreversibili sull'account.",
    "sections": [
      {
        "title": "La tua identità pubblica",
        "paragraphs": [
          "Il profilo professionale rappresenta il giocatore in classifiche, tornei e funzioni sociali. Altri manager possono aprire i profili dalle Classifiche."
        ]
      },
      {
        "title": "Pagina Giocatore e account",
        "bullets": [
          "Mostra nome fisso, email dell'account, circuito e Paese.",
          "Mostra l'avatar corrente e la procedura di sostituzione.",
          "Le modifiche della password usano un'email di recupero verificata.",
          "La zona pericolosa include riavvio dell'account ed eliminazione definitiva del giocatore e dell'account."
        ]
      },
      {
        "title": "Sostituzione dell'avatar",
        "paragraphs": [
          "La sostituzione dell'avatar segue una procedura di revisione. Puoi inviare una foto di riferimento e scegliere i colori della maglia. Le foto sono temporanee e vengono eliminate automaticamente secondo il periodo di conservazione previsto. L'avatar preparato deve essere approvato o rifiutato prima dell'uso."
        ]
      },
      {
        "title": "Messaggi privati dai profili",
        "paragraphs": [
          "Dal profilo di un altro giocatore umano puoi avviare una conversazione privata nella Posta del manager. Solo i due partecipanti possono leggerla."
        ],
        "links": [
          {
            "label": "Apri Giocatore e account",
            "href": "/game/player-account"
          },
          {
            "label": "Apri Classifiche",
            "href": "/game/rankings"
          }
        ]
      }
    ]
  },
  {
    "id": "skills",
    "title": "Abilità e identità iniziale",
    "summary": "Abilità tecniche e fisiche, attributi di prontezza e influenza di superficie e stile iniziali.",
    "sections": [
      {
        "title": "Attributi tecnici",
        "table": {
          "headers": [
            "Attributo",
            "Significato"
          ],
          "rows": [
            [
              "Servizio",
              "Potenza, piazzamento e affidabilità"
            ],
            [
              "Diritto",
              "Colpo d'attacco principale da fondo"
            ],
            [
              "Rovescio",
              "Qualità, controllo e stabilità"
            ],
            [
              "Risposta",
              "Neutralizzazione e attacco del servizio"
            ],
            [
              "Volée",
              "Gioco a rete e chiusura dei punti"
            ],
            [
              "Slice",
              "Variazione e controllo delle palle basse"
            ],
            [
              "Palla corta",
              "Tocco e variazione nel campo corto"
            ],
            [
              "Pallonetto",
              "Altezza, profondità e precisione sopra l'avversario"
            ],
            [
              "Smash",
              "Tempismo, potenza e chiusura dei colpi alti"
            ]
          ]
        }
      },
      {
        "title": "Attributi fisici",
        "table": {
          "headers": [
            "Attributo",
            "Significato"
          ],
          "rows": [
            [
              "Forma fisica",
              "Preparazione atletica generale"
            ],
            [
              "Resistenza",
              "Mantenimento della qualità nelle partite lunghe"
            ],
            [
              "Recupero",
              "Recupero tra partite e allenamenti"
            ],
            [
              "Movimento",
              "Copertura del campo, velocità ed equilibrio"
            ]
          ]
        }
      },
      {
        "title": "Prontezza e mentalità",
        "table": {
          "headers": [
            "Attributo",
            "Significato"
          ],
          "rows": [
            [
              "Morale",
              "Motivazione e stato emotivo"
            ],
            [
              "Fiducia",
              "Sicurezza influenzata da forma e risultati"
            ],
            [
              "Brillantezza",
              "Ritmo competitivo e preparazione alla partita"
            ],
            [
              "Concentrazione",
              "Attenzione e stabilità mentale"
            ],
            [
              "Stanchezza",
              "Fatica accumulata: un valore più basso è migliore"
            ]
          ]
        }
      },
      {
        "title": "Profili iniziali per superficie",
        "paragraphs": [
          "Cemento, terra battuta ed erba partono da distribuzioni tecniche diverse, ma tutti e tre i profili base totalizzano esattamente 450 punti tecnici. La superficie crea identità, non un vantaggio gratuito di forza complessiva."
        ],
        "table": {
          "headers": [
            "Abilità",
            "Cemento",
            "Terra battuta",
            "Erba"
          ],
          "rows": [
            [
              "Servizio",
              "56",
              "48",
              "62"
            ],
            [
              "Diritto",
              "58",
              "59",
              "52"
            ],
            [
              "Rovescio",
              "55",
              "57",
              "48"
            ],
            [
              "Risposta",
              "57",
              "60",
              "46"
            ],
            [
              "Volée",
              "46",
              "42",
              "57"
            ],
            [
              "Slice",
              "45",
              "48",
              "54"
            ],
            [
              "Palla corta",
              "42",
              "47",
              "38"
            ],
            [
              "Pallonetto",
              "43",
              "51",
              "38"
            ],
            [
              "Smash",
              "48",
              "38",
              "55"
            ],
            [
              "Totale base",
              "450",
              "450",
              "450"
            ]
          ]
        }
      },
      {
        "title": "Mano dominante e geometria degli incontri",
        "paragraphs": [
          "Destrimani e mancini partono dallo stesso budget di forza; la mano non rende automaticamente diritto o rovescio migliori o peggiori.",
          "Durante le partite cambiano angoli al servizio, traiettorie incrociate e rapporto tra il diritto di un giocatore e il rovescio dell'avversario. La mano è una caratteristica pubblica dell'avversario da considerare nelle tattiche."
        ]
      },
      {
        "title": "Redistribuzione per stile",
        "bullets": [
          "Fondocampista aggressivo: punti verso servizio e colpi d'attacco.",
          "Fondocampista difensivo: punti verso risposta, stabilità del rovescio e gestione della pressione.",
          "Servizio e volée: punti verso servizio, volée, slice e gioco avanzato.",
          "A tutto campo: nessuna redistribuzione aggiuntiva; conta soprattutto la superficie scelta."
        ]
      },
      {
        "title": "Variazioni e limiti di sviluppo",
        "paragraphs": [
          "I nuovi giocatori umani ricevono piccole variazioni individuali deterministiche, normalizzate intorno a 440–455 punti tecnici iniziali. Le abilità elevate crescono progressivamente più lentamente di quelle iniziali."
        ],
        "links": [
          {
            "label": "Apri Abilità",
            "href": "/game/skills"
          }
        ]
      }
    ]
  },
  {
    "id": "regular-training",
    "title": "Allenamento regolare",
    "summary": "Pianificazione settimanale, blocchi del calendario e distribuzione dello sviluppo.",
    "sections": [
      {
        "title": "Regola dei giorni a casa",
        "paragraphs": [
          "L'allenamento regolare è disponibile solo nei giorni marcati Casa nel calendario e quando il giocatore è idoneo dal punto di vista medico. Tornei, viaggi, ritiri e giorni bloccati per salute occupano la data e impediscono l'allenamento regolare."
        ]
      },
      {
        "title": "Pianificazione settimanale",
        "paragraphs": [
          "Il pianificatore salva scelte diverse per i giorni a casa. Il motore automatico giornaliero le esegue quando arriva quella data di gioco. Le attività del calendario hanno sempre la precedenza."
        ]
      },
      {
        "title": "Distribuzione del focus",
        "paragraphs": [
          "L'allenamento focalizzato assegna la maggior parte dello sviluppo all'attributo scelto e ripartisce il resto nella categoria corrispondente. Il modello attuale usa una divisione 85% sull'attributo selezionato e 15% sul resto della categoria."
        ]
      },
      {
        "title": "Curva di sviluppo",
        "table": {
          "headers": [
            "Livello attuale",
            "Moltiplicatore di sviluppo"
          ],
          "rows": [
            [
              "1–59",
              "100%"
            ],
            [
              "60–69",
              "90%"
            ],
            [
              "70–79",
              "75%"
            ],
            [
              "80–89",
              "55%"
            ],
            [
              "90–94",
              "35%"
            ],
            [
              "95–99",
              "20%"
            ]
          ]
        }
      },
      {
        "title": "Recupero e risultati",
        "bullets": [
          "Il giorno di riposo privilegia il recupero, non lo sviluppo permanente.",
          "Ogni sessione registra miglioramenti, aumento di livello e condizione prima/dopo.",
          "I ritiri prenotati compaiono anche in Allenamento regolare e i relativi giorni di viaggio hanno precedenza sul piano."
        ],
        "links": [
          {
            "label": "Apri Allenamento",
            "href": "/game/training"
          }
        ]
      }
    ]
  },
  {
    "id": "training-camps",
    "title": "Ritiri di allenamento",
    "summary": "Prenotazioni, costi, vantaggi, cancellazioni, viaggi di transizione e completamento.",
    "sections": [
      {
        "title": "Funzione dei ritiri",
        "paragraphs": [
          "Un ritiro è un periodo di sviluppo a pagamento legato a una destinazione. Lo sviluppo è più intenso dell'allenamento ordinario, ma i ritiri lunghi hanno rendimenti decrescenti."
        ]
      },
      {
        "title": "Prezzi del programma",
        "table": {
          "headers": [
            "Tipo di ritiro",
            "Standard",
            "Avanzato",
            "Élite"
          ],
          "rows": [
            [
              "Recupero e mentalità",
              "1.200 $/settimana",
              "1.800 $/settimana",
              "2.700 $/settimana"
            ],
            [
              "Fisico",
              "1.400 $/settimana",
              "2.100 $/settimana",
              "3.200 $/settimana"
            ],
            [
              "Abilità tennistiche",
              "1.500 $/settimana",
              "2.300 $/settimana",
              "3.400 $/settimana"
            ]
          ]
        }
      },
      {
        "title": "Qualità e durata",
        "bullets": [
          "Moltiplicatori della qualità: Standard 1,00×, Avanzato 1,15×, Élite 1,30×.",
          "I ritiri durano da una a quattro settimane.",
          "Lo sviluppo tecnico/fisico applica 100%, 95%, 85% e 75% rispettivamente nelle settimane 1–4.",
          "Una settimana normale comprende sei giorni di sviluppo e uno di recupero."
        ]
      },
      {
        "title": "Alloggio",
        "table": {
          "headers": [
            "Alloggio",
            "Costo base settimanale",
            "Finalità"
          ],
          "rows": [
            [
              "Economico 2 stelle",
              "350 $",
              "Prezzo minimo"
            ],
            [
              "Standard 3 stelle",
              "560 $",
              "Equilibrio"
            ],
            [
              "Comfort 4 stelle",
              "840 $",
              "Recupero e comfort migliori"
            ],
            [
              "Premium 5 stelle",
              "1.260 $",
              "Massimo comfort e recupero"
            ]
          ]
        }
      },
      {
        "title": "Preventivo e pagamento",
        "paragraphs": [
          "Il preventivo include quota del programma, alloggio adeguato alla destinazione, viaggio del giocatore e costi dello staff al seguito. La liquidità della carriera è visibile prima della prenotazione. Se è insufficiente, il sistema rifiuta l'operazione senza registrare prenotazioni o transazioni finanziarie."
        ]
      },
      {
        "title": "Protezione da conflitti e duplicati",
        "bullets": [
          "I ritiri sovrapposti sono bloccati.",
          "Sono bloccate le richieste e iscrizioni ai tornei che si sovrappongono al ritiro.",
          "Vengono verificati impegni nel calendario e restrizioni mediche.",
          "I doppi clic e le richieste duplicate vengono serializzati.",
          "Prenotazioni, Finanze e occupazione del calendario sono transazionali."
        ]
      },
      {
        "title": "Annullamento",
        "paragraphs": [
          "Un ritiro futuro non ancora iniziato può essere annullato con rimborso del 100% del denaro della carriera. Dopo l'inizio non è più disponibile la normale cancellazione preventiva."
        ]
      },
      {
        "title": "Viaggi e ritiri accorciati",
        "paragraphs": [
          "Le transizioni torneo→ritiro e ritiro→torneo passano per la città di residenza del giocatore. Se c'è un solo giorno di transizione, due mezze giornate di viaggio possono condividere la stessa data. Se il torneo precedente occupa il normale giorno di viaggio verso il ritiro, il primo giorno del ritiro diventa viaggio diviso, la data finale resta invariata e si perde un giorno di sviluppo."
        ]
      },
      {
        "title": "Mancata presenza per viaggio",
        "paragraphs": [
          "Se dopo un ritiro è necessario un giorno di viaggio diviso e la partita del torneo successivo è troppo presto per arrivare, il giocatore perde per mancata presenza e l'avversario avanza. Non viene addebitata usura all'attrezzatura perché la partita non è stata disputata."
        ]
      },
      {
        "title": "Completamento e monitoraggio",
        "paragraphs": [
          "I risultati giornalieri del ritiro sono idempotenti e non vengono attribuiti due volte. Gli stati sono Prenotato → Attivo → Completato. Un'interruzione sanitaria nell'ultimo giorno non lascia il ritiro bloccato. Ciclo di vita e trasferimenti sono monitorati nella Salute del sistema."
        ],
        "links": [
          {
            "label": "Apri Ritiri di allenamento",
            "href": "/game/training"
          }
        ]
      }
    ]
  },
  {
    "id": "readiness-recovery",
    "title": "Stanchezza, brillantezza, forma e recupero",
    "summary": "Come la condizione a breve termine interagisce con allenamento, viaggi e prestazioni.",
    "sections": [
      {
        "title": "Stanchezza",
        "paragraphs": [
          "La stanchezza misura la fatica accumulata ed è il principale valore di condizione in cui più basso significa meglio. Allenamenti, partite e viaggi possono aumentarla; riposo, recupero, hotel e staff pertinenti possono ridurla o contenerla."
        ]
      },
      {
        "title": "Brillantezza",
        "paragraphs": [
          "La brillantezza rappresenta ritmo agonistico e preparazione alla partita. Non è un'abilità permanente: anche un giocatore molto forte può essere poco pronto se ha brillantezza bassa o stanchezza elevata."
        ]
      },
      {
        "title": "Morale, fiducia e concentrazione",
        "bullets": [
          "Morale: motivazione e stato emotivo attuali.",
          "Fiducia: influenzata da forma e risultati.",
          "Concentrazione: attenzione e stabilità mentale."
        ]
      },
      {
        "title": "Forma e abilità permanenti",
        "paragraphs": [
          "Le abilità sono attributi a lungo termine. La prontezza rappresenta lo stato di breve termine. Le statistiche della forma stagionale derivano dai risultati. Non confondere questi tre aspetti."
        ]
      },
      {
        "title": "Pianificazione pratica del recupero",
        "steps": [
          "Controlla salute e stanchezza prima dell'allenamento intenso.",
          "Lascia che i giorni di viaggio rimangano riservati ai viaggi.",
          "Scegli giorni di riposo o recupero quando la stanchezza è alta.",
          "Con eventi ravvicinati, classe di viaggio, hotel e staff possono contare quanto un giorno di allenamento in più."
        ],
        "links": [
          {
            "label": "Apri Allenamento",
            "href": "/game/training"
          },
          {
            "label": "Apri Salute",
            "href": "/game/injuries"
          }
        ]
      }
    ]
  },
  {
    "id": "health",
    "title": "Infortuni, malattie e disponibilità",
    "summary": "Centro salute, fattori di rischio, restrizioni mediche e regole di rientro.",
    "sections": [
      {
        "title": "Centro salute",
        "paragraphs": [
          "Infortuni e salute mostra stato medico, rischio di infortunio, rischio giornaliero di malattia, cure, rientro agli allenamenti e ai tornei, recupero completo previsto e penalità attuale alle prestazioni."
        ]
      },
      {
        "title": "Fattori di rischio d'infortunio",
        "paragraphs": [
          "Il rischio è specifico per attività e aumenta con combinazioni di stanchezza, carico di lavoro, durata delle partite, caldo e condizione fisica ridotta. La pagina mostra i fattori attuali, invece di rendere gli infortuni completamente imprevedibili."
        ]
      },
      {
        "title": "Rischio di malattia",
        "paragraphs": [
          "Il rischio di malattia viene calcolato separatamente da quello d'infortunio e può dipendere da stanchezza, recupero, esposizione durante i viaggi e condizioni di salute attuali."
        ]
      },
      {
        "title": "Disponibilità medica",
        "bullets": [
          "Il ritorno agli allenamenti e quello ai tornei possono avvenire in date diverse.",
          "L'elaborazione del calendario rispetta i blocchi medici.",
          "I ritiri non possono essere prenotati sopra restrizioni mediche già note.",
          "Gli effetti dello staff sanitario vengono mostrati quando pertinenti."
        ]
      },
      {
        "title": "Cronologia della salute",
        "paragraphs": [
          "Infortuni e malattie risolti restano nella cronologia della carriera. La pagina contiene anche riferimenti ai tipi di infortunio, alle durate delle malattie e ai livelli di cura e riabilitazione."
        ],
        "links": [
          {
            "label": "Apri Infortuni e salute",
            "href": "/game/injuries"
          }
        ]
      }
    ]
  },
  {
    "id": "staff",
    "title": "Staff e mercato dello staff",
    "summary": "Assunzioni, contratti, effetti, stipendi, trattative e risoluzioni.",
    "sections": [
      {
        "title": "Ruoli disponibili",
        "table": {
          "headers": [
            "Ruolo",
            "Contributo principale"
          ],
          "rows": [
            [
              "Allenatore capo",
              "Sviluppo tecnico, tattiche e preparazione alle partite"
            ],
            [
              "Preparatore atletico",
              "Sviluppo fisico, condizione e carichi"
            ],
            [
              "Fisioterapista",
              "Recupero dalla stanchezza, prevenzione e riabilitazione"
            ],
            [
              "Psicologo sportivo",
              "Morale, fiducia, concentrazione e gestione della pressione"
            ],
            [
              "Analista delle prestazioni",
              "Stime di scouting, affidabilità della preparazione, osservazioni sulla mano dominante e tattiche"
            ],
            [
              "Manager di carriera",
              "Sponsorizzazioni, rappresentanza commerciale e gestione della carriera"
            ]
          ]
        }
      },
      {
        "title": "Regole su ruoli e qualità",
        "paragraphs": [
          "Ogni ruolo può essere occupato da una sola persona attiva. Le nuove carriere iniziano senza staff. I candidati sono divisi per qualità: In crescita, Professionale, Avanzato, Élite e Classe mondiale."
        ]
      },
      {
        "title": "Procedura di trattativa",
        "steps": [
          "Filtra il mercato per ruolo, qualità, Paese e stipendio.",
          "Apri un candidato e scegli durata del contratto e offerta salariale.",
          "Controlla probabilità di accettazione, compenso alla firma e costo totale.",
          "Anche un'offerta accettata richiede conferma finale prima dell'assunzione.",
          "Il denaro deve coprire il compenso iniziale; alcuni candidati rifiutano trattative con giocatori di reputazione sportiva insufficiente."
        ]
      },
      {
        "title": "Risoluzione e viaggi",
        "paragraphs": [
          "I contratti mostrano settimane non pagate, valore residuo, aliquota di indennizzo e penale di risoluzione. Lo staff può accompagnare tornei o ritiri: comporta costi, e gli effetti che richiedono presenza funzionano solo se viaggia.",
          "L'Analista delle prestazioni offre informazioni, non bonus nascosti di forza. Gli analisti migliori restringono gli intervalli delle stime. Quando è noto il prossimo avversario, la preparazione evolve da rapida a parziale, normale e completa; la fase completa arriva dopo 24 ore di gioco."
        ],
        "links": [
          {
            "label": "Apri Staff",
            "href": "/game/staff"
          }
        ]
      }
    ]
  },
  {
    "id": "calendar",
    "title": "Calendario e pianificazione delle competizioni",
    "summary": "Come interagiscono calendario del giocatore e calendario dei tornei.",
    "sections": [
      {
        "title": "Le due viste del calendario",
        "paragraphs": [
          "Il Calendario combina le attività sincronizzate del giocatore con il Calendario tornei. La vista del giocatore mostra chi occupa ogni data, mentre quella dei tornei serve a trovare occasioni competitive."
        ]
      },
      {
        "title": "Tipi di attività",
        "bullets": [
          "Torneo",
          "Viaggio",
          "Ritiro di allenamento",
          "Nazionale",
          "Salute / Recupero",
          "Casa"
        ]
      },
      {
        "title": "Priorità del calendario",
        "paragraphs": [
          "Una data non può essere considerata libera per l'allenamento se è occupata da un altro sistema. Tornei, viaggi, ritiri, nazionali e blocchi medici hanno precedenza su allenamenti regolari salvati."
        ]
      },
      {
        "title": "Scelta dei tornei",
        "paragraphs": [
          "Le schede dei tornei mostrano date, località, categoria, superficie, tabellone/punti e stato delle iscrizioni. Gli obiettivi degli sponsor possono segnalare eventi importanti a livello commerciale."
        ]
      },
      {
        "title": "Viaggi automatici",
        "paragraphs": [
          "Impegni accettati e preparazione salvata alimentano il motore comune dei viaggi. I giorni di viaggio vengono quindi mostrati nel calendario. Le transizioni dei ritiri possono richiedere due mezze giornate di viaggio nello stesso giorno."
        ],
        "links": [
          {
            "label": "Apri Calendario",
            "href": "/game/calendar"
          }
        ]
      }
    ]
  }
]
