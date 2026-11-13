type TravelCopy = {
 title:string; intro:string; viaHome:string; direct:string; quoteTitle:string;
 route:string; flight:string; hotel:string; subtotal:string; fatigue:string; jet:string;
 costNote:string; awayMorale:string; jetFirst:string; loading:string; error:string;
 unavailable:string; early:string; homeComparison:string; day:string; days:string;
 directChoice:string; noTravelYet:string; connectionWarning:string; included:string;
 saveToConfirm:string; flightCommercial:string; flightJet:string;
}
const messages: Record<string,TravelCopy> = {
 en:{
 title:'Travel between tournaments',intro:'Choose your trip from {previous} to {next}.',
 viaHome:'Return home first (default)',direct:'Travel directly to the next tournament',
 quoteTitle:'Direct transfer estimate',route:'Route',flight:'Player and staff flight',
 hotel:'Extra hotel nights',subtotal:'Transfer + extra hotel nights',fatigue:'Arrival fatigue',
 jet:'Private jet',costNote:'Estimated from current tournament dates. Actual charges follow the completed flight and hotel nights; the final match date may change this estimate.',
 awayMorale:'Time away from home: −1 morale from day 8, −2 from day 15. At home, recover 1 point per day.',
 jetFirst:'Save the tournament plan first to confirm direct travel, then select your private jet below.',
 loading:'Calculating transfer costs…',error:'Could not calculate the transfer quote:',
 unavailable:'Direct travel can be chosen when two accepted tournaments are scheduled.',
 early:'additional nights before the tournament',homeComparison:'Commercial flights via home (comparison only)',
 day:'night',days:'nights',directChoice:'Direct journey selected',noTravelYet:'The actual departure day is updated after your last match.',
 connectionWarning:'Possible tight connection: verify the match schedule before departure.',
 included:'Staff included in flight total',saveToConfirm:'Save the tournament plan to apply your route.',
 flightCommercial:'Commercial flight',flightJet:'Owned private jet'
 },
 de:{
 title:'Reise zwischen Turnieren',intro:'Wähle die Reise von {previous} nach {next}.',
 viaHome:'Zuerst nach Hause (Standard)',direct:'Direkt zum nächsten Turnier',
 quoteTitle:'Schätzung für die Direktreise',route:'Strecke',flight:'Flug für Spieler und Team',
 hotel:'Zusätzliche Hotelnächte',subtotal:'Reise und zusätzliche Hotelnächte',fatigue:'Reisemüdigkeit',
 jet:'Privatjet',costNote:'Schätzung anhand der aktuellen Turnierdaten. Tatsächliche Kosten richten sich nach Flügen und Hotelnächten; das letzte Spiel kann die Daten ändern.',
 awayMorale:'Abwesenheit von zu Hause: −1 Moral ab Tag 8, −2 ab Tag 15. Zu Hause erholt sich die Moral um 1 pro Tag.',
 jetFirst:'Speichere zuerst die direkte Reiseroute und wähle danach deinen Privatjet.',
 loading:'Reisekosten werden berechnet…',error:'Reisekosten konnten nicht berechnet werden:',
 unavailable:'Direktreisen sind zwischen zwei bestätigten Turnieren möglich.',
 early:'zusätzliche Nächte vor dem Turnier',homeComparison:'Linienflüge über Zuhause (nur Vergleich)',
 day:'Nacht',days:'Nächte',directChoice:'Direktreise ausgewählt',noTravelYet:'Der genaue Reisetag wird nach dem letzten Spiel festgelegt.',
 connectionWarning:'Knappes Zeitfenster: Spielplan vor Abreise prüfen.',
 included:'Team im Flugpreis enthalten',saveToConfirm:'Speichere den Turnierplan für diese Route.',
 flightCommercial:'Linienflug',flightJet:'Eigener Privatjet'
 },
 es:{
 title:'Viaje entre torneos',intro:'Elige tu viaje de {previous} a {next}.',
 viaHome:'Volver a casa primero (predeterminado)',direct:'Viajar directamente al siguiente torneo',
 quoteTitle:'Estimación del viaje directo',route:'Ruta',flight:'Vuelo del jugador y equipo',
 hotel:'Noches de hotel adicionales',subtotal:'Viaje y noches adicionales',fatigue:'Fatiga de llegada',
 jet:'Jet privado',costNote:'Estimación basada en las fechas actuales. Los gastos reales dependen de los vuelos y las noches de hotel.',
 awayMorale:'Lejos de casa: −1 moral desde el día 8 y −2 desde el 15. En casa se recupera 1 al día.',
 jetFirst:'Guarda primero el viaje directo y luego elige tu jet privado.',
 loading:'Calculando gastos…',error:'No se pudo calcular el viaje:',
 unavailable:'El viaje directo requiere dos torneos aceptados.',
 early:'noches adicionales antes del torneo',homeComparison:'Vuelos comerciales pasando por casa (comparación)',
 day:'noche',days:'noches',directChoice:'Viaje directo elegido',noTravelYet:'La salida se ajusta tras el último partido.',
 connectionWarning:'Conexión ajustada: revisa el calendario.',included:'Equipo incluido en el coste del vuelo',
 saveToConfirm:'Guarda el plan para confirmar esta ruta.',flightCommercial:'Vuelo comercial',flightJet:'Jet propio'
 },
 fr:{
 title:'Voyage entre les tournois',intro:'Choisissez le trajet de {previous} à {next}.',
 viaHome:'Rentrer chez soi (par défaut)',direct:'Aller directement au prochain tournoi',
 quoteTitle:'Estimation du trajet direct',route:'Trajet',flight:'Vol du joueur et du staff',hotel:'Nuits d’hôtel supplémentaires',
 subtotal:'Trajet et nuits supplémentaires',fatigue:'Fatigue à l’arrivée',jet:'Jet privé',
 costNote:'Estimation selon le calendrier actuel. Les frais réels dépendent des vols et des nuits d’hôtel.',
 awayMorale:'Loin de chez soi : −1 moral dès le 8e jour, −2 dès le 15e. À domicile : +1 par jour.',
 jetFirst:'Enregistrez d’abord le trajet direct, puis choisissez votre jet.',
 loading:'Calcul des frais…',error:'Impossible de calculer le trajet :',unavailable:'Deux tournois acceptés sont nécessaires.',
 early:'nuits avant le tournoi',homeComparison:'Vols commerciaux via domicile (comparaison)',
 day:'nuit',days:'nuits',directChoice:'Trajet direct choisi',noTravelYet:'Le départ sera ajusté après le dernier match.',
 connectionWarning:'Correspondance serrée : vérifiez le calendrier.',included:'Staff inclus dans le tarif du vol',
 saveToConfirm:'Enregistrez le plan pour confirmer le trajet.',flightCommercial:'Vol commercial',flightJet:'Jet privé'
 },
 it:{
 title:'Viaggio tra tornei',intro:'Scegli il viaggio da {previous} a {next}.',
 viaHome:'Rientra prima a casa (predefinito)',direct:'Vai direttamente al prossimo torneo',
 quoteTitle:'Stima del trasferimento diretto',route:'Percorso',flight:'Volo per giocatore e staff',hotel:'Notti extra in hotel',
 subtotal:'Trasferimento e notti extra',fatigue:'Fatica all’arrivo',jet:'Jet privato',
 costNote:'Stima basata sul calendario attuale. I costi effettivi dipendono dai voli e dalle notti in hotel.',
 awayMorale:'Lontano da casa: −1 morale dall’8° giorno, −2 dal 15°. A casa: +1 al giorno.',
 jetFirst:'Salva prima il viaggio diretto, poi seleziona il jet.',
 loading:'Calcolo dei costi…',error:'Impossibile calcolare il trasferimento:',
 unavailable:'Servono due tornei accettati.',early:'notti prima del torneo',
 homeComparison:'Voli commerciali passando da casa (confronto)',day:'notte',days:'notti',
 directChoice:'Viaggio diretto selezionato',noTravelYet:'La partenza sarà aggiornata dopo l’ultimo match.',
 connectionWarning:'Coincidenza stretta: controlla il calendario.',included:'Staff incluso nel prezzo del volo',
 saveToConfirm:'Salva il piano per confermare la rotta.',flightCommercial:'Volo commerciale',flightJet:'Jet privato'
 },
 pt:{
 title:'Viagem entre torneios',intro:'Escolha a viagem de {previous} para {next}.',
 viaHome:'Voltar primeiro a casa (padrão)',direct:'Viajar diretamente para o próximo torneio',
 quoteTitle:'Estimativa da viagem direta',route:'Rota',flight:'Voo do jogador e equipa',hotel:'Noites extra no hotel',
 subtotal:'Viagem e noites extra',fatigue:'Fadiga à chegada',jet:'Jato privado',
 costNote:'Estimativa baseada no calendário atual. Os custos reais dependem dos voos e das noites no hotel.',
 awayMorale:'Longe de casa: −1 moral a partir do dia 8, −2 a partir do dia 15. Em casa: +1 por dia.',
 jetFirst:'Guarde primeiro a viagem direta e depois escolha o jato.',
 loading:'A calcular custos…',error:'Não foi possível calcular a viagem:',
 unavailable:'São necessários dois torneios aceites.',early:'noites antes do torneio',
 homeComparison:'Voos comerciais via casa (comparação)',day:'noite',days:'noites',
 directChoice:'Viagem direta selecionada',noTravelYet:'A partida ajusta-se após o último jogo.',
 connectionWarning:'Ligação apertada: consulte o calendário.',included:'Equipa incluída no custo do voo',
 saveToConfirm:'Guarde o plano para confirmar a rota.',flightCommercial:'Voo comercial',flightJet:'Jato próprio'
 },
 ru:{
 title:'Переезд между турнирами',intro:'Выберите маршрут из {previous} в {next}.',
 viaHome:'Сначала домой (по умолчанию)',direct:'Сразу на следующий турнир',
 quoteTitle:'Оценка прямого переезда',route:'Маршрут',flight:'Перелёт игрока и команды',hotel:'Дополнительные ночи в отеле',
 subtotal:'Переезд и отель',fatigue:'Усталость после перелёта',jet:'Частный самолёт',
 costNote:'Оценка по текущему расписанию. Фактические расходы зависят от рейсов и проживания.',
 awayMorale:'Вдали от дома: −1 к морали с 8-го дня, −2 с 15-го. Дома: +1 в день.',
 jetFirst:'Сначала сохраните прямой маршрут, затем выберите самолёт.',
 loading:'Расчёт расходов…',error:'Не удалось рассчитать поездку:',
 unavailable:'Нужно два подтверждённых турнира.',early:'ночей до турнира',
 homeComparison:'Обычные рейсы через дом (для сравнения)',day:'ночь',days:'ночей',
 directChoice:'Выбран прямой маршрут',noTravelYet:'Дата вылета уточнится после последнего матча.',
 connectionWarning:'Мало времени на пересадку: проверьте расписание.',included:'Команда включена в стоимость',
 saveToConfirm:'Сохраните план, чтобы применить маршрут.',flightCommercial:'Обычный рейс',flightJet:'Свой самолёт'
 },
 sr:{
 title:'Putovanje između turnira',intro:'Izaberi put od {previous} do {next}.',
 viaHome:'Prvo se vrati kući (podrazumevano)',direct:'Putuj direktno na sledeći turnir',
 quoteTitle:'Procena direktnog putovanja',route:'Ruta',flight:'Let igrača i osoblja',hotel:'Dodatna noćenja',
 subtotal:'Put i dodatna noćenja',fatigue:'Umor posle puta',jet:'Privatni avion',
 costNote:'Procena prema trenutnom rasporedu. Stvarni troškovi zavise od leta i hotela.',
 awayMorale:'Van kuće: −1 moral od 8. dana, −2 od 15. dana. Kod kuće: +1 dnevno.',
 jetFirst:'Prvo sačuvaj direktnu rutu, pa izaberi privatni avion.',
 loading:'Računamo troškove…',error:'Nije moguće izračunati put:',
 unavailable:'Potrebna su dva prihvaćena turnira.',early:'noćenja pre turnira',
 homeComparison:'Komercijalni letovi preko kuće (poređenje)',day:'noć',days:'noćenja',
 directChoice:'Izabran direktan put',noTravelYet:'Datum polaska će se ažurirati posle poslednjeg meča.',
 connectionWarning:'Malo vremena za put: proveri raspored.',included:'Osoblje je uključeno u cenu leta',
 saveToConfirm:'Sačuvaj plan da potvrdiš rutu.',flightCommercial:'Komercijalni let',flightJet:'Privatni avion'
 }
}
export function directTournamentTravelCopy(locale?: string): TravelCopy {
 const lang=(locale || 'en').split('-')[0].toLowerCase()
 return messages[lang] ?? messages.en
}
