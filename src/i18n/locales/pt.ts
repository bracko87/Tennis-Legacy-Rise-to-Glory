// Brazilian Portuguese localization — staged rollout. English fallback remains for untranslated keys.
// Keep this locale disabled in the public selector until the complete translation passes QA.
import en from './en'

type TranslationShape<T> = T extends string ? string
  : T extends readonly (infer U)[] ? TranslationShape<U>[]
  : T extends object ? { [K in keyof T]?: TranslationShape<T[K]> }
  : T

const portugueseTranslations = {
  common: {
    language: 'Idioma', english: 'Inglês', serbian: 'Sérvio', german: 'Alemão',
    spanish: 'Espanhol', italian: 'Italiano', french: 'Francês', russian: 'Russo',
    portuguese: 'Português (Brasil)',
    save: 'Salvar', saving: 'Salvando…', saved: 'Salvo',
    cancel: 'Cancelar', close: 'Fechar', back: 'Voltar', next: 'Próximo',
    continue: 'Continuar', confirm: 'Confirmar', loading: 'Carregando…',
    error: 'Erro', retry: 'Tentar novamente', search: 'Pesquisar',
    filters: 'Filtros', all: 'Todos', yes: 'Sim', no: 'Não', free: 'Grátis',
    premium: 'Premium', coins: 'Coins', active: 'Ativo',
    unavailable: 'Indisponível', details: 'Detalhes', hide: 'Ocultar',
    open: 'Abrir', remove: 'Remover', apply: 'Aplicar', applied: 'Aplicado',
    selected: 'Selecionado', choose: 'Escolher', today: 'Hoje',
    days_one: '{{count}} dia', days_other: '{{count}} dias',
    matches_one: '{{count}} partida', matches_other: '{{count}} partidas',
    players_one: '{{count}} jogador', players_other: '{{count}} jogadores',
    tournaments_one: '{{count}} torneio', tournaments_other: '{{count}} torneios',
    notifications_one: '{{count}} notificação', notifications_other: '{{count}} notificações',
    coinsCount_one: '{{count}} Coin', coinsCount_other: '{{count}} Coins',
    points_one: '{{count}} ponto', points_other: '{{count}} pontos',
  },
  nav: {
    managerCenter: 'Central de gerenciamento',
    overview: 'Visão geral', overviewDesc: 'Centro de controle da carreira',
    skills: 'Habilidades', skillsDesc: 'Atributos e desenvolvimento',
    training: 'Treinamento', trainingDesc: 'Treinamento regular e períodos de preparação',
    staff: 'Equipe técnica', staffDesc: 'Treinadores e equipe de apoio',
    calendar: 'Calendário', calendarDesc: 'Temporada e torneios',
    schedule: 'Agenda', scheduleDesc: 'Eventos e compromissos',
    rankings: 'Rankings', rankingsDesc: 'Simples ATP / WTA',
    equipment: 'Equipamentos', equipmentDesc: 'Equipamentos de desempenho',
    finance: 'Finanças', financeDesc: 'Economia da carreira',
    nationalTeam: 'Seleção nacional', nationalTeamDesc: 'Federação e capitania',
    privateLife: 'Vida pessoal', privateLifeDesc: 'Estilo de vida Premium',
    tennisClub: 'Clube de tênis', tennisClubDesc: 'Comunidade do clube',
    statistics: 'Estatísticas', statisticsDesc: 'Resultados e análises',
    playerProfile: 'Perfil do jogador', tournament: 'Torneio',
    managerInbox: 'Caixa de entrada', playerAccount: 'Jogador e conta',
    gamePreferences: 'Preferências do jogo', helpCenter: 'Central de ajuda',
    forumDiscord: 'Fórum / Discord', contactUs: 'Fale conosco',
    inviteFriends: 'Convide amigos', notifications: 'Notificações',
    proPackages: 'Pacotes Pro', expandNavigation: 'Expandir navegação',
    collapseNavigation: 'Recolher navegação', gameNavigation: 'Navegação do jogo',
    signOut: 'Sair', version: 'Versão {{version}}',
  },
  header: {
    countryNotSet: 'País não definido', playerFallback: 'Jogador do Tennis Legacy',
    openNavigation: 'Abrir navegação',
    worldRankAria: 'Posição atual no ranking mundial: {{rank}}',
    worldRankUnavailable: 'Ranking mundial indisponível',
    earnFreeCoins: 'Ganhe Coins grátis',
    earnFreeCoinsAria: 'Ganhe Coins grátis respondendo a pesquisas opcionais',
    notifications: 'Notificações',
    notificationsUnread: 'Notificações, {{count}} não lidas',
    premium: 'Premium', settings: 'Configurações',
    managerSettings: 'Configurações de gerenciamento',
    playerAccount: 'Jogador e conta', playerAccountDesc: 'Identidade e conta',
    gamePreferences: 'Preferências do jogo',
    gamePreferencesDesc: 'Configurações pessoais do jogo',
    inbox: 'Caixa de entrada', inboxDesc: 'Mensagens de gerenciamento',
    help: 'Ajuda', helpDesc: 'Guias e suporte',
    forum: 'Fórum', forumDesc: 'Discussões da comunidade',
    proPackages: 'Pacotes Pro', proPackagesDesc: 'Serviços Premium e Coins',
    contactUs: 'Fale conosco', contactUsDesc: 'Entre em contato com o Tennis Legacy',
    inviteFriends: 'Convide amigos', inviteFriendsDesc: 'Compartilhe o Tennis Legacy',
    logout: 'Sair', logoutDesc: 'Sair da sua conta',
  },
  footer: {
    synchronizingClock: 'Sincronizando o relógio do jogo…',
    clockUnavailable: 'Relógio do jogo indisponível',
    season: 'Temporada {{season}}',
    alsoFromStudio: 'Também do nosso estúdio: ProPeloton Manager ↗',
    proPelotonAria: 'Jogue ProPeloton Manager, outro jogo da Next Quest Studio',
    coinBalanceAria: '{{count}} Coins. Abrir Pacotes Pro.',
    coinStoreTitle: 'Abrir Pacotes Pro e loja de Coins',
  },
  settings: {
    title: 'Preferências do jogo',
    subtitle: 'Configurações da experiência pessoal de jogo',
    managerSettings: 'Configurações de gerenciamento',
    preferences: 'Preferências',
    intro: 'Controle como o Tennis Legacy comunica eventos importantes do jogo e novidades da carreira.',
    languageSection: 'Idioma', languageTitle: 'Idioma do jogo',
    languageDescription: 'Escolha o idioma usado no Tennis Legacy. Sua escolha é salva na sua conta e acompanha você em outros dispositivos.',
    sourceNote: 'O inglês é o idioma de origem. Apenas os pacotes de idioma aprovados nos testes de qualidade ficam disponíveis.',
    languageSaved: 'Preferência de idioma salva.',
    languageSaveError: 'Não foi possível salvar a preferência de idioma. Tente novamente.',
    serbianLatin: 'Sérvio (latino)', qaReady: 'Disponível',
    qaPending: 'Disponível após os testes',
    notifications: 'Notificações',
    inGameNotifications: 'Notificações do jogo',
    notificationDescription: 'Escolha quais eventos do jogo devem gerar notificações na central de gerenciamento.',
    notificationNotConfigured: 'As preferências de notificações ainda não foram configuradas',
    notificationPlaceholder: 'Esta seção está preparada para controles individuais de notificações. As opções serão adicionadas quando os respectivos sistemas de notificação do Tennis Legacy forem conectados.',
  },
  marketing: {
    home: 'Início', features: 'Recursos', howItWorks: 'Como funciona',
    gameWorld: 'Mundo do jogo', signIn: 'Entrar', signOut: 'Sair',
    signingOut: 'Saindo…', dashboard: 'Painel',
    createPlayer: 'Criar jogador', startPlaying: 'Começar a jogar',
    openNavigation: 'Abrir navegação', closeNavigation: 'Fechar navegação',
    mainNavigation: 'Navegação principal', mobileNavigation: 'Navegação móvel',
  },
  home: {
    stats: {
      activePlayers: 'Jogadores ativos', tournaments: 'Total de torneios',
      matches: 'Partidas concluídas', countries: 'Países representados',
      connecting: 'Conectando ao Supabase', liveData: 'Dados ao vivo',
    },
    hero: {
      eyebrow: 'Gerenciamento de tênis multijogador online',
      line1: 'Construa sua carreira.', line2: 'Crie seu legado.',
      description: 'Crie e desenvolva seu próprio tenista profissional, domine todas as superfícies, enfrente técnicos reais e avance de uma promessa desconhecida até se tornar uma lenda do tênis mundial.',
      start: 'Começar a jogar', signIn: 'Entrar',
      explore: 'Conhecer o jogo', persistent: 'Mundo multijogador persistente',
      seasonTime: 'Tempo de jogo por temporadas', worlds: 'Circuitos ATP e WTA',
      ranking: 'Ranking mundial', futureData: 'Dados futuros do Supabase',
      currentTime: 'Horário atual do jogo',
    },
    liveWorld: {
      eyebrow: 'Mundo do jogo ao vivo',
      title: 'Um universo de tênis compartilhado',
      description: 'Estes valores estão preparados para integração direta com o Supabase e atualmente não exibem dados ao vivo inventados.',
      aria: 'Estatísticas do jogo ao vivo',
    },
    fantasy: {
      eyebrow: 'A carreira dos sonhos',
      title: 'Um jogador. Uma carreira.', titleAccent: ' Um legado.',
      description: 'O Tennis Legacy coloca você no controle de todas as decisões importantes da carreira. Seu jogador não é apenas um conjunto de atributos: é um atleta em desenvolvimento que compete em um mundo online vivo.',
      decisions: [
        'Escolha torneios e planeje a temporada',
        'Desenvolva atributos técnicos e físicos',
        'Prepare táticas para adversários específicos',
        'Gerencie equipamentos, viagens e finanças da carreira',
        'Preserve energia, condição física e confiança',
        'Construa rankings, recordes e reputação',
      ],
    },
    journey: {
      eyebrow: 'Sua jornada', title: 'De promessa a campeão',
      description: 'Cada carreira começa com um jogador e evolui por meio de preparação, competições e gerenciamento de longo prazo.',
      createTitle: 'Crie seu jogador',
      createBody: 'Escolha o circuito ATP ou WTA, selecione seu país e crie uma identidade profissional realista.',
      trainTitle: 'Treine e evolua',
      trainBody: 'Melhore atributos técnicos, físicos, táticos e mentais ao longo da temporada.',
      competeTitle: 'Compita pelo mundo',
      competeBody: 'Inscreva-se em torneios, prepare-se para os adversários e enfrente outros técnicos reais.',
      legacyTitle: 'Construa seu legado',
      legacyBody: 'Conquiste títulos, suba no ranking e crie uma carreira que fará parte da história do tênis.',
    },
    worlds: {
      eyebrow: 'Escolha seu circuito',
      title: 'Dois circuitos. Um padrão de excelência.',
      description: 'Seu jogador entra no circuito profissional ATP ou WTA. Essa escolha define o ambiente competitivo e é permanente para o jogador.',
      atpTitle: 'Circuito ATP', atpSubtitle: 'Tênis profissional masculino',
      atpBody: 'Construa uma carreira em uma estrutura profissional completa, com torneios, ranking mundial e competição multijogador.',
      wtaTitle: 'Circuito WTA', wtaSubtitle: 'Tênis profissional feminino',
      wtaBody: 'Crie uma jogadora e compita em um circuito profissional dedicado, com ranking, torneios e recordes próprios.',
      permanent: 'Escolha permanente do jogador', create: 'Criar jogador',
    },
  },
} satisfies TranslationShape<typeof en>

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}
function mergeTranslations(base: Record<string, unknown>, overrides: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = { ...base }
  for (const [key, value] of Object.entries(overrides)) {
    result[key] = isPlainObject(value) && isPlainObject(base[key])
      ? mergeTranslations(base[key] as Record<string, unknown>, value)
      : value
  }
  return result
}
export default mergeTranslations(en as unknown as Record<string, unknown>, portugueseTranslations)
