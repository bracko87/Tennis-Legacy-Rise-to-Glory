export const TUTORIAL_VERSION = 'launch-v1'

export type TutorialRoute =
  | string
  | 'player-profile'
  | 'next-tournament'
  | 'next-tournament-doubles'
  | 'tournament-preparation'

export type TutorialPlacement = 'auto' | 'top' | 'bottom' | 'left' | 'right'

export interface TutorialPhase {
  id: string
  titleKey: string
  descriptionKey: string
}

export interface TutorialStep {
  id: string
  phaseId: string
  route: TutorialRoute
  target?: string
  fallbackTarget?: string
  placement?: TutorialPlacement
  copyKey: string
  noTournamentCopyKey?: string
  accessKey?: string
}

export interface TutorialCopy {
  title: string
  body: string
  action?: string
  actionLabel?: string
  tip?: string
}

type TutorialResources = {
  phases: Record<string, { title: string; description: string }>
  steps: Record<string, TutorialCopy>
  access: Record<string, {
    tone: 'premium' | 'coins' | 'mixed' | 'optional'
    label: string
    title: string
    body: string
  }>
  ui: {
    tutorial: string
    phase: string
    step: string
    back: string
    next: string
    finish: string
    pause: string
    skip: string
    resume: string
    start: string
    restart: string
    completed: string
    doThis: string
    tip: string
    closeLabel: string
  }
}

export const TUTORIAL_PHASES: TutorialPhase[] = [
  { id: 'welcome', titleKey: 'welcome', descriptionKey: 'welcome' },
  { id: 'player', titleKey: 'player', descriptionKey: 'player' },
  { id: 'development', titleKey: 'development', descriptionKey: 'development' },
  { id: 'season', titleKey: 'season', descriptionKey: 'season' },
  { id: 'competition', titleKey: 'competition', descriptionKey: 'competition' },
  { id: 'career', titleKey: 'career', descriptionKey: 'career' },
  { id: 'communication', titleKey: 'communication', descriptionKey: 'communication' },
  { id: 'support', titleKey: 'support', descriptionKey: 'support' },
]

export const TUTORIAL_STEPS: TutorialStep[] = [
  {
    id: 'welcome.overview',
    phaseId: 'welcome',
    route: '/game/overview',
    target: '[data-tutorial-page-content]',
    placement: 'bottom',
    copyKey: 'welcome.overview',
    accessKey: 'overview-premium-extra',
  },
  {
    id: 'welcome.rank',
    phaseId: 'welcome',
    route: '/game/overview',
    target: '[data-tutorial-id="header-rank"]',
    fallbackTarget: '[data-tutorial-page-content]',
    copyKey: 'welcome.rank',
  },
  {
    id: 'welcome.navigation',
    phaseId: 'welcome',
    route: '/game/overview',
    target: '[data-tutorial-id="nav-overview"]',
    fallbackTarget: '[data-tutorial-page-content]',
    copyKey: 'welcome.navigation',
  },

  {
    id: 'player.profile',
    phaseId: 'player',
    route: 'player-profile',
    target: '[data-tutorial-page-content]',
    copyKey: 'player.profile',
  },
  {
    id: 'player.account',
    phaseId: 'player',
    route: '/game/player-account',
    target: '[data-tutorial-page-content]',
    copyKey: 'player.account',
  },
  {
    id: 'player.skills',
    phaseId: 'player',
    route: '/game/skills',
    target: '[data-tutorial-page-content]',
    copyKey: 'player.skills',
  },

  {
    id: 'development.training',
    phaseId: 'development',
    route: '/game/training',
    target: '[data-tutorial-page-content]',
    copyKey: 'development.training',
  },
  {
    id: 'development.training-camps',
    phaseId: 'development',
    route: '/game/training?view=camps',
    target: '.tlg-camp-page',
    fallbackTarget: '.tlg-training-main-tabs',
    copyKey: 'development.training-camps',
  },
  {
    id: 'development.staff',
    phaseId: 'development',
    route: '/game/staff',
    target: '[data-tutorial-page-content]',
    copyKey: 'development.staff',
  },
  {
    id: 'development.staff-market',
    phaseId: 'development',
    route: '/game/staff?view=market',
    target: '.tlg-staff-market-layout',
    fallbackTarget: '.tlg-staff-tabs',
    copyKey: 'development.staff-market',
  },
  {
    id: 'development.health',
    phaseId: 'development',
    route: '/game/injuries',
    target: '[data-tutorial-page-content]',
    copyKey: 'development.health',
  },

  {
    id: 'season.calendar',
    phaseId: 'season',
    route: '/game/calendar',
    target: '.tlg-season-calendar',
    fallbackTarget: '[data-tutorial-page-content]',
    copyKey: 'season.calendar',
  },
  {
    id: 'season.tournament-calendar',
    phaseId: 'season',
    route: '/game/calendar?tab=tournament-calendar',
    target: '.tlg-tournament-calendar',
    fallbackTarget: '[data-tutorial-page-content]',
    copyKey: 'season.tournament-calendar',
  },
  {
    id: 'season.schedule',
    phaseId: 'season',
    route: '/game/schedule',
    target: '.tlg-next-tournament-card',
    fallbackTarget: '[data-tutorial-page-content]',
    copyKey: 'season.schedule',
  },
  {
    id: 'season.tournament',
    phaseId: 'season',
    route: 'next-tournament',
    target: '[data-tutorial-page-content]',
    copyKey: 'season.tournament',
    noTournamentCopyKey: 'season.tournament.empty',
  },
  {
    id: 'season.preparation',
    phaseId: 'season',
    route: 'tournament-preparation',
    target: '.tlg-tournament-prep-dialog',
    fallbackTarget: '[data-tutorial-page-content]',
    copyKey: 'season.preparation',
    noTournamentCopyKey: 'season.preparation.empty',
  },
  {
    id: 'season.doubles',
    phaseId: 'season',
    route: 'next-tournament-doubles',
    target: '[data-tutorial-page-content]',
    copyKey: 'season.doubles',
    noTournamentCopyKey: 'season.doubles.empty',
  },

  {
    id: 'competition.rankings',
    phaseId: 'competition',
    route: '/game/rankings',
    target: '[data-tutorial-page-content]',
    copyKey: 'competition.rankings',
    accessKey: 'rankings-premium-extra',
  },
  {
    id: 'competition.national-team',
    phaseId: 'competition',
    route: '/game/national-team',
    target: '[data-tutorial-page-content]',
    copyKey: 'competition.national-team',
    accessKey: 'national-team-coins',
  },
  {
    id: 'competition.equipment',
    phaseId: 'competition',
    route: '/game/equipment',
    target: '[data-tutorial-page-content]',
    copyKey: 'competition.equipment',
  },
  {
    id: 'competition.technical-sponsors',
    phaseId: 'competition',
    route: '/game/equipment?tab=sponsors',
    target: '.tlg-technical-sponsor-panel',
    fallbackTarget: '.tlg-equipment-tabs',
    copyKey: 'competition.technical-sponsors',
  },

  {
    id: 'career.finance',
    phaseId: 'career',
    route: '/game/finance',
    target: '[data-tutorial-page-content]',
    copyKey: 'career.finance',
  },
  {
    id: 'career.financial-sponsors',
    phaseId: 'career',
    route: '/game/finance?tab=sponsors',
    target: '.tlg-finance-sponsor-page',
    fallbackTarget: '.tlg-finance-v2-sponsors',
    copyKey: 'career.financial-sponsors',
  },
  {
    id: 'career.private-life',
    phaseId: 'career',
    route: '/game/private-life',
    target: '[data-tutorial-page-content]',
    copyKey: 'career.private-life',
    accessKey: 'private-life-premium',
  },
  {
    id: 'career.tennis-club',
    phaseId: 'career',
    route: '/game/tennis-club',
    target: '[data-tutorial-page-content]',
    copyKey: 'career.tennis-club',
    accessKey: 'tennis-club-coins',
  },
  {
    id: 'career.statistics',
    phaseId: 'career',
    route: '/game/statistics',
    target: '[data-tutorial-page-content]',
    copyKey: 'career.statistics',
  },

  {
    id: 'communication.notifications',
    phaseId: 'communication',
    route: '/game/notifications',
    target: '[data-tutorial-page-content]',
    copyKey: 'communication.notifications',
  },
  {
    id: 'communication.inbox',
    phaseId: 'communication',
    route: '/game/inbox',
    target: '[data-tutorial-page-content]',
    copyKey: 'communication.inbox',
  },
  {
    id: 'communication.preferences',
    phaseId: 'communication',
    route: '/game/preferences',
    target: '[data-tutorial-page-content]',
    copyKey: 'communication.preferences',
  },
  {
    id: 'communication.premium',
    phaseId: 'communication',
    route: '/game/pro-packages',
    target: '[data-tutorial-page-content]',
    copyKey: 'communication.premium',
    accessKey: 'premium-store-optional',
  },

  {
    id: 'support.help',
    phaseId: 'support',
    route: '/game/help',
    target: '.tlg-help-hero',
    fallbackTarget: '[data-tutorial-page-content]',
    copyKey: 'support.help',
  },
  {
    id: 'support.manual',
    phaseId: 'support',
    route: '/game/manual',
    target: '.tlg-manual-page',
    fallbackTarget: '[data-tutorial-page-content]',
    copyKey: 'support.manual',
  },
  {
    id: 'support.forum',
    phaseId: 'support',
    route: '/game/forum',
    target: '[data-tutorial-page-content]',
    copyKey: 'support.forum',
  },
  {
    id: 'support.contact',
    phaseId: 'support',
    route: '/game/contact',
    target: '[data-tutorial-page-content]',
    copyKey: 'support.contact',
  },
  {
    id: 'support.bug-report',
    phaseId: 'support',
    route: '/game/help',
    target: '.tlg-bug-launcher',
    fallbackTarget: '.tlg-help-hero',
    copyKey: 'support.bug-report',
  },
  {
    id: 'support.invite',
    phaseId: 'support',
    route: '/game/invite-friends',
    target: '[data-tutorial-page-content]',
    copyKey: 'support.invite',
  },
  {
    id: 'support.access-model',
    phaseId: 'support',
    route: '/game/pro-packages',
    target: '[data-tutorial-page-content]',
    copyKey: 'support.access-model',
    accessKey: 'free-coins-premium',
  },
  {
    id: 'support.complete',
    phaseId: 'support',
    route: '/game/overview',
    target: '[data-tutorial-page-content]',
    copyKey: 'support.complete',
  },
]

