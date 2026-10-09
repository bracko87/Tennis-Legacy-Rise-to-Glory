import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCareerChaptersSr: ManualChapter[] = [
  {
    id: 'notifications-inbox',
    title: 'Obaveštenja i Menadžersko sanduče',
    summary: 'Upozorenja iz karijere, akcije obaveštenja i privatne poruke između menadžera.',
    sections: [
      s('Centar za obaveštenja', { paragraphs: [
        'Obaveštenja su strukturirani događaji karijere sa kategorijom, tipom, prioritetom, statusom, punim opisom i vremenom kreiranja. Mnoga imaju direktnu akciju kao što su Pogledaj turnir, Otvori raspored, Otvori trening, Otvori zdravlje, Pogledaj opremu ili Glasaj sada.',
      ]}),
      s('Tipične kategorije', { bullets: ['Turniri i putovanja', 'Trening i razvoj igrača', 'Zdravlje i povrede', 'Oprema', 'Finansije', 'Stručni tim', 'Privatni život', 'Nacionalni tim', 'Nalog'] }),
      s('Brojači nepročitanog i važnog', { paragraphs: [
        'Centar razlikuje nepročitano, važno i ukupan broj. Uklanjanje obaveštenja skida ga iz aktivne pažnje, ali ne poništava događaj u igri koji ga je kreirao.',
      ]}),
      s('Menadžersko sanduče', { paragraphs: [
        'Menadžersko sanduče je privatna komunikacija igrač–igrač. Razgovor se normalno pokreće sa javnog profila drugog ljudskog igrača. Samo dva uključena menadžera mogu ga čitati.',
      ]}),
      s('Sistemska upozorenja su drugačija', { paragraphs: [
        'Administratorska System Health upozorenja su operativni alat i nisu normalna obaveštenja karijere. Igrači dobijaju događaje koji utiču na njihovo stanje igre.',
      ], links: [{ label: 'Otvori Obaveštenja', href: '/game/notifications' }, { label: 'Otvori Menadžersko sanduče', href: '/game/inbox' }]}),
    ],
  },
  {
    id: 'premium-coins',
    title: 'Premium funkcije, Coini i naplata',
    summary: 'Opcioni Premium, Coin paketi i šta plaćene funkcije menjaju — a šta ne.',
    sections: [
      s('Besplatna osnovna igra', { paragraphs: [
        'Normalna karijera je besplatna. Premium dodaje opcione analize, pogodnosti i odabrane Premium sisteme; nije potreban za kreiranje igrača, trening, prijavu turnira ili osnovni tok karijere.',
      ]}),
      s('Premium planovi', { table: {
        headers: ['Plan', 'Cena', 'Coin nagrada po uspešnoj uplati'],
        rows: [
          ['Mesečno', 'EUR 3,29 mesečno', '30 Coina'],
          ['3 meseca · glavni plan', 'EUR 9,49 na 3 meseca', '90 Coina'],
          ['12 meseci · 15% popusta', 'EUR 33,49 godišnje', '360 Coina'],
        ],
      }}),
      s('Trenutni Coin paketi', { table: {
        headers: ['Paket', 'Cena'],
        rows: [['70 Coina', 'EUR 2,99'], ['130 Coina', 'EUR 4,99'], ['270 Coina', 'EUR 9,99'], ['390 Coina', 'EUR 13,99'], ['570 Coina', 'EUR 19,99'], ['900 Coina', 'EUR 29,99']],
      }}),
      s('Početni Coini', { paragraphs: [
        'Nova ljudska karijera dobija 20 početnih Coina jednom. Coini imaju sopstveni novčanik/ledger i odvojeni su od Career Cash.',
      ]}),
      s('Primeri trenutno implementiranog Premiuma', { bullets: [
        'Ranking Protection prikaz predstojećeg isteka singl/dubl poena.',
        'Pristup Privatnom životu i jednokratno pravo na početni Premium apartman.',
        'Coin nagrada srazmerna plaćenom periodu Premiuma: 30 po pokrivenom mesecu.',
      ]}),
      s('Istorija naplate', { paragraphs: [
        'Premium računi, kupovine Coin paketa i Coin ledger prikazuju se odvojeno. Bezbedan checkout i periodičnu naplatu obrađuje Stripe. Kupovina Coina ne aktivira Premium, a Premium ne uklanja posebne Coin troškove opcionih sistema.',
      ], links: [{ label: 'Otvori Premium i naplatu', href: '/game/pro-packages' }]}),
    ],
  },
  {
    id: 'private-life',
    title: 'Privatni život',
    summary: 'Premium imovina van terena, tržišta nekretnina, prestiž, investicije i redovni troškovi vlasništva.',
    sections: [
      s('Samo za Premium', { paragraphs: [
        'Privatni život je Premium sistem. Premium karijera dobija jedan početni apartman u gradu prebivališta. Taj apartman je zaključan za trgovinu kako pravo na Premium ne bi moglo direktno da se pretvori u Career Cash.',
      ]}),
      s('Fizička imovina i prestiž', { paragraphs: [
        'Fizička imovina u vlasništvu doprinosi tržišnoj vrednosti, prestižu i, za neke klase, mesečnim troškovima. Dashboard odvojeno prikazuje Career Cash, fizičku imovinu, investicije, trenutnu neto vrednost i mesečne troškove vlasništva.',
      ]}),
      s('Redovni troškovi', { paragraphs: [
        'Vozila, kuće, jahte i privatni avioni imaju redovne troškove vlasništva i života. Satovi, nakit, umetnost i kolekcionarski predmeti ne koriste isti model redovnih troškova.',
      ]}),
      s('Cene nekretnina', { paragraphs: [
        'Vrednosti nekretnina koriste osnovu države sa 10 nivoa za gradove bez posebne tržišne cene. Eksplicitna tržišta velikih gradova imaju prednost nad osnovom države, pa New York i znatno jeftiniji grad ne dobijaju istu vrednost.',
      ]}),
      s('Pravilo prebivališta', { paragraphs: [
        'Igrač može morati da poseduje drugu odgovarajuću rezidenciju pre prodaje trenutnog glavnog doma. Premium početni dom je zaključan i ne može se prodati.',
      ]}),
      s('Marketplace i istorija transakcija', { paragraphs: [
        'Kupovine, prodaje i troškovi vlasništva prolaze kroz Career Finance i beleže se u istoriji Privatnog života. Aktivni oglasi za prodaju mogu se otkazati dok su otvoreni.',
      ], links: [{ label: 'Otvori Privatni život', href: '/game/private-life' }]}),
    ],
  },
  {
    id: 'tennis-club',
    title: 'Teniski klub i klupska zajednica',
    summary: 'Društveni klubovi preko oba tura, prijave članova, klupska rang-lista i privatni chat.',
    sections: [
      s('Članstvo preko oba tura', { paragraphs: [
        'Teniski klubovi su zajedničke društvene organizacije koje mogu sadržati ATP i WTA ljudske igrače. Igrač može biti član jednog kluba preko kreiranja, prijave ili pozivnice.',
      ]}),
      s('Kreiranje kluba', { paragraphs: [
        'Kreiranje Teniskog kluba košta 50 Coina. Kreator postaje vlasnik kluba. Ime kluba mora ispuniti aktuelna pravila validacije i biti jedinstveno.',
      ]}),
      s('Pridruživanje klubu', { paragraphs: [
        'Koristi World Clubs za prijavu u postojeći klub ili prihvati poziv vlasnika. Prijave i pozivnice ostaju vidljive dok se ne reše.',
      ]}),
      s('Klupski poeni i rang', { paragraphs: [
        'Klupski poeni su živi zbir trenutnih zvaničnih poena rang-liste svih članova kroz ATP i WTA. Svetska klupska rang-lista prikazuje 50 najboljih klubova.',
      ]}),
      s('Klupski chat', { paragraphs: [
        'Klupski chat je samo za članove. Trenutno podešen period nedavne istorije je 14 dana igre.',
      ], links: [{ label: 'Otvori Teniski klub', href: '/game/tennis-club' }]}),
    ],
  },
  {
    id: 'national-association',
    title: 'Nacionalni savez i Nacionalni tim',
    summary: 'Članstvo, finansiranje saveza, izbor kapitena i upravljanje zajednicom.',
    sections: [
      s('Članstvo', { paragraphs: [
        'Članstvo u Nacionalnom savezu je opciono. Novi igrač nije automatski član. Pridruživanje stavlja igrača u skup kandidata za reprezentativni poziv i omogućava učešće u upravljanju kada ispunjava uslove.',
      ]}),
      s('Principi upravljanja zajednicom', { bullets: [
        'Jedan član ima jedan glas.',
        'Iznos donacije nikada ne povećava glasačku moć.',
        'Status osnivača/aktivacije je kozmetički i ne stvara trajno vlasništvo.',
        'Nacionalni kapiten je aktivni igrač i zauzima normalno mesto u sastavu.',
        'Kapiten ne zaobilazi pravila umora, zdravlja ili kalendara.',
      ]}),
      s('Godišnja obnova', { paragraphs: [
        'Obnova saveza otvara se u januaru i mora biti završena do 31. januara. Neplaćen savez postaje neaktivan od 1. februara.',
      ]}),
      s('Vremenska linija izbora kapitena', { table: {
        headers: ['Datum / period', 'Akcija'],
        rows: [
          ['1. januar', 'Otvaraju se godišnja obnova i registracija kandidata'],
          ['10. januar', 'Počinje glavno glasanje za kapitena'],
          ['20. januar', 'Završava se glavni izborni krug'],
          ['21–27. januar', 'Prvi dodatni krug ako nema jedinstvenog pobednika'],
          ['Svakih narednih 7 dana', 'Novi krugovi se ponavljaju dok nema pobednika'],
          ['31. januar', 'Rok za obnovu'],
          ['1. februar', 'Neplaćen savez postaje neaktivan'],
        ],
      }}),
      s('Pravilo pobednika', { paragraphs: [
        'Kandidat pobeđuje samo ako ima najmanje jedan glas i strogo više glasova od svakog drugog kandidata. Ako nema jedinstvenog pobednika, kreira se dodatni krug.',
      ]}),
      s('Ostavka kapitena', { paragraphs: [
        'Trenutni kapiten može podneti ostavku. Zatim se može otvoriti izbor za zamenu umesto da funkcija trajno ostane vezana za prethodnog pobednika.',
      ], links: [{ label: 'Otvori Nacionalni savez', href: '/game/national-team' }]}),
    ],
  },
  {
    id: 'statistics',
    title: 'Statistika i istorija karijere',
    summary: 'Svetske rang-liste učinka, turnirska statistika, rekordi igrača i istorija po sezonama.',
    sections: [
      s('Oblasti statistike', { bullets: ['Svetska statistika', 'Statistika igrača', 'Statistika turnira', 'Rekordi karijere'] }),
      s('Svetski leaderboard', { paragraphs: [
        'Svetska statistika prikazuje vodeće igrače sa završenim zvaničnim mečevima u izabranom periodu, uključujući rang, poene, procenat pobeda, titule i ukupne statistike meča gde su dostupne.',
      ]}),
      s('Baza turnira', { paragraphs: [
        'Statistika turnira objedinjuje zvanične završene mečeve, učešća, produkciju udaraca i najbolje učinke po događaju.',
      ]}),
      s('Statistika karijere igrača', { paragraphs: [
        'Statistika igrača uključuje trenutni rang, najbolji rang karijere, skor mečeva, titule/finala, nagradni novac, rezultate po podlogama, udarce i učinak po kategoriji turnira.',
      ]}),
      s('Vremenska linija karijere', { paragraphs: [
        'Pregled po sezonama postaje dugoročni istorijski zapis kako karijera napreduje i odvaja rezultate trenutne sezone od ukupne karijere.',
      ], links: [{ label: 'Otvori Statistiku', href: '/game/statistics' }]}),
    ],
  },
  {
    id: 'preferences-support',
    title: 'Podešavanja, pomoć, zajednica i podrška',
    summary: 'Podešavanja i alati podrške izvan glavnog takmičarskog toka karijere.',
    sections: [
      s('Podešavanja igre', { paragraphs: [
        'Podešavanja igre su mesto za lične opcije interfejsa, jezika i komunikacije. Izabrani jezik čuva se na nalogu i prati menadžera na drugim uređajima.',
      ]}),
      s('Centar za pomoć', { paragraphs: [
        'Centar za pomoć daje brze linkove, Kontakt podrške, Discord, tutorial i ovaj Kompletan priručnik igre. Priručnik ostaje unutar Tennis Legacy i ima PDF izdanje kada je dostupno.',
      ]}),
      s('Forum / Discord', { paragraphs: [
        'Zvanični Tennis Legacy Discord je zajednica za strategiju, screenshotove, pitanja, prijave grešaka, predloge i razvojne najave.',
      ]}),
      s('Kontakt podrške', { paragraphs: [
        'Kontakt je direktan put do podrške. Za tehnički problem navedi stranicu, ime igrača, screenshot i tačne korake za ponavljanje.',
      ]}),
      s('Pozovi prijatelje', { paragraphs: [
        'Pozovi prijatelje daje registracioni/referral link kojim drugi menadžer kreira zasebnu ATP ili WTA karijeru.',
      ], links: [
        { label: 'Otvori Podešavanja igre', href: '/game/preferences' },
        { label: 'Otvori Centar za pomoć', href: '/game/help' },
        { label: 'Kontaktiraj podršku', href: '/game/contact' },
        { label: 'Otvori Forum', href: '/game/forum' },
      ]}),
    ],
  },
  {
    id: 'season-progression',
    title: 'Napredovanje sezone i obrada vremena igre',
    summary: 'Kako Tennis Legacy napreduje kroz dane igre i zašto se mnogi sistemi ažuriraju automatski.',
    sections: [
      s('Vreme igre, ne stvarno vreme', { paragraphs: [
        'Tennis Legacy koristi sopstveni kalendar. Turniri, objava rang-lista, ugovori, porez, zdravlje, trening, putovanja i periodi nacionalnog saveza vezani su za datume igre, a ne stvarni datum menadžera.',
      ]}),
      s('Automatska dnevna obrada', { paragraphs: [
        'Mnogi sistemi se automatski ažuriraju kako dani napreduju: redovni trening, dani Trening kampa, putni segmenti, zdravstvene provere, finansijska poravnanja, sponzorske isplate, objava rang-lista i životni ciklus turnira. Igrač ne treba ručno da obrađuje svaki pozadinski prelaz.',
      ]}),
      s('Nova sezona i kontinuitet karijere', { paragraphs: [
        'Nova sezona menja sezonske rasporede, kontekst odbrane poena, sponzorske cikluse, period obnove/izbora saveza i sezonsku statistiku. Dugoročna karijera nastavlja sa istim identitetom, veštinama, opremom u vlasništvu i istorijskim rekordima osim kada konkretan sistem kaže drugačije.',
      ]}),
      s('System Health', { paragraphs: [
        'Kritične pozadinske procese nadgledaju System Health i administratorski Control Center. Ovaj sloj otkriva zaglavljene ili neuspešne procese i probleme integriteta kako tehnički kvar ne bi tiho postao normalno stanje igre.',
      ]}),
    ],
  },
  {
    id: 'important-rules',
    title: 'Važna pravila i ograničenja igre',
    summary: 'Pravila koja sprečavaju najčešće nesporazume o trenutnom ponašanju igre.',
    sections: [
      s('Identitet i svetovi', { bullets: [
        'Profesionalno ime igrača je fiksno nakon kreiranja karijere.',
        'Dominantna ruka je osnovni identitet. Levoruki i desnoruki ne dobijaju automatske trajne forhend/bekhend bonuse; ruka utiče na geometriju meča i taktičku pogodnost.',
        'ATP i WTA takmičarske rang-liste su odvojene.',
        'Singl i dubl rang-liste su odvojene discipline.',
        'Teniski klubovi mogu imati članove i iz ATP i iz WTA sveta.',
      ]}),
      s('Vlasništvo kalendara', { bullets: [
        'Turnir, putovanje, Trening kamp, Nacionalni tim ili zdravstveni datum nije normalan Home dan za trening.',
        'Sačuvani plan redovnog treninga nikada ne prepisuje jače kalendarsko vlasništvo.',
        'Nemoguće vreme putovanja može dovesti do propuštenog meča.',
      ]}),
      s('Novac i Coini', { bullets: [
        'Career Cash i Coini su odvojene valute.',
        'Premium ne uklanja potrebu za upravljanjem Career Cash.',
        'Kupovina Coina ne stvara Career Cash.',
        'Promene finansijske vrednosti projektovane su kao idempotentne kako ponovni pokušaj ne bi duplirao naplatu ili nagradu.',
      ]}),
      s('Poznavanje protivnika i taktika', { bullets: [
        'Dominantna ruka, omiljena podloga i stil igre su javne informacije.',
        'Tačne veštine protivnika ostaju privatne. Analitičar učinka daje procene čiji se raspon sužava sa kvalitetom analitičara i vremenom pripreme.',
        'Kvalitet analitičara povećava sigurnost informacije, a ne skrivenu snagu igrača.',
        'Taktičke kontre su umereni matchup efekti, a ne dugme za sigurnu pobedu. Sopstvene i protivničke veštine, podloga, stanje i rizik i dalje su važni.',
      ]}),
      s('Razvoj', { bullets: [
        'Omiljena podloga i stil menjaju početnu raspodelu, ne ukupnu početnu snagu.',
        'Visoke veštine razvijaju se sporije od nižih.',
        'Trening kampovi su jači od običnog treninga, ali imaju opadajući prinos kroz više nedelja.',
        'Vrednosti spremnosti nisu trajne veštine.',
      ]}),
      s('Granice Premiuma', { bullets: [
        'Osnovna karijera je dostupna Free igračima.',
        'Privatni život je Premium-only.',
        'Ranking Protection je informacija za planiranje, a ne zaštita od gubitka poena.',
        'Premium početni apartman se ne može prodati.',
      ]}),
      s('Nedovršene ideje nisu aktivne funkcije', { paragraphs: [
        'Ako trenutna stranica igre kaže da kontrola još nije podešena, priručnik je opisuje kao nedostupnu umesto da buduću ideju predstavlja kao implementiranu.',
      ]}),
    ],
  },
  {
    id: 'faq',
    title: 'Česta pitanja',
    summary: 'Odgovori na česta pitanja o upravljanju karijerom.',
    sections: [
      s('Zašto danas ne mogu da treniram?', { paragraphs: [
        'Proveri trenutnu aktivnost u kalendaru i Zdravlje. Redovni trening zahteva Home dan i medicinsku dozvolu. Turnir, putovanje, Trening kamp, Nacionalni tim ili povreda/oporavak blokiraju normalni trening.',
      ]}),
      s('Zašto mi je rang pao iako danas nisam izgubio?', { paragraphs: [
        'Rang je relativan prema svim igračima, a aktivni doprinosi mogu isteći. Drugi igrači takođe mogu osvojiti poene. Premium Ranking Protection prikazuje buduće isteke, ali ih ne sprečava.',
      ]}),
      s('Zašto je Trening kamp postao kraći?', { paragraphs: [
        'Ako turnir neposredno pre kampa zauzme normalni putni datum, prvi dan kampa može postati podeljeni putni dan preko grada prebivališta. Originalni kraj kampa ostaje isti, pa se gubi jedan razvojni dan.',
      ]}),
      s('Mogu li zadržati redovni trening tokom Trening kampa?', { paragraphs: [
        'Da. Sačuvani nedeljni plan može ostati, ali datumi kampa i putovanja automatski ga prepisuju. Redovni trening prikazuje rezervisani kamp da konflikt bude vidljiv.',
      ]}),
      s('Zašto sam propustio turnirski meč?', { paragraphs: [
        'Jedan podržan razlog je travel no-show: ako putovanje ne može da učini igrača spremnim pre vremena meča, protivnik prolazi bez odigranog meča. Zdravstvena ograničenja takođe mogu proizvesti ishode bez igre.',
      ]}),
      s('Da li dobijam osoblje ili sponzore na početku?', { paragraphs: [
        'Ne. Nova karijera počinje bez osoblja, glavnog sponzora i tehničkog sponzora. Ti sistemi se grade tokom karijere.',
      ]}),
      s('Na šta da potrošim prvih $25.000?', { paragraphs: [
        'Ne postoji jedan tačan odgovor. Početna oprema je dovoljna za igru, pa rano trošenje može ići na trening, putovanja/hotele, pažljivo izabrano osoblje ili ciljane nadogradnje opreme. Pre velike obaveze proveri buduće troškove.',
      ]}),
      s('Čemu služi prvih 20 Coina?', { paragraphs: [
        'Oni uvode Coin novčanik i mogu se sačuvati za opcione sisteme. Kreiranje Teniskog kluba trenutno košta 50 Coina, pa početna nagrada namerno nije dovoljna da odmah napraviš klub.',
      ]}),
      s('Mogu li prodati Premium početni apartman?', { paragraphs: [
        'Ne. Zaključan je za trgovinu kako Premium pravo ne bi moglo postati Career Cash exploit.',
      ]}),
      s('Da li je Premium potreban da bih bio konkurentan?', { paragraphs: [
        'Osnovni takmičarski sistemi dostupni su bez Premiuma. Premium dodaje opcione analize/pogodnosti i Privatni život, a ne garantovan turnirski ili rang rezultat.',
      ]}),
      s('Gde prijavljujem grešku?', { paragraphs: [
        'Koristi Kontakt podršku, dugme Prijavi grešku ili zvanični Discord. Dodaj screenshot, ime igrača, stranicu i tačne korake za ponavljanje.',
      ], links: [{ label: 'Otvori Centar za pomoć', href: '/game/help' }, { label: 'Kontaktiraj podršku', href: '/game/contact' }]}),
    ],
  },
]
