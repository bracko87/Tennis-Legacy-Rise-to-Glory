const en = {
  title: 'Premium Tournament Watchlist',
  intro: 'Star a tournament before applications open. We will remind you in the game notification center when its official application window starts.',
  locked: 'Tournament reminders are a Premium convenience. Calendar browsing and applications stay Free.',
  plans: 'Explore Premium',
  loading: 'Loading tournament reminders…',
  empty: 'No watched tournaments yet. Select a star beside a future tournament.',
  upcoming: 'Waiting for applications',
  open: 'Applications are open',
  applied: 'Already applied',
  closed: 'Application window closed',
  canceled: 'Tournament canceled',
  opens: 'Opens',
  closes: 'Closes',
  watch: 'Remind me when applications open',
  unwatch: 'Remove reminder',
  openTournament: 'Open tournament',
  limit: 'Up to 60 watched tournaments per game season',
  note: 'In-game notifications are delivered automatically near the opening time, including while you are offline. This does not apply for you or guarantee a place. Notifications appear in the game inbox, not as email or device push alerts.',
  error: 'Could not load or update reminders. Please try again.',
  saved: 'Reminder saved',
  removed: 'Reminder removed',
} as const
type Translation = Record<keyof typeof en, string>
const de: Translation = {
 title:'Premium-Turniermerkliste',intro:'Markiere Turniere vor der Anmeldeöffnung mit einem Stern. Beim Öffnen des offiziellen Fensters erhältst du eine Spielbenachrichtigung.',locked:'Turniererinnerungen sind Premium. Kalender und normale Anmeldungen bleiben kostenlos.',plans:'Premium ansehen',loading:'Turniererinnerungen werden geladen…',empty:'Noch keine gemerkten Turniere. Wähle den Stern bei einem zukünftigen Turnier.',upcoming:'Anmeldung noch nicht offen',open:'Anmeldungen geöffnet',applied:'Bereits angemeldet',closed:'Anmeldefenster geschlossen',canceled:'Turnier abgesagt',opens:'Öffnet',closes:'Schließt',watch:'Erinnere mich an die Anmeldung',unwatch:'Erinnerung entfernen',openTournament:'Turnier öffnen',limit:'Bis zu 60 Turniere pro Spielsaison',note:'Benachrichtigungen kommen automatisch nahe der Öffnungszeit, auch wenn du offline bist. Es erfolgt keine automatische Anmeldung. Nachrichten erscheinen im Spiel, nicht per E-Mail oder Geräte-Push.',error:'Erinnerungen konnten nicht geladen oder gespeichert werden.',saved:'Erinnerung gespeichert',removed:'Erinnerung entfernt',
}
const sr: Translation = {
 title:'Premium podsetnici za turnire',intro:'Označi turnir zvezdicom pre otvaranja prijava. Kada se prijave otvore, stiže obaveštenje u igri.',locked:'Podsetnici su Premium funkcija. Kalendar i prijavljivanje ostaju besplatni.',plans:'Pogledaj Premium',loading:'Učitavanje podsetnika…',empty:'Još nema označenih turnira. Odaberi zvezdicu pored budućeg turnira.',upcoming:'Prijave još nisu otvorene',open:'Prijave su otvorene',applied:'Već prijavljen',closed:'Prijave su zatvorene',canceled:'Turnir je otkazan',opens:'Otvara se',closes:'Zatvara se',watch:'Podseti me na otvaranje prijava',unwatch:'Ukloni podsetnik',openTournament:'Otvori turnir',limit:'Do 60 turnira po sezoni igre',note:'Obaveštenje stiže blizu otvaranja, čak i kada nisi na mreži. Nema automatske prijave ni garancije učešća. Poruka stiže u igri, ne mejlom ili kao push.',error:'Podsetnik nije mogao da se učita ili sačuva.',saved:'Podsetnik sačuvan',removed:'Podsetnik uklonjen',
}
const es: Translation = {
 title:'Lista de seguimiento Premium',intro:'Marca un torneo antes de abrirse las inscripciones. Recibirás un aviso en el juego al abrirse el plazo oficial.',locked:'Los recordatorios son Premium. El calendario y las inscripciones siguen siendo gratuitos.',plans:'Ver Premium',loading:'Cargando recordatorios…',empty:'No hay torneos guardados. Marca la estrella de uno futuro.',upcoming:'Inscripciones pendientes',open:'Inscripciones abiertas',applied:'Ya inscrito',closed:'Plazo cerrado',canceled:'Torneo cancelado',opens:'Abre',closes:'Cierra',watch:'Recordarme cuando abran las inscripciones',unwatch:'Quitar recordatorio',openTournament:'Abrir torneo',limit:'Hasta 60 torneos por temporada del juego',note:'El aviso llegará cerca de la apertura aunque estés desconectado. No inscribe automáticamente ni garantiza una plaza. Solo avisos dentro del juego, no correo ni push.',error:'No se pudo guardar o cargar el recordatorio.',saved:'Recordatorio guardado',removed:'Recordatorio eliminado',
}
const fr: Translation = {
 title:'Liste de suivi Premium',intro:'Marquez un tournoi avant l’ouverture des inscriptions. Une notification du jeu vous avertira dès l’ouverture officielle.',locked:'Les rappels sont Premium. Calendrier et inscriptions restent gratuits.',plans:'Découvrir Premium',loading:'Chargement des rappels…',empty:'Aucun tournoi suivi. Sélectionnez l’étoile d’un tournoi futur.',upcoming:'Inscriptions à venir',open:'Inscriptions ouvertes',applied:'Déjà inscrit',closed:'Inscriptions closes',canceled:'Tournoi annulé',opens:'Ouverture',closes:'Clôture',watch:'Me rappeler l’ouverture des inscriptions',unwatch:'Retirer le rappel',openTournament:'Ouvrir le tournoi',limit:'Jusqu’à 60 tournois par saison de jeu',note:'Le rappel arrive près de l’ouverture, même hors ligne. Il ne vous inscrit pas et ne garantit aucune place. Notification dans le jeu uniquement, sans courriel ni push.',error:'Impossible de charger ou modifier les rappels.',saved:'Rappel enregistré',removed:'Rappel retiré',
}
const it: Translation = {
 title:'Promemoria tornei Premium',intro:'Segna un torneo con la stella prima dell’apertura iscrizioni. Riceverai una notifica nel gioco quando apriranno.',locked:'I promemoria sono Premium. Calendario e iscrizioni restano gratuiti.',plans:'Scopri Premium',loading:'Caricamento promemoria…',empty:'Nessun torneo seguito. Premi la stella accanto a un torneo futuro.',upcoming:'Iscrizioni non ancora aperte',open:'Iscrizioni aperte',applied:'Già iscritto',closed:'Iscrizioni chiuse',canceled:'Torneo annullato',opens:'Apre',closes:'Chiude',watch:'Ricordami quando aprono le iscrizioni',unwatch:'Rimuovi promemoria',openTournament:'Apri torneo',limit:'Fino a 60 tornei per stagione di gioco',note:'La notifica arriva vicino all’apertura anche quando sei offline. Nessuna iscrizione automatica o posto garantito. Solo notifica nel gioco, non email o push.',error:'Impossibile caricare o salvare il promemoria.',saved:'Promemoria salvato',removed:'Promemoria rimosso',
}
const ru: Translation = {
 title:'Premium — избранные турниры',intro:'Отметьте турнир звездой до открытия заявок. В момент открытия получите уведомление в игре.',locked:'Напоминания доступны в Premium. Календарь и заявки остаются бесплатными.',plans:'Узнать о Premium',loading:'Загрузка напоминаний…',empty:'Пока нет избранных турниров. Нажмите звезду у будущего турнира.',upcoming:'Заявки ещё не открыты',open:'Приём заявок открыт',applied:'Заявка уже подана',closed:'Приём заявок закрыт',canceled:'Турнир отменён',opens:'Открытие',closes:'Закрытие',watch:'Напомнить об открытии заявок',unwatch:'Убрать напоминание',openTournament:'Открыть турнир',limit:'До 60 турниров за игровой сезон',note:'Уведомление придёт около открытия, даже если вы офлайн. Заявка не подаётся автоматически, участие не гарантировано. Только уведомление в игре, без почты и push.',error:'Не удалось загрузить или сохранить напоминание.',saved:'Напоминание сохранено',removed:'Напоминание удалено',
}
const pt: Translation = {
 title:'Lista de torneios Premium',intro:'Marca um torneio com a estrela antes da abertura das inscrições. Receberás uma notificação no jogo quando abrirem.',locked:'Os lembretes são Premium. Calendário e inscrições continuam gratuitos.',plans:'Explorar Premium',loading:'A carregar lembretes…',empty:'Ainda não há torneios guardados. Marca a estrela de um torneio futuro.',upcoming:'Inscrições ainda fechadas',open:'Inscrições abertas',applied:'Já inscrito',closed:'Prazo encerrado',canceled:'Torneio cancelado',opens:'Abre',closes:'Fecha',watch:'Lembrar quando abrirem as inscrições',unwatch:'Remover lembrete',openTournament:'Abrir torneio',limit:'Até 60 torneios por época do jogo',note:'O aviso chega perto da abertura, mesmo offline. Não faz a inscrição nem garante vaga. Notificação apenas no jogo, sem email ou push.',error:'Não foi possível carregar ou guardar o lembrete.',saved:'Lembrete guardado',removed:'Lembrete removido',
}
const labels: Record<string, Translation> = {en,de,sr,es,fr,it,ru,pt}
export function tournamentWatchLabels(lang?: string): Translation {
  return labels[(lang ?? 'en').toLowerCase().split('-')[0]] ?? en
}