const EN: TutorialResources = {
  phases: {
    welcome: {
      title: 'Welcome to your career',
      description: 'Learn the manager center, your world ranking and the navigation you will use every game day.',
    },
    player: {
      title: 'Your player',
      description: 'Understand your identity, attributes and the information that defines your tennis career.',
    },
    development: {
      title: 'Development & health',
      description: 'Learn how training, staff and health decisions change your player over time.',
    },
    season: {
      title: 'Season planning & tournaments',
      description: 'Plan the calendar, manage commitments and prepare correctly for competition.',
    },
    competition: {
      title: 'Competitive systems',
      description: 'Understand rankings, national competition and the equipment you take onto court.',
    },
    career: {
      title: 'Career management',
      description: 'Control money, optional lifestyle systems, club features and long-term statistics.',
    },
    communication: {
      title: 'Communication & preferences',
      description: 'Stay informed, manage messages and understand optional premium services.',
    },
    support: {
      title: 'Help & community',
      description: 'Know where to find detailed rules, support and the Tennis Legacy community.',
    },
  },
  steps: {
    'welcome.overview': {
      title: 'Welcome to Tennis Legacy',
      body: 'Overview is your career command center. It brings together your current condition, next tournament, recent results, ranking context, finances and the most important actions that need your attention. The page itself is part of the free core game; only the Ranking Protection panel is a Premium extra.',
      action: 'Use Overview as the first page you check when a new game day begins.',
      tip: 'The tutorial will move page by page. You can pause it at any time and resume later.',
    },
    'welcome.rank': {
      title: 'Your current world ranking',
      body: 'The number in the header is your live ATP or WTA singles ranking. Tournament results add ranking points and older contributions eventually expire, so your position can move even when you are not playing.',
      action: 'Keep an eye on this number, but make season decisions from the Rankings and Calendar pages rather than chasing rank alone.',
    },
    'welcome.navigation': {
      title: 'The Manager Center',
      body: 'The left navigation is the main map of your career. Each page owns a specific system, so important changes should be made on the page designed for them instead of from Overview.',
      action: 'On mobile, open the menu button in the header to reach the same navigation.',
    },

    'player.profile': {
      title: 'Player Profile',
      body: 'Your profile is the public tennis identity other managers can inspect. It shows your nationality, ranking context, playing identity and career-facing information without exposing private management controls.',
      action: 'Use profiles to understand opponents and other players; use Player & Account for your own account-level actions.',
    },
    'player.account': {
      title: 'Player & Account',
      body: 'This page contains identity and account controls such as your player name, competition world, country, avatar management, password recovery and destructive account actions.',
      action: 'Treat restart and delete actions carefully. Your professional player name is intentionally permanent after career creation.',
    },
    'player.skills': {
      title: 'Skills & attributes',
      body: 'Skills are the foundation of match performance. Technical abilities, physical qualities and player condition work together; a high number in one area cannot completely compensate for weaknesses elsewhere.',
      action: 'Use this page to identify what your player needs to improve before choosing training priorities.',
      tip: 'Surface preference and playing style matter when you interpret the same attribute values.',
    },

    'development.training': {
      title: 'Regular Training',
      body: 'Plan weekly development on Home days. Tournament, travel, camp and health days automatically take priority.',
      action: 'Use harder sessions when fresh; use recovery or a Day Off when fatigue is building.',
    },
    'development.training-camps': {
      title: 'Training Camps',
      body: 'Camps are focused development blocks with destination, week, duration, accommodation, staff, travel and total cost.',
      action: 'Choose a camp that fits your development goal and calendar. A camp cannot overlap a tournament or blocked travel period.',
      actionLabel: 'What to check',
      tip: 'Travelling staff can add camp-specific benefits, but they also increase travel and accommodation cost.',
    },
    'development.staff': {
      title: 'Your Staff',
      body: 'You can employ one specialist per role. Each role affects a different part of development, recovery, analysis or career management.',
      action: 'Check the real effect, weekly salary and remaining contract before changing your team.',
    },
    'development.staff-market': {
      title: 'Staff Market',
      body: 'The Staff Market is where you search worldwide candidates by role, quality, country and salary.',
      action: 'Select a candidate, compare attributes and total contract commitment, then negotiate before confirming the hire.',
      actionLabel: 'What to do',
      tip: 'Higher-rated staff are useful, but salary and role fit matter more than simply hiring the most expensive person.',
    },
    'development.health': {
      title: 'Health, injuries & illness',
      body: 'This page explains your current health state, fatigue, injury risk, illness risk, restrictions and recovery timeline. Health rules are game-day based and can block training or competition when necessary.',
      action: 'If risk rises, reduce workload and prioritize recovery instead of waiting for an injury to happen.',
    },

    'season.calendar': {
      title: 'Your Career Calendar',
      body: 'The Calendar tab shows your own season: matches, tournament commitments, travel, training camps, recovery and other blocked days.',
      action: 'Check this view before booking a camp or adding another tournament so you do not create avoidable conflicts.',
    },
    'season.tournament-calendar': {
      title: 'Tournament Calendar',
      body: 'The Tournament Calendar lists official ATP or WTA events by competition week, category, surface, location and entry status.',
      action: 'Open a tournament row, review the application window and your entry status, then submit the tournament application from that tournament page when applications are open.',
      actionLabel: 'How to join a tournament',
      tip: 'Plan at least a few weeks ahead. Consecutive events can create extra travel and reduce recovery time.',
    },
    'season.schedule': {
      title: 'Schedule & commitments',
      body: 'Schedule turns applications and accepted events into your personal plan. It shows what is coming next, travel timing, preparation status and other commitments that can conflict with one another.',
      action: 'Check this page after every tournament application or schedule change.',
    },
    'season.tournament': {
      title: 'Tournament page',
      body: 'A tournament page contains the event-specific information you need: draw and entry state, match schedule, opponents, results and tournament actions. This is where the general calendar becomes a real competition.',
      action: 'Before the event starts, confirm your entry state and watch for the first scheduled match.',
    },
    'season.tournament.empty': {
      title: 'Tournament page',
      body: 'You do not currently have a next tournament that the tutorial can open. Tournament pages become available from Calendar or Schedule once you have an event to inspect.',
      action: 'Use Calendar to choose an event, then return to Schedule when the application or entry becomes relevant.',
    },
    'season.preparation': {
      title: 'Prepare Tournament',
      body: 'Tournament preparation controls travel class, hotel, travelling staff and your default tactic. Costs and effects are calculated before saving, and unsaved changes do not become active.',
      action: 'Review Summary & Effects before saving. Travelling staff cost money but provide their role-specific tournament benefit while they travel with you.',
      tip: 'Preparation locks according to the real travel and match schedule, so do not wait until the last moment.',
    },
    'season.preparation.empty': {
      title: 'Tournament preparation',
      body: 'There is no eligible upcoming tournament to open in preparation mode right now. The Prepare Tournament action appears on Schedule when an event is available and preparation is still open.',
      action: 'Remember the flow: Schedule → Prepare Tournament → review costs/effects → Save Tournament Plan.',
    },
    'season.doubles': {
      title: 'Tournament doubles',
      body: 'When doubles is available, the doubles tournament view keeps partner, entry and draw information separate from your singles competition. A doubles commitment can still affect your overall schedule.',
      action: 'Treat doubles as an additional commitment when planning fatigue, travel and match timing.',
    },
    'season.doubles.empty': {
      title: 'Tournament doubles',
      body: 'No upcoming tournament is available for the tutorial to open in doubles mode. When you have an event, the tournament page provides the doubles entry and partner flow where supported.',
      action: 'Remember that singles and doubles entries are separate even when they happen at the same tournament.',
    },

    'competition.rankings': {
      title: 'ATP / WTA Rankings',
      body: 'Rankings show the live competitive order of your tennis world. ATP and WTA remain separate, and official results create ranking-point contributions that move players over time. The ranking tables are free; the detailed Ranking Protection view showing upcoming point expirations is Premium-only.',
      action: 'Use rankings to compare your position, open player profiles and understand what level of tournament is realistic for your current career.',
    },
    'competition.national-team': {
      title: 'National Team',
      body: 'National competition adds country-based selection and association systems on top of your individual career. The page is not Premium-only, but association activation and seasonal renewal use community Coin funding. The current association activation target is 50 Coins plus at least 5 members, and the renewal target is 30 Coins.',
      action: 'Joining and participating are separate from purchasing Premium. Only contribute Coins when you choose to support an activation or renewal fund; contributions come from your Coin wallet.',
    },
    'competition.equipment': {
      title: 'Equipment',
      body: 'Your equipped racquet, shoes, clothing and accessories affect matches, condition and wear.',
      action: 'Check the active setup and equipment condition before important tournaments.',
    },
    'competition.technical-sponsors': {
      title: 'Technical Sponsors',
      body: 'Technical sponsors are equipment partnerships for racquets, shoes or clothing. They are separate from your main financial sponsor.',
      action: 'Compare the brand, contract slot, equipment discount, signing payment and season exclusivity before signing.',
      tip: 'A technical sponsor can lower equipment costs, but sponsored equipment is still managed through Equipment and Inventory.',
    },

    'career.finance': {
      title: 'Finance',
      body: 'Finance tracks career cash, income, expenses, tax, staff, travel, accommodation and the permanent transaction ledger.',
      action: 'Check available cash and upcoming commitments before an expensive decision.',
    },
    'career.financial-sponsors': {
      title: 'Main Financial Sponsor',
      body: 'Your main sponsor pays guaranteed career income and may add separate performance objectives with cash bonuses.',
      action: 'Compare guaranteed value, weekly payments, objectives, deadlines and maximum bonus value before signing.',
      actionLabel: 'What to compare',
      tip: 'This is separate from Technical Sponsors: the main sponsor is primarily a financial agreement, not an equipment contract.',
    },
    'career.private-life': {
      title: 'Private Life',
      body: 'Private Life is a Premium-only lifestyle system. Free players can continue the complete core tennis career without it. Premium members can use the page for properties, vehicles and other personal assets; purchases inside Private Life use the normal career Finance balance, not Coins.',
      action: 'If you are a Free player, you can simply skip this system. Becoming Premium unlocks the page, but it is not required for the core tennis career.',
    },
    'career.tennis-club': {
      title: 'Tennis Club',
      body: 'Tennis Club is the shared club layer for community and club-related gameplay. Viewing clubs, applying to join and accepting an invitation are different from creating your own club. Creating a new Tennis Club currently costs 50 Coins.',
      action: 'You do not need Premium membership to use the club system. Spend Coins only if you choose to create a new club; joining an existing club does not use the club-creation Coin fee.',
    },
    'career.statistics': {
      title: 'Statistics & career history',
      body: 'Statistics turns completed matches and tournament results into records. You can compare player statistics, tournament statistics and your own career records across surfaces, categories and seasons.',
      action: 'Use this page to evaluate long-term performance instead of judging your player from one good or bad match.',
    },

    'communication.notifications': {
      title: 'Notifications',
      body: 'Notifications surface important game events such as tournament changes, results, health information and other career updates. The unread badge in the header tells you when something still needs attention.',
      action: 'Open notifications regularly and clear important items after you understand what changed.',
    },
    'communication.inbox': {
      title: 'Manager Inbox',
      body: 'Inbox is for direct manager communication and messages that belong to a conversation rather than a system alert. It is intentionally separate from Notifications.',
      action: 'Use Notifications for automated game events and Inbox for direct correspondence.',
    },
    'communication.preferences': {
      title: 'Game Preferences',
      body: 'Preferences is the home for personal game-experience controls. Only settings that are actually connected to a live system should appear here.',
      action: 'Tutorial restart is kept in Help Center, so Game Preferences stays focused on actual personal settings.',
    },
    'communication.premium': {
      title: 'Premium & coin packages',
      body: 'This page is where optional purchases are kept transparent. Tennis Legacy Free provides the core career. Premium membership unlocks Premium-only features and includes 30 Coins per covered month: 30 on monthly billing, 90 on 3-month billing or 360 on annual billing. Coin packs are separate one-time purchases.',
      action: 'Premium and Coins are separate: buying Coins does not activate Premium, and becoming Premium does not make every Coin action free. Review the exact benefit before purchasing.',
    },

    'support.help': {
      title: 'Help Center',
      body: 'Help Center is the quick starting point when something is unclear. It links to common pages, support and the Full Game Manual without forcing you to search outside the game.',
      action: 'Use Help for quick direction. Use the Manual when you need the full rule or calculation explanation.',
    },
    'support.manual': {
      title: 'Full Game Manual',
      body: 'The Manual is the detailed reference for implemented gameplay. Unlike this tutorial, it is designed to be searched and revisited when you need exact rules, page explanations or system limitations.',
      action: 'Search by page or system whenever you need more detail than a tutorial step should provide.',
    },
    'support.forum': {
      title: 'Forum / Discord',
      body: 'The official community area is where players can discuss careers, strategy, tournaments, bugs and suggestions. Community advice can be useful, but the in-game Manual remains the authoritative gameplay reference.',
      action: 'Use the community to compare experiences and report reproducible issues.',
    },
    'support.contact': {
      title: 'Contact Support',
      body: 'Contact is for account questions, technical problems or support cases that need direct attention from the Tennis Legacy team.',
      action: 'When reporting a problem, include the page, what you expected, what happened and a screenshot when possible.',
    },
    'support.bug-report': {
      title: 'Report a Bug',
      body: 'If something looks wrong in the game, use the Report Bug button. The report automatically knows which page you are on.',
      action: 'Describe what happened, what you expected, and the steps to reproduce it. Add a screenshot when it helps.',
      actionLabel: 'Best bug report',
      tip: 'Please report problems instead of working around them silently — reproducible reports help us fix the game faster.',
    },
    'support.invite': {
      title: 'Invite Friends',
      body: 'Invite Friends gives you the game referral flow for bringing another manager into Tennis Legacy. Their career remains completely separate from yours.',
      action: 'Use the official invite link so referral tracking can work correctly when applicable.',
    },
    'support.access-model': {
      title: 'Free, Coins and Premium',
      body: 'You can play the core Tennis Legacy career for free. Optional Coins are used only for specific Coin actions, such as contributing to National Association funding or creating your own Tennis Club. Premium membership unlocks Premium-only features such as Private Life and Ranking Protection. Coin packs and Premium membership are optional purchases.',
      action: 'Play Free for the core career. Buy Coins only when you want an optional Coin action, or choose Premium only when its additional features are valuable to you.',
      tip: 'Coins and Premium are separate products: buying Coins does not activate Premium, and Premium does not remove every Coin cost.',
    },
    'support.complete': {
      title: 'You are ready to manage your career',
      body: 'You now know where every launch page belongs and how the core systems connect: develop the player, plan the season, prepare tournaments, protect health, manage money and review results. The core career remains playable on the Free plan; optional Coins and Premium features are clearly marked when they appear.',
      action: 'Return to Overview, check your next commitment and decide the single most important action for the current game day.',
      tip: 'You can restart this tutorial later only from Help Center. Paid or locked features are clearly marked inside the relevant tutorial step.',
    },
  },
  access: {
    'overview-premium-extra': {
      tone: 'mixed',
      label: 'FREE PAGE · PREMIUM EXTRA',
      title: 'Overview: Free · Ranking Protection: Premium',
      body: 'Core Overview stays Free. Only Ranking Protection requires Premium.',
    },
    'rankings-premium-extra': {
      tone: 'mixed',
      label: 'FREE PAGE · PREMIUM EXTRA',
      title: 'Rankings: Free · Protection: Premium',
      body: 'ATP/WTA rankings stay Free. Point-expiration protection tools require Premium.',
    },
    'national-team-coins': {
      tone: 'coins',
      label: 'COIN-FUNDED FEATURE',
      title: 'National Association funding uses Coins',
      body: 'Not Premium-only. Activation target: 50 Coins + 5 members. Renewal target: 30 Coins. Contributions are optional.',
    },
    'private-life-premium': {
      tone: 'premium',
      label: 'PREMIUM REQUIRED',
      title: 'Private Life requires Premium',
      body: 'Premium unlocks the page. Asset purchases then use normal Career Finance money, not Coins.',
    },
    'tennis-club-coins': {
      tone: 'coins',
      label: 'OPTIONAL COIN ACTION',
      title: 'Creating a Tennis Club costs 50 Coins',
      body: 'Viewing or joining a club does not use the creation fee. Only creating a new club costs 50 Coins.',
    },
    'premium-store-optional': {
      tone: 'optional',
      label: 'OPTIONAL PURCHASES',
      title: 'Premium and Coins are optional',
      body: 'The core career is playable for Free. Premium and Coin packs are separate optional purchases.',
    },
    'free-coins-premium': {
      tone: 'optional',
      label: 'CORE GAME IS FREE',
      title: 'Free career · Optional Coins · Optional Premium',
      body: 'Free covers the core career. Coins pay for specific optional actions; Premium unlocks clearly marked extras.',
    },
  },
  ui: {
    tutorial: 'Game Tutorial',
    phase: 'Phase',
    step: 'Step',
    back: 'Back',
    next: 'Next',
    finish: 'Finish tutorial',
    pause: 'Pause',
    skip: 'Skip tutorial',
    resume: 'Resume tutorial',
    start: 'Start tutorial',
    restart: 'Restart tutorial',
    completed: 'Tutorial completed',
    doThis: 'What to do',
    tip: 'Tip',
    closeLabel: 'Pause tutorial',
  },
}


