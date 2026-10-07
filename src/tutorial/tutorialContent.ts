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
      body: 'This page is where optional purchases are kept transparent. Tennis Legacy Free provides the core career. Premium membership unlocks Premium-only features and currently grants a monthly Coin reward after successful payment. Coin packs are separate one-time purchases for optional Coin actions.',
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

const RESOURCES: Record<string, TutorialResources> = {
  en: EN,
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
