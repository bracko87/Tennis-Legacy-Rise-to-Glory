import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCareerChapters: ManualChapter[] = [
  {
    id: 'notifications-inbox',
    title: 'Notifications and Manager Inbox',
    summary: 'Career alerts, notification actions and private manager-to-manager messages.',
    sections: [
      s('Notification Center', { paragraphs: [
        'Notifications are structured career events with category, type, priority, status, full description and creation time. Many notifications include a direct action such as View Tournament, Open Schedule, Open Training, Open Health, View Equipment or Vote Now.',
      ]}),
      s('Typical categories', { bullets: ['Tournament and travel', 'Training and player development', 'Health and injuries', 'Equipment', 'Finance', 'Staff', 'Private Life', 'National Team', 'Account'] }),
      s('Unread and important counters', { paragraphs: [
        'The Notification Center distinguishes unread, important and total counts. Dismissing a notification removes it from active attention but does not reverse the game event that created it.',
      ]}),
      s('Manager Inbox', { paragraphs: [
        'Manager Inbox is private player-to-player communication. Conversations are normally started from another human player\'s public profile. Only the two participating managers can read that conversation.',
      ]}),
      s('System alerts are different', { paragraphs: [
        'Administrator System Health alerts are operational tooling and are not normal player-career notifications. Players receive career events that affect their own game state.',
      ], links: [{ label: 'Open Notifications', href: '/game/notifications' }, { label: 'Open Manager Inbox', href: '/game/inbox' }]}),
    ],
  },
  {
    id: 'premium-coins',
    title: 'Premium Features, Coins and Billing',
    summary: 'Optional Premium membership, Coin packs and what paid features do - and do not - change.',
    sections: [
      s('Free core gameplay', { paragraphs: [
        'Normal career gameplay is free. Premium adds optional analysis, convenience and selected premium-only systems; it is not required to create a player, train, enter tournaments or use the core career loop.',
      ]}),
      s('Current Premium plan', { table: {
        headers: ['Item', 'Current value'],
        rows: [['Premium price', 'EUR 3.29 per real-life month'], ['Monthly Premium Coin reward', '30 Coins after a successful monthly payment'], ['Cancellation', 'Can be cancelled; normal gameplay remains Free']],
      }}),
      s('Current Coin packs', { table: {
        headers: ['Pack', 'Price'],
        rows: [['70 Coins', 'EUR 2.99'], ['130 Coins', 'EUR 4.99'], ['270 Coins', 'EUR 9.99'], ['390 Coins', 'EUR 13.99'], ['570 Coins', 'EUR 19.99'], ['900 Coins', 'EUR 29.99']],
      }}),
      s('Starting Coins', { paragraphs: [
        'A new human career receives 20 starting Coins once. Coins have their own wallet/ledger and are separate from Career Cash.',
      ]}),
      s('Premium examples currently implemented', { bullets: [
        'Ranking Protection view for upcoming singles/doubles ranking-point expirations.',
        'Private Life access and the one-time Premium starter apartment entitlement.',
        'Monthly Premium Coin reward after successful billing.',
      ]}),
      s('Billing history', { paragraphs: [
        'Premium invoices, Coin-package purchases and Coin-ledger activity are shown separately. Secure checkout and recurring billing are handled through Stripe.',
      ], links: [{ label: 'Open Premium & Billing', href: '/game/pro-packages' }]}),
    ],
  },
  {
    id: 'private-life',
    title: 'Private Life',
    summary: 'Premium off-court assets, property markets, prestige, investments and recurring ownership costs.',
    sections: [
      s('Premium-only access', { paragraphs: [
        'Private Life is Premium-only. A Premium career receives one starter apartment in the player\'s home city. The starter apartment is trade-locked so the entitlement cannot be converted directly into Career Cash.',
      ]}),
      s('Physical assets and prestige', { paragraphs: [
        'Owned physical assets contribute market value, prestige and, for some asset classes, recurring monthly costs. The dashboard separates Career Cash, physical assets, investments, current net worth and monthly ownership cost.',
      ]}),
      s('Recurring costs', { paragraphs: [
        'Vehicles, homes, yachts and private jets carry recurring ownership/living costs. Watches, jewelry, art and collectibles do not use the same recurring-cost model.',
      ]}),
      s('Property pricing', { paragraphs: [
        'Property values use a 10-tier country baseline for home cities without a dedicated marketplace price. Explicit major-city markets override the country baseline, so New York and a lower-cost city do not receive the same property value.',
      ]}),
      s('Residence rule', { paragraphs: [
        'The player may need another qualifying residence before selling the current primary residence. The Premium starter home itself is trade-locked and cannot be sold.',
      ]}),
      s('Marketplace and transaction history', { paragraphs: [
        'Purchases, sales and ownership charges flow through Career Finance and are recorded in Private Life transaction history. Active sale listings can be cancelled while still open.',
      ], links: [{ label: 'Open Private Life', href: '/game/private-life' }]}),
    ],
  },
  {
    id: 'tennis-club',
    title: 'Tennis Club and Community Clubs',
    summary: 'Cross-tour social clubs, membership applications, club rankings and private club chat.',
    sections: [
      s('Cross-tour membership', { paragraphs: [
        'Tennis Clubs are shared social organizations that can include ATP and WTA human players. A player can belong to one club through creation, application or invitation.',
      ]}),
      s('Creating a club', { paragraphs: [
        'Creating a Tennis Club costs 50 Coins. The creator becomes the Club Owner. The club name must satisfy the current validation rules and be unique.',
      ]}),
      s('Joining a club', { paragraphs: [
        'Use World Clubs to apply to an existing club, or accept an invitation from a club owner. Pending applications and invitations remain visible until resolved.',
      ]}),
      s('Club points and ranking', { paragraphs: [
        'Club points are the live sum of every member\'s current official ranking points across ATP and WTA. World Club Ranking shows the top 50 clubs.',
      ]}),
      s('Club chat', { paragraphs: [
        'Club Chat is members-only. The configured recent-chat window is 14 game days.',
      ], links: [{ label: 'Open Tennis Club', href: '/game/tennis-club' }]}),
    ],
  },
  {
    id: 'national-association',
    title: 'National Association and National Team',
    summary: 'Membership, association funding, captain elections and community governance.',
    sections: [
      s('Membership', { paragraphs: [
        'National Association membership is opt-in. A new player is not automatically a member. Joining puts the player in the association\'s eligible call-up pool and enables governance participation where eligible.',
      ]}),
      s('Community governance principles', { bullets: [
        'One member equals one vote.',
        'Donation amount never increases voting power.',
        'Founding/activation status is cosmetic and does not create permanent ownership.',
        'The national captain is a playing member and uses a normal squad place.',
        'Captaincy does not bypass fatigue, health or calendar rules.',
      ]}),
      s('Annual renewal', { paragraphs: [
        'Association renewal opens in January and must be completed by 31 January. An unpaid association becomes inactive from 1 February.',
      ]}),
      s('Captain election timeline', { table: {
        headers: ['Date / period', 'Action'],
        rows: [
          ['1 January', 'Annual renewal and candidate registration open'],
          ['10 January', 'Main captain vote opens'],
          ['20 January', 'Main election round closes'],
          ['21-27 January', 'First runoff if no unique winner'],
          ['Every 7 days after', 'Further runoffs repeat if still unresolved'],
          ['31 January', 'Renewal deadline'],
          ['1 February', 'Unpaid association becomes inactive'],
        ],
      }}),
      s('Winner rule', { paragraphs: [
        'A candidate wins only when they have at least one vote and strictly more votes than every other candidate. If there is no unique winner, a runoff is created.',
      ]}),
      s('Captain resignation', { paragraphs: [
        'The current captain can resign. A replacement election can then open instead of leaving captaincy permanently tied to the previous winner.',
      ], links: [{ label: 'Open National Association', href: '/game/national-team' }]}),
    ],
  },
  {
    id: 'statistics',
    title: 'Statistics and Career History',
    summary: 'World leaderboards, tournament statistics, player records and season-by-season history.',
    sections: [
      s('Statistics areas', { bullets: ['World Statistics', 'Player Statistics', 'Tournament Statistics', 'Career Records'] }),
      s('World leaderboard', { paragraphs: [
        'World Statistics shows leading players with completed official matches in the selected period, including ranking, points, win percentage, titles and match-production totals where available.',
      ]}),
      s('Tournament database', { paragraphs: [
        'Tournament Statistics aggregate official completed matches, participation, shot production and top-performer information by event.',
      ]}),
      s('Player career statistics', { paragraphs: [
        'Player Statistics includes current rank, career best, match record, titles/finals, prize money, surface record, shot production and performance by tournament category.',
      ]}),
      s('Career timeline', { paragraphs: [
        'The season-by-season timeline becomes the long-term historical record as the career advances and keeps current-season performance separate from all-time totals.',
      ], links: [{ label: 'Open Statistics', href: '/game/statistics' }]}),
    ],
  },
  {
    id: 'preferences-support',
    title: 'Game Preferences, Help, Community and Support',
    summary: 'Manager-facing settings and support tools outside the competitive career loop.',
    sections: [
      s('Game Preferences', { paragraphs: [
        'Game Preferences is the home for personal interface and communication settings. Individual notification-category controls are not yet configured there, so the manual does not describe unavailable toggles as active.',
      ]}),
      s('Help Center', { paragraphs: [
        'Help Center provides quick-start links, Contact Support, Discord and this Full Game Manual. The manual stays inside Tennis Legacy and also has a downloadable PDF edition.',
      ]}),
      s('Forum / Discord', { paragraphs: [
        'The official Tennis Legacy Discord is the community forum for strategy, screenshots, questions, bug reports, suggestions and development announcements.',
      ]}),
      s('Contact Support', { paragraphs: [
        'Contact Us is the direct support route. For technical issues, include page name, player name, screenshots and exact reproduction steps.',
      ]}),
      s('Invite Friends', { paragraphs: [
        'Invite Friends provides a registration/referral link for another manager to create a separate ATP or WTA career.',
      ], links: [
        { label: 'Open Game Preferences', href: '/game/preferences' },
        { label: 'Open Help Center', href: '/game/help' },
        { label: 'Contact Support', href: '/game/contact' },
        { label: 'Open Forum', href: '/game/forum' },
      ]}),
    ],
  },
  {
    id: 'season-progression',
    title: 'Season Progression and Game-Time Processing',
    summary: 'How Tennis Legacy advances through game days and why many systems update automatically.',
    sections: [
      s('Game time, not real-world time', { paragraphs: [
        'Tennis Legacy uses its own game calendar. Tournaments, ranking publication, contracts, tax, health, training, travel and association windows are keyed to game dates rather than the manager\'s real-world date.',
      ]}),
      s('Automatic daily processing', { paragraphs: [
        'Many systems update automatically as game days advance: regular training, Training Camp days, travel legs, health rolls, Finance settlements, sponsor payments, ranking publication and tournament lifecycle actions. Players should not need to manually process every background transition.',
      ]}),
      s('Season reset versus career continuity', { paragraphs: [
        'A new game season changes seasonal schedules, ranking-contribution defence context, sponsor cycles, association renewal/election windows and season statistics. The long-term career continues with the same identity, skills, owned equipment and historical records unless a specific system states otherwise.',
      ]}),
      s('System Health', { paragraphs: [
        'Critical background processes are monitored by System Health and the administrative Control Center. This operational layer detects stale/failing lifecycle jobs and integrity issues so technical failures do not silently become normal gameplay.',
      ]}),
    ],
  },
  {
    id: 'important-rules',
    title: 'Important Game Rules and Limitations',
    summary: 'Rules that prevent common misunderstandings about what the current game does.',
    sections: [
      s('Identity and worlds', { bullets: [
        'The professional player name is fixed after career creation.',
        'Playing hand is a core player identity. Left-handed and right-handed players do not receive automatic permanent Forehand/Backhand bonuses; handedness affects match geometry and tactical suitability.',
        'ATP and WTA competitive rankings are separate.',
        'Singles and doubles rankings are separate disciplines.',
        'Tennis Clubs can contain members from both ATP and WTA.',
      ]}),
      s('Calendar ownership', { bullets: [
        'A tournament, travel, Training Camp, National Team or health date is not a normal Home training day.',
        'A saved regular-training plan never overrides stronger calendar ownership.',
        'Impossible travel timing can make the player miss a match.',
      ]}),
      s('Money and Coins', { bullets: [
        'Career Cash and Coins are separate currencies.',
        'Premium does not remove the need to manage Career Cash.',
        'Buying Coins does not create Career Cash.',
        'Finance value movements are designed to be idempotent so a retry does not duplicate a charge or reward.',
      ]}),
      s('Opponent knowledge and tactics', { bullets: [
        'Playing hand, preferred surface and playing style are public opponent information.',
        'Exact opponent skills remain private. A Performance Analyst reports estimates whose range narrows with analyst quality and preparation time.',
        'Performance Analyst quality improves information certainty rather than directly increasing hidden player strength.',
        'Tactical counters are modest matchup effects, not guaranteed-win buttons. Own skills, opponent skills, surface, condition and risk still matter.',
      ]}),
      s('Development', { bullets: [
        'Preferred surface/style changes starting distribution, not total starting strength.',
        'High skills develop more slowly than lower skills.',
        'Training Camps are stronger than ordinary training but use diminishing returns over multiple weeks.',
        'Readiness values are not permanent skills.',
      ]}),
      s('Premium boundaries', { bullets: [
        'Core career gameplay is available to Free players.',
        'Private Life is Premium-only.',
        'Ranking Protection is planning information, not protection from losing points.',
        'The Premium starter apartment is trade-locked.',
      ]}),
      s('Unfinished ideas are not documented as active', { paragraphs: [
        'If a current game page states that a control is not configured yet, this manual describes it as unavailable rather than presenting a future idea as already implemented.',
      ]}),
    ],
  },
  {
    id: 'faq',
    title: 'Frequently Asked Questions',
    summary: 'Answers to common career-management questions.',
    sections: [
      s('Why can\'t I train today?', { paragraphs: [
        'Check the current calendar activity and Health. Regular Training requires a Home day and medical clearance. Tournament, travel, Training Camp, National Team or injury/recovery ownership blocks normal training.',
      ]}),
      s('Why did my ranking drop even though I did not lose today?', { paragraphs: [
        'Rank is relative to every player, and active ranking contributions can expire. Other players can also gain points. Premium Ranking Protection can show upcoming expirations but does not stop them.',
      ]}),
      s('Why did a Training Camp become shorter?', { paragraphs: [
        'If a tournament immediately before the camp consumes the normal travel date, the first camp date can become a split travel day through the home city. The original camp end date remains, so one development day is lost.',
      ]}),
      s('Can I keep regular training planned during a Training Camp?', { paragraphs: [
        'Yes. The saved weekly plan can remain, but camp and camp-travel dates override it automatically. Regular Training shows the booked camp so the conflict is visible.',
      ]}),
      s('Why did I miss a tournament match?', { paragraphs: [
        'One supported reason is travel no-show: if the itinerary cannot make the player ready before scheduled match time, the opponent advances without a played match. Health restrictions can also create non-played outcomes.',
      ]}),
      s('Do I get staff or sponsors when I start?', { paragraphs: [
        'No. A new career begins with no staff, no main sponsor and no technical sponsor. Those systems are built during the career.',
      ]}),
      s('What should I spend the first $25,000 on?', { paragraphs: [
        'There is no single correct answer. Starter equipment is sufficient to play, so early spending can focus on training, tournament travel/hotels, carefully selected staff or targeted equipment upgrades. Check upcoming costs before committing too much cash.',
      ]}),
      s('What are the first 20 Coins for?', { paragraphs: [
        'They introduce the Coin wallet and can be saved for optional Coin-based systems. Creating a Tennis Club currently costs 50 Coins, so the starting grant is intentionally not enough to create a club immediately.',
      ]}),
      s('Can I sell the Premium starter apartment?', { paragraphs: [
        'No. It is trade-locked so the Premium entitlement cannot become a Career Cash exploit.',
      ]}),
      s('Is Premium required to be competitive?', { paragraphs: [
        'Core competitive systems are available without Premium. Premium adds optional analysis/convenience and Private Life, not a guaranteed tournament or ranking result.',
      ]}),
      s('Where do I report a bug?', { paragraphs: [
        'Use Contact Support or the official Discord. Include screenshots, the player name, game page and exact reproduction steps.',
      ], links: [{ label: 'Open Help Center', href: '/game/help' }, { label: 'Contact Support', href: '/game/contact' }]}),
    ],
  },
]
