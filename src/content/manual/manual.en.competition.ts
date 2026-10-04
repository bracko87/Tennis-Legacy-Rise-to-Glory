import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCompetitionChapters: ManualChapter[] = [
  {
    id: 'tournament-selection',
    title: 'Tournament Selection and Applications',
    summary: 'How to choose events, apply and interpret the difference between an application and an accepted entry.',
    sections: [
      s('Before applying', { steps: [
        'Check the tournament category and expected competitive level.',
        'Check the surface against the player\'s skills and current condition.',
        'Check the complete tournament period, not only the opening date.',
        'Check existing tournaments, Training Camps, National Team activity and travel.',
        'Consider the travel/hotel spending that follows if the player is accepted.',
      ]}),
      s('Application lifecycle', { paragraphs: [
        'A tournament application is a request for entry, not an accepted tournament place. The entry lifecycle processes applications against eligibility, ranking and draw capacity. Schedule keeps application history and accepted outcomes visible so a player can distinguish Applied, Main Draw, Qualification and completed entry outcomes.',
      ]}),
      s('Qualification and main draw', { paragraphs: [
        'Depending on category and field allocation, a player can be placed directly into the main draw or into qualification. Qualifiers who progress can claim the configured qualifier slots in the main draw.',
      ]}),
      s('Calendar conflicts', { paragraphs: [
        'The game prevents supported impossible overlaps. Training Camps, for example, cannot be booked across an existing tournament application or accepted tournament entry. Travel and health systems also contribute to availability.',
      ]}),
      s('Entry notifications', { paragraphs: [
        'Important application, accepted-entry, draw and tournament-preparation events can generate career notifications with a direct action back to the relevant tournament or Schedule page.',
      ], links: [
        { label: 'Open Tournament Calendar', href: '/game/calendar' },
        { label: 'Open Schedule', href: '/game/schedule' },
      ]}),
    ],
  },
  {
    id: 'tournament-categories',
    title: 'Tournament Categories and Entry Rules',
    summary: 'The current singles competition ladder, draw capacities and winner ranking-point values.',
    sections: [
      s('Current category ladder', { table: {
        headers: ['Category', 'Winner points', 'Main draw', 'Max qualifying', 'Qualifier slots', 'Weeks'],
        rows: [
          ['Grand Slam 2000', '2000', '128', '128', '16', '2'],
          ['Masters 1000', '1000', '64', '32', '8', '2'],
          ['Tour 500', '500', '32', '16', '4', '1'],
          ['Tour 250', '250', '32', '16', '4', '1'],
          ['Challenger 125', '125', '32', '24', '6', '1'],
          ['Challenger 100', '100', '32', '24', '6', '1'],
          ['Challenger 75', '75', '32', '24', '6', '1'],
          ['Challenger 50', '50', '32', '24', '6', '1'],
          ['Futures 25', '25', '32', '32', '8', '1'],
          ['Futures 15', '15', '32', '32', '8', '1'],
        ],
      }}),
      s('Scheduling rules', { bullets: [
        'Standard professional categories use one match per player per game day.',
        'Qualification is hosted in the same tournament city.',
        'Grand Slams and Masters span two competition weeks; lower categories normally use one.',
        'Grand Slams can use up to three qualification rounds; the other listed categories use up to two.',
      ]}),
      s('Choosing the right level', { paragraphs: [
        'Higher categories offer larger ranking-point opportunities but stronger fields and harder entry. Futures and Challenger events are important early-career development routes rather than filler competitions.',
      ]}),
      s('National Team category', { paragraphs: [
        'National Team competition is governed by the National Association system and should not be interpreted as a standard individual-tour ranking category.',
      ]}),
    ],
  },
  {
    id: 'schedule-travel',
    title: 'Schedule, Commitments and Travel',
    summary: 'The Schedule page, preparation commitments, travel classes, hotels and automatic travel timing.',
    sections: [
      s('Schedule page', { paragraphs: [
        'Schedule shows the next tournament, later tournament commitments, application history and preparation controls. Only competitions belonging to the current player appear in the schedule list.',
      ]}),
      s('Automatic travel timing', { paragraphs: [
        'The shared travel engine builds planned travel from tournament/camp commitments, geography and match timing. It records source and destination, departure/arrival day, travel cost, expected fatigue and readiness timing.',
      ]}),
      s('Travel classes', { table: {
        headers: ['Class', 'Gameplay intent'],
        rows: [['Economy', 'Standard travel fatigue'], ['Premium Economy', 'About 15% less travel fatigue'], ['Business', 'About 35% less travel fatigue'], ['First Class', 'About 50% less travel fatigue']],
      }}),
      s('Tournament hotels', { table: {
        headers: ['Hotel', 'Positioning'],
        rows: [['Budget Hotel 2-star', 'Lowest cost'], ['Standard Hotel 3-star', 'Balanced option'], ['Premium Hotel 4-star', 'Higher comfort'], ['Luxury Hotel 5-star', 'Maximum comfort']],
      }}),
      s('Travelling party', { paragraphs: [
        'Active staff can be selected to travel. Staff add travel and accommodation cost, but presence-dependent staff effects require the staff member to actually travel with the player.',
      ]}),
      s('Tight travel and no-show risk', { paragraphs: [
        'Travel timing is not cosmetic. If a planned itinerary cannot make the player ready before a scheduled match, the player can miss that match. Training Camp transitions use special home-routed first-half/second-half travel when dates are extremely tight.',
      ], links: [{ label: 'Open Schedule', href: '/game/schedule' }]}),
    ],
  },
  {
    id: 'tournament-preparation',
    title: 'Tournament Preparation',
    summary: 'Travel, hotel, staff, equipment and tactical preparation before competition.',
    sections: [
      s('Preparation flow', { steps: [
        'Open Schedule and select Prepare Tournament for the next event.',
        'Choose a travel class and hotel tier.',
        'Choose which contracted staff travel with the player.',
        'Review the travel quote and the cost/fatigue trade-off.',
        'Save the tournament-default tactic or keep the current default. Tactics include approach, rally length, serve strategy and placement, return strategy and position, court position, opponent target and risk.',
        'Save preparation; the shared travel engine recalculates the planned itinerary.',
      ]}),
      s('Tournament default tactic', { paragraphs: [
        'The Tournament Default tactic is used for matches in that tournament unless a specific upcoming match has its own override. This avoids having to create a new tactical plan for every round.',
      ]}),
      s('Opponent analysis and match-specific overrides', { paragraphs: [
        'When an opponent is known, the match page always shows public identity such as playing hand, playing style and preferred surface. If a Performance Analyst is employed, Opponent Analysis adds approximate skill ranges, report confidence, observed tendencies and tactical considerations.',
        'The match detail can store an opponent-specific plan. Clearing the override returns the match to the Tournament Default. A tactical plan is evaluated against both players: exploiting a real weakness can help, while choosing a counter that does not suit your own skills can be ineffective or harmful.',
      ]}),
      s('Equipment readiness', { paragraphs: [
        'Tournament preparation should be checked together with the Equipment Center. The authoritative match equipment effect uses the currently equipped items, their condition and relevant court-surface matching.',
      ]}),
      s('Preparation does not bypass travel physics', { paragraphs: [
        'A premium travel class can reduce fatigue pressure, but it does not teleport the player. Geography and match timing still matter, and impossible readiness can cause a travel no-show.',
      ], links: [{ label: 'Open Schedule', href: '/game/schedule' }, { label: 'Open Equipment', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'matches',
    title: 'Match Tactics and Tournament Progression',
    summary: 'Draws, match windows, tactical controls, results and progression through a tournament.',
    sections: [
      s('Draw and bracket', { paragraphs: [
        'Once published, the tournament page shows the knockout bracket, round progression, byes where applicable and the player\'s path through the event. Match states distinguish Scheduled, Live, Final and Cancelled.',
      ]}),
      s('Match detail', { paragraphs: [
        'Match detail shows the players, tournament context, timing, score/result and, when recorded, match statistics such as aces, double faults, first-serve percentage, break points won, winners, unforced errors and total points won.',
      ]}),
      s('Tactical controls', { paragraphs: [
        'Tactical settings influence attack intent, winner attempts, serve/return pressure, serve placement (Automatic, Wide, Body or T), return position (Normal, Closer or Deeper), rally length, court position, opponent target and error exposure.',
        'Opponent targeting can focus on Forehand, Backhand, Movement, Stamina or Second Serve. Handedness changes the geometry of those patterns but is not an inherent strength bonus. More aggressive choices can create upside while increasing tactical and physical risk.',
      ]}),
      s('Result progression', { paragraphs: [
        'A completed match records a winner and advances the bracket. Tournament results then feed ranking contributions, statistics, prize money and relevant sponsor/objective systems.',
      ]}),
      s('Non-played outcomes', { paragraphs: [
        'A match can complete without normal play for supported health or travel reasons. Travel no-show occurs when the itinerary makes the player impossible to be ready at match time. No equipment durability is charged when no match was actually played.',
      ]}),
      s('Head-to-head and road to match', { paragraphs: [
        'Where history exists, match detail can show previous meetings, earlier-round results and the player\'s route to the current round. A first meeting naturally has no H2H history.',
      ]}),
    ],
  },
  {
    id: 'singles-rankings',
    title: 'ATP and WTA Singles Rankings',
    summary: 'How the world-ranking page is organized and how ranking changes are presented.',
    sections: [
      s('Separate worlds', { paragraphs: [
        'ATP and WTA singles rankings are separate. A player appears only in the correct tour world. Rankings are paginated and ranked human/AI players can be opened as player profiles.',
      ]}),
      s('Ranking columns', { bullets: ['Rank', 'Rank change', 'Player', 'Country', 'Points', 'Points change']}),
      s('New careers', { paragraphs: [
        'A new career begins with 0 official singles ranking points but receives a ranking record so the player can enter the ranking system immediately. Tournament results create active ranking contributions.',
      ]}),
      s('Why rank can move without a new result', { paragraphs: [
        'Rank is relative to everyone else. A player can move because another player gains points, because an old contribution expires, or because a previous ranking snapshot is being compared with the newly published one.',
      ]}),
      s('Premium Ranking Protection', { paragraphs: [
        'Premium exposes up to the next five active singles contributions scheduled to expire. It is a planning view only and does not preserve the points.',
      ], links: [{ label: 'Open Rankings', href: '/game/rankings' }]}),
    ],
  },
  {
    id: 'doubles',
    title: 'Doubles and Doubles Rankings',
    summary: 'The separate doubles discipline, partnership-based tournament participation and ranking tracking.',
    sections: [
      s('Separate discipline', { paragraphs: [
        'Singles and doubles are recorded separately. Doubles has its own applications, tournament results, ranking points, rank and expiring contributions. A singles ranking does not become a doubles ranking.',
      ]}),
      s('Partnership', { paragraphs: [
        'Doubles participation requires a partner where the application flow requires one. Schedule shows doubles applications and partnership status separately from singles applications.',
      ]}),
      s('Doubles ranking', { paragraphs: [
        'The Rankings page can switch to Doubles World Ranking. Individual players receive doubles ranking contributions from partnership results.',
      ]}),
      s('Doubles notifications', { paragraphs: [
        'Draw, match preparation, result and partnership-deadline events can appear in Notifications with direct routes to the relevant doubles tournament view.',
      ], links: [{ label: 'Open Rankings', href: '/game/rankings' }, { label: 'Open Schedule', href: '/game/schedule' }]}),
    ],
  },
  {
    id: 'ranking-points',
    title: 'Ranking Points, Contributions and Expiration',
    summary: 'How tournament results become active ranking contributions and later leave the total.',
    sections: [
      s('Contribution model', { paragraphs: [
        'Ranking points are stored as result contributions rather than as an unexplained permanent number. The current ranking total is the sum of active contributions for the player and tour.',
      ]}),
      s('Category point ceiling', { paragraphs: [
        'Tournament category defines the maximum winner-point scale: 15/25 at Futures, 50-125 at Challenger level, 250/500 at Tour level, 1000 at Masters and 2000 at Grand Slam level. Earlier-round values follow the result rules for that category.',
      ]}),
      s('Expiration and defence cycles', { paragraphs: [
        'Each active contribution stores an awarded game day and expiration game day. When it expires or is superseded by the ranking defence cycle, it is deactivated and the ranking total is recalculated.',
      ]}),
      s('Defending points', { paragraphs: [
        'Defending points means replacing value that is scheduled to leave the active total. A future edition being scheduled does not guarantee replacement; the player still needs an appropriate result.',
      ]}),
      s('Premium planning', { paragraphs: [
        'Premium shows the next five expiring singles or doubles contributions with tournament, source result, points, expiration date and days remaining. Expiration itself is identical for Free and Premium players.',
      ]}),
    ],
  },
  {
    id: 'equipment',
    title: 'Equipment Center and Equipment Effects',
    summary: 'Gear Room, Inventory, Market, condition, wear, surface matching and active accessory slots.',
    sections: [
      s('Active equipment families', { paragraphs: [
        'The current catalog contains rackets, shoes, apparel and accessories. Active accessory kinds are bags, bottles, caps, towels and wristbands. Overgrips and dampeners are not active categories.',
      ]}),
      s('Gear Room', { paragraphs: [
        'Racket, shoes and clothing each use one active slot. Accessories use one active slot per accessory kind. The Current Match Setup is the authoritative equipped configuration used by match systems.',
      ]}),
      s('Inventory', { paragraphs: [
        'Owned items display condition-adjusted bonuses, durability, wear per match, brand identity and resale value. Starter gear, purchases and other acquired equipment stay in Inventory until sold or discarded.',
      ]}),
      s('Market', { paragraphs: [
        'Equipment Market purchases use Career Cash and enter Inventory at 100% condition. An active matching technical sponsor can reduce the player price.',
      ]}),
      s('Condition and wear', { paragraphs: [
        'Gameplay modifiers use current condition rather than always applying the 100%-condition catalog number. Match wear reduces condition according to item durability/wear rules. Walkovers/no-shows with no played match do not reduce equipment durability.',
      ]}),
      s('Surface matching and product profile', { paragraphs: [
        'Some products have surface/weather characteristics or trade-offs. The final equipment profile combines item bonuses, condition and court-surface matching instead of blindly adding every catalog value.',
      ]}),
      s('Selling and discarding', { paragraphs: [
        'Eligible equipment can be sold for its current resale value or discarded. An item that is currently equipped must be replaced/unequipped before removal when the slot cannot be left in an invalid state.',
      ], links: [{ label: 'Open Equipment Center', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'technical-sponsors',
    title: 'Technical Sponsors',
    summary: 'Brand sponsorships for racket, shoes and clothing and how they change equipment prices.',
    sections: [
      s('Separate from the main sponsor', { paragraphs: [
        'Technical sponsorship lives in Equipment and is separate from the main career sponsor in Finance. Technical contracts are category-specific: racket, shoes and apparel.',
      ]}),
      s('Offer eligibility', { paragraphs: [
        'Technical offers are generated from the player\'s current ranking group. Ranking bands influence available brand tiers, offer count, discount range and possible signing bonus.',
      ]}),
      s('Current benefit model', { paragraphs: [
        'The implemented equipment benefit is discount-based. Active technical sponsors reduce the Career Cash price of matching equipment. The current model does not provide unlimited free equipment or automatic free replacements.',
      ]}),
      s('Contract timing', { paragraphs: [
        'With no current category contract, a signed offer can start immediately. When an active deal reaches its final 28 days, the player can sign a replacement for that category; the new deal is scheduled to start after the current one ends.',
      ]}),
      s('Signing bonus and contract notifications', { paragraphs: [
        'Technical deals can include a Career Cash signing bonus. Expiring, starting and completed technical contracts create notifications; discounts stop when the relevant contract is no longer active.',
      ], links: [{ label: 'Open Technical Sponsors', href: '/game/equipment' }]}),
    ],
  },
  {
    id: 'finance',
    title: 'Finance and Career Economy',
    summary: 'Career Cash, permanent ledger, taxes, upcoming costs and the difference between money and Coins.',
    sections: [
      s('Career Cash', { paragraphs: [
        'Career Cash is the professional career economy used for staff, equipment, Training Camps, tournament travel/hotels, Private Life and other career transactions. A new career begins with $25,000 USD.',
      ]}),
      s('Permanent ledger', { paragraphs: [
        'Every Career Cash movement is recorded with game date, category, source, reason, amount and resulting balance. The Finance page therefore shows not only the balance but how it was created.',
      ]}),
      s('Income and expenses', { paragraphs: [
        'Finance analytics separate income and expenses. Typical income includes prize money, sponsorship and bonuses; common expenses include travel, hotels, staff, training and purchases.',
      ]}),
      s('Monthly income tax', { paragraphs: [
        'The current universal tax version uses a flat 18% rate on taxable monthly income. Expenses are not deductions in this version. On the first game day of the next month, the completed month is settled once through an idempotent transaction key.',
      ]}),
      s('Upcoming commitments', { paragraphs: [
        'Finance shows upcoming cost pressure over the next 60 game days. Check it before committing to an expensive camp, staff deal, equipment upgrade or luxury purchase.',
      ]}),
      s('Career Cash is not Coins', { paragraphs: [
        'Coins are an optional game/premium currency used by selected optional systems. Career Cash and Coins cannot substitute for each other.',
      ], links: [{ label: 'Open Finance Center', href: '/game/finance' }]}),
    ],
  },
  {
    id: 'main-sponsors',
    title: 'Main Sponsors and Sponsor Objectives',
    summary: 'Season sponsor offers, weekly payments and tournament objectives.',
    sections: [
      s('No sponsor at career creation', { paragraphs: ['A new player starts without a main sponsor and must sign an offer during the career.']}),
      s('How offers are generated', { paragraphs: [
        'Main-sponsor offers are ranking-sensitive and use the player\'s national sponsor market group. Higher-ranked players can also receive worldwide-brand opportunities. Offer count and contract value change with ranking.',
      ]}),
      s('Weekly offer window', { paragraphs: [
        'Open sponsor offers belong to a game-week offer window and can expire. Once a season main sponsor is signed, other open main-sponsor offers for that season are closed.',
      ]}),
      s('Contract money', { paragraphs: [
        'A signed main sponsor pays scheduled weekly Career Cash amounts through the season. Sponsor transactions use the same permanent Finance ledger as other career money.',
      ]}),
      s('Objectives', { paragraphs: [
        'Active sponsor objectives can identify target tournaments or performance requirements. Relevant tournament objectives appear in Calendar so the player can plan commercial commitments alongside ranking goals.',
      ], links: [{ label: 'Open Finance / Sponsorship', href: '/game/finance' }, { label: 'Open Calendar', href: '/game/calendar' }]}),
    ],
  },
]
