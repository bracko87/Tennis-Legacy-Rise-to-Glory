export type TravelCalendarCopy = {
 changeFlight:string; planTrip:string; rescheduleTitle:string; subtitle:string;
 returnHome:string; direct:string; quoteTitle:string; route:string; flight:string;
 hotel:string; total:string; fatigue:string; viaHome:string; morale:string;
 expectedRefund:string; noRefund:string; refundNote:string; savingsNote:string;
 costDisclaimer:string; save:string; saving:string; cancel:string; loading:string;
 saved:string; savedRefund:string; error:string; note:string; preparation:string;
 locked:string; days:string; night:string; commercial:string; jet:string; warning:string;
}
const texts: Record<string,TravelCalendarCopy> = {
en:{
changeFlight:'Change flight',planTrip:'Travel options',rescheduleTitle:'Reschedule travel',
subtitle:'Change the trip from {from} to {to}. Only future flights can be changed.',
returnHome:'Return home first (default)',direct:'Travel directly to the next tournament',
quoteTitle:'Direct travel estimate',route:'Route',flight:'Flight (player and staff)',hotel:'Additional hotel nights',
total:'Direct flight and extra hotel',fatigue:'Arrival fatigue',viaHome:'Commercial flights via home (comparison)',
morale:'Away from home: −1 morale from day 8, −2 from day 15; regain up to 1 per day at home.',
expectedRefund:'Paid unused flight refundable',noRefund:'No flight payment to refund',
refundNote:'Only verified prepaid, untravelled flights are refunded once. Completed travel is not refundable.',
savingsNote:'Actual flight and hotel costs are posted by the game as days progress.',
costDisclaimer:'Estimates may change after the last match. The comparison via home excludes accommodation and private-jet changes.',
save:'Save travel change',saving:'Saving travel…',cancel:'Cancel',loading:'Checking journey…',
saved:'Travel route updated. Calendar and Tournament Preparation now use the same choice.',
savedRefund:'Refund credited for unused flight:',error:'Unable to change travel:',note:'If the tournament lasts longer, the departure adjusts after your last match.',
preparation:'Open tournament preparation',locked:'Past or started flights cannot be changed.',
days:'nights',night:'night',commercial:'Commercial',jet:'Private jet',warning:'Close connection: check match and arrival dates.'
},
de:{
changeFlight:'Flug ändern',planTrip:'Reiseoptionen',rescheduleTitle:'Reise umbuchen',subtitle:'Reise von {from} nach {to} ändern. Nur zukünftige Flüge können geändert werden.',
returnHome:'Zuerst nach Hause (Standard)',direct:'Direkt zum nächsten Turnier',quoteTitle:'Schätzung der Direktreise',route:'Strecke',flight:'Flug (Spieler und Team)',hotel:'Zusätzliche Hotelnächte',
total:'Flug und zusätzliche Hotelnächte',fatigue:'Reisemüdigkeit',viaHome:'Linienflüge über Zuhause (Vergleich)',morale:'Abwesenheit: −1 Moral ab Tag 8, −2 ab Tag 15; zu Hause bis zu +1 pro Tag.',
expectedRefund:'Erstattbare bezahlte Flüge',noRefund:'Keine Flugzahlung zu erstatten',refundNote:'Nur nachweislich bezahlte, ungenutzte Flüge werden einmal erstattet. Bereits geflogene Reisen nicht.',
savingsNote:'Die Spielabrechnung erfolgt bei tatsächlichen Reisen und Hotelnächten.',costDisclaimer:'Schätzungen können sich nach dem letzten Spiel ändern. Der Vergleich über Zuhause enthält keine Hotels oder Privatjet-Anpassungen.',
save:'Reiseänderung speichern',saving:'Speichern…',cancel:'Abbrechen',loading:'Reise wird geprüft…',
saved:'Reise geändert. Kalender und Turniervorbereitung verwenden dieselbe Auswahl.',savedRefund:'Erstattung für ungenutzten Flug:',
error:'Reise kann nicht geändert werden:',note:'Dauert das Turnier länger, wird die Abreise nach dem letzten Spiel angepasst.',
preparation:'Turniervorbereitung öffnen',locked:'Vergangene oder gestartete Flüge sind gesperrt.',
days:'Nächte',night:'Nacht',commercial:'Linienflug',jet:'Privatjet',warning:'Wenig Zeit: Spielplan und Anreise prüfen.'
},
sr:{
changeFlight:'Promeni let',planTrip:'Opcije putovanja',rescheduleTitle:'Promena putovanja',subtitle:'Promeni put od {from} do {to}. Samo budući letovi mogu da se menjaju.',
returnHome:'Prvo kući (podrazumevano)',direct:'Direktno na sledeći turnir',quoteTitle:'Procena direktnog puta',route:'Ruta',flight:'Let igrača i osoblja',hotel:'Dodatna noćenja',
total:'Let i dodatna noćenja',fatigue:'Umor po dolasku',viaHome:'Letovi preko kuće (poređenje)',morale:'Daleko od kuće: −1 moral od 8. dana, −2 od 15. dana; kod kuće do +1 dnevno.',
expectedRefund:'Povraćaj za plaćeni neiskorišćeni let',noRefund:'Nema uplaćenog leta za povraćaj',refundNote:'Vraća se samo potvrđeno plaćen, neiskorišćen let, jedanput. Završeni letovi se ne vraćaju.',
savingsNote:'Igra naplaćuje stvarne letove i noćenja kada nastanu.',costDisclaimer:'Procena može da se promeni posle poslednjeg meča. Poređenje preko kuće ne uključuje hotele i privatne avione.',
save:'Sačuvaj putovanje',saving:'Čuvanje…',cancel:'Otkaži',loading:'Proveravamo put…',
saved:'Ruta je promenjena. Kalendar i priprema turnira koriste isti izbor.',savedRefund:'Vraćen novac za neiskorišćeni let:',
error:'Ne možemo da promenimo put:',note:'Ako turnir traje duže, polazak se pomera posle poslednjeg meča.',
preparation:'Otvori pripremu turnira',locked:'Prošli i započeti letovi ne mogu da se menjaju.',
days:'noćenja',night:'noć',commercial:'Komercijalni let',jet:'Privatni avion',warning:'Malo vremena: proveri raspored.'
}
}
export function calendarTravelCopy(lang?:string):TravelCalendarCopy {
 return texts[(lang||'en').split('-')[0].toLowerCase()]??texts.en
}