const DE: TutorialResources = {
  phases: {
    welcome: {
      title: 'Willkommen in deiner Karriere',
      description: 'Lerne die Manager-Zentrale, deine Weltranglistenposition und die Navigation kennen, die du an jedem Spieltag nutzt.',
    },
    player: {
      title: 'Dein Spieler',
      description: 'Verstehe Identität, Attribute und die Informationen, die deine Tenniskarriere bestimmen.',
    },
    development: {
      title: 'Entwicklung & Gesundheit',
      description: 'Lerne, wie Training, Team und Gesundheitsentscheidungen deinen Spieler im Laufe der Zeit verändern.',
    },
    season: {
      title: 'Saisonplanung & Turniere',
      description: 'Plane den Kalender, verwalte Verpflichtungen und bereite dich richtig auf Wettkämpfe vor.',
    },
    competition: {
      title: 'Wettkampfsysteme',
      description: 'Verstehe Ranglisten, Nationalwettbewerbe und die Ausrüstung, die du mit auf den Platz nimmst.',
    },
    career: {
      title: 'Karrieremanagement',
      description: 'Kontrolliere Geld, optionale Lifestyle-Systeme, Clubfunktionen und langfristige Statistiken.',
    },
    communication: {
      title: 'Kommunikation & Einstellungen',
      description: 'Bleibe informiert, verwalte Nachrichten und verstehe optionale Premium-Dienste.',
    },
    support: {
      title: 'Hilfe & Community',
      description: 'Wisse, wo du ausführliche Regeln, Support und die Tennis-Legacy-Community findest.',
    },
  },
  steps: {
    'welcome.overview': {
      title: 'Willkommen bei Tennis Legacy',
      body: 'Übersicht ist dein Karriere-Kontrollzentrum. Hier findest du aktuellen Zustand, nächstes Turnier, letzte Ergebnisse, Ranglistenkontext, Finanzen und die wichtigsten Aktionen, die deine Aufmerksamkeit brauchen. Die Seite selbst gehört zum kostenlosen Kernspiel; nur Ranglistenschutz ist ein Premium-Zusatz.',
      action: 'Nutze Übersicht als erste Seite, die du zu Beginn eines neuen Spieltags prüfst.',
      tip: 'Das Tutorial führt dich Seite für Seite. Du kannst es jederzeit pausieren und später fortsetzen.',
    },
    'welcome.rank': {
      title: 'Deine aktuelle Weltranglistenposition',
      body: 'Die Zahl im Kopfbereich ist deine aktuelle ATP- oder WTA-Einzelranglistenposition. Turnierergebnisse bringen Ranglistenpunkte, und ältere Beiträge verfallen irgendwann, sodass sich deine Position auch ohne eigenes Match ändern kann.',
      action: 'Behalte diese Zahl im Blick, triff Saisonentscheidungen aber über Ranglisten und Kalender statt nur dem Rang hinterherzujagen.',
    },
    'welcome.navigation': {
      title: 'Die Manager-Zentrale',
      body: 'Die linke Navigation ist die Hauptkarte deiner Karriere. Jede Seite besitzt ein bestimmtes System, daher sollten wichtige Änderungen auf der dafür vorgesehenen Seite statt direkt aus der Übersicht vorgenommen werden.',
      action: 'Auf Mobilgeräten öffnest du über die Menüschaltfläche im Kopfbereich dieselbe Navigation.',
    },

    'player.profile': {
      title: 'Spielerprofil',
      body: 'Dein Profil ist die öffentliche Tennisidentität, die andere Manager ansehen können. Es zeigt Nationalität, Ranglistenkontext, Spielidentität und karriererelevante Informationen, ohne private Managementkontrollen offenzulegen.',
      action: 'Nutze Profile, um Gegner und andere Spieler zu verstehen; für eigene Kontoaktionen nutzt du Spieler & Konto.',
    },
    'player.account': {
      title: 'Spieler & Konto',
      body: 'Diese Seite enthält Identitäts- und Kontokontrollen wie Spielername, Wettbewerbswelt, Land, Avatarverwaltung, Passwortwiederherstellung und destruktive Kontoaktionen.',
      action: 'Gehe mit Neustart- und Löschaktionen vorsichtig um. Dein professioneller Spielername bleibt nach der Karriereerstellung absichtlich dauerhaft.',
    },
    'player.skills': {
      title: 'Fähigkeiten & Attribute',
      body: 'Fähigkeiten bilden die Grundlage der Matchleistung. Technische Fähigkeiten, körperliche Qualitäten und Spielerzustand wirken zusammen; ein hoher Wert in einem Bereich kann Schwächen an anderer Stelle nicht vollständig ausgleichen.',
      action: 'Nutze diese Seite, um vor der Wahl deiner Trainingsprioritäten zu erkennen, was dein Spieler verbessern muss.',
      tip: 'Bevorzugter Belag und Spielstil sind wichtig, wenn du dieselben Attributwerte interpretierst.',
    },

    'development.training': {
      title: 'Reguläres Training',
      body: 'Plane die wöchentliche Entwicklung an Tagen zu Hause. Turnier-, Reise-, Camp- und Gesundheitstage haben automatisch Vorrang.',
      action: 'Nutze härtere Einheiten, wenn dein Spieler frisch ist; wähle Erholung oder einen Ruhetag, wenn die Ermüdung steigt.',
    },
    'development.training-camps': {
      title: 'Trainingscamps',
      body: 'Camps sind fokussierte Entwicklungsblöcke mit Zielort, Woche, Dauer, Unterkunft, Team, Reise und Gesamtkosten.',
      action: 'Wähle ein Camp, das zu deinem Entwicklungsziel und Kalender passt. Ein Camp kann sich nicht mit einem Turnier oder blockierten Reisezeitraum überschneiden.',
      actionLabel: 'Was du prüfen solltest',
      tip: 'Mitreisende Teammitglieder können campspezifische Vorteile bringen, erhöhen aber auch Reise- und Unterkunftskosten.',
    },
    'development.staff': {
      title: 'Dein Team',
      body: 'Du kannst pro Rolle einen Spezialisten beschäftigen. Jede Rolle beeinflusst einen anderen Teil von Entwicklung, Erholung, Analyse oder Karrieremanagement.',
      action: 'Prüfe den echten Effekt, das Wochengehalt und die verbleibende Vertragslaufzeit, bevor du dein Team änderst.',
    },
    'development.staff-market': {
      title: 'Teammarkt',
      body: 'Im Teammarkt suchst du weltweit Kandidaten nach Rolle, Qualität, Land und Gehalt.',
      action: 'Wähle einen Kandidaten, vergleiche Attribute und gesamte Vertragsverpflichtung und verhandle anschließend, bevor du die Einstellung bestätigst.',
      actionLabel: 'Was zu tun ist',
      tip: 'Höher bewertete Teammitglieder sind nützlich, aber Gehalt und Rollenpassung sind wichtiger als einfach die teuerste Person einzustellen.',
    },
    'development.health': {
      title: 'Gesundheit, Verletzungen & Erkrankungen',
      body: 'Diese Seite erklärt aktuellen Gesundheitszustand, Ermüdung, Verletzungsrisiko, Krankheitsrisiko, Einschränkungen und Erholungszeit. Gesundheitsregeln basieren auf Spieltagen und können Training oder Wettkampf bei Bedarf blockieren.',
      action: 'Wenn das Risiko steigt, reduziere die Belastung und priorisiere Erholung, statt auf eine Verletzung zu warten.',
    },

    'season.calendar': {
      title: 'Dein Karrierekalender',
      body: 'Der Kalender-Tab zeigt deine eigene Saison: Matches, Turnierverpflichtungen, Reisen, Trainingscamps, Erholung und andere blockierte Tage.',
      action: 'Prüfe diese Ansicht, bevor du ein Camp buchst oder ein weiteres Turnier hinzufügst, um vermeidbare Konflikte zu verhindern.',
    },
    'season.tournament-calendar': {
      title: 'Turnierkalender',
      body: 'Der Turnierkalender listet offizielle ATP- oder WTA-Events nach Wettkampfwoche, Kategorie, Belag, Ort und Anmeldestatus.',
      action: 'Öffne ein Turnier, prüfe das Anmeldefenster und deinen Status und reiche die Anmeldung auf der Turnierseite ein, wenn Anmeldungen geöffnet sind.',
      actionLabel: 'So nimmst du an einem Turnier teil',
      tip: 'Plane mindestens einige Wochen voraus. Aufeinanderfolgende Events können zusätzliche Reisen verursachen und Erholungszeit reduzieren.',
    },
    'season.schedule': {
      title: 'Zeitplan & Verpflichtungen',
      body: 'Der Zeitplan verwandelt Anmeldungen und angenommene Events in deinen persönlichen Plan. Er zeigt, was als Nächstes kommt, Reisezeit, Vorbereitungsstatus und andere Verpflichtungen, die miteinander kollidieren können.',
      action: 'Prüfe diese Seite nach jeder Turnieranmeldung oder Änderung deines Zeitplans.',
    },
    'season.tournament': {
      title: 'Turnierseite',
      body: 'Eine Turnierseite enthält die eventspezifischen Informationen, die du brauchst: Auslosung und Teilnahmestatus, Matchplan, Gegner, Ergebnisse und Turnieraktionen. Hier wird aus dem allgemeinen Kalender ein echter Wettbewerb.',
      action: 'Bestätige vor Turnierbeginn deinen Teilnahmestatus und achte auf das erste angesetzte Match.',
    },
    'season.tournament.empty': {
      title: 'Turnierseite',
      body: 'Du hast derzeit kein nächstes Turnier, das das Tutorial öffnen kann. Turnierseiten werden über Kalender oder Zeitplan verfügbar, sobald du ein Event zum Prüfen hast.',
      action: 'Nutze den Kalender, um ein Event zu wählen, und kehre zum Zeitplan zurück, sobald Anmeldung oder Teilnahme relevant wird.',
    },
    'season.preparation': {
      title: 'Turnier vorbereiten',
      body: 'Die Turniervorbereitung steuert Reiseklasse, Hotel, mitreisendes Team und deine Standardtaktik. Kosten und Effekte werden vor dem Speichern berechnet, und nicht gespeicherte Änderungen werden nicht aktiv.',
      action: 'Prüfe Zusammenfassung & Effekte vor dem Speichern. Mitreisende Teammitglieder kosten Geld, bieten aber ihren rollenspezifischen Turniervorteil, solange sie dich begleiten.',
      tip: 'Die Vorbereitung wird entsprechend dem realen Reise- und Matchplan gesperrt, also warte nicht bis zum letzten Moment.',
    },
    'season.preparation.empty': {
      title: 'Turniervorbereitung',
      body: 'Derzeit gibt es kein geeignetes kommendes Turnier, das im Vorbereitungsmodus geöffnet werden kann. Die Aktion Turnier vorbereiten erscheint im Zeitplan, wenn ein Event verfügbar und die Vorbereitung noch offen ist.',
      action: 'Merke dir den Ablauf: Zeitplan → Turnier vorbereiten → Kosten/Effekte prüfen → Turnierplan speichern.',
    },
    'season.doubles': {
      title: 'Turnier-Doppel',
      body: 'Wenn Doppel verfügbar ist, hält die Doppelansicht Partner-, Teilnahme- und Auslosungsinformationen getrennt von deinem Einzelwettbewerb. Eine Doppelverpflichtung kann trotzdem deinen gesamten Zeitplan beeinflussen.',
      action: 'Behandle Doppel als zusätzliche Verpflichtung, wenn du Ermüdung, Reisen und Matchzeiten planst.',
    },
    'season.doubles.empty': {
      title: 'Turnier-Doppel',
      body: 'Kein kommendes Turnier ist verfügbar, das das Tutorial im Doppelmodus öffnen kann. Wenn du ein Event hast, bietet die Turnierseite – sofern unterstützt – den Ablauf für Doppelanmeldung und Partner.',
      action: 'Denke daran, dass Einzel- und Doppelmeldungen getrennt sind, auch wenn sie beim selben Turnier stattfinden.',
    },

    'competition.rankings': {
      title: 'ATP-/WTA-Ranglisten',
      body: 'Ranglisten zeigen die aktuelle Wettbewerbsreihenfolge deiner Tenniswelt. ATP und WTA bleiben getrennt, und offizielle Ergebnisse erzeugen Ranglistenpunkt-Beiträge, die Spieler im Laufe der Zeit bewegen. Die Ranglistentabellen sind kostenlos; die detaillierte Ranglistenschutz-Ansicht mit kommendem Punkteverfall ist Premium-only.',
      action: 'Nutze Ranglisten, um deine Position zu vergleichen, Spielerprofile zu öffnen und zu verstehen, welches Turnierniveau für deine aktuelle Karriere realistisch ist.',
    },
    'competition.national-team': {
      title: 'Nationalteam',
      body: 'Nationalwettbewerbe ergänzen deine individuelle Karriere um länderbasierte Auswahl- und Verbandssysteme. Die Seite ist nicht Premium-only, aber Verbandsaktivierung und saisonale Verlängerung werden gemeinschaftlich mit Coins finanziert. Das aktuelle Aktivierungsziel beträgt 50 Coins plus mindestens 5 Mitglieder, das Verlängerungsziel 30 Coins.',
      action: 'Beitritt und Teilnahme sind vom Premium-Kauf getrennt. Trage nur Coins bei, wenn du eine Aktivierung oder Verlängerung unterstützen möchtest; Beiträge kommen aus deiner Coin-Wallet.',
    },
    'competition.equipment': {
      title: 'Ausrüstung',
      body: 'Dein ausgerüsteter Schläger, Schuhe, Kleidung und Zubehör beeinflussen Matches, Zustand und Verschleiß.',
      action: 'Prüfe aktives Setup und Ausrüstungszustand vor wichtigen Turnieren.',
    },
    'competition.technical-sponsors': {
      title: 'Technische Sponsoren',
      body: 'Technische Sponsoren sind Ausrüstungspartnerschaften für Schläger, Schuhe oder Kleidung. Sie sind von deinem Haupt-Finanzsponsor getrennt.',
      action: 'Vergleiche Marke, Vertragsplatz, Ausrüstungsrabatt, Handgeld und Saisonexklusivität vor der Unterschrift.',
      tip: 'Ein technischer Sponsor kann Ausrüstungskosten reduzieren, aber gesponserte Ausrüstung wird weiterhin über Ausrüstung und Inventar verwaltet.',
    },

    'career.finance': {
      title: 'Finanzen',
      body: 'Finanzen verfolgt Karriereguthaben, Einnahmen, Ausgaben, Steuern, Team, Reisen, Unterkunft und das permanente Transaktions-Ledger.',
      action: 'Prüfe verfügbares Geld und kommende Verpflichtungen vor einer teuren Entscheidung.',
    },
    'career.financial-sponsors': {
      title: 'Haupt-Finanzsponsor',
      body: 'Dein Hauptsponsor zahlt garantierte Karriereeinnahmen und kann separate Leistungsziele mit Geldboni hinzufügen.',
      action: 'Vergleiche garantierten Wert, wöchentliche Zahlungen, Ziele, Fristen und maximalen Bonuswert vor der Unterschrift.',
      actionLabel: 'Was du vergleichen solltest',
      tip: 'Dies ist von technischen Sponsoren getrennt: Der Hauptsponsor ist vor allem eine finanzielle Vereinbarung, kein Ausrüstungsvertrag.',
    },
    'career.private-life': {
      title: 'Privatleben',
      body: 'Privatleben ist ein Premium-only-Lifestyle-System. Kostenlose Spieler können die komplette Kern-Tenniskarriere ohne dieses System fortsetzen. Premium-Mitglieder können die Seite für Immobilien, Fahrzeuge und andere persönliche Vermögenswerte nutzen; Käufe im Privatleben verwenden das normale Karrierefinanz-Guthaben, nicht Coins.',
      action: 'Wenn du kostenlos spielst, kannst du dieses System einfach überspringen. Premium schaltet die Seite frei, ist aber nicht für die Kern-Tenniskarriere erforderlich.',
    },
    'career.tennis-club': {
      title: 'Tennisclub',
      body: 'Tennisclub ist die gemeinsame Club-Ebene für Community und clubbezogenes Gameplay. Clubs ansehen, Beitritt beantragen und eine Einladung annehmen sind etwas anderes als einen eigenen Club zu gründen. Einen neuen Tennisclub zu erstellen kostet derzeit 50 Coins.',
      action: 'Du brauchst keine Premium-Mitgliedschaft für das Clubsystem. Gib Coins nur aus, wenn du einen neuen Club erstellen möchtest; einem bestehenden Club beizutreten kostet diese Gründungsgebühr nicht.',
    },
    'career.statistics': {
      title: 'Statistiken & Karrierehistorie',
      body: 'Statistiken verwandelt abgeschlossene Matches und Turnierergebnisse in Datensätze. Du kannst Spielerstatistiken, Turnierstatistiken und eigene Karriererekorde über Beläge, Kategorien und Saisons hinweg vergleichen.',
      action: 'Nutze diese Seite, um langfristige Leistung zu bewerten, statt deinen Spieler anhand eines einzigen guten oder schlechten Matches zu beurteilen.',
    },

    'communication.notifications': {
      title: 'Benachrichtigungen',
      body: 'Benachrichtigungen zeigen wichtige Spielereignisse wie Turnieränderungen, Ergebnisse, Gesundheitsinformationen und andere Karriere-Updates. Das Ungelesen-Badge im Kopfbereich zeigt, wenn noch etwas deine Aufmerksamkeit braucht.',
      action: 'Öffne Benachrichtigungen regelmäßig und arbeite wichtige Meldungen ab, nachdem du verstanden hast, was sich geändert hat.',
    },
    'communication.inbox': {
      title: 'Manager-Postfach',
      body: 'Das Postfach ist für direkte Managerkommunikation und Nachrichten gedacht, die zu einer Unterhaltung statt zu einer Systemwarnung gehören. Es ist absichtlich von Benachrichtigungen getrennt.',
      action: 'Nutze Benachrichtigungen für automatische Spielereignisse und das Postfach für direkte Kommunikation.',
    },
    'communication.preferences': {
      title: 'Spieleinstellungen',
      body: 'Einstellungen ist die zentrale Seite für persönliche Kontrollen deines Spielerlebnisses. Es sollten nur Einstellungen erscheinen, die tatsächlich mit einem aktiven System verbunden sind.',
      action: 'Der Neustart des Tutorials bleibt im Hilfe-Center, damit Spieleinstellungen auf echte persönliche Einstellungen fokussiert bleibt.',
    },
    'communication.premium': {
      title: 'Premium & Coin-Pakete',
      body: 'Auf dieser Seite werden optionale Käufe transparent dargestellt. Tennis Legacy Kostenlos bietet die Kernkarriere. Premium-Mitgliedschaft schaltet Premium-only-Funktionen frei und enthält 30 Coins pro abgedecktem Monat: 30 bei monatlicher Abrechnung, 90 bei 3-monatiger oder 360 bei jährlicher Abrechnung. Coin-Pakete sind separate Einmalkäufe.',
      action: 'Premium und Coins sind getrennt: Coins zu kaufen aktiviert kein Premium, und Premium macht nicht jede Coin-Aktion kostenlos. Prüfe den genauen Vorteil vor dem Kauf.',
    },

    'support.help': {
      title: 'Hilfe-Center',
      body: 'Das Hilfe-Center ist der schnelle Ausgangspunkt, wenn etwas unklar ist. Es verlinkt häufig genutzte Seiten, Support und das vollständige Spielhandbuch, ohne dass du außerhalb des Spiels suchen musst.',
      action: 'Nutze Hilfe für schnelle Orientierung. Nutze das Handbuch, wenn du vollständige Regeln oder Berechnungen brauchst.',
    },
    'support.manual': {
      title: 'Vollständiges Spielhandbuch',
      body: 'Das Handbuch ist die ausführliche Referenz für implementiertes Gameplay. Anders als dieses Tutorial ist es zum Suchen und wiederholten Nachschlagen gedacht, wenn du genaue Regeln, Seitenbeschreibungen oder Systemgrenzen brauchst.',
      action: 'Suche nach Seite oder System, wenn du mehr Details brauchst, als ein Tutorial-Schritt sinnvoll liefern sollte.',
    },
    'support.forum': {
      title: 'Forum / Discord',
      body: 'Im offiziellen Community-Bereich können Spieler Karrieren, Strategien, Turniere, Bugs und Vorschläge diskutieren. Community-Ratschläge können hilfreich sein, aber das Handbuch im Spiel bleibt die maßgebliche Gameplay-Referenz.',
      action: 'Nutze die Community, um Erfahrungen zu vergleichen und reproduzierbare Probleme zu melden.',
    },
    'support.contact': {
      title: 'Support kontaktieren',
      body: 'Kontakt ist für Kontofragen, technische Probleme oder Supportfälle gedacht, die direkte Aufmerksamkeit des Tennis-Legacy-Teams benötigen.',
      action: 'Gib bei einer Problemmeldung Seite, Erwartung, tatsächliches Verhalten und wenn möglich einen Screenshot an.',
    },
    'support.bug-report': {
      title: 'Bug melden',
      body: 'Wenn etwas im Spiel falsch aussieht, nutze die Schaltfläche Bug melden. Der Bericht kennt automatisch die Seite, auf der du dich befindest.',
      action: 'Beschreibe, was passiert ist, was du erwartet hast und welche Schritte das Problem reproduzieren. Füge einen Screenshot hinzu, wenn er hilft.',
      actionLabel: 'Gute Bug-Meldung',
      tip: 'Bitte melde Probleme, statt sie still zu umgehen — reproduzierbare Berichte helfen uns, das Spiel schneller zu verbessern.',
    },
    'support.invite': {
      title: 'Freunde einladen',
      body: 'Freunde einladen bietet den Empfehlungsablauf, um einen weiteren Manager zu Tennis Legacy zu bringen. Dessen Karriere bleibt vollständig von deiner getrennt.',
      action: 'Verwende den offiziellen Einladungslink, damit die Empfehlungsverfolgung korrekt funktionieren kann.',
    },
    'support.access-model': {
      title: 'Kostenlos, Coins und Premium',
      body: 'Du kannst die Kernkarriere von Tennis Legacy kostenlos spielen. Optionale Coins werden nur für bestimmte Coin-Aktionen verwendet, zum Beispiel Beiträge zur Finanzierung eines Nationalverbands oder die Gründung deines eigenen Tennisclubs. Premium-Mitgliedschaft schaltet Premium-only-Funktionen wie Privatleben und Ranglistenschutz frei. Coin-Pakete und Premium-Mitgliedschaft sind optionale Käufe.',
      action: 'Spiele die Kernkarriere kostenlos. Kaufe Coins nur für eine gewünschte optionale Coin-Aktion oder wähle Premium nur, wenn seine Zusatzfunktionen für dich wertvoll sind.',
      tip: 'Coins und Premium sind getrennte Produkte: Coins zu kaufen aktiviert kein Premium, und Premium entfernt nicht jede Coin-Kostenstelle.',
    },
    'support.complete': {
      title: 'Du bist bereit, deine Karriere zu managen',
      body: 'Du weißt jetzt, wo jede Startseite hingehört und wie die Kernsysteme zusammenwirken: Spieler entwickeln, Saison planen, Turniere vorbereiten, Gesundheit schützen, Geld verwalten und Ergebnisse prüfen. Die Kernkarriere bleibt im kostenlosen Plan spielbar; optionale Coins und Premium-Funktionen sind klar markiert.',
      action: 'Kehre zur Übersicht zurück, prüfe deine nächste Verpflichtung und entscheide die wichtigste einzelne Aktion für den aktuellen Spieltag.',
      tip: 'Du kannst dieses Tutorial später nur im Hilfe-Center neu starten. Bezahlte oder gesperrte Funktionen sind im jeweiligen Tutorial-Schritt klar markiert.',
    },
  },
  access: {
    'overview-premium-extra': {
      tone: 'mixed',
      label: 'KOSTENLOSE SEITE · PREMIUM-ZUSATZ',
      title: 'Übersicht: kostenlos · Ranglistenschutz: Premium',
      body: 'Die Kern-Übersicht bleibt kostenlos. Nur Ranglistenschutz benötigt Premium.',
    },
    'rankings-premium-extra': {
      tone: 'mixed',
      label: 'KOSTENLOSE SEITE · PREMIUM-ZUSATZ',
      title: 'Ranglisten: kostenlos · Schutz: Premium',
      body: 'ATP-/WTA-Ranglisten bleiben kostenlos. Werkzeuge zum bevorstehenden Punkteverfall benötigen Premium.',
    },
    'national-team-coins': {
      tone: 'coins',
      label: 'DURCH COINS FINANZIERTE FUNKTION',
      title: 'Nationalverbands-Finanzierung verwendet Coins',
      body: 'Nicht Premium-only. Aktivierungsziel: 50 Coins + 5 Mitglieder. Verlängerungsziel: 30 Coins. Beiträge sind optional.',
    },
    'private-life-premium': {
      tone: 'premium',
      label: 'PREMIUM ERFORDERLICH',
      title: 'Privatleben benötigt Premium',
      body: 'Premium schaltet die Seite frei. Vermögenskäufe verwenden anschließend normales Karrierefinanz-Geld, nicht Coins.',
    },
    'tennis-club-coins': {
      tone: 'coins',
      label: 'OPTIONALE COIN-AKTION',
      title: 'Einen Tennisclub zu erstellen kostet 50 Coins',
      body: 'Clubs anzusehen oder ihnen beizutreten verwendet die Gründungsgebühr nicht. Nur die Erstellung eines neuen Clubs kostet 50 Coins.',
    },
    'premium-store-optional': {
      tone: 'optional',
      label: 'OPTIONALE KÄUFE',
      title: 'Premium und Coins sind optional',
      body: 'Die Kernkarriere ist kostenlos spielbar. Premium und Coin-Pakete sind getrennte optionale Käufe.',
    },
    'free-coins-premium': {
      tone: 'optional',
      label: 'KERNSPIEL IST KOSTENLOS',
      title: 'Kostenlose Karriere · Optionale Coins · Optionales Premium',
      body: 'Kostenlos deckt die Kernkarriere ab. Coins bezahlen bestimmte optionale Aktionen; Premium schaltet klar markierte Extras frei.',
    },
  },
  ui: {
    tutorial: 'Spiel-Tutorial',
    phase: 'Phase',
    step: 'Schritt',
    back: 'Zurück',
    next: 'Weiter',
    finish: 'Tutorial beenden',
    pause: 'Pausieren',
    skip: 'Tutorial überspringen',
    resume: 'Tutorial fortsetzen',
    start: 'Tutorial starten',
    restart: 'Tutorial neu starten',
    completed: 'Tutorial abgeschlossen',
    doThis: 'Was zu tun ist',
    tip: 'Tipp',
    closeLabel: 'Tutorial pausieren',
  },
}

