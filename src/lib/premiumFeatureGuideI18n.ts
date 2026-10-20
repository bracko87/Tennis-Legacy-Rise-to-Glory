// The one source of truthful, localized Premium marketing descriptions.
// Keep this list aligned with modules actually wired into the application.
// Convenience Tools is intentionally not advertised because it is not implemented.
export const PREMIUM_INTELLIGENCE_IDS = [
  'statistics', 'deepMatch', 'development', 'training', 'tournaments',
  'season', 'staff', 'sponsors', 'finance', 'equipment', 'career',
] as const

export type PremiumIntelligenceId = typeof PREMIUM_INTELLIGENCE_IDS[number]
type BenefitCopy = {
  heading: string
  intro: string
  freeTitle: string
  freeIntro: string
  freeItems: [string, string, string, string]
  premiumTitle: string
  premiumIntro: string
  extrasTitle: string
  ranking: string
  privateLife: string
  trustNote: string
  coinsNote: string
  trialNote: string
  modules: Record<PremiumIntelligenceId, string>
}

const en: BenefitCopy = {
  heading: 'Exactly what Free and Premium include',
  intro: 'The tennis career stays playable for free. Premium provides extra analysis, planning and off-court features, not guaranteed sporting results.',
  freeTitle: 'Included in Free',
  freeIntro: 'These core game systems do not require a subscription:',
  freeItems: [
    'Create a player and enter ATP or WTA competitions.',
    'Train and develop skills, hire staff, manage equipment and your career finances.',
    'View official tournament outcomes, rankings, match results and core statistics.',
    'Use ordinary tournament entry, scheduling and match tactics. Optional coin actions are separate.',
  ],
  premiumTitle: 'Extra Premium intelligence',
  premiumIntro: 'Detailed, read-only reports and planning tools in 11 areas. Expand a module in its normal game page.',
  extrasTitle: 'Also included with Premium',
  ranking: 'See upcoming ranking-point expirations so you can plan how to protect your ranking.',
  privateLife: 'Build an off-court lifestyle with properties, possessions and investments using career money.',
  trustNote: 'Premium reports and scenarios are advisory: they do not promise wins, entry, earnings, ranking gains or skill points. All normal gameplay remains Free.',
  coinsNote: 'Premium membership is separate from Coins. Paid plans grant Coins according to the selected billing period; some optional actions still require Coins. Coin packs alone do not unlock Premium.',
  trialNote: 'The seven-day Premium trial includes Premium features but does not grant paid subscription Coins or start automatic billing.',
  modules: {
    statistics: 'Compare recorded win rates, aces and winners with leaderboard samples; the core statistics remain Free.',
    deepMatch: 'Examine recorded match factors and player strengths to better understand why you won or lost; results and replays stay Free.',
    development: 'Explore skill history and evidence-based development trends across in-game weeks, including Development Outlook.',
    training: 'Review actual training gains, efficiency and level-ups, then explore skill priorities and suggested focus rotations in Training Optimization.',
    tournaments: 'Compare tournament alternatives, entry context, known overlaps and published ranking/prize scenarios; official entries stay Free. Star future tournaments to get an in-game alert when applications open.',
    season: 'Explore a full-season calendar, save optional target tournaments and view hypothetical points, prize and scheduling trade-offs.',
    staff: 'Compare payroll commitments, staff value and documented role effects; hiring, firing and salaries remain Free.',
    sponsors: 'Review sponsor offer economics, guaranteed versus conditional income and objective deadlines; signing stays Free.',
    finance: 'Analyze historical income and expenses, known commitments and what-if cash scenarios without changing your balance.',
    equipment: 'Compare inventory costs, equipment condition and replacement economics; purchasing and equipment effects remain Free.',
    career: 'Track observed ranking trajectories, season changes, surface trends and career milestones beyond normal career records.',
  },
}
const sr: BenefitCopy = {
  heading:'Šta tačno dobijate uz Free i Premium', intro:'Teniska karijera ostaje besplatna. Premium dodaje analizu, planiranje i privatni život, a ne garantovane rezultate.',
  freeTitle:'Uključeno u Free', freeIntro:'Osnovni sistemi igre ne zahtevaju pretplatu:',
  freeItems:['Napravite igrača i igrajte ATP ili WTA turnire.','Trenirajte, razvijajte veštine, zaposlite osoblje i upravljajte opremom i novcem.','Pratite zvanične rezultate, rang liste, mečeve i osnovnu statistiku.','Prijave na turnire, raspored i taktike ostaju besplatni. Opcione akcije za novčiće su odvojene.'],
  premiumTitle:'Dodatna Premium inteligencija', premiumIntro:'Detaljni izveštaji i alati za planiranje u 11 oblasti. Otvorite modul na njegovoj stranici u igri.',
  extrasTitle:'Premium takođe uključuje', ranking:'Pogledajte kada ističu rang-bodovi i planirajte zaštitu plasmana.', privateLife:'Gradite privatni život kupovinom imovine i investiranjem novca iz karijere.',
  trustNote:'Premium analize i scenariji služe kao savet: ne garantuju pobede, prijave, zaradu, bodove ili razvoj veština. Osnovna igra ostaje besplatna.',
  coinsNote:'Premium i novčići su odvojeni. Plaćeni paketi daju novčiće prema periodu naplate; neke dodatne akcije se zasebno plaćaju novčićima. Kupovina novčića ne otključava Premium.',
  trialNote:'Sedmodnevni Premium probni period daje pristup funkcijama, ali ne donosi plaćene novčiće i ne pokreće automatsku naplatu.',
  modules:{
    statistics:'Uporedite stvarne procente pobeda, asove i vinere sa drugim igračima; osnovna statistika ostaje besplatna.',
    deepMatch:'Analizirajte zabeležene faktore meča i snagu igrača kako biste razumeli pobedu ili poraz; rezultati i snimci ostaju besplatni.',
    development:'Pratite istoriju veština i potvrđene trendove po nedeljama igre, uključujući razvojni pregled.',
    training:'Pratite stvarne dobitke, efikasnost i nivoe treninga, pa planirajte prioritetne veštine i rotaciju fokusa.',
    tournaments:'Uporedite turnire, uslove prijave, preklapanja i poznate bodove i nagrade; zvanične prijave ostaju besplatne. Obeleži buduće turnire za obaveštenje o otvaranju prijava.',
    season:'Planirajte sezonu, sačuvajte ciljne turnire i uporedite hipotetične bodove, nagrade i sukobe termina.',
    staff:'Uporedite troškove osoblja, plate i poznate efekte uloga; zapošljavanje ostaje besplatno.',
    sponsors:'Uporedite ponude sponzora, siguran i uslovan prihod i rokove ciljeva; ugovori ostaju besplatni.',
    finance:'Analizirajte prihode, troškove, obaveze i probne scenarije novca bez promene stvarnog stanja.',
    equipment:'Uporedite cenu inventara, stanje opreme i zamenu; kupovina i efekti ostaju besplatni.',
    career:'Pratite kretanje na rang listi, sezone, podloge i važne prekretnice mimo osnovnih rekorda.',
  },
}
const de: BenefitCopy = {
  heading:'Was Free und Premium wirklich enthalten', intro:'Deine Tenniskarriere bleibt kostenlos spielbar. Premium ergänzt Analysen, Planung und Privatleben, nicht garantierte Ergebnisse.',
  freeTitle:'In Free enthalten', freeIntro:'Diese Grundfunktionen benötigen kein Abo:',
  freeItems:['Erstelle einen Spieler und nimm an ATP- oder WTA-Turnieren teil.','Trainiere, verbessere Fähigkeiten und verwalte Personal, Ausrüstung und Karrierefinanzen.','Sieh offizielle Turnierresultate, Ranglisten, Match-Ergebnisse und Basisstatistiken.','Turnieranmeldungen, Spielplan und Taktiken bleiben kostenlos. Optionale Coin-Aktionen sind getrennt.'],
  premiumTitle:'Zusätzliche Premium-Analysen', premiumIntro:'Vertiefte Berichte und Planungswerkzeuge in 11 Bereichen. Öffne die Module auf ihrer jeweiligen Spielseite.',
  extrasTitle:'Außerdem mit Premium', ranking:'Sieh kommende Ranglistenpunkt-Verfälle und plane, wie du deine Position schützt.', privateLife:'Gestalte dein Privatleben mit Immobilien, Besitz und Investitionen aus Karrieregeld.',
  trustNote:'Premium-Berichte und Szenarien sind Empfehlungen. Sie garantieren weder Siege, Teilnahme, Einnahmen, Ranglistenpunkte noch Skillpunkte. Das Grundspiel bleibt kostenlos.',
  coinsNote:'Premium und Coins sind getrennt. Bezahlte Abos gewähren Coins je Abrechnungszeitraum; manche Optionen kosten weiterhin Coins. Coin-Pakete schalten Premium nicht frei.',
  trialNote:'Der siebentägige Premium-Test bietet die Funktionen, aber keine bezahlten Abo-Coins und keine automatische Abbuchung.',
  modules:{
    statistics:'Vergleiche erfasste Siegquoten, Asse und Winner mit Bestenlisten; Basisstatistiken bleiben kostenlos.',
    deepMatch:'Untersuche gemessene Matchfaktoren und Spielerstärken, um Siege oder Niederlagen zu verstehen. Ergebnisse und Replays bleiben kostenlos.',
    development:'Sieh Skillverläufe und belegte Entwicklungstrends nach Spielwochen inklusive Development Outlook.',
    training:'Prüfe reale Trainingsgewinne, Effizienz und Levelanstiege und plane Prioritäten und Fokusrotationen.',
    tournaments:'Vergleiche Turnieroptionen, Meldekontext, Überschneidungen sowie veröffentlichte Punkte und Preise. Anmeldungen bleiben kostenlos. Markiere künftige Turniere, um bei Anmeldestart benachrichtigt zu werden.',
    season:'Plane eine ganze Saison, speichere Wunschturniere und vergleiche hypothetische Punkte, Preisgelder und Terminkonflikte.',
    staff:'Vergleiche Gehaltsverpflichtungen, Kosten und dokumentierte Personaleffekte. Einstellen und Entlassen bleibt kostenlos.',
    sponsors:'Analysiere Angebote, sichere und bedingte Einnahmen sowie Zieltermine. Vertragsabschlüsse bleiben kostenlos.',
    finance:'Analysiere Einnahmen, Ausgaben, bekannte Verpflichtungen und hypothetische Kontostände ohne echte Buchungen.',
    equipment:'Vergleiche Besitzkosten, Materialzustand und Ersatzoptionen. Einkaufen und Effekte bleiben kostenlos.',
    career:'Verfolge Ranglistenverläufe, Saisonvergleiche, Belagtrends und Karrieremeilensteine über normale Rekorde hinaus.',
  },
}
const es: BenefitCopy = {
  heading:'Qué incluyen realmente Free y Premium', intro:'Tu carrera de tenis sigue siendo gratuita. Premium añade análisis, planificación y vida privada, no resultados garantizados.',
  freeTitle:'Incluido en Free', freeIntro:'Estos sistemas básicos no requieren suscripción:',
  freeItems:['Crea un jugador y compite en torneos ATP o WTA.','Entrena, desarrolla habilidades y gestiona personal, equipo y finanzas.','Consulta resultados oficiales, clasificaciones y estadísticas básicas.','Las inscripciones, el calendario y las tácticas siguen siendo gratuitos. Las acciones con monedas son aparte.'],
  premiumTitle:'Inteligencia Premium adicional', premiumIntro:'Informes avanzados y planificación en 11 áreas, accesibles desde sus páginas del juego.',
  extrasTitle:'Premium también incluye', ranking:'Consulta cuándo caducan los puntos de clasificación y planifica su protección.', privateLife:'Desarrolla tu vida privada con propiedades, objetos e inversiones pagados con dinero de tu carrera.',
  trustNote:'Los informes y escenarios Premium son orientativos: no garantizan victorias, inscripciones, ingresos ni puntos de clasificación o habilidades. El juego básico sigue siendo gratis.',
  coinsNote:'Premium y las monedas son independientes. Los planes de pago entregan monedas según la facturación; algunas acciones opcionales siguen requiriéndolas. Comprar monedas no activa Premium.',
  trialNote:'La prueba Premium de siete días incluye funciones Premium, pero no monedas de pago ni cobros automáticos.',
  modules:{
    statistics:'Compara victorias, aces y golpes ganadores registrados con muestras de la clasificación; las estadísticas básicas son gratuitas.',
    deepMatch:'Analiza los factores registrados y la fuerza de cada jugador para entender los partidos. Resultados y repeticiones son gratuitos.',
    development:'Consulta la evolución de habilidades y las tendencias por semanas del juego, incluido Development Outlook.',
    training:'Examina ganancias reales, eficiencia y niveles de entrenamiento, y planifica prioridades y rotaciones de enfoque.',
    tournaments:'Compara torneos, condiciones de inscripción, coincidencias y premios publicados. Inscribirse sigue siendo gratis. Marca torneos futuros para recibir avisos cuando se abran las inscripciones.',
    season:'Planifica toda la temporada, guarda torneos objetivo y explora puntos, premios y conflictos hipotéticos.',
    staff:'Compara salarios, compromisos y efectos registrados del personal; contratar sigue siendo gratuito.',
    sponsors:'Estudia ofertas, ingresos garantizados o condicionales y vencimientos de objetivos. Los contratos siguen siendo gratuitos.',
    finance:'Analiza ingresos, gastos, compromisos y escenarios de caja sin modificar el saldo real.',
    equipment:'Compara costes, estado del inventario y alternativas de sustitución. Comprar sigue siendo gratis.',
    career:'Sigue clasificaciones observadas, cambios de temporada, superficies e hitos más allá del historial básico.',
  },
}
const fr: BenefitCopy = {
  heading:'Ce que comprennent vraiment Free et Premium', intro:'Votre carrière de tennis reste gratuite. Premium ajoute des analyses, des outils de planification et une vie privée, sans garantir les résultats.',
  freeTitle:'Inclus dans Free', freeIntro:'Ces fonctions de base restent sans abonnement :',
  freeItems:['Créez un joueur et participez aux tournois ATP ou WTA.','Entraînez-vous, progressez et gérez personnel, équipement et finances.','Consultez résultats officiels, classements et statistiques de base.','Inscriptions, calendrier et tactiques restent gratuits. Les actions en Coins sont distinctes.'],
  premiumTitle:'Analyses Premium supplémentaires', premiumIntro:'Rapports détaillés et planification dans 11 domaines, sur leurs pages habituelles du jeu.',
  extrasTitle:'Également avec Premium', ranking:'Consultez les prochaines expirations de points au classement pour anticiper leur protection.', privateLife:'Créez une vie privée avec propriétés, biens et investissements financés par votre carrière.',
  trustNote:'Les rapports et simulations Premium sont des conseils : aucune victoire, inscription, recette ou progression n’est garantie. Le jeu de base reste gratuit.',
  coinsNote:'Premium et Coins sont distincts. Les offres payantes octroient des Coins selon la période facturée; certaines options en utilisent toujours. Les packs de Coins ne donnent pas Premium.',
  trialNote:'L’essai Premium de sept jours donne accès aux fonctions, mais n’octroie pas les Coins payants et ne déclenche aucune facturation.',
  modules:{
    statistics:'Comparez victoires, aces et coups gagnants enregistrés aux échantillons du classement; les statistiques de base restent gratuites.',
    deepMatch:'Analysez facteurs de match et forces des joueurs pour comprendre le résultat; scores et replays restent gratuits.',
    development:'Suivez les historiques de compétences et les tendances par semaine du jeu, y compris Development Outlook.',
    training:'Consultez gains, efficacité et niveaux réels puis préparez vos priorités et rotations d’entraînement.',
    tournaments:'Comparez tournois, contexte d’inscription, conflits et points ou prix publiés; les inscriptions restent gratuites. Marquez vos futurs tournois pour recevoir un avis à l’ouverture des inscriptions.',
    season:'Planifiez la saison, enregistrez des tournois cibles et comparez les scénarios de points, prix et conflits.',
    staff:'Comparez masse salariale, coûts et effets documentés; les embauches restent gratuites.',
    sponsors:'Analysez offres, revenus garantis ou conditionnels et échéances; signer un contrat reste gratuit.',
    finance:'Étudiez revenus, dépenses, engagements connus et scénarios de trésorerie sans toucher au solde.',
    equipment:'Comparez coûts, état du matériel et remplacement; achats et effets restent gratuits.',
    career:'Suivez rangs observés, saisons, surfaces et jalons au-delà des records ordinaires.',
  },
}
const it: BenefitCopy = {
  heading:'Cosa includono davvero Free e Premium', intro:'La carriera tennistica resta gratuita. Premium aggiunge analisi, pianificazione e vita privata, non risultati garantiti.',
  freeTitle:'Incluso in Free', freeIntro:'Queste funzioni principali non richiedono abbonamento:',
  freeItems:['Crea un giocatore e partecipa ai tornei ATP o WTA.','Allenati, migliora le abilità e gestisci staff, attrezzatura e finanze.','Consulta risultati ufficiali, classifiche e statistiche di base.','Iscrizioni, calendario e tattiche restano gratuiti. Le azioni con monete sono separate.'],
  premiumTitle:'Analisi Premium aggiuntive', premiumIntro:'Rapporti dettagliati e strumenti di pianificazione in 11 aree, nelle rispettive pagine.',
  extrasTitle:'Premium include anche', ranking:'Controlla le prossime scadenze dei punti ranking per proteggere la posizione.', privateLife:'Sviluppa la vita privata con proprietà, beni e investimenti finanziati dalla carriera.',
  trustNote:'I rapporti e gli scenari Premium sono indicativi: non garantiscono vittorie, iscrizioni, guadagni o punti. Il gioco principale resta gratuito.',
  coinsNote:'Premium e monete sono separati. Gli abbonamenti danno monete secondo il periodo pagato; alcune azioni richiedono ancora monete. Acquistarle non attiva Premium.',
  trialNote:'La prova Premium di sette giorni include le funzioni ma non le monete degli abbonamenti e non avvia addebiti automatici.',
  modules:{
    statistics:'Confronta percentuali di vittoria, ace e vincenti registrati con i dati della classifica; le statistiche base restano gratis.',
    deepMatch:'Analizza fattori registrati e forza dei giocatori per capire i risultati; punteggi e replay restano gratis.',
    development:'Osserva lo storico delle abilità e i trend nelle settimane di gioco, incluso Development Outlook.',
    training:'Studia guadagni, efficienza e livelli reali, poi pianifica priorità e rotazioni del focus.',
    tournaments:'Confronta tornei, accesso, sovrapposizioni e premi pubblicati; l’iscrizione rimane gratuita. Segna i tornei futuri per ricevere un avviso quando aprono le iscrizioni.',
    season:'Organizza la stagione, salva tornei obiettivo e valuta scenari ipotetici di punti, premi e date.',
    staff:'Confronta stipendi, costi ed effetti documentati dello staff; assunzioni e licenziamenti rimangono gratuiti.',
    sponsors:'Analizza offerte, introiti garantiti e condizionati e scadenze; firmare resta gratuito.',
    finance:'Valuta entrate, spese, obblighi e scenari di cassa senza modificare il saldo.',
    equipment:'Confronta costi, stato e sostituzione dell’attrezzatura; acquisti ed effetti restano gratuiti.',
    career:'Segui classifiche osservate, stagioni, superfici e traguardi oltre ai record normali.',
  },
}
const ru: BenefitCopy = {
  heading:'Что действительно входит в Free и Premium', intro:'Теннисная карьера остаётся бесплатной. Premium добавляет аналитику, планирование и личную жизнь, но не гарантирует побед.',
  freeTitle:'Доступно в Free', freeIntro:'Основные функции не требуют подписки:',
  freeItems:['Создавайте игрока и участвуйте в турнирах ATP или WTA.','Тренируйтесь, развивайте навыки, управляйте персоналом, экипировкой и финансами.','Смотрите официальные результаты, рейтинги и основную статистику.','Заявки, расписание и тактика бесплатны. Опциональные действия за монеты — отдельно.'],
  premiumTitle:'Дополнительная аналитика Premium', premiumIntro:'Подробные отчёты и планирование в 11 разделах на обычных страницах игры.',
  extrasTitle:'Также входит в Premium', ranking:'Узнавайте о скором сгорании рейтинговых очков и планируйте защиту позиции.', privateLife:'Покупайте имущество и инвестируйте заработанные в карьере средства для личной жизни.',
  trustNote:'Аналитика и сценарии Premium носят рекомендательный характер: победы, участие, доходы и очки не гарантируются. Основная игра бесплатна.',
  coinsNote:'Premium и монеты разделены. Платные планы выдают монеты за расчётный период; некоторые действия по-прежнему требуют монет. Покупка монет не открывает Premium.',
  trialNote:'Семидневный пробный Premium открывает функции, но не даёт платные монеты и не запускает автоматические списания.',
  modules:{
    statistics:'Сравнивайте реальные проценты побед, эйсы и виннеры с данными рейтинга; базовая статистика бесплатна.',
    deepMatch:'Анализируйте факторы матчей и силу игроков, чтобы понять результат; итоги и повторы бесплатны.',
    development:'Просматривайте историю навыков и тенденции по игровым неделям, включая Development Outlook.',
    training:'Изучайте реальные прибавки, эффективность и уровни, выбирайте приоритеты и смену фокуса.',
    tournaments:'Сравнивайте турниры, допуск, пересечения и опубликованные очки и призы; заявки бесплатны. Отмечайте будущие турниры и получайте уведомления об открытии заявок.',
    season:'Планируйте сезон, сохраняйте цели и оценивайте гипотетические очки, призы и конфликты дат.',
    staff:'Сравнивайте зарплаты, расходы и известные эффекты персонала; найм остаётся бесплатным.',
    sponsors:'Анализируйте предложения, гарантированные и условные выплаты и сроки целей; подписание бесплатно.',
    finance:'Анализируйте доходы, расходы, обязательства и сценарии баланса без настоящих переводов.',
    equipment:'Сравнивайте стоимость, состояние экипировки и варианты замены; покупки бесплатны.',
    career:'Отслеживайте рейтинговую динамику, сезоны, покрытия и вехи сверх основных рекордов.',
  },
}
const pt: BenefitCopy = {
  heading:'O que Free e Premium realmente incluem', intro:'A tua carreira de ténis continua gratuita. Premium acrescenta análise, planeamento e vida privada, não resultados garantidos.',
  freeTitle:'Incluído em Free', freeIntro:'Estes sistemas principais não precisam de subscrição:',
  freeItems:['Cria um jogador e participa em torneios ATP ou WTA.','Treina, desenvolve habilidades e gere pessoal, equipamento e finanças.','Consulta resultados oficiais, rankings e estatísticas básicas.','Inscrições, calendário e táticas continuam gratuitos. As ações com moedas são separadas.'],
  premiumTitle:'Inteligência Premium adicional', premiumIntro:'Relatórios aprofundados e planeamento em 11 áreas, nas páginas habituais do jogo.',
  extrasTitle:'Também incluído em Premium', ranking:'Consulta as próximas expirações de pontos do ranking e planeia proteger a posição.', privateLife:'Cria uma vida pessoal com propriedades, bens e investimentos pagos com dinheiro da carreira.',
  trustNote:'Relatórios e cenários Premium são apenas orientativos: não garantem vitórias, entradas, receitas nem pontos. O jogo principal continua gratuito.',
  coinsNote:'Premium e moedas são separados. Os planos pagos dão moedas consoante a faturação; algumas ações continuam a custar moedas. Comprar moedas não ativa Premium.',
  trialNote:'Os sete dias de teste Premium dão acesso às funções, mas não às moedas dos planos pagos nem a cobranças automáticas.',
  modules:{
    statistics:'Compara vitórias, ases e winners registados com dados da classificação; as estatísticas básicas são gratuitas.',
    deepMatch:'Analisa fatores de jogo e forças dos jogadores para compreender os resultados; marcadores e repetições são gratuitos.',
    development:'Explora a história das habilidades e tendências por semana do jogo, incluindo Development Outlook.',
    training:'Consulta ganhos, eficiência e níveis reais e planeia prioridades e rotações de foco.',
    tournaments:'Compara torneios, condições de inscrição, conflitos e prémios publicados; inscrever-se continua gratuito. Marca torneios futuros para seres avisado quando as inscrições abrirem.',
    season:'Planeia uma época inteira, guarda torneios alvo e compara cenários de pontos, prémios e datas.',
    staff:'Compara salários, custos e efeitos documentados do pessoal; contratar continua gratuito.',
    sponsors:'Analisa ofertas, valores garantidos ou condicionais e prazos; assinar contratos continua gratuito.',
    finance:'Analisa receitas, despesas, compromissos e cenários de caixa sem alterar o saldo real.',
    equipment:'Compara custos, condição e substituição de equipamento; compras e efeitos continuam gratuitos.',
    career:'Acompanha ranking, épocas, superfícies e marcos para lá dos registos normais.',
  },
}
const copies: Record<string, BenefitCopy> = {en, sr, de, es, fr, it, ru, pt}
export function premiumGuideCopy(language?: string): BenefitCopy {
  const code = (language ?? 'en').toLowerCase().split('-')[0]
  return copies[code] ?? en
}
