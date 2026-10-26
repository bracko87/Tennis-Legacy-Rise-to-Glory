export type LifestyleCopy = {
 title: string; subtitle: string; nationality: string; homeBase: string; currentLocation: string;
 morale: string; moraleNote: string; ownedJets: string; none: string; range: string; capacity: string;
 operating: string; fatigueBenefit: string; selectedResidence: string; movePending: string;
 setHomeBase: string; preferredTravel: string; cheapest: string; commercial: string;
 bestOwnedJet: string; askEveryTime: string; preferenceSaved: string; relocationScheduled: string;
 jetEligible: string; jetIneligible: string; relocateNote: string; jetMode: string;
 selectedJet: string; selectJet: string; quote: string; travelCost: string; staffOnBoard: string;
 staffCommercial: string; reposition: string; bookCommercial: string; bookJet: string;
 jetNotAvailable: string; save: string; loading: string; travelHours: string;
 staffIncluded: string; includedInFare: string; fullPartyCostNote: string;
 overnightTransfer: string; overnightCandidate: string; overnightTooLong: string; overnightDisclaimer: string;
 travelDays: string; refuelStops: string; refuelFees: string; routeStops: string; refuelDisclaimer: string
}

const english: LifestyleCopy = {
 title: 'Lifestyle and career', subtitle: 'Private Life improves comfort, not tennis skills.',
 nationality: 'Nationality', homeBase: 'Home base', currentLocation: 'Current location',
 morale: 'Lifestyle morale', moraleNote: 'Temporary, maximum +3; decreases over game days.',
 ownedJets: 'Travel-capable aircraft', none: 'None', range: 'Maximum flight range',
 capacity: 'Passenger seats', operating: 'One-way operating cost',
 fatigueBenefit: 'Travel fatigue reduction', selectedResidence: 'Active residence',
 movePending: 'Relocation scheduled', setHomeBase: 'Set as Home Base',
 preferredTravel: 'Preferred tournament travel', cheapest: 'Cheapest available',
 commercial: 'Commercial flight', bestOwnedJet: 'Best owned private jet',
 askEveryTime: 'Ask every time', preferenceSaved: 'Travel preference saved.',
 relocationScheduled: 'Relocation requested: moving in 2 game days. Cost: $5,000 plus the journey.',
 jetEligible: 'Tournament travel eligible', jetIneligible: 'Lifestyle aircraft only',
 relocateNote: 'Move from home only; 2 game-day transition and 30 game-day cooldown.',
 jetMode: 'Tournament flight', selectedJet: 'Selected private jet', selectJet: 'Choose a private jet',
 quote: 'Flight estimate', travelCost: 'Estimated one-way cost',
 staffOnBoard: 'Staff on jet', staffCommercial: 'Staff flying commercially',
 reposition: 'Aircraft repositioning', bookCommercial: 'Use commercial flight',
 bookJet: 'Use this private jet', jetNotAvailable: 'This aircraft cannot fly this route.',
 save: 'Save travel choice', loading: 'Checking flight options…', travelHours: 'Estimated flight hours',
 staffIncluded: 'Staff airfare', includedInFare: 'Included in one jet flight cost',
 fullPartyCostNote: 'One total flight charge covers the player and all selected staff; aircraft repositioning is included in the quote.',
 overnightTransfer: 'Overnight flight',overnightCandidate:'Flight time within 10h',overnightTooLong:'Flight time over 10h',
 overnightDisclaimer: 'Sunday-to-Monday scheduling still depends on actual tournament and match timing.',
 travelDays: 'Travel days', refuelStops: 'Refuelling stops', refuelFees: 'Refuelling fees',
 routeStops: 'Refuelling airports', refuelDisclaimer: 'Long routes require all flight legs to be within aircraft range. Extra stops increase travel time and reduce the fatigue advantage.',
}
const overrides: Record<string, Partial<LifestyleCopy>> = {
 de: {
  title:'Privatleben und Karriere',subtitle:'Luxus verbessert den Komfort, nicht die Tennisfähigkeiten.',
  nationality:'Nationalität',homeBase:'Wohnsitz',currentLocation:'Aktueller Standort',
  morale:'Lifestyle-Moral',moraleNote:'Vorübergehend, maximal +3; nimmt mit Spieltagen ab.',
  ownedJets:'Reisetaugliche Flugzeuge',none:'Keine',range:'Maximale Flugreichweite',
  capacity:'Passagierplätze',operating:'Betriebskosten pro Flugstrecke',
  fatigueBenefit:'Weniger Reisemüdigkeit',selectedResidence:'Aktiver Wohnsitz',
  movePending:'Umzug geplant',setHomeBase:'Als Wohnsitz festlegen',
  preferredTravel:'Bevorzugte Turnierreise',cheapest:'Günstigste Option',
  commercial:'Linienflug',bestOwnedJet:'Bester eigener Privatjet',askEveryTime:'Jedes Mal fragen',
  preferenceSaved:'Reisepräferenz gespeichert.',
  relocationScheduled:'Umzug in 2 Spieltagen geplant. Kosten: 5.000 $ plus Reise.',
  jetEligible:'Für Turnierreisen geeignet',jetIneligible:'Nur für den Lifestyle',
  relocateNote:'Umzug nur von zuhause; 2 Spieltage Umzugszeit und 30 Tage Sperrfrist.',
  jetMode:'Turnierflug',selectedJet:'Ausgewählter Privatjet',selectJet:'Privatjet auswählen',
  quote:'Flugkostenvoranschlag',travelCost:'Geschätzte Kosten (einfach)',
  staffOnBoard:'Teammitglieder im Jet',staffCommercial:'Teammitglieder im Linienflug',
  reposition:'Jet-Überführung',bookCommercial:'Linienflug wählen',bookJet:'Diesen Privatjet nutzen',
  jetNotAvailable:'Dieses Flugzeug kann diese Strecke nicht fliegen.',save:'Reiseauswahl speichern',
  loading:'Flüge werden geprüft…',travelHours:'Geschätzte Flugstunden',
  staffIncluded:'Flugkosten für das Team', includedInFare:'Im Gesamtpreis enthalten',
  fullPartyCostNote:'Ein Flugpreis für Spieler und Team, inklusive nötiger Überführung.',
  overnightTransfer:'Nachtflug',overnightCandidate:'Flugzeit innerhalb von 10 Std.',overnightTooLong:'Flugzeit über 10 Std.',
  overnightDisclaimer:'Sonntag-auf-Montag hängt weiterhin von den tatsächlichen Spielzeiten ab.',
  travelDays:'Reisetage',refuelStops:'Tankstopps',refuelFees:'Tankstoppgebühren',
  routeStops:'Zwischenlandungen',refuelDisclaimer:'Jede Teilstrecke muss innerhalb der Reichweite liegen; mehr Stopps kosten Zeit und verringern den Müdigkeitsvorteil.',
 },
 sr: {
  title:'Privatni život i karijera',subtitle:'Luksuz povećava udobnost, a ne teniske veštine.',
  nationality:'Državljanstvo',homeBase:'Mesto stanovanja',currentLocation:'Trenutna lokacija',
  morale:'Moral od luksuza',ownedJets:'Avioni za putovanja',none:'Nema',
  range:'Maksimalni domet',capacity:'Broj putnika',operating:'Trošak leta u jednom smeru',
  fatigueBenefit:'Smanjenje umora od putovanja',selectedResidence:'Aktivna adresa',
  movePending:'Selidba zakazana',setHomeBase:'Postavi kao mesto stanovanja',
  preferredTravel:'Željeni način putovanja',cheapest:'Najjeftinije',commercial:'Komercijalni let',
  bestOwnedJet:'Najbolji privatni avion',askEveryTime:'Pitaj svaki put',
  preferenceSaved:'Sačuvana podešavanja putovanja.',
  jetEligible:'Dostupan za turnirska putovanja',jetIneligible:'Samo privatna upotreba',
  jetMode:'Let za turnir',selectJet:'Izaberi privatni avion',bookJet:'Koristi ovaj avion',
  bookCommercial:'Komercijalni let',save:'Sačuvaj izbor',
  staffIncluded:'Let stručnog štaba',includedInFare:'Uključeno u ukupnu cenu',
  fullPartyCostNote:'Jedna cena leta pokriva igrača i odabrani stručni štab.',
  overnightTransfer:'Noćni let',overnightCandidate:'Let do 10 sati',overnightTooLong:'Let duži od 10 sati',
  overnightDisclaimer:'Prelaz nedelja–ponedeljak zavisi i od termina mečeva.',
  travelDays:'Dani putovanja',refuelStops:'Zaustavljanja za gorivo',refuelFees:'Trošak zaustavljanja',
  routeStops:'Aerodromi za dopunu goriva',refuelDisclaimer:'Svaka deonica mora biti u dometu aviona. Više stajanja znači više vremena i umora.',
 },
 es: {title:'Vida privada y carrera',nationality:'Nacionalidad',homeBase:'Residencia',currentLocation:'Ubicación actual',
  morale:'Moral por estilo de vida',ownedJets:'Aviones aptos para viajar',none:'Ninguno',range:'Autonomía',
  capacity:'Plazas',operating:'Coste de vuelo de ida',fatigueBenefit:'Reducción de fatiga de viaje',
  selectedResidence:'Residencia activa',movePending:'Mudanza programada',setHomeBase:'Establecer residencia',
  preferredTravel:'Transporte preferido',cheapest:'Más barato',commercial:'Vuelo comercial',
  bestOwnedJet:'Mejor jet propio',askEveryTime:'Preguntar siempre',jetEligible:'Apto para torneos',
  jetIneligible:'Solo uso privado',bookJet:'Usar este jet',bookCommercial:'Vuelo comercial',save:'Guardar'},
 fr: {title:'Vie privée et carrière',nationality:'Nationalité',homeBase:'Résidence',currentLocation:'Position actuelle',
  morale:'Moral lié au style de vie',ownedJets:'Avions utilisables',none:'Aucun',range:'Autonomie',
  capacity:'Passagers',operating:'Coût aller simple',fatigueBenefit:'Réduction de fatigue',
  selectedResidence:'Résidence principale',movePending:'Déménagement prévu',setHomeBase:'Définir comme résidence',
  preferredTravel:'Voyage préféré',cheapest:'Le moins cher',commercial:'Vol commercial',
  bestOwnedJet:'Meilleur jet privé',askEveryTime:'Demander à chaque fois',
  jetEligible:'Compatible avec les tournois',jetIneligible:'Loisir uniquement',bookJet:'Utiliser ce jet',
  bookCommercial:'Vol commercial',save:'Enregistrer'},
 it: {title:'Vita privata e carriera',nationality:'Nazionalità',homeBase:'Residenza',currentLocation:'Posizione attuale',
  morale:'Morale da stile di vita',ownedJets:'Aerei adatti ai viaggi',none:'Nessuno',range:'Autonomia massima',
  capacity:'Posti passeggeri',operating:'Costo per tratta',fatigueBenefit:'Riduzione fatica da viaggio',
  selectedResidence:'Residenza attiva',movePending:'Trasloco programmato',setHomeBase:'Imposta residenza',
  preferredTravel:'Viaggio preferito',cheapest:'Più economico',commercial:'Volo commerciale',
  bestOwnedJet:'Miglior jet privato',askEveryTime:'Chiedi ogni volta',
  jetEligible:'Adatto ai tornei',jetIneligible:'Solo uso privato',bookJet:'Usa questo jet',
  bookCommercial:'Volo commerciale',save:'Salva'},
 pt: {title:'Vida privada e carreira',nationality:'Nacionalidade',homeBase:'Residência',currentLocation:'Localização atual',
  morale:'Moral do estilo de vida',ownedJets:'Aviões aptos para viagens',none:'Nenhum',range:'Autonomia máxima',
  capacity:'Capacidade',operating:'Custo de ida',fatigueBenefit:'Redução da fadiga de viagem',
  selectedResidence:'Residência ativa',movePending:'Mudança agendada',setHomeBase:'Definir residência',
  preferredTravel:'Transporte preferido',cheapest:'Mais barato',commercial:'Voo comercial',
  bestOwnedJet:'Melhor jato próprio',askEveryTime:'Perguntar sempre',
  jetEligible:'Elegível para torneios',jetIneligible:'Apenas lazer',bookJet:'Usar este jato',
  bookCommercial:'Voo comercial',save:'Guardar'},
 ru: {title:'Личная жизнь и карьера',nationality:'Гражданство',homeBase:'Место проживания',
  currentLocation:'Текущее местоположение',morale:'Бонус настроя',ownedJets:'Самолёты для поездок',
  none:'Нет',range:'Дальность полёта',capacity:'Мест для пассажиров',
  operating:'Стоимость перелёта',fatigueBenefit:'Снижение усталости от поездки',
  selectedResidence:'Основной дом',movePending:'Переезд запланирован',setHomeBase:'Сделать основным домом',
  preferredTravel:'Предпочтительный транспорт',cheapest:'Самый дешёвый',commercial:'Коммерческий рейс',
  bestOwnedJet:'Лучший личный самолёт',askEveryTime:'Спрашивать каждый раз',
  jetEligible:'Подходит для поездок на турниры',jetIneligible:'Только для личного пользования',
  bookJet:'Использовать этот самолёт',bookCommercial:'Коммерческий рейс',save:'Сохранить'}
}
export const SUPPORTED_LIFESTYLE_LANGUAGES = ['en','sr','de','es','fr','it','ru','pt'] as const
export function lifestyleCopy(language: string): LifestyleCopy {
 const prefix = language.toLowerCase().split('-')[0]
 return {...english,...(overrides[prefix] ?? {})}
}
