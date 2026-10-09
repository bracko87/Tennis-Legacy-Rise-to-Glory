import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCompetitionChaptersSr: ManualChapter[] = [
  {
    id: 'tournament-selection',
    title: 'Izbor turnira i prijave',
    summary: 'Kako izabrati događaj, poslati prijavu i razumeti razliku između prijave i prihvaćenog mesta.',
    sections: [
      s('Pre prijave', { steps: [
        'Proveri kategoriju turnira i očekivani nivo konkurencije.',
        'Uporedi podlogu sa veštinama i trenutnim stanjem igrača.',
        'Proveri kompletan period turnira, a ne samo datum početka.',
        'Proveri postojeće turnire, Trening kampove, aktivnosti Nacionalnog tima i putovanja.',
        'Razmisli o trošku putovanja i hotela koji sledi ako prijava bude prihvaćena.',
      ]}),
      s('Životni ciklus prijave', { paragraphs: [
        'Prijava za turnir je zahtev za ulazak, a ne potvrđeno mesto. Sistem prijava obrađuje zahteve prema uslovima, rang-listi i kapacitetu žreba. Raspored čuva istoriju prijava i prihvaćenih ishoda kako bi jasno razlikovao Prijavljen, Glavni žreb, Kvalifikacije i završene ishode.',
      ]}),
      s('Kvalifikacije i glavni žreb', { paragraphs: [
        'U zavisnosti od kategorije i raspodele mesta, igrač može direktno ući u glavni žreb ili u kvalifikacije. Kvalifikanti koji prođu mogu zauzeti predviđena mesta u glavnom žrebu.',
      ]}),
      s('Kalendarski konflikti', { paragraphs: [
        'Igra sprečava podržane nemoguće preklapanje. Na primer, Trening kamp ne može biti rezervisan preko postojeće prijave ili prihvaćenog turnira. Putovanja i zdravstveni sistem takođe utiču na dostupnost.',
      ]}),
      s('Obaveštenja o prijavi', { paragraphs: [
        'Važni događaji kao što su prijava, prihvatanje, objava žreba i dostupna priprema mogu kreirati obaveštenje sa direktnom akcijom ka odgovarajućem turniru ili Rasporedu.',
      ], links: [
        { label: 'Otvori Kalendar turnira', href: '/game/calendar' },
        { label: 'Otvori Raspored', href: '/game/schedule' },
      ]}),
    ],
  },
  {
    id: 'tournament-categories',
    title: 'Kategorije turnira i pravila ulaska',
    summary: 'Trenutna lestvica singl takmičenja, kapaciteti žreba i maksimalni poeni za pobednika.',
    sections: [
      s('Trenutna lestvica kategorija', { table: {
        headers: ['Kategorija', 'Poeni pobednika', 'Glavni žreb', 'Maks. kvalifikacije', 'Mesta kvalifikanata', 'Nedelje'],
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
      s('Pravila rasporeda', { bullets: [
        'Standardne profesionalne kategorije koriste najviše jedan meč po igraču na dan igre.',
        'Kvalifikacije se igraju u istom gradu kao i turnir.',
        'Grand Slam i Masters traju dve takmičarske nedelje; niže kategorije normalno traju jednu.',
        'Grand Slam može imati do tri kola kvalifikacija, dok ostale navedene kategorije imaju do dva.',
      ]}),
      s('Izbor odgovarajućeg nivoa', { paragraphs: [
        'Više kategorije nude veće prilike za poene rang-liste, ali imaju jača polja i teži ulazak. Futures i Challenger turniri su važan razvojni put na početku karijere, a ne popuna kalendara.',
      ]}),
      s('Kategorija Nacionalnog tima', { paragraphs: [
        'Takmičenje Nacionalnog tima vodi sistem Nacionalnog saveza i ne treba ga tumačiti kao standardnu individualnu kategoriju profesionalnog tura.',
      ]}),
    ],
  },
  {
    id: 'schedule-travel',
    title: 'Raspored, obaveze i putovanja',
    summary: 'Stranica Raspored, turnirske obaveze, klase putovanja, hoteli i automatsko planiranje puta.',
    sections: [
      s('Stranica Raspored', { paragraphs: [
        'Raspored prikazuje sledeći turnir, kasnije turnirske obaveze, istoriju prijava i kontrole pripreme. U listi se pojavljuju samo takmičenja koja pripadaju trenutnom igraču.',
      ]}),
      s('Automatsko vreme putovanja', { paragraphs: [
        'Zajednički sistem putovanja gradi plan na osnovu turnirskih i kamp obaveza, geografije i vremena meča. Beleži polazište i odredište, dan polaska/dolaska, trošak, očekivani umor i trenutak spremnosti.',
      ]}),
      s('Klase putovanja', { table: {
        headers: ['Klasa', 'Efekat u igri'],
        rows: [['Economy', 'Standardni umor od putovanja'], ['Premium Economy', 'Oko 15% manje umora od putovanja'], ['Business', 'Oko 35% manje umora od putovanja'], ['First Class', 'Oko 50% manje umora od putovanja']],
      }}),
      s('Turnirski hoteli', { table: {
        headers: ['Hotel', 'Pozicioniranje'],
        rows: [['Budget Hotel 2 zvezdice', 'Najniži trošak'], ['Standard Hotel 3 zvezdice', 'Uravnotežena opcija'], ['Premium Hotel 4 zvezdice', 'Veći komfor'], ['Luxury Hotel 5 zvezdica', 'Maksimalni komfor']],
      }}),
      s('Putni tim', { paragraphs: [
        'Aktivno osoblje može biti izabrano da putuje sa igračem. Osoblje povećava cenu putovanja i smeštaja, ali efekti koji zavise od prisustva važe samo kada taj član zaista putuje.',
      ]}),
      s('Tesna putovanja i rizik propuštanja meča', { paragraphs: [
        'Vreme putovanja nije samo vizuelno. Ako plan puta ne može da učini igrača spremnim pre zakazanog meča, igrač može propustiti meč. Prelazi iz Trening kampa koriste posebna putovanja preko grada prebivališta u dve polovine kada su datumi izuzetno tesni.',
      ], links: [{ label: 'Otvori Raspored', href: '/game/schedule' }]}),
    ],
  },
  {
    id: 'tournament-preparation',
    title: 'Priprema turnira',
    summary: 'Putovanje, hotel, osoblje, oprema i taktička priprema pre takmičenja.',
    sections: [
      s('Tok pripreme', { steps: [
        'Otvori Raspored i izaberi Pripremi turnir za sledeći događaj.',
        'Izaberi klasu putovanja i nivo hotela.',
        'Izaberi koji članovi ugovorenog osoblja putuju sa igračem.',
        'Pregledaj cenu putovanja i odnos troška prema umoru.',
        'Sačuvaj podrazumevanu turnirsku taktiku ili zadrži postojeću. Taktika uključuje pristup, dužinu razmene, servisnu strategiju i plasman, ritern strategiju i poziciju, poziciju na terenu, metu na protivniku i rizik.',
        'Sačuvaj pripremu; zajednički sistem putovanja ponovo izračunava plan puta.',
      ]}),
      s('Podrazumevana turnirska taktika', { paragraphs: [
        'Podrazumevana taktika turnira koristi se za mečeve na tom turniru osim kada konkretni meč ima sopstvenu izmenu. Tako nije potrebno praviti novu taktiku za svako kolo.',
      ]}),
      s('Analiza protivnika i izmene za konkretan meč', { paragraphs: [
        'Kada je protivnik poznat, stranica meča uvek prikazuje javne podatke poput dominantne ruke, stila igre i omiljene podloge. Ako je zaposlen Analitičar učinka, Analiza protivnika dodaje procenjene opsege veština, pouzdanost izveštaja, primećene navike i taktičke napomene.',
        'Detalj meča može sačuvati plan za konkretnog protivnika. Brisanje izmene vraća meč na podrazumevanu taktiku turnira. Taktički plan ocenjuje se prema oba igrača: iskorišćavanje stvarne slabosti može pomoći, dok kontra koja ne odgovara sopstvenim veštinama može biti beskorisna ili štetna.',
      ]}),
      s('Spremnost opreme', { paragraphs: [
        'Pripremu turnira treba proveriti zajedno sa Centrom za opremu. Autoritativni efekat opreme u meču koristi trenutno opremljene predmete, njihovo stanje i relevantno poklapanje sa podlogom.',
      ]}),
      s('Priprema ne poništava geografiju', { paragraphs: [
        'Skuplja klasa putovanja može smanjiti pritisak umora, ali ne teleportuje igrača. Geografija i vreme meča i dalje su važni, a nemoguća spremnost može izazvati propušten meč zbog putovanja.',
      ], links: [{ label: 'Otvori Raspored', href: '/game/schedule' }, { label: 'Otvori Opremu', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'matches',
    title: 'Taktika meča i napredovanje kroz turnir',
    summary: 'Žreb, termini meča, taktičke kontrole, rezultati i napredovanje kroz turnir.',
    sections: [
      s('Žreb i kostur', { paragraphs: [
        'Kada se objavi, stranica turnira prikazuje eliminacioni žreb, napredovanje po kolima, slobodna mesta kada postoje i put igrača kroz događaj. Stanja meča razlikuju Zakazan, Uživo, Završen i Otkazan.',
      ]}),
      s('Detalj meča', { paragraphs: [
        'Detalj meča prikazuje igrače, kontekst turnira, vreme, rezultat i, kada su zabeležene, statistike poput asova, duplih grešaka, procenta prvog servisa, iskorišćenih brejk lopti, vinera, neiznuđenih grešaka i ukupno osvojenih poena.',
      ]}),
      s('Taktičke kontrole', { paragraphs: [
        'Taktička podešavanja utiču na nameru napada, pokušaje vinera, pritisak servisa/riterna, plasman servisa (Automatic, Wide, Body ili T), poziciju riterna (Normal, Closer ili Deeper), dužinu razmene, poziciju na terenu, metu na protivniku i izloženost greškama.',
        'Meta na protivniku može biti Forhend, Bekhend, Kretanje, Izdržljivost ili Drugi servis. Dominantna ruka menja geometriju ovih obrazaca, ali sama po sebi nije bonus snage. Agresivnije odluke mogu doneti više dobitka uz veći taktički i fizički rizik.',
      ]}),
      s('Napredovanje rezultata', { paragraphs: [
        'Završen meč beleži pobednika i pomera žreb. Turnirski rezultat zatim utiče na doprinose rang-listi, statistiku, nagradni novac i relevantne sponzorske ciljeve.',
      ]}),
      s('Ishodi bez odigranog meča', { paragraphs: [
        'Meč može biti završen bez normalne igre zbog podržanih zdravstvenih ili putnih razloga. Travel no-show nastaje kada plan puta ne može učiniti igrača spremnim u vreme meča. Kada meč nije odigran, oprema se ne haba.',
      ]}),
      s('Međusobni skor i put do meča', { paragraphs: [
        'Kada istorija postoji, detalj meča može prikazati prethodne međusobne duele, rezultate ranijih kola i put igrača do trenutnog kola. Prvi međusobni duel prirodno nema H2H istoriju.',
      ]}),
    ],
  },
  {
    id: 'singles-rankings',
    title: 'ATP i WTA singl rang-liste',
    summary: 'Kako je organizovana svetska rang-lista i kako se prikazuju promene ranga.',
    sections: [
      s('Odvojeni svetovi', { paragraphs: [
        'ATP i WTA singl rang-liste su odvojene. Igrač se pojavljuje samo u odgovarajućem svetu. Rang-liste su podeljene po stranicama, a rangirani ljudski i AI igrači mogu se otvoriti kao profili.',
      ]}),
      s('Kolone rang-liste', { bullets: ['Rang', 'Promena ranga', 'Igrač', 'Država', 'Poeni', 'Promena poena'] }),
      s('Nove karijere', { paragraphs: [
        'Nova karijera počinje sa 0 zvaničnih singl poena, ali dobija zapis rangiranja kako bi odmah ušla u sistem. Rezultati turnira kreiraju aktivne doprinose rang-listi.',
      ]}),
      s('Zašto se rang menja bez novog rezultata', { paragraphs: [
        'Rang je relativan u odnosu na sve ostale. Igrač se može pomeriti jer drugi igrač osvaja poene, jer stari doprinos ističe ili jer se prethodni snapshot rang-liste poredi sa novoobjavljenim.',
      ]}),
      s('Premium Ranking Protection', { paragraphs: [
        'Premium prikazuje do sledećih pet aktivnih singl doprinosa koji uskoro ističu. Ovo je samo alat za planiranje i ne čuva poene.',
      ], links: [{ label: 'Otvori Rang-liste', href: '/game/rankings' }]}),
    ],
  },
  {
    id: 'doubles',
    title: 'Dubl i dubl rang-lista',
    summary: 'Odvojena disciplina dubla, partnerstva na turnirima i praćenje dubl ranga.',
    sections: [
      s('Odvojena disciplina', { paragraphs: [
        'Singl i dubl se beleže odvojeno. Dubl ima svoje prijave, rezultate turnira, poene, rang i doprinose koji ističu. Singl rang se ne pretvara u dubl rang.',
      ]}),
      s('Partnerstvo', { paragraphs: [
        'Za dubl je potreban partner kada tok prijave to zahteva. Raspored prikazuje dubl prijave i status partnerstva odvojeno od singl prijava.',
      ]}),
      s('Dubl rang-lista', { paragraphs: [
        'Na stranici Rang-liste može se prebaciti na svetsku dubl rang-listu. Pojedinačni igrači dobijaju dubl doprinose kroz rezultate partnerstva.',
      ]}),
      s('Dubl obaveštenja', { paragraphs: [
        'Objava žreba, priprema meča, rezultat i rokovi partnerstva mogu se pojaviti u Obaveštenjima sa direktnim linkom do odgovarajućeg dubl prikaza turnira.',
      ], links: [{ label: 'Otvori Rang-liste', href: '/game/rankings' }, { label: 'Otvori Raspored', href: '/game/schedule' }]}),
    ],
  },
  {
    id: 'ranking-points',
    title: 'Poeni rang-liste, doprinosi i isticanje',
    summary: 'Kako turnirski rezultati postaju aktivni doprinosi i kasnije izlaze iz ukupnog zbira.',
    sections: [
      s('Model doprinosa', { paragraphs: [
        'Poeni rang-liste čuvaju se kao doprinosi rezultata, a ne kao neobjašnjiv trajni broj. Trenutni zbir je suma aktivnih doprinosa igrača u odgovarajućem turu i disciplini.',
      ]}),
      s('Maksimalni poeni po kategoriji', { paragraphs: [
        'Kategorija određuje maksimalnu skalu pobedničkih poena: 15/25 na Futures nivou, 50–125 na Challenger nivou, 250/500 na Tour nivou, 1000 na Masters i 2000 na Grand Slam nivou. Ranija kola dobijaju vrednosti prema pravilima kategorije.',
      ]}),
      s('Isticanje i odbrana poena', { paragraphs: [
        'Svaki aktivni doprinos čuva dan dodele i dan isteka. Kada doprinos istekne ili bude zamenjen kroz ciklus odbrane, deaktivira se i ukupan rang se ponovo računa.',
      ]}),
      s('Odbrana poena', { paragraphs: [
        'Odbrana poena znači zamenu vrednosti koja treba da napusti aktivni zbir. Zakazana buduća edicija ne garantuje zamenu; igrač i dalje mora ostvariti odgovarajući rezultat.',
      ]}),
      s('Premium planiranje', { paragraphs: [
        'Premium prikazuje sledećih pet doprinosa u singlu ili dublu koji ističu, sa turnirom, izvorom rezultata, poenima, datumom isteka i preostalim danima. Samo isticanje je isto za Free i Premium igrače.',
      ]}),
    ],
  },
  {
    id: 'equipment',
    title: 'Centar za opremu i efekti opreme',
    summary: 'Gear Room, Inventar, Market, stanje, habanje, podloga i aktivni slotovi dodataka.',
    sections: [
      s('Aktivne porodice opreme', { paragraphs: [
        'Trenutni katalog sadrži rekete, obuću, odeću i dodatke. Aktivni tipovi dodataka su torbe, flaše, kačketi, peškiri i znojnice. Overgrip i dampener nisu aktivne kategorije.',
      ]}),
      s('Gear Room', { paragraphs: [
        'Reket, obuća i odeća koriste po jedan aktivni slot. Dodaci koriste jedan aktivni slot za svaki tip. Current Match Setup je autoritativna opremljena konfiguracija koju koriste sistemi meča.',
      ]}),
      s('Inventar', { paragraphs: [
        'Predmeti u vlasništvu prikazuju bonuse prilagođene stanju, trajnost, habanje po meču, brend i prodajnu vrednost. Početna oprema, kupovine i druga stečena oprema ostaju u Inventaru dok se ne prodaju ili odbace.',
      ]}),
      s('Market', { paragraphs: [
        'Kupovine na Marketu opreme koriste Career Cash i ulaze u Inventar sa 100% stanjem. Aktivni odgovarajući tehnički sponzor može smanjiti cenu.',
      ]}),
      s('Stanje i habanje', { paragraphs: [
        'Gameplay modifikatori koriste trenutno stanje umesto kataloške vrednosti na 100%. Mečevi smanjuju stanje prema pravilima trajnosti/habanja. Walkover ili no-show bez odigranog meča ne smanjuju trajnost opreme.',
      ]}),
      s('Poklapanje podloge i profil proizvoda', { paragraphs: [
        'Neki proizvodi imaju karakteristike podloge/vremena ili kompromise. Završni profil opreme kombinuje bonuse predmeta, stanje i poklapanje sa podlogom umesto prostog sabiranja svih kataloških vrednosti.',
      ]}),
      s('Prodaja i odbacivanje', { paragraphs: [
        'Oprema koja ispunjava uslove može se prodati po trenutnoj prodajnoj vrednosti ili odbaciti. Opremljeni predmet mora prvo biti zamenjen ili skinut kada slot ne sme ostati u nevažećem stanju.',
      ], links: [{ label: 'Otvori Centar za opremu', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'technical-sponsors',
    title: 'Tehnički sponzori',
    summary: 'Sponzorstva brendova za rekete, obuću i odeću i njihov uticaj na cenu opreme.',
    sections: [
      s('Odvojeno od glavnog sponzora', { paragraphs: [
        'Tehnička sponzorstva nalaze se u Oprema i odvojena su od glavnog sponzora karijere u Finansijama. Tehnički ugovori su po kategorijama: reket, obuća i odeća.',
      ]}),
      s('Uslovi za ponude', { paragraphs: [
        'Tehničke ponude generišu se prema trenutnoj grupi ranga igrača. Rang opseg utiče na dostupni nivo brenda, broj ponuda, raspon popusta i mogući bonus za potpis.',
      ]}),
      s('Trenutni model pogodnosti', { paragraphs: [
        'Implementirana pogodnost zasniva se na popustu. Aktivni tehnički sponzor smanjuje Career Cash cenu odgovarajuće opreme. Trenutni model ne daje neograničenu besplatnu opremu niti automatske besplatne zamene.',
      ]}),
      s('Vreme ugovora', { paragraphs: [
        'Ako nema aktivnog ugovora u kategoriji, potpisana ponuda može početi odmah. Kada aktivni ugovor uđe u poslednjih 28 dana, može se potpisati zamenski ugovor koji počinje nakon isteka trenutnog.',
      ]}),
      s('Bonus za potpis i obaveštenja', { paragraphs: [
        'Tehnički ugovori mogu uključiti Career Cash bonus za potpis. Isticanje, početak i završetak ugovora kreiraju obaveštenja; popust prestaje kada relevantni ugovor više nije aktivan.',
      ], links: [{ label: 'Otvori Tehničke sponzore', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'finance',
    title: 'Finansije i ekonomija karijere',
    summary: 'Career Cash, trajni ledger, porezi, budući troškovi i razlika između novca i Coina.',
    sections: [
      s('Career Cash', { paragraphs: [
        'Career Cash je profesionalna valuta karijere za osoblje, opremu, Trening kampove, turnirska putovanja/hotele, Privatni život i druge transakcije. Nova karijera počinje sa $25.000 USD.',
      ]}),
      s('Trajna evidencija', { paragraphs: [
        'Svaka promena Career Cash beleži se sa datumom igre, kategorijom, izvorom, razlogom, iznosom i novim stanjem. Finansije zato prikazuju ne samo stanje nego i kako je nastalo.',
      ]}),
      s('Prihodi i rashodi', { paragraphs: [
        'Finansijska analitika razdvaja prihode i rashode. Tipični prihodi su nagradni novac, sponzorstva i bonusi; tipični rashodi su putovanja, hoteli, osoblje, trening i kupovine.',
      ]}),
      s('Mesečni porez na prihod', { paragraphs: [
        'Trenutna univerzalna verzija poreza koristi ravnu stopu od 18% na oporezivi mesečni prihod. Rashodi nisu odbitak u ovoj verziji. Prvog dana sledećeg meseca završeni mesec se obračunava jednom, uz idempotentni ključ transakcije.',
      ]}),
      s('Predstojeće obaveze', { paragraphs: [
        'Finansije prikazuju pritisak budućih troškova za narednih 60 dana igre. Proveri ga pre skupog kampa, ugovora sa osobljem, nadogradnje opreme ili luksuzne kupovine.',
      ]}),
      s('Career Cash nije Coin', { paragraphs: [
        'Coini su opciona Premium/game valuta za određene opcione sisteme. Career Cash i Coini ne mogu zameniti jedno drugo.',
      ], links: [{ label: 'Otvori Finansije', href: '/game/finance' }]}),
    ],
  },
  {
    id: 'main-sponsors',
    title: 'Glavni sponzori i sponzorski ciljevi',
    summary: 'Sezonske sponzorske ponude, nedeljne isplate i turnirski ciljevi.',
    sections: [
      s('Nema sponzora na početku karijere', { paragraphs: ['Novi igrač počinje bez glavnog sponzora i mora potpisati ponudu tokom karijere.'] }),
      s('Kako se generišu ponude', { paragraphs: [
        'Ponude glavnih sponzora zavise od ranga i koriste nacionalnu tržišnu grupu sponzora igrača. Bolje rangirani igrači mogu dobiti i ponude globalnih brendova. Broj ponuda i vrednost ugovora menjaju se sa rangom.',
      ]}),
      s('Nedeljni prozor ponuda', { paragraphs: [
        'Otvorene sponzorske ponude pripadaju određenoj nedelji igre i mogu isteći. Kada je sezonski glavni sponzor potpisan, ostale otvorene ponude glavnih sponzora za tu sezonu se zatvaraju.',
      ]}),
      s('Novac iz ugovora', { paragraphs: [
        'Potpisani glavni sponzor isplaćuje planirane nedeljne Career Cash iznose kroz sezonu. Sponzorske transakcije koriste isti trajni finansijski ledger kao i ostali novac karijere.',
      ]}),
      s('Ciljevi', { paragraphs: [
        'Aktivni sponzorski ciljevi mogu označiti ciljne turnire ili zahteve učinka. Relevantni turnirski ciljevi pojavljuju se u Kalendaru kako bi igrač mogao planirati komercijalne obaveze zajedno sa ciljevima rang-liste.',
      ], links: [{ label: 'Otvori Finansije / Sponzorstva', href: '/game/finance' }, { label: 'Otvori Kalendar', href: '/game/calendar' }]}),
    ],
  },
]
