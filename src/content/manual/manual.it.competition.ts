import type { ManualChapter } from './types'

export const manualCompetitionChaptersIt: ManualChapter[] = [
  {
    "id": "tournament-selection",
    "title": "Scelta dei tornei e richieste d'iscrizione",
    "summary": "Come scegliere gli eventi, presentare domanda e distinguere una richiesta da un'iscrizione accettata.",
    "sections": [
      {
        "title": "Prima di iscriversi",
        "steps": [
          "Controlla la categoria del torneo e il livello di competizione previsto.",
          "Confronta la superficie con le abilità e la condizione attuale del tuo giocatore.",
          "Controlla tutto il periodo del torneo, non soltanto la data di apertura.",
          "Verifica gli impegni nei tornei, ritiri di allenamento, nazionali e viaggi.",
          "Valuta i costi di viaggio e hotel che dovrai sostenere se l'iscrizione viene accettata."
        ]
      },
      {
        "title": "Ciclo della richiesta d'iscrizione",
        "paragraphs": [
          "Presentare una richiesta non significa essere automaticamente ammessi. Il sistema valuta idoneità, classifica e posti disponibili nel tabellone. Programma conserva la cronologia delle richieste e degli esiti, così puoi distinguere Richiesta inviata, Tabellone principale, Qualificazioni e iscrizioni concluse."
        ]
      },
      {
        "title": "Qualificazioni e tabellone principale",
        "paragraphs": [
          "In base alla categoria e alla distribuzione dei posti, un giocatore può entrare direttamente nel tabellone principale oppure nelle qualificazioni. Chi supera le qualificazioni occupa uno dei posti previsti nel tabellone principale."
        ]
      },
      {
        "title": "Conflitti di calendario",
        "paragraphs": [
          "Il gioco impedisce le sovrapposizioni non consentite. Per esempio, non puoi prenotare un ritiro di allenamento che si sovrappone a una richiesta o iscrizione a un torneo. Anche viaggi e condizioni mediche influiscono sulla disponibilità."
        ]
      },
      {
        "title": "Notifiche d'iscrizione",
        "paragraphs": [
          "Richieste, ammissioni, pubblicazione dei tabelloni e preparazione ai tornei possono generare notifiche della carriera con collegamenti diretti al torneo o al Programma."
        ],
        "links": [
          {
            "label": "Apri il Calendario tornei",
            "href": "/game/calendar"
          },
          {
            "label": "Apri Programma",
            "href": "/game/schedule"
          }
        ]
      }
    ]
  },
  {
    "id": "tournament-categories",
    "title": "Categorie dei tornei e regole d'accesso",
    "summary": "Livelli del singolare, dimensioni dei tabelloni e punti classifica assegnati ai vincitori.",
    "sections": [
      {
        "title": "Livelli attuali dei tornei",
        "table": {
          "headers": [
            "Categoria",
            "Punti al vincitore",
            "Tabellone principale",
            "Qualificazioni max",
            "Posti dei qualificati",
            "Settimane"
          ],
          "rows": [
            [
              "Grand Slam 2000",
              "2000",
              "128",
              "128",
              "16",
              "2"
            ],
            [
              "Masters 1000",
              "1000",
              "64",
              "32",
              "8",
              "2"
            ],
            [
              "Tour 500",
              "500",
              "32",
              "16",
              "4",
              "1"
            ],
            [
              "Tour 250",
              "250",
              "32",
              "16",
              "4",
              "1"
            ],
            [
              "Challenger 125",
              "125",
              "32",
              "24",
              "6",
              "1"
            ],
            [
              "Challenger 100",
              "100",
              "32",
              "24",
              "6",
              "1"
            ],
            [
              "Challenger 75",
              "75",
              "32",
              "24",
              "6",
              "1"
            ],
            [
              "Challenger 50",
              "50",
              "32",
              "24",
              "6",
              "1"
            ],
            [
              "Futures 25",
              "25",
              "32",
              "32",
              "8",
              "1"
            ],
            [
              "Futures 15",
              "15",
              "32",
              "32",
              "8",
              "1"
            ]
          ]
        }
      },
      {
        "title": "Regole di programmazione",
        "bullets": [
          "Le categorie professionistiche standard prevedono una partita per giocatore e per giorno di gioco.",
          "Le qualificazioni si svolgono nella stessa città del torneo.",
          "Grand Slam e Masters durano due settimane di competizione; le categorie inferiori normalmente una.",
          "I Grand Slam possono avere fino a tre turni di qualificazione; le altre categorie elencate fino a due."
        ]
      },
      {
        "title": "Scegliere il livello giusto",
        "paragraphs": [
          "Le categorie più alte offrono più punti classifica, ma hanno avversari più forti e criteri di accesso più selettivi. Futures e Challenger sono tappe importanti dello sviluppo iniziale, non competizioni secondarie senza valore."
        ]
      },
      {
        "title": "Categoria delle nazionali",
        "paragraphs": [
          "Le competizioni nazionali sono gestite dalle federazioni nazionali e non vanno interpretate come normali categorie delle classifiche individuali ATP o WTA."
        ]
      }
    ]
  },
  {
    "id": "schedule-travel",
    "title": "Programma, impegni e viaggi",
    "summary": "Pagina Programma, preparazione, classi di viaggio, hotel e tempistiche automatiche.",
    "sections": [
      {
        "title": "Pagina Programma",
        "paragraphs": [
          "Programma mostra il prossimo torneo, gli impegni successivi, la cronologia delle richieste e i controlli di preparazione. L'elenco include soltanto le competizioni del tuo giocatore."
        ]
      },
      {
        "title": "Tempi di viaggio automatici",
        "paragraphs": [
          "Il motore di viaggio comune genera itinerari a partire da tornei e ritiri, geografia e orari delle partite. Registra partenza e destinazione, giorni di partenza e arrivo, costo del viaggio, stanchezza prevista e momento in cui il giocatore sarà pronto."
        ]
      },
      {
        "title": "Classi di viaggio",
        "table": {
          "headers": [
            "Classe",
            "Effetto nel gioco"
          ],
          "rows": [
            [
              "Economy",
              "Stanchezza da viaggio standard"
            ],
            [
              "Premium Economy",
              "Circa il 15% di stanchezza in meno"
            ],
            [
              "Business",
              "Circa il 35% di stanchezza in meno"
            ],
            [
              "Prima classe",
              "Circa il 50% di stanchezza in meno"
            ]
          ]
        }
      },
      {
        "title": "Hotel per i tornei",
        "table": {
          "headers": [
            "Hotel",
            "Caratteristica"
          ],
          "rows": [
            [
              "Hotel economico 2 stelle",
              "Costo minimo"
            ],
            [
              "Hotel standard 3 stelle",
              "Opzione equilibrata"
            ],
            [
              "Hotel Premium 4 stelle",
              "Comfort maggiore"
            ],
            [
              "Hotel di lusso 5 stelle",
              "Comfort massimo"
            ]
          ]
        }
      },
      {
        "title": "Gruppo di viaggio",
        "paragraphs": [
          "Puoi scegliere quali membri dello staff sotto contratto accompagnano il giocatore. Staff in viaggio aumenta costi di trasporto e alloggio, ma i benefici legati alla presenza si applicano soltanto quando il membro interessato viaggia realmente."
        ]
      },
      {
        "title": "Viaggi ravvicinati e rischio di mancata presenza",
        "paragraphs": [
          "Le tempistiche dei viaggi hanno effetti concreti. Se l'itinerario non permette al giocatore di essere pronto prima di una partita, potrebbe perdere per mancata presenza. Le transizioni dai ritiri prevedono, nei casi più stretti, due mezze giornate di viaggio passando dalla città di residenza."
        ],
        "links": [
          {
            "label": "Apri Programma",
            "href": "/game/schedule"
          }
        ]
      }
    ]
  },
  {
    "id": "tournament-preparation",
    "title": "Preparazione dei tornei",
    "summary": "Viaggio, hotel, staff, attrezzatura e tattiche prima delle competizioni.",
    "sections": [
      {
        "title": "Procedura di preparazione",
        "steps": [
          "Apri Programma e scegli Prepara il torneo per il prossimo evento.",
          "Seleziona una classe di viaggio e una categoria di hotel.",
          "Scegli i membri dello staff sotto contratto che accompagneranno il giocatore.",
          "Esamina il preventivo e il compromesso tra costi e stanchezza.",
          "Salva una tattica predefinita del torneo oppure mantieni quella attuale. Le opzioni comprendono approccio, durata degli scambi, strategia e piazzamento del servizio, risposta e posizione in campo, bersaglio sull'avversario e livello di rischio.",
          "Salva la preparazione: il motore comune ricalcola l'itinerario previsto."
        ]
      },
      {
        "title": "Tattica predefinita del torneo",
        "paragraphs": [
          "La tattica predefinita si applica alle partite del torneo, salvo quando salvi un piano specifico per una partita imminente. Così non serve creare una nuova tattica a ogni turno."
        ]
      },
      {
        "title": "Analisi dell'avversario e piani specifici",
        "paragraphs": [
          "Quando l'avversario è noto, la pagina della partita mostra informazioni pubbliche come mano dominante, stile e superficie preferita. Con un Analista delle prestazioni assunto puoi vedere intervalli approssimativi delle abilità, attendibilità del rapporto, tendenze osservate e considerazioni tattiche.",
          "Nei dettagli della partita puoi salvare un piano per il singolo avversario. Rimuovendo il piano specifico torni alla tattica predefinita del torneo. Il gioco valuta le scelte rispetto a entrambi i giocatori: sfruttare una debolezza reale può aiutare, ma usare una contromisura non adatta alle tue abilità può risultare inutile o dannoso."
        ]
      },
      {
        "title": "Condizione dell'attrezzatura",
        "paragraphs": [
          "Controlla la preparazione insieme al Centro attrezzatura. Gli effetti effettivi in partita dipendono dagli oggetti equipaggiati, dalla loro condizione e dalla compatibilità con la superficie del campo."
        ]
      },
      {
        "title": "La preparazione non elimina i vincoli di viaggio",
        "paragraphs": [
          "Una classe superiore può ridurre la stanchezza, ma non teletrasporta il giocatore. Distanza e orario della partita contano comunque: un arrivo impossibile può causare una sconfitta per mancata presenza."
        ],
        "links": [
          {
            "label": "Apri Programma",
            "href": "/game/schedule"
          },
          {
            "label": "Apri Attrezzatura",
            "href": "/game/equipment"
          }
        ]
      }
    ]
  },
  {
    "id": "matches",
    "title": "Tattiche e avanzamento nei tornei",
    "summary": "Tabelloni, orari, tattiche, risultati e progressione nei turni.",
    "sections": [
      {
        "title": "Tabellone ed eliminazione diretta",
        "paragraphs": [
          "Dopo la pubblicazione, la pagina del torneo mostra il tabellone a eliminazione diretta, l'avanzamento nei turni, gli eventuali bye e il percorso del giocatore. Gli stati delle partite distinguono Programmate, In diretta, Finali e Annullate."
        ]
      },
      {
        "title": "Dettagli della partita",
        "paragraphs": [
          "I dettagli mostrano giocatori, torneo, orari e punteggi. Quando disponibili sono riportate statistiche come ace, doppi falli, percentuale di prime, palle break convertite, colpi vincenti, errori non forzati e punti totali vinti."
        ]
      },
      {
        "title": "Controlli tattici",
        "paragraphs": [
          "Le tattiche modificano intenzione offensiva, tentativi di colpi vincenti, pressione in servizio e risposta, piazzamento del servizio (Automatico, Esterno, Corpo o T), posizione in risposta (Normale, Più vicino o Più lontano), durata degli scambi, posizione in campo, bersaglio avversario e rischio di errore.",
          "Puoi concentrarti su Diritto, Rovescio, Movimento, Resistenza o Seconda di servizio dell'avversario. La mano dominante cambia la geometria degli scambi ma non rappresenta un bonus intrinseco di forza. Scelte più aggressive offrono maggiori possibilità offensive, aumentando però i rischi tattici e fisici."
        ]
      },
      {
        "title": "Avanzamento dopo i risultati",
        "paragraphs": [
          "Una partita conclusa registra il vincitore e aggiorna il tabellone. I risultati confluiscono poi in contributi alla classifica, statistiche, premi in denaro e obiettivi degli sponsor pertinenti."
        ]
      },
      {
        "title": "Esiti senza partita disputata",
        "paragraphs": [
          "Una partita può concludersi senza il normale gioco per motivi di salute o viaggio previsti dal sistema. La mancata presenza per viaggio si verifica quando l'itinerario impedisce di essere pronti all'orario previsto. L'attrezzatura non perde durata quando la partita non viene giocata."
        ]
      },
      {
        "title": "Scontri diretti e percorso fino alla partita",
        "paragraphs": [
          "Se esiste una cronologia, i dettagli possono mostrare scontri diretti precedenti, risultati dei turni passati e percorso fino al turno attuale. Nel primo incontro tra due giocatori non esiste ancora uno storico degli scontri diretti."
        ]
      }
    ]
  },
  {
    "id": "singles-rankings",
    "title": "Classifiche di singolare ATP e WTA",
    "summary": "Organizzazione delle classifiche mondiali e visualizzazione delle variazioni di posizione.",
    "sections": [
      {
        "title": "Due circuiti separati",
        "paragraphs": [
          "Le classifiche di singolare ATP e WTA sono separate. Ogni giocatore compare solo nel proprio circuito. Le classifiche sono suddivise in pagine e i profili dei giocatori umani e IA in classifica possono essere aperti."
        ]
      },
      {
        "title": "Colonne della classifica",
        "bullets": [
          "Posizione",
          "Variazione di posizione",
          "Giocatore",
          "Paese",
          "Punti",
          "Variazione di punti"
        ]
      },
      {
        "title": "Nuove carriere",
        "paragraphs": [
          "Un nuovo giocatore inizia con zero punti ufficiali nel singolare, ma riceve subito una voce nella classifica per entrare nel sistema. I risultati dei tornei creano contributi attivi ai punti."
        ]
      },
      {
        "title": "Perché la posizione cambia senza un nuovo risultato",
        "paragraphs": [
          "La posizione è relativa agli altri. Può cambiare quando un altro giocatore guadagna punti, un vecchio risultato scade o si confrontano la precedente fotografia della classifica e quella appena pubblicata."
        ]
      },
      {
        "title": "Protezione classifica Premium",
        "paragraphs": [
          "Premium mostra fino ai prossimi cinque contributi in singolare in scadenza. È solo uno strumento di pianificazione: non conserva i punti."
        ],
        "links": [
          {
            "label": "Apri Classifiche",
            "href": "/game/rankings"
          }
        ]
      }
    ]
  },
  {
    "id": "doubles",
    "title": "Doppio e classifiche di doppio",
    "summary": "Disciplina separata, coppie nei tornei e attribuzione dei punti.",
    "sections": [
      {
        "title": "Disciplina separata",
        "paragraphs": [
          "Singolare e doppio vengono registrati separatamente. Il doppio ha richieste, risultati, punti, posizioni e contributi in scadenza propri. La posizione nel singolare non diventa una posizione nel doppio."
        ]
      },
      {
        "title": "La coppia",
        "paragraphs": [
          "Quando la procedura d'iscrizione lo richiede, per partecipare in doppio devi avere un compagno. Programma mostra richieste e stato della coppia separatamente rispetto al singolare."
        ]
      },
      {
        "title": "Classifica del doppio",
        "paragraphs": [
          "Nella pagina Classifiche puoi selezionare la classifica mondiale del doppio. I singoli giocatori ricevono contributi ai punti classifica dai risultati ottenuti in coppia."
        ]
      },
      {
        "title": "Notifiche del doppio",
        "paragraphs": [
          "Pubblicazione del tabellone, preparazione delle partite, risultati e scadenze della coppia possono comparire nelle Notifiche, con collegamenti diretti al torneo di doppio pertinente."
        ],
        "links": [
          {
            "label": "Apri Classifiche",
            "href": "/game/rankings"
          },
          {
            "label": "Apri Programma",
            "href": "/game/schedule"
          }
        ]
      }
    ]
  },
  {
    "id": "ranking-points",
    "title": "Punti classifica, contributi e scadenze",
    "summary": "Come i risultati diventano contributi attivi e quando vengono rimossi dal totale.",
    "sections": [
      {
        "title": "Modello dei contributi",
        "paragraphs": [
          "I punti classifica sono memorizzati come contributi ottenuti dai risultati, non come un numero permanente privo di spiegazione. Il totale corrente è la somma dei contributi attivi per giocatore e circuito."
        ]
      },
      {
        "title": "Punti massimi per categoria",
        "paragraphs": [
          "La categoria determina il massimo assegnabile al vincitore: 15/25 nei Futures, 50–125 nei Challenger, 250/500 nel Tour, 1000 nei Masters e 2000 nei Grand Slam. I turni precedenti seguono le regole della relativa categoria."
        ]
      },
      {
        "title": "Scadenza e cicli di difesa",
        "paragraphs": [
          "Ogni contributo attivo registra il giorno di gioco in cui sono stati assegnati i punti e quello di scadenza. Quando scade o viene sostituito nel ciclo di difesa, viene disattivato e il totale della classifica viene ricalcolato."
        ]
      },
      {
        "title": "Difendere punti",
        "paragraphs": [
          "Difendere i punti significa sostituire un risultato che sta per uscire dal totale attivo. Una nuova edizione del torneo non garantisce una sostituzione: serve comunque un risultato adeguato."
        ]
      },
      {
        "title": "Pianificazione Premium",
        "paragraphs": [
          "Premium mostra i prossimi cinque contributi in scadenza di singolare o doppio con torneo, risultato d'origine, punti, data di scadenza e giorni rimanenti. I punti scadono allo stesso modo per giocatori Free e Premium."
        ]
      }
    ]
  },
  {
    "id": "equipment",
    "title": "Centro attrezzatura ed effetti",
    "summary": "Spogliatoio, inventario, mercato, condizione, usura, superfici e spazi accessori attivi.",
    "sections": [
      {
        "title": "Famiglie di attrezzatura attive",
        "paragraphs": [
          "Il catalogo attuale comprende racchette, scarpe, abbigliamento e accessori. Gli accessori attivi sono borse, borracce, cappellini, asciugamani e polsini. Overgrip e antivibranti non sono categorie attive."
        ]
      },
      {
        "title": "Spogliatoio",
        "paragraphs": [
          "Racchetta, scarpe e abbigliamento hanno uno spazio attivo ciascuno. Gli accessori hanno uno spazio per tipologia. La configurazione partita attuale è quella di riferimento usata dal motore delle partite."
        ]
      },
      {
        "title": "Inventario",
        "paragraphs": [
          "Gli oggetti posseduti mostrano bonus adeguati alla condizione, durata, usura per partita, marca e valore di rivendita. Attrezzatura iniziale, acquisti e altri oggetti ottenuti rimangono nell'inventario finché non vengono venduti o eliminati."
        ]
      },
      {
        "title": "Mercato",
        "paragraphs": [
          "Gli acquisti sul Mercato dell'attrezzatura usano il denaro della carriera e vengono aggiunti all'inventario con condizione al 100%. Uno sponsor tecnico attivo nella categoria può ridurre il prezzo."
        ]
      },
      {
        "title": "Condizione e usura",
        "paragraphs": [
          "I modificatori effettivi usano la condizione corrente, non sempre il valore di catalogo al 100%. Le partite consumano gli oggetti secondo le rispettive regole di durata. Vittorie a tavolino e mancate presenze senza partita giocata non riducono la durata."
        ]
      },
      {
        "title": "Superficie e profilo del prodotto",
        "paragraphs": [
          "Alcuni oggetti hanno caratteristiche o compromessi legati a superficie e meteo. Il profilo finale combina bonus, condizione e compatibilità con il campo invece di sommare indiscriminatamente tutti i valori di catalogo."
        ]
      },
      {
        "title": "Vendere o eliminare",
        "paragraphs": [
          "Puoi vendere gli oggetti idonei al loro valore di rivendita attuale o eliminarli. Prima di rimuovere un oggetto equipaggiato devi sostituirlo o toglierlo, quando lo spazio non può rimanere in uno stato non valido."
        ],
        "links": [
          {
            "label": "Apri Centro attrezzatura",
            "href": "/game/equipment"
          }
        ]
      }
    ]
  },
  {
    "id": "technical-sponsors",
    "title": "Sponsor tecnici",
    "summary": "Partnership per racchette, scarpe e abbigliamento e relativi sconti.",
    "sections": [
      {
        "title": "Separati dallo sponsor principale",
        "paragraphs": [
          "Le sponsorizzazioni tecniche si gestiscono in Attrezzatura e sono separate dallo sponsor finanziario principale delle Finanze. I contratti tecnici sono specifici per categoria: racchette, scarpe e abbigliamento."
        ]
      },
      {
        "title": "Requisiti delle offerte",
        "paragraphs": [
          "Le offerte tecniche dipendono dal gruppo di classifica attuale. Le fasce determinano marchi disponibili, numero di offerte, sconti e possibili bonus alla firma."
        ]
      },
      {
        "title": "Modello dei benefici",
        "paragraphs": [
          "Il beneficio attuale consiste negli sconti: gli sponsor tecnici attivi riducono il prezzo in denaro della carriera dell'attrezzatura compatibile. Non forniscono quantità illimitate di prodotti gratuiti né sostituzioni automatiche gratis."
        ]
      },
      {
        "title": "Durata dei contratti",
        "paragraphs": [
          "Se non hai un contratto in una categoria, quello firmato può iniziare immediatamente. Negli ultimi 28 giorni di un contratto attivo puoi firmare un sostituto per la stessa categoria: il nuovo accordo inizierà quando quello attuale termina."
        ]
      },
      {
        "title": "Bonus alla firma e notifiche",
        "paragraphs": [
          "I contratti tecnici possono includere un bonus alla firma in denaro della carriera. Scadenza, inizio e conclusione producono notifiche; gli sconti cessano quando il contratto non è più attivo."
        ],
        "links": [
          {
            "label": "Apri Sponsor tecnici",
            "href": "/game/equipment"
          }
        ]
      }
    ]
  },
  {
    "id": "finance",
    "title": "Finanze ed economia della carriera",
    "summary": "Denaro della carriera, registro permanente, imposte, costi futuri e differenza dai Coins.",
    "sections": [
      {
        "title": "Denaro della carriera",
        "paragraphs": [
          "È la valuta professionale usata per staff, attrezzatura, ritiri, viaggi e hotel dei tornei, Vita privata e altre transazioni della carriera. Una nuova carriera inizia con 25.000 USD."
        ]
      },
      {
        "title": "Registro permanente",
        "paragraphs": [
          "Ogni movimento riporta data di gioco, categoria, origine, causale, importo e saldo risultante. Le Finanze mostrano quindi non solo il saldo, ma come è stato determinato."
        ]
      },
      {
        "title": "Entrate e uscite",
        "paragraphs": [
          "Le analisi distinguono entrate e spese. Le entrate tipiche includono premi, sponsorizzazioni e bonus; le spese comprendono viaggio, hotel, staff, allenamento e acquisti."
        ]
      },
      {
        "title": "Imposta mensile sul reddito",
        "paragraphs": [
          "La versione attuale applica un'aliquota fissa universale del 18% al reddito mensile imponibile. Le spese non sono deducibili. Il primo giorno di gioco del mese successivo il mese concluso viene liquidato una sola volta con una chiave di transazione idempotente."
        ]
      },
      {
        "title": "Impegni futuri",
        "paragraphs": [
          "Le Finanze mostrano la pressione dei costi previsti nei successivi 60 giorni di gioco. Controllali prima di prenotare un ritiro costoso, assumere staff, migliorare l'attrezzatura o comprare beni di lusso."
        ]
      },
      {
        "title": "Il denaro della carriera non è Coins",
        "paragraphs": [
          "I Coins sono una valuta facoltativa, usata da determinati sistemi. Denaro della carriera e Coins non sono intercambiabili."
        ],
        "links": [
          {
            "label": "Apri Finanze",
            "href": "/game/finance"
          }
        ]
      }
    ]
  },
  {
    "id": "main-sponsors",
    "title": "Sponsor principali e obiettivi",
    "summary": "Offerte stagionali, pagamenti settimanali e obiettivi di torneo.",
    "sections": [
      {
        "title": "Nessuno sponsor all'inizio",
        "paragraphs": [
          "Un nuovo giocatore parte senza uno sponsor principale e deve firmare una proposta durante la carriera."
        ]
      },
      {
        "title": "Come si generano le offerte",
        "paragraphs": [
          "Le offerte dipendono dalla classifica e dal mercato nazionale degli sponsor del giocatore. I giocatori più in alto in classifica possono ricevere anche offerte da marchi internazionali. Numero e valore delle offerte cambiano con la posizione."
        ]
      },
      {
        "title": "Finestra delle offerte settimanali",
        "paragraphs": [
          "Le offerte aperte appartengono a una finestra settimanale di gioco e possono scadere. Quando firmi uno sponsor principale stagionale, le altre offerte aperte per la stagione vengono chiuse."
        ]
      },
      {
        "title": "Denaro del contratto",
        "paragraphs": [
          "Lo sponsor principale firmato versa importi settimanali programmati nel denaro della carriera durante la stagione. Queste transazioni usano lo stesso registro finanziario permanente degli altri movimenti."
        ]
      },
      {
        "title": "Obiettivi",
        "paragraphs": [
          "Gli obiettivi degli sponsor possono indicare tornei o requisiti di prestazione specifici. Quelli pertinenti compaiono nel Calendario, aiutandoti a combinare impegni commerciali e obiettivi di classifica."
        ],
        "links": [
          {
            "label": "Apri Finanze / Sponsor",
            "href": "/game/finance"
          },
          {
            "label": "Apri Calendario",
            "href": "/game/calendar"
          }
        ]
      }
    ]
  }
]
