import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCoreChaptersSr: ManualChapter[] = [
  {
    id: 'getting-started',
    title: 'Početak igre',
    summary: 'Praktičan uvod u Tennis Legacy karijeru, glavne stranice i odluke koje su najvažnije na početku.',
    sections: [
      s('Šta je Tennis Legacy', { paragraphs: [
        'Tennis Legacy: Rise to Glory je trajna menadžerska igra profesionalne teniske karijere. Upravljaš jednim ljudskim igračem u ATP ili WTA svetu, planiraš razvoj, prijavljuješ turnire, upravljaš putovanjima i opremom, gradiš stručni tim, vodiš finansije i reaguješ na zdravlje, rang-listu i kalendarske obaveze kroz više sezona igre.',
        'ATP i WTA su odvojeni takmičarski svetovi za singl i dubl rang-liste. Društveni sistemi, kao što su Teniski klubovi, mogu imati članove sa oba tura, dok prijave, rang-lista i rezultati ostaju vezani za tur konkretnog igrača.',
      ]}),
      s('Preporučen redosled u prvoj sesiji', { steps: [
        'Otvori Pregled i proveri trenutni datum igre, rang, spremnost, Career Cash, sledeću obavezu i lična obaveštenja.',
        'Otvori Veštine da razumeš tehnički, fizički i trenutni profil spremnosti igrača.',
        'Otvori Trening i podesi redovni nedeljni plan. Nova karijera počinje bez podešenog plana redovnog treninga.',
        'Otvori Opremu. Nova karijera već ima početni reket, obuću i odeću koji su opremljeni.',
        'Pre prijave proveri Kalendar turnira. Obrati pažnju na kategoriju, podlogu, termin i posledice putovanja.',
        'Nakon prijave ili prihvatanja otvori Raspored. Tu upravljaš turnirskim obavezama, pripremom i putovanjem.',
        'Redovno proveravaj Finansije. Career Cash je odvojen od Coina i svaka promena stanja novca trajno se beleži.',
      ]}),
      s('Osnovni tok karijere', { bullets: [
        'Planiraj trening, turnire, putovanja, opremu i stručni tim u skladu sa kalendarom.',
        'Pre takmičenja pripremi umor, zdravlje, taktiku, opremu i putovanje.',
        'Takmiči se za rezultate, poene za rang-listu, statistiku, nagradni novac i napredak sponzorskih ciljeva.',
        'Oporavljaj se i razvijaj kroz redovni trening, Trening kampove i razumno upravljanje opterećenjem.',
        'Ponovo ulaži Career Cash u osoblje, opremu, kampove, putovanja, hotele i kupovine u Privatnom životu.',
        'Pregledaj Rang-liste, Statistiku, Obaveštenja i Finansije da vidiš posledice ranijih odluka.',
      ]}),
      s('Gde da tražiš pomoć', { paragraphs: [
        'Za pravila i objašnjenja procesa koristi ovaj Kompletan priručnik igre. Centar za pomoć vodi i do Kontakt podrške i zvaničnog Tennis Legacy Discorda. Kada prijavljuješ problem, navedi stranicu, ime igrača, screenshot i tačne korake za ponavljanje.',
      ], links: [
        { label: 'Otvori Pregled', href: '/game/overview' },
        { label: 'Otvori Centar za pomoć', href: '/game/help' },
      ]}),
    ],
  },
  {
    id: 'creating-a-career',
    title: 'Kreiranje karijere',
    summary: 'Kako funkcioniše kreiranje igrača i koji tačno početni paket dobija svaka nova ljudska karijera.',
    sections: [
      s('Izbori pri kreiranju karijere', { bullets: [
        'Tur: izaberi ATP ili WTA. Ovo određuje takmičarski svet i rang-listu kojoj igrač pripada.',
        'Identitet: izaberi realistično ime, prezime i nacionalnost. Profesionalno ime igrača je trajno nakon kreiranja.',
        'Grad prebivališta: izaberi podržani grad za izabranu državu. Grad koristi sistem putovanja i Privatnog života.',
        'Portret: opcioni. Portreti iz kataloga koje već koristi druga aktivna karijera nisu dostupni.',
        'Omiljena podloga: tvrda, šljaka ili trava.',
        'Stil igre: agresivni osnovac, defanzivni osnovac, igra na celom terenu ili servis i volej.',
        'Dominantna ruka: desna ili leva. Ruka menja uglove servisa, geometriju razmena i taktičke duele; ne daje besplatne poene za forhend ili bekhend.',
      ]}),
      s('Tačan početni paket', { table: {
        headers: ['Sistem', 'Početno stanje'],
        rows: [
          ['Career Cash', '$25.000 USD'], ['Coini', '20 Coina, dodeljuju se jednom'], ['Poeni singl rang-liste', '0'],
          ['Poeni dubl rang-liste', '0'], ['Redovni trening', 'Nije podešen'], ['Stručni tim', 'Nema'],
          ['Glavni sponzor', 'Nema'], ['Tehnički sponzori', 'Nema'], ['Nacionalni savez', 'Nije član'],
          ['Teniski klub', 'Nije član'], ['Kalendarske obaveze', 'Nema'], ['Umor', '0'], ['Oštrina', '50'],
          ['Moral', '50'], ['Samopouzdanje', '50'], ['Fokus', '50'],
          ['Početni reket', 'Rosignol F-200 Carbon, stanje 100%, opremljen'],
          ['Početna obuća', 'Antta PG 7, stanje 100%, opremljena'],
          ['ATP početna odeća', 'BlokUV Guardian Court, stanje 100%, opremljena'],
          ['WTA početna odeća', 'BlokUV Solar Shield 8, stanje 100%, opremljena'],
          ['Početni dodaci', 'Nema'], ['Besplatni Privatni život', 'Nema početne nekretnine'],
          ['Premium Privatni život', 'Jedan početni apartman u gradu prebivališta koji se ne može prodati'],
        ],
      }}),
      s('Jednokratna inicijalizacija', { paragraphs: [
        'Inicijalizacija karijere je idempotentna. Osvežavanje, ponovni pokušaj ili ponovno otvaranje igre ne sme da duplira početnih $25.000, 20 Coina, početnu opremu ili Premium apartman. Audit inicijalizacije beleži primenjenu verziju početne šeme.',
      ]}),
      s('Restart ili brisanje naloga', { paragraphs: [
        'Igrač i nalog sadrži destruktivne opcije za restart i trajno brisanje. Koristi ih samo ako zaista želiš da ukloniš trenutno stanje karijere. Početni Coini su zaštićeni od dupliranja prostim osvežavanjem ili ponovnim pokušajem.',
      ], links: [{ label: 'Otvori Igrač i nalog', href: '/game/player-account' }]}),
    ],
  },
  {
    id: 'overview',
    title: 'Pregled i dnevni tok karijere',
    summary: 'Kako čitati kontrolni centar karijere i koristiti ga kao početnu tačku svakog dana u igri.',
    sections: [
      s('Šta prikazuje Pregled', { bullets: [
        'Profesionalni profil i trenutni kontekst rang-liste.',
        'Sledeći turnir i sledeći zakazani meč kada su poznati.',
        'Rezultat prethodnog meča.',
        'Stanje Career Finance uz sezonske prihode, rashode i neto tok.',
        'Sledeću obavezu i turnirsku aktivnost trenutnog dana.',
        'Statistiku forme u sezoni.',
        'Spremnost i trenutne informacije o treningu.',
        'Brzi pristup opremi, stručnom timu i klubu.',
        'Nedavne zvanične rezultate na turu i lična obaveštenja.',
      ]}),
      s('Premium Ranking Protection', { paragraphs: [
        'Premium nalog može proširiti Ranking Protection i videti sledećih pet aktivnih doprinosa rang-listi koji uskoro ističu. Ovo je samo pomoć za planiranje: Premium ne sprečava istek poena i ne menja rezultate mečeva ili rangiranja.',
      ]}),
      s('Koristan dnevni redosled', { steps: [
        'Prvo pročitaj lična obaveštenja.',
        'Proveri sledeću obavezu i sledeći meč.',
        'Proveri spremnost, umor i Zdravlje ako se približava trening ili takmičenje.',
        'Pre nove prijave proveri Raspored ili Kalendar.',
        'Pre potpisa osoblja, rezervacije kampa, kupovine opreme ili skupog putovanja proveri Finansije.',
        'Za dugoročne trendove koristi Rang-liste i Statistiku.',
      ], links: [{ label: 'Otvori Pregled', href: '/game/overview' }]}),
    ],
  },
  {
    id: 'player-profile-account',
    title: 'Profil igrača i nalog',
    summary: 'Identitet, javni profil, upravljanje avatarom, bezbednost i destruktivne akcije nad nalogom.',
    sections: [
      s('Javni identitet igrača', { paragraphs: [
        'Profesionalni profil predstavlja karijeru u rang-listama, turnirima i društvenim prikazima. Drugi menadžeri mogu otvoriti igrača iz Rang-lista i videti njegov javni profil.',
      ]}),
      s('Stranica Igrač i nalog', { bullets: [
        'Prikazuje trajno ime igrača, email naloga, takmičarski svet i državu.',
        'Prikazuje trenutni avatar i tok zamene avatara.',
        'Promena lozinke koristi potvrđeni email za resetovanje.',
        'Danger Zone sadrži restart karijere i trajno brisanje igrača/naloga.',
      ]}),
      s('Zamena avatara', { paragraphs: [
        'Zamena avatara koristi proces pregleda. Igrač može dostaviti referentnu fotografiju i željene boje dresa. Referentne fotografije su privremene i automatski se brišu u predviđenom periodu čuvanja. Pripremljeni avatar zatim mora biti odobren ili odbijen pre upotrebe.',
      ]}),
      s('Privatne poruke sa profila', { paragraphs: [
        'Sa javnog profila drugog ljudskog igrača može se pokrenuti privatni razgovor u Menadžerskom sandučetu. Samo ta dva menadžera mogu da čitaju razgovor.',
      ], links: [
        { label: 'Otvori Igrač i nalog', href: '/game/player-account' },
        { label: 'Otvori Rang-liste', href: '/game/rankings' },
      ]}),
    ],
  },
  {
    id: 'skills',
    title: 'Veštine i početni identitet igrača',
    summary: 'Tehničke i fizičke veštine, atributi spremnosti i način na koji podloga i stil oblikuju novog igrača.',
    sections: [
      s('Tehnički atributi', { table: {
        headers: ['Atribut', 'Značenje'],
        rows: [
          ['Servis', 'Snaga, plasman i pouzdanost servisa'], ['Forhend', 'Glavni napadački udarac sa osnovne linije'],
          ['Bekhend', 'Kvalitet, kontrola i stabilnost'], ['Ritern', 'Neutralisanje i napad na servis'],
          ['Volej', 'Igra na mreži i završavanje poena'], ['Slajs', 'Varijacija i kontrola niskih lopti'],
          ['Drop šot', 'Osećaj i kratka varijacija'], ['Lob', 'Visina, dubina i preciznost preko protivnika'],
          ['Smeč', 'Tajming, snaga i završavanje iznad glave'],
        ],
      }}),
      s('Fizički atributi', { table: {
        headers: ['Atribut', 'Značenje'],
        rows: [['Kondicija', 'Opšta sportska spremnost'], ['Izdržljivost', 'Održavanje kvaliteta u dugim mečevima'], ['Oporavak', 'Oporavak između mečeva i sesija'], ['Kretanje', 'Pokrivanje terena, brzina i ravnoteža']],
      }}),
      s('Spremnost i mentalno stanje', { table: {
        headers: ['Atribut', 'Značenje'],
        rows: [['Moral', 'Trenutna motivacija i emocionalno stanje'], ['Samopouzdanje', 'Vera oblikovana formom i rezultatima'], ['Oštrina', 'Takmičarski ritam i spremnost za meč'], ['Fokus', 'Koncentracija i mentalna stabilnost'], ['Umor', 'Akumulirani zamor; niže je bolje']],
      }}),
      s('Početni profili podloge', { paragraphs: [
        'Tvrda podloga, šljaka i trava počinju sa različitim raspodelama tehničkih poena, ali sva tri osnovna profila imaju tačno 450 tehničkih poena. Izbor podloge gradi identitet, a ne besplatnu ukupnu prednost.',
      ], table: {
        headers: ['Veština', 'Tvrda', 'Šljaka', 'Trava'],
        rows: [
          ['Servis', '56', '48', '62'], ['Forhend', '58', '59', '52'], ['Bekhend', '55', '57', '48'],
          ['Ritern', '57', '60', '46'], ['Volej', '46', '42', '57'], ['Slajs', '45', '48', '54'],
          ['Drop šot', '42', '47', '38'], ['Lob', '43', '51', '38'], ['Smeč', '48', '38', '55'],
          ['Osnovni zbir', '450', '450', '450'],
        ],
      }}),
      s('Dominantna ruka i geometrija meča', { paragraphs: [
        'Desnoruki i levoruki igrači koriste isti budžet početne snage. Dominantna ruka automatski ne čini forhend ili bekhend jačim ili slabijim.',
        'Efekat se vidi u meču: uglovi servisa, dijagonalne razmene i odnos jednog forhenda prema protivničkom bekhendu razlikuju se u duelima iste i suprotne ruke. Dominantna ruka je javna informacija o protivniku i treba je uzeti u obzir pri izboru taktike.',
      ]}),
      s('Preraspodela prema stilu igre', { bullets: [
        'Agresivni osnovac prebacuje više poena ka servisu i napadačkim udarcima sa osnovne linije.',
        'Defanzivni osnovac prebacuje više poena ka riternu, stabilnosti bekhenda i upijanju pritiska.',
        'Servis i volej prebacuje više poena ka servisu, voleju, slajsu i igri napred.',
        'Igra na celom terenu ne dodaje posebnu preraspodelu i oslanja se prvenstveno na profil podloge.',
      ]}),
      s('Varijacija i plafon razvoja', { paragraphs: [
        'Novi ljudski igrači dobijaju malu determinističku individualnu varijaciju i normalizuju se na približno 440–455 početnih tehničkih poena. Veštine visokog nivoa razvijaju se postepeno sporije od ranijih nivoa.',
      ], links: [{ label: 'Otvori Veštine', href: '/game/skills' }]}),
    ],
  },
  {
    id: 'regular-training',
    title: 'Redovni trening',
    summary: 'Kako radi nedeljni redovni trening, šta ga blokira i kako se raspodeljuje razvoj.',
    sections: [
      s('Pravilo dana kod kuće', { paragraphs: [
        'Redovni trening je dostupan samo kada je dnevno stanje kalendara Home i kada je igrač medicinski sposoban. Turnir, putovanje, Trening kamp i medicinski blokirani dani preuzimaju datum i redovni trening se tada ne izvršava.',
      ]}),
      s('Nedeljni planer', { paragraphs: [
        'Planer omogućava različite izbore za dane kod kuće. Automatski dnevni sistem obrađuje sačuvani plan kada igra stigne do tog datuma. Vlasništvo kalendara uvek ima prednost nad sačuvanim planom treninga.',
      ]}),
      s('Raspodela fokusa', { paragraphs: [
        'Fokusirani trening daje izabranom atributu glavni deo razvoja, dok ostatak raspodeljuje unutar odgovarajuće kategorije. Trenutni model koristi 85% za izabrani fokus i 15% za ostale atribute kategorije.',
      ]}),
      s('Kriva razvoja', { table: {
        headers: ['Trenutni nivo veštine', 'Množilac razvoja'],
        rows: [['1–59', '100%'], ['60–69', '90%'], ['70–79', '75%'], ['80–89', '55%'], ['90–94', '35%'], ['95–99', '20%']],
      }}),
      s('Oporavak i rezultati', { bullets: [
        'Slobodan dan daje prioritet oporavku umesto trajnom razvoju.',
        'Trening beleži dobitke u razvoju, prelazak nivoa i stanje pre i posle sesije.',
        'Rezervisan Trening kamp prikazuje se i u Redovnom treningu; datumi kampa i putovanja automatski imaju prednost nad nedeljnim planom.',
      ], links: [{ label: 'Otvori Trening', href: '/game/training' }]}),
    ],
  },
  {
    id: 'training-camps',
    title: 'Trening kampovi',
    summary: 'Rezervacija, troškovi, razvojne prednosti, otkazivanje, putovanja i pravila završetka.',
    sections: [
      s('Šta radi Trening kamp', { paragraphs: [
        'Trening kamp je plaćeni razvojni blok vezan za lokaciju. Razvoj u kampu jači je od običnog treninga, dok duži kampovi koriste opadajući prinos kako dodatne nedelje ne bi davale neograničen efekat.',
      ]}),
      s('Cene programa', { table: {
        headers: ['Tip kampa', 'Standard', 'Advanced', 'Elite'],
        rows: [['Oporavak i mentalna priprema', '$1.200/nedeljno', '$1.800/nedeljno', '$2.700/nedeljno'], ['Fizički', '$1.400/nedeljno', '$2.100/nedeljno', '$3.200/nedeljno'], ['Teniske veštine', '$1.500/nedeljno', '$2.300/nedeljno', '$3.400/nedeljno']],
      }}),
      s('Kvalitet i trajanje', { bullets: [
        'Množioci razvoja po kvalitetu su Standard 1,00x, Advanced 1,15x i Elite 1,30x.',
        'Kamp može trajati od jedne do četiri nedelje.',
        'Teniski/fizički razvoj koristi nedeljne množice 100%, 95%, 85% i 75% kroz nedelje 1–4.',
        'Normalna nedelja kampa sadrži šest razvojnih dana i jedan dan oporavka.',
      ]}),
      s('Smeštaj', { table: {
        headers: ['Smeštaj', 'Osnovna nedeljna cena', 'Namena'],
        rows: [['Budget 2 zvezdice', '$350', 'Najniža cena'], ['Standard 3 zvezdice', '$560', 'Uravnotežena opcija'], ['Comfort 4 zvezdice', '$840', 'Bolji oporavak i komfor'], ['Premium 5 zvezdica', '$1.260', 'Najviši komfor i oporavak']],
      }}),
      s('Ponuda i plaćanje', { paragraphs: [
        'Ponuda kombinuje cenu treninga, smeštaj prilagođen destinaciji, putovanje igrača i trošak izabranog osoblja koje putuje. Raspoloživi Career Cash vidi se pre rezervacije. Nedovoljno sredstava odbija rezervaciju pre nego što se bilo šta trajno zabeleži.',
      ]}),
      s('Zaštita od konflikta i dupliranja', { bullets: [
        'Preklapanje Trening kampova je blokirano.',
        'Blokirane su prijave i prihvaćeni turniri koji se preklapaju sa periodom kampa.',
        'Proveravaju se postojeće kalendarske obaveze i medicinska ograničenja.',
        'Dupli klik ili ponovljeni zahtev za rezervaciju obrađuju se serijski.',
        'Rezervacija, finansije i kalendarsko vlasništvo menjaju se transakciono.',
      ]}),
      s('Otkazivanje', { paragraphs: [
        'Budući kamp koji još nije počeo može da se otkaže uz 100% povraćaj Career Cash. Kada kamp počne, normalno otkazivanje pre početka više nije dostupno.',
      ]}),
      s('Putovanje i skraćeni kamp', { paragraphs: [
        'Prelazi turnir→kamp i kamp→turnir idu preko grada prebivališta. Ako postoji samo jedan prelazni dan, dve polovine putovanja mogu deliti isti datum. Ako prethodni turnir zauzme normalni datum za put ka kampu, prvi planirani dan kampa postaje podeljeni putni dan, originalni datum završetka ostaje isti i gubi se jedan razvojni dan.',
      ]}),
      s('Propušten meč zbog putovanja', { paragraphs: [
        'Ako igrač posle kampa mora da koristi podeljeni putni dan, a sledeći turnir zakaže meč pre nego što putovanje može da ga dovede spremnog, meč se propušta i protivnik prolazi dalje. Oprema se ne haba jer meč nije odigran.',
      ]}),
      s('Završetak i nadzor', { paragraphs: [
        'Rezultati dana u kampu su idempotentni i ne mogu se primeniti dvaput. Kamp prolazi kroz Booked → Active → Completed. Zdravstveni prekid poslednjeg dana više ne ostavlja kamp zaglavljenim. Životni ciklus kampa i prelazna putovanja nadgleda System Health.',
      ], links: [{ label: 'Otvori Trening kampove', href: '/game/training' }]}),
    ],
  },
  {
    id: 'readiness-recovery',
    title: 'Umor, oštrina, forma i oporavak',
    summary: 'Kako kratkoročno stanje utiče na trening, putovanje i učinak u meču.',
    sections: [
      s('Umor', { paragraphs: ['Umor je akumulirani zamor i glavni broj stanja kod kog je niža vrednost bolja. Trening, mečevi i putovanje mogu ga povećati; odmor, oporavak, kvalitet smeštaja i relevantno osoblje mogu ga smanjiti ili ublažiti.'] }),
      s('Oštrina', { paragraphs: ['Oštrina predstavlja takmičarski ritam i spremnost za meč. Nije trajna veština: veoma kvalitetan igrač i dalje može biti loše pripremljen ako je oštrina niska ili umor visok.'] }),
      s('Moral, samopouzdanje i fokus', { bullets: [
        'Moral je trenutna motivacija i emocionalno stanje.', 'Samopouzdanje oblikuju forma i rezultati.', 'Fokus predstavlja koncentraciju i mentalnu stabilnost.',
      ]}),
      s('Forma naspram trajne veštine', { paragraphs: ['Veštine su dugoročni atributi. Vrednosti spremnosti su kratkoročno stanje. Statistika forme u sezoni zasniva se na rezultatima. Ne koristi jedan od ovih pokazatelja kao zamenu za ostale.'] }),
      s('Praktično planiranje oporavka', { steps: [
        'Pre teškog treninga proveri Zdravlje i umor.', 'Putni dan ostavi kao putni dan.', 'Kada je umor visok, koristi slobodan dan ili oporavak.', 'Kada su turniri blizu, klasa putovanja, hotel i osoblje mogu biti jednako važni kao još jedan dan treninga.',
      ], links: [{ label: 'Otvori Trening', href: '/game/training' }, { label: 'Otvori Zdravlje', href: '/game/injuries' }]}),
    ],
  },
  {
    id: 'health',
    title: 'Povrede, bolesti i dostupnost',
    summary: 'Centar za zdravlje, faktori rizika, medicinska ograničenja i pravila povratka.',
    sections: [
      s('Centar za zdravlje', { paragraphs: ['Povrede i zdravlje prikazuju trenutno medicinsko stanje, rizik od povrede, dnevni rizik od bolesti, status tretmana, povratak treningu, povratak turnirima, očekivani potpuni oporavak i trenutnu kaznu na učinak.'] }),
      s('Faktori rizika od povrede', { paragraphs: ['Rizik od povrede zavisi od aktivnosti i raste kombinacijom umora, opterećenja, trajanja meča, vrućine i slabijeg fizičkog stanja. Stranica prikazuje trenutne faktore rizika umesto da povrede budu potpuno nevidljive.'] }),
      s('Rizik od bolesti', { paragraphs: ['Bolest se računa odvojeno od fizičke povrede i na nju mogu uticati umor, stanje oporavka, izloženost tokom putovanja i trenutni oporavak.'] }),
      s('Medicinska dostupnost', { bullets: [
        'Povratak treningu i povratak turnirima mogu biti različitih datuma.',
        'Kalendarska obrada poštuje medicinske blokade.',
        'Rezervacija Trening kampa se odbija ako se period preklapa sa poznatim zdravstvenim ograničenjem.',
        'Efekti medicinskog osoblja prikazuju se na stranici Zdravlje kada su relevantni.',
      ]}),
      s('Zdravstvena istorija karijere', { paragraphs: ['Oporavljene povrede i bolesti ostaju u zdravstvenoj istoriji karijere. Stranica sadrži i referentne informacije za podržane povrede, trajanje bolesti i nivoe tretmana/rehabilitacije.'], links: [{ label: 'Otvori Povrede i zdravlje', href: '/game/injuries' }]}),
    ],
  },
  {
    id: 'staff',
    title: 'Stručni tim i tržište osoblja',
    summary: 'Angažovanje, ugovori, efekti, plate, pregovori i raskid.',
    sections: [
      s('Dostupne uloge', { table: {
        headers: ['Uloga', 'Glavni doprinos'],
        rows: [
          ['Glavni trener', 'Tehnički razvoj, taktika i priprema meča'],
          ['Kondicioni trener', 'Fizički razvoj, kondicija i kontrola opterećenja'],
          ['Fizioterapeut', 'Oporavak od umora, prevencija povreda i rehabilitacija'],
          ['Sportski psiholog', 'Moral, samopouzdanje, fokus i upravljanje pritiskom'],
          ['Analitičar učinka', 'Procene protivnika, sigurnost analize, zapažanja o dominantnoj ruci i taktičke preporuke'],
          ['Menadžer karijere', 'Sponzorstva, komercijalno zastupanje i upravljanje karijerom'],
        ],
      }}),
      s('Pravila uloga i kvaliteta', { paragraphs: [
        'Jedna aktivna osoba popunjava svaku ulogu. Nova karijera počinje bez osoblja. Kandidati su grupisani u nivoe Developing, Professional, Advanced, Elite i World Class.',
      ]}),
      s('Tok pregovora', { steps: [
        'Filtriraj Tržište osoblja po ulozi, kvalitetu, državi i plati.',
        'Otvori kandidata i izaberi trajanje ugovora i ponudu plate.',
        'Pregledaj verovatnoću prihvatanja, bonus za potpis i ukupnu vrednost obaveze.',
        'Čak i prihvaćena ponuda zahteva završnu potvrdu pre angažovanja.',
        'Career Cash mora pokriti bonus za potpis, a neki kandidati neće pregovarati bez dovoljne sportske reputacije.',
      ]}),
      s('Raskid i putovanja', { paragraphs: [
        'Aktivni ugovori prikazuju neplaćene nedelje, preostalu vrednost plate, stopu poravnanja i trošak raskida. Izabrano osoblje može putovati na turnire ili Trening kampove; to povećava trošak, a efekti koji zahtevaju prisustvo važe samo ako osoba zaista putuje.',
        'Analitičar učinka je informativna uloga, a ne skriveni direktni bonus snage. Bolji analitičar sužava procenjene opsege veština. Kada je sledeći protivnik poznat, priprema napreduje od brze preko delimične i normalne do pune analize tokom vremena igre, sa punom pripremom nakon 24 sata u igri.',
      ], links: [{ label: 'Otvori Stručni tim', href: '/game/staff' }]}),
    ],
  },
  {
    id: 'calendar',
    title: 'Kalendar i planiranje takmičenja',
    summary: 'Kako zajedno rade lični kalendar igrača i Kalendar turnira.',
    sections: [
      s('Dva prikaza kalendara', { paragraphs: ['Kalendar kombinuje sinhronizovani lični kalendar aktivnosti sa širim Kalendarom turnira. Lični prikaz pokazuje ko „poseduje“ datum, dok prikaz turnira služi za pregled takmičarskih mogućnosti.'] }),
      s('Tipovi aktivnosti', { bullets: ['Turnir', 'Putovanje', 'Trening kamp', 'Nacionalni tim', 'Zdravlje / oporavak', 'Kod kuće'] }),
      s('Vlasništvo kalendara', { paragraphs: ['Datum nije običan dan treninga kod kuće kada ga zauzima drugi sistem. Turnir, putovanje, kamp, nacionalni tim ili medicinska aktivnost imaju prednost nad sačuvanim redovnim treningom.'] }),
      s('Pregled turnira', { paragraphs: ['Kartice turnira prikazuju datum, lokaciju, kategoriju, podlogu, informacije o žrebu/poenima i status prijave. Sponzorski ciljevi mogu označiti i komercijalno važne događaje.'] }),
      s('Automatsko putovanje', { paragraphs: ['Prihvaćene obaveze i sačuvana priprema koriste zajednički sistem putovanja. Datumi puta zatim se pojavljuju u ličnom kalendaru. Prelazi Trening kampova mogu napraviti dva poludnevna segmenta putovanja istog datuma kada je raspored veoma tesan.'], links: [{ label: 'Otvori Kalendar', href: '/game/calendar' }]}),
    ],
  },
]
