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