const SR: TutorialResources = {
  phases: {
    welcome: {
      title: 'Dobro došao u svoju karijeru',
      description: 'Upoznaj menadžerski centar, svetski plasman i navigaciju koju koristiš svakog dana u igri.',
    },
    player: {
      title: 'Tvoj igrač',
      description: 'Razumi identitet, atribute i podatke koji određuju tvoju tenisku karijeru.',
    },
    development: {
      title: 'Razvoj i zdravlje',
      description: 'Nauči kako trening, stručni tim i zdravstvene odluke vremenom menjaju igrača.',
    },
    season: {
      title: 'Planiranje sezone i turniri',
      description: 'Planiraj kalendar, upravljaj obavezama i pravilno se pripremi za takmičenje.',
    },
    competition: {
      title: 'Takmičarski sistemi',
      description: 'Razumi rang-liste, nacionalna takmičenja i opremu koju nosiš na teren.',
    },
    career: {
      title: 'Upravljanje karijerom',
      description: 'Upravljaj novcem, opcionim životnim sistemima, klubom i dugoročnom statistikom.',
    },
    communication: {
      title: 'Komunikacija i podešavanja',
      description: 'Prati važne informacije, poruke i opcione Premium usluge.',
    },
    support: {
      title: 'Pomoć i zajednica',
      description: 'Saznaj gde se nalaze detaljna pravila, podrška i Tennis Legacy zajednica.',
    },
  },
  steps: {
    'welcome.overview': {
      title: 'Dobro došao u Tennis Legacy',
      body: 'Pregled je kontrolni centar tvoje karijere. Na jednom mestu prikazuje trenutno stanje, sledeći turnir, poslednje rezultate, rang-listu, finansije i najvažnije akcije. Osnovna stranica je besplatna; samo Ranking Protection je Premium dodatak.',
      action: 'Pregled neka bude prva stranica koju proveravaš kada počne novi dan u igri.',
      tip: 'Tutorial ide stranicu po stranicu. Možeš ga pauzirati i nastaviti kasnije.',
    },
    'welcome.rank': {
      title: 'Trenutni svetski plasman',
      body: 'Broj u zaglavlju je tvoj trenutni ATP ili WTA plasman u singlu. Rezultati sa turnira dodaju poene, a stariji rezultati vremenom ističu, pa se plasman može promeniti i kada ne igraš.',
      action: 'Prati plasman, ali odluke o sezoni donosi preko Rang-lista i Kalendara, a ne samo jureći broj na listi.',
    },
    'welcome.navigation': {
      title: 'Menadžerski centar',
      body: 'Leva navigacija je glavna mapa tvoje karijere. Svaka stranica pripada određenom sistemu, zato važne promene radi na odgovarajućoj stranici, a ne iz Pregleda.',
      action: 'Na mobilnom telefonu istu navigaciju otvaraš dugmetom menija u zaglavlju.',
    },
    'player.profile': {
      title: 'Profil igrača',
      body: 'Profil je javni teniski identitet koji drugi menadžeri mogu da pregledaju. Prikazuje državu, rang, stil igre i podatke o karijeri bez privatnih menadžerskih kontrola.',
      action: 'Profile koristi za pregled protivnika i drugih igrača; svoje nalog-kontrole koristi na stranici Igrač i nalog.',
    },
    'player.account': {
      title: 'Igrač i nalog',
      body: 'Ovde se nalaze podaci i kontrole naloga: ime igrača, ATP/WTA svet, država, avatar, oporavak lozinke i trajne akcije nad nalogom.',
      action: 'Restart i brisanje koristi pažljivo. Profesionalno ime igrača je namerno trajno nakon početka karijere.',
    },
    'player.skills': {
      title: 'Veštine i atributi',
      body: 'Veštine su osnova učinka u meču. Tehničke, fizičke i kondicione vrednosti rade zajedno; visoka vrednost u jednoj oblasti ne može potpuno da prikrije slabost u drugoj.',
      action: 'Na ovoj stranici utvrdi šta igrač treba da popravi pre nego što odrediš prioritete treninga.',
      tip: 'Podloga i stil igre utiču na to kako treba tumačiti iste vrednosti atributa.',
    },
    'development.training': {
      title: 'Redovni trening',
      body: 'Planiraj razvoj tokom dana kod kuće. Turniri, putovanja, kampovi i zdravstvena ograničenja automatski imaju prednost.',
      action: 'Jače treninge koristi kada je igrač svež; oporavak ili slobodan dan koristi kada raste umor.',
    },
    'development.training-camps': {
      title: 'Trening kampovi',
      body: 'Kampovi su fokusirani razvojni blokovi sa destinacijom, nedeljom, trajanjem, smeštajem, stručnim timom, putovanjem i ukupnom cenom.',
      action: 'Izaberi kamp koji odgovara razvojnom cilju i kalendaru. Kamp ne može da se preklapa sa turnirom ili blokiranim putovanjem.',
      actionLabel: 'Šta proveriti',
      tip: 'Osoblje koje putuje može dati dodatne koristi, ali povećava troškove puta i smeštaja.',
    },
    'development.staff': {
      title: 'Tvoj stručni tim',
      body: 'Možeš imati po jednog stručnjaka za svaku ulogu. Svaka uloga utiče na drugi deo razvoja, oporavka, analize ili vođenja karijere.',
      action: 'Pre promene tima proveri stvarni efekat, nedeljnu platu i preostalo trajanje ugovora.',
    },
    'development.staff-market': {
      title: 'Tržište osoblja',
      body: 'Na tržištu osoblja tražiš kandidate iz celog sveta prema ulozi, kvalitetu, državi i plati.',
      action: 'Izaberi kandidata, uporedi atribute i ukupnu vrednost ugovora, zatim pregovaraj pre potvrde angažmana.',
      actionLabel: 'Šta uraditi',
      tip: 'Bolje ocenjen stručnjak nije uvek najbolji izbor ako su plata i uklapanje u ulogu loši.',
    },
    'development.health': {
      title: 'Zdravlje, povrede i bolest',
      body: 'Ovde vidiš zdravstveno stanje, umor, rizik od povrede i bolesti, ograničenja i tok oporavka. Zdravstvena pravila rade po danima igre i mogu blokirati trening ili nastup.',
      action: 'Kada rizik raste, smanji opterećenje i daj prednost oporavku umesto da čekaš povredu.',
    },
    'season.calendar': {
      title: 'Kalendar karijere',
      body: 'Kalendar prikazuje tvoju sezonu: mečeve, turnirske obaveze, putovanja, kampove, oporavak i druge blokirane dane.',
      action: 'Proveri ga pre rezervacije kampa ili dodavanja novog turnira kako ne bi napravio nepotreban konflikt.',
    },
    'season.tournament-calendar': {
      title: 'Kalendar turnira',
      body: 'Kalendar turnira prikazuje zvanične ATP ili WTA događaje po nedelji, kategoriji, podlozi, lokaciji i statusu prijave.',
      action: 'Otvori turnir, proveri period prijave i svoj status, pa pošalji prijavu sa stranice turnira dok su prijave otvorene.',
      actionLabel: 'Kako se prijaviti',
      tip: 'Planiraj nekoliko nedelja unapred. Uzastopni turniri povećavaju putovanja i smanjuju vreme za oporavak.',
    },
    'season.schedule': {
      title: 'Raspored i obaveze',
      body: 'Raspored pretvara prijave i prihvaćene turnire u tvoj lični plan. Prikazuje šta sledi, vreme putovanja, status pripreme i moguće konflikte.',
      action: 'Proveri ovu stranicu posle svake prijave na turnir ili promene rasporeda.',
    },
    'season.tournament': {
      title: 'Stranica turnira',
      body: 'Stranica turnira sadrži žreb, status prijave, raspored mečeva, protivnike, rezultate i turnirske akcije. Tu opšti kalendar postaje stvarno takmičenje.',
      action: 'Pre početka turnira proveri status ulaska i prati kada je zakazan prvi meč.',
    },
    'season.tournament.empty': {
      title: 'Stranica turnira',
      body: 'Trenutno nema sledećeg turnira koji tutorial može da otvori. Turnire možeš otvoriti iz Kalendara ili Rasporeda kada postoji događaj za pregled.',
      action: 'Izaberi turnir u Kalendaru, pa se vrati u Raspored kada prijava ili ulazak postanu aktuelni.',
    },
    'season.preparation': {
      title: 'Priprema turnira',
      body: 'Priprema turnira određuje klasu putovanja, hotel, osoblje koje putuje i podrazumevanu taktiku. Troškovi i efekti se računaju pre čuvanja, a nesačuvane promene nisu aktivne.',
      action: 'Pre čuvanja proveri pregled efekata. Osoblje koje putuje košta više, ali daje specifične koristi svoje uloge.',
      tip: 'Priprema se zaključava prema stvarnom putovanju i rasporedu mečeva, zato ne čekaj poslednji trenutak.',
    },
    'season.preparation.empty': {
      title: 'Priprema turnira',
      body: 'Trenutno nema odgovarajućeg predstojećeg turnira koji može da se otvori u režimu pripreme. Akcija Pripremi turnir pojavljuje se u Rasporedu dok je priprema dostupna.',
      action: 'Zapamti tok: Raspored → Pripremi turnir → proveri troškove i efekte → Sačuvaj plan turnira.',
    },
    'season.doubles': {
      title: 'Dubl na turniru',
      body: 'Kada je dubl dostupan, partner, prijava i žreb vode se odvojeno od singla. Dubl ipak utiče na ukupan raspored.',
      action: 'Dubl računaj kao dodatnu obavezu kada planiraš umor, putovanje i vreme mečeva.',
    },
    'season.doubles.empty': {
      title: 'Dubl na turniru',
      body: 'Nema predstojećeg turnira koji tutorial može da otvori u dubl režimu. Kada postoji događaj, stranica turnira prikazuje prijavu i izbor partnera gde je dubl podržan.',
      action: 'Singl i dubl prijave su odvojene čak i kada se igraju na istom turniru.',
    },
    'competition.rankings': {
      title: 'ATP / WTA rang-liste',
      body: 'Rang-liste prikazuju trenutni poredak u tvom teniskom svetu. ATP i WTA su odvojeni, a zvanični rezultati dodaju poene koji vremenom menjaju plasman. Rang-liste su besplatne; detaljni Ranking Protection sa predstojećim istekom poena je Premium.',
      action: 'Koristi rang-liste za poređenje plasmana, otvaranje profila i procenu koji nivo turnira odgovara tvojoj karijeri.',
    },
    'competition.national-team': {
      title: 'Nacionalni tim',
      body: 'Nacionalna takmičenja dodaju selekciju po državama i sistem saveza. Stranica nije samo za Premium, ali aktivacija i sezonska obnova saveza koriste zajedničko Coin finansiranje. Aktivacija trenutno traži 50 Coina i najmanje 5 članova, a obnova 30 Coina.',
      action: 'Učešće nije isto što i kupovina Premiuma. Coine doniraš samo ako želiš da podržiš fond za aktivaciju ili obnovu.',
    },
    'competition.equipment': {
      title: 'Oprema',
      body: 'Reket, obuća, odeća i dodaci koje koristiš utiču na mečeve, stanje i habanje.',
      action: 'Pre važnih turnira proveri aktivnu postavku i stanje opreme.',
    },
    'competition.technical-sponsors': {
      title: 'Tehnički sponzori',
      body: 'Tehnički sponzori su partnerstva za rekete, obuću ili odeću i odvojeni su od glavnog finansijskog sponzora.',
      action: 'Pre potpisa uporedi brend, slot ugovora, popust na opremu, početnu isplatu i sezonsku ekskluzivnost.',
      tip: 'Tehnički sponzor može smanjiti troškove opreme, ali opremom i dalje upravljaš kroz Oprema i Inventar.',
    },
    'career.finance': {
      title: 'Finansije',
      body: 'Finansije prate stanje karijere, prihode, troškove, porez, osoblje, putovanja, smeštaj i trajnu evidenciju transakcija.',
      action: 'Pre skupe odluke proveri raspoloživ novac i predstojeće obaveze.',
    },
    'career.financial-sponsors': {
      title: 'Glavni finansijski sponzor',
      body: 'Glavni sponzor daje zagarantovan prihod i može dodati ciljeve učinka sa novčanim bonusima.',
      action: 'Pre potpisa uporedi garantovanu vrednost, nedeljne isplate, ciljeve, rokove i maksimalni bonus.',
      actionLabel: 'Šta uporediti',
      tip: 'Ovo je odvojeno od tehničkih sponzora: glavni sponzor je prvenstveno finansijski ugovor.',
    },
    'career.private-life': {
      title: 'Privatni život',
      body: 'Privatni život je Premium sistem životnog stila. Besplatni igrači mogu igrati kompletnu osnovnu tenisku karijeru bez njega. Premium otključava nekretnine, vozila i drugu imovinu, a kupovine koriste novac iz Finansija, ne Coine.',
      action: 'Ako igraš besplatno, ovaj sistem možeš preskočiti. Premium ga otključava, ali nije potreban za osnovnu karijeru.',
    },
    'career.tennis-club': {
      title: 'Teniski klub',
      body: 'Teniski klub je zajednički sistem za klupsku igru i zajednicu. Pregled klubova, prijava i prihvatanje poziva nisu isto što i kreiranje sopstvenog kluba. Kreiranje novog kluba trenutno košta 50 Coina.',
      action: 'Premium nije potreban za klub. Coine trošiš samo ako želiš da napraviš novi klub; pridruživanje postojećem ne koristi naknadu za kreiranje.',
    },
    'career.statistics': {
      title: 'Statistika i istorija karijere',
      body: 'Statistika pretvara završene mečeve i turnirske rezultate u evidenciju. Možeš uporediti statistiku igrača, turnira i sopstvene karijere po podlozi, kategoriji i sezoni.',
      action: 'Koristi ovu stranicu za dugoročnu procenu, a ne za zaključke na osnovu jednog dobrog ili lošeg meča.',
    },
    'communication.notifications': {
      title: 'Obaveštenja',
      body: 'Obaveštenja prikazuju važne događaje: promene na turnirima, rezultate, zdravstvene informacije i druge novosti. Broj u zaglavlju pokazuje da li nešto još zahteva pažnju.',
      action: 'Redovno otvaraj obaveštenja i označi važne stavke kao pročitane kada razumeš šta se promenilo.',
    },
    'communication.inbox': {
      title: 'Menadžersko sanduče',
      body: 'Sanduče je za direktnu komunikaciju i poruke koje pripadaju razgovoru, a ne automatskom sistemskom upozorenju. Namerno je odvojeno od Obaveštenja.',
      action: 'Obaveštenja koristi za automatske događaje igre, a Sanduče za direktnu prepisku.',
    },
    'communication.preferences': {
      title: 'Podešavanja igre',
      body: 'Podešavanja sadrže lične kontrole iskustva u igri. Ovde treba da se pojavljuju samo opcije koje su stvarno povezane sa aktivnim sistemima.',
      action: 'Ponovno pokretanje tutoriala ostaje u Centru za pomoć, kako bi Podešavanja igre ostala fokusirana na stvarna podešavanja.',
    },
    'communication.premium': {
      title: 'Premium i Coin paketi',
      body: 'Ovde su jasno prikazane opcione kupovine. Tennis Legacy Free omogućava osnovnu karijeru. Premium otključava dodatne funkcije i daje 30 Coina po pokrivenom mesecu: 30 mesečno, 90 na tri meseca ili 360 godišnje. Coin paketi su odvojene jednokratne kupovine.',
      action: 'Premium i Coini su odvojeni: kupovina Coina ne aktivira Premium, a Premium ne čini svaku Coin akciju besplatnom. Pre kupovine proveri tačnu korist.',
    },
    'support.help': {
      title: 'Centar za pomoć',
      body: 'Centar za pomoć je početno mesto kada nešto nije jasno. Vodi do važnih stranica, podrške i kompletnog priručnika bez potrebe da tražiš informacije van igre.',
      action: 'Za brzi smer koristi Pomoć; za detaljna pravila i izračunavanja koristi Priručnik.',
    },
    'support.manual': {
      title: 'Kompletan priručnik igre',
      body: 'Priručnik je detaljna referenca za implementirane sisteme. Za razliku od tutoriala, namenjen je pretrazi i ponovnom čitanju kada su ti potrebna precizna pravila, objašnjenja stranica ili ograničenja.',
      action: 'Pretraži po stranici ili sistemu kada ti treba više detalja nego što tutorial treba da sadrži.',
    },
    'support.forum': {
      title: 'Forum / Discord',
      body: 'Zvanična zajednica je mesto za razgovor o karijerama, strategiji, turnirima, greškama i predlozima. Saveti zajednice mogu pomoći, ali Priručnik u igri ostaje zvanična referenca.',
      action: 'Zajednicu koristi za poređenje iskustava i prijavu grešaka koje se mogu ponoviti.',
    },
    'support.contact': {
      title: 'Kontakt podrške',
      body: 'Kontakt služi za pitanja o nalogu, tehničke probleme ili slučajeve kojima je potrebna direktna pažnja Tennis Legacy tima.',
      action: 'Kod prijave problema navedi stranicu, očekivano ponašanje, šta se zapravo dogodilo i po mogućnosti dodaj screenshot.',
    },
    'support.bug-report': {
      title: 'Prijavi grešku',
      body: 'Ako nešto u igri izgleda pogrešno, koristi dugme Prijavi grešku. Sistem automatski zna na kojoj si stranici.',
      action: 'Opiši šta se dogodilo, šta si očekivao i korake za ponavljanje problema. Dodaj screenshot kada pomaže.',
      actionLabel: 'Dobra prijava greške',
      tip: 'Prijavi problem umesto da ga zaobilaziš — greške koje se mogu ponoviti mnogo brže popravljamo.',
    },
    'support.invite': {
      title: 'Pozovi prijatelje',
      body: 'Pozovi prijatelje daje zvaničan referral tok za dovođenje drugog menadžera u Tennis Legacy. Njegova karijera ostaje potpuno odvojena od tvoje.',
      action: 'Koristi zvanični pozivni link kako bi praćenje preporuke radilo kada je primenljivo.',
    },
    'support.access-model': {
      title: 'Besplatno, Coini i Premium',
      body: 'Osnovnu Tennis Legacy karijeru možeš igrati besplatno. Coini se koriste samo za određene opcione akcije, kao što su finansiranje nacionalnog saveza ili kreiranje sopstvenog kluba. Premium otključava dodatne funkcije poput Privatnog života i Ranking Protection. Coin paketi i Premium su opcioni.',
      action: 'Igraj besplatno za osnovnu karijeru. Coine kupuj samo kada želiš opcionu Coin akciju, a Premium samo ako su ti njegove dodatne funkcije korisne.',
      tip: 'Coini i Premium su odvojeni proizvodi: Coini ne aktiviraju Premium, a Premium ne uklanja svaki Coin trošak.',
    },
    'support.complete': {
      title: 'Spreman si da vodiš karijeru',
      body: 'Sada znaš gde se nalazi svaka glavna stranica i kako su sistemi povezani: razvijaj igrača, planiraj sezonu, pripremaj turnire, čuvaj zdravlje, upravljaj novcem i analiziraj rezultate. Osnovna karijera ostaje dostupna besplatno; opcioni Coini i Premium funkcije su jasno označeni.',
      action: 'Vrati se na Pregled, proveri sledeću obavezu i izaberi jednu najvažniju akciju za trenutni dan u igri.',
      tip: 'Tutorial kasnije možeš ponovo pokrenuti samo iz Centra za pomoć. Plaćene ili zaključane funkcije jasno su označene u odgovarajućem koraku.',
    },
  },
  access: {
    'overview-premium-extra': {
      tone: 'mixed',
      label: 'BESPLATNA STRANICA · PREMIUM DODATAK',
      title: 'Pregled: besplatno · Ranking Protection: Premium',
      body: 'Osnovni Pregled ostaje besplatan. Samo Ranking Protection zahteva Premium.',
    },
    'rankings-premium-extra': {
      tone: 'mixed',
      label: 'BESPLATNA STRANICA · PREMIUM DODATAK',
      title: 'Rang-liste: besplatno · Protection: Premium',
      body: 'ATP/WTA rang-liste su besplatne. Alati za zaštitu poena koji uskoro ističu zahtevaju Premium.',
    },
    'national-team-coins': {
      tone: 'coins',
      label: 'FUNKCIJA KOJA KORISTI COINE',
      title: 'Finansiranje nacionalnog saveza koristi Coine',
      body: 'Nije samo za Premium. Aktivacija: 50 Coina + 5 članova. Obnova: 30 Coina. Donacije su opcione.',
    },
    'private-life-premium': {
      tone: 'premium',
      label: 'POTREBAN JE PREMIUM',
      title: 'Privatni život zahteva Premium',
      body: 'Premium otključava stranicu. Kupovine imovine zatim koriste običan novac iz Finansija, ne Coine.',
    },
    'tennis-club-coins': {
      tone: 'coins',
      label: 'OPCIONA COIN AKCIJA',
      title: 'Kreiranje Teniskog kluba košta 50 Coina',
      body: 'Pregled i pridruživanje klubu ne koriste ovu naknadu. Samo kreiranje novog kluba košta 50 Coina.',
    },
    'premium-store-optional': {
      tone: 'optional',
      label: 'OPCIONE KUPOVINE',
      title: 'Premium i Coini su opcioni',
      body: 'Osnovna karijera može da se igra besplatno. Premium i Coin paketi su odvojene opcione kupovine.',
    },
    'free-coins-premium': {
      tone: 'optional',
      label: 'OSNOVNA IGRA JE BESPLATNA',
      title: 'Besplatna karijera · Opcioni Coini · Opcioni Premium',
      body: 'Besplatna verzija pokriva osnovnu karijeru. Coini plaćaju određene opcione akcije, a Premium jasno označene dodatke.',
    },
  },
  ui: {
    tutorial: 'Tutorial igre',
    phase: 'Faza',
    step: 'Korak',
    back: 'Nazad',
    next: 'Dalje',
    finish: 'Završi tutorial',
    pause: 'Pauziraj',
    skip: 'Preskoči tutorial',
    resume: 'Nastavi tutorial',
    start: 'Pokreni tutorial',
    restart: 'Pokreni tutorial ponovo',
    completed: 'Tutorial je završen',
    doThis: 'Šta uraditi',
    tip: 'Savet',
    closeLabel: 'Pauziraj tutorial',
  },
}

const RESOURCES: Record<string, TutorialResources> = {
  en: EN,
  sr: SR,
  de: DE,
}

export function normalizeTutorialLocale(locale?: string | null) {
  const value = (locale || 'en').split('-')[0].toLowerCase()
  return RESOURCES[value] ? value : 'en'
}

export function getTutorialResources(locale?: string | null) {
  return RESOURCES[normalizeTutorialLocale(locale)]
}

export function getTutorialPhase(phaseId: string) {
  return TUTORIAL_PHASES.find((phase) => phase.id === phaseId) ?? TUTORIAL_PHASES[0]
}

export function getTutorialPhaseSteps(phaseId: string) {
  return TUTORIAL_STEPS.filter((step) => step.phaseId === phaseId)
}
