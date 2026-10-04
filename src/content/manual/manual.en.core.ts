import type { ManualChapter, ManualSection } from './types'

const s = (title: string, data: Omit<ManualSection, 'title'> = {}): ManualSection => ({ title, ...data })

export const manualCoreChapters: ManualChapter[] = [
  {
    id: 'getting-started',
    title: 'Getting Started',
    summary: 'A practical orientation to the Tennis Legacy career loop, the main pages and the decisions that matter first.',
    sections: [
      s('What Tennis Legacy is', { paragraphs: [
        'Tennis Legacy: Rise to Glory is a persistent professional tennis career-management game. You control one human player in either the ATP or WTA world, plan development, enter tournaments, manage travel and equipment, build a staff team, handle finances, and react to health, ranking and calendar pressure over multiple game seasons.',
        'ATP and WTA are separate competitive worlds for singles and doubles rankings. Social systems such as Tennis Clubs can include members from both tours, while tournament entry, ranking and results remain tied to the player\'s own tour.',
      ]}),
      s('Recommended first-session order', { steps: [
        'Open Overview and check the current game date, ranking, readiness, Career Cash, next commitment and personal notifications.',
        'Open Skills to understand the player\'s technical, physical and readiness profile.',
        'Open Training and configure a regular weekly plan. New careers start without a configured regular-training plan.',
        'Open Equipment. A new career already has a starter racket, starter shoes and starter clothing equipped.',
        'Open Tournament Calendar before applying anywhere. Check category, surface, timing and travel implications.',
        'Open Schedule after applying or being accepted. Tournament commitments, preparation and travel are managed there.',
        'Open Finance regularly. Career Cash is separate from Coins and every Career Cash movement is permanently logged.',
      ]}),
      s('The core career loop', { bullets: [
        'Plan training, tournaments, travel, equipment and staff around the calendar.',
        'Prepare fatigue, health, tactics, gear and travel before competition.',
        'Compete for results, ranking contributions, statistics, prize money and sponsor progress.',
        'Recover and develop through regular training, Training Camps and sensible workload management.',
        'Reinvest Career Cash into staff, equipment, camps, travel, hotels and Private Life purchases.',
        'Review Rankings, Statistics, Notifications and Finance to understand the consequences of earlier decisions.',
      ]}),
      s('Where to go when something is unclear', { paragraphs: [
        'Use this Full Game Manual for rules and process explanations. The Help Center also links to Contact Support and the official Tennis Legacy Discord. When reporting a problem, include the page, player name, screenshots and exact reproduction steps.',
      ], links: [
        { label: 'Open Overview', href: '/game/overview' },
        { label: 'Open Help Center', href: '/game/help' },
      ]}),
    ],
  },
  {
    id: 'creating-a-career',
    title: 'Creating a Career',
    summary: 'How player creation works and the exact Day-1 package assigned to every new human career.',
    sections: [
      s('Career creation choices', { bullets: [
        'Tour: choose ATP or WTA. This determines the competitive world and ranking the player belongs to.',
        'Identity: choose a realistic first name, last name and nationality. The professional player name is permanent after creation.',
        'Home city: choose a supported city for the selected country. Home city is used by travel and Private Life.',
        'Portrait: optional. Catalog portraits already used by another active career are unavailable.',
        'Preferred surface: Hard, Clay or Grass.',
        'Playing style: Aggressive Baseliner, Defensive Baseliner, All-court, or Serve & Volley.',
        'Playing hand: Right-handed or Left-handed. Handedness changes serve/rally geometry and tactical matchups; it does not grant free Forehand or Backhand skill points.',
      ]}),
      s('Exact Day-1 package', { table: {
        headers: ['System', 'Starting state'],
        rows: [
          ['Career Cash', '$25,000 USD'], ['Coins', '20 Coins, granted once'], ['Singles ranking points', '0'],
          ['Doubles ranking points', '0'], ['Regular training', 'Not configured'], ['Staff', 'None'],
          ['Main sponsor', 'None'], ['Technical sponsors', 'None'], ['National Association', 'Not joined'],
          ['Tennis Club', 'Not joined'], ['Calendar commitments', 'None'], ['Fatigue', '0'], ['Sharpness', '50'],
          ['Morale', '50'], ['Confidence', '50'], ['Focus', '50'],
          ['Starter racket', 'Rosignol F-200 Carbon, 100% condition, equipped'],
          ['Starter shoes', 'Antta PG 7, 100% condition, equipped'],
          ['ATP starter clothing', 'BlokUV Guardian Court, 100% condition, equipped'],
          ['WTA starter clothing', 'BlokUV Solar Shield 8, 100% condition, equipped'],
          ['Starter accessories', 'None'], ['Free Private Life', 'No starter property'],
          ['Premium Private Life', 'One trade-locked starter apartment in the home city'],
        ],
      }}),
      s('One-time initialization', { paragraphs: [
        'Career initialization is idempotent. Refreshing, retrying or re-opening the game must not duplicate the $25,000 opening balance, the 20-Coin grant, starter gear or a Premium starter apartment. The initialization audit records the applied scheme version.',
      ]}),
      s('Restarting or deleting an account', { paragraphs: [
        'Player & Account contains destructive restart and permanent deletion actions. Use them only when you intend to remove the current career state. Starting Coins are protected against simple retry/refresh duplication and are not intended as a repeatable farming method.',
      ], links: [{ label: 'Open Player & Account', href: '/game/player-account' }]}),
    ],
  },
  {
    id: 'overview',
    title: 'Overview and Daily Career Workflow',
    summary: 'How to read the career command center and use it as the starting point for each game day.',
    sections: [
      s('What Overview shows', { bullets: [
        'Professional profile and current ranking context.',
        'Next tournament and next scheduled match when available.',
        'Previous match result.',
        'Career Finance balance plus season income, expenses and net flow.',
        'Next commitment and current-day tournament activity.',
        'Season-form statistics.',
        'Readiness and current training information.',
        'Quick access to gear, team and club systems.',
        'Recent official results around the tour and personal career notifications.',
      ]}),
      s('Premium ranking protection panel', { paragraphs: [
        'Premium accounts can expand Ranking Protection to see the next five active ranking-point contributions scheduled to expire. This is planning information only: Premium does not prevent points from expiring and does not change match or ranking results.',
      ]}),
      s('A useful daily routine', { steps: [
        'Read personal notifications first.',
        'Check next commitment and next match.',
        'Check readiness, fatigue and Health if training or competition is approaching.',
        'Check Schedule or Calendar before applying to another event.',
        'Check Finance before signing staff, booking a camp, buying gear or selecting expensive travel.',
        'Use Rankings and Statistics for longer-term trend review.',
      ], links: [{ label: 'Open Overview', href: '/game/overview' }]}),
    ],
  },
  {
    id: 'player-profile-account',
    title: 'Player Profile and Account',
    summary: 'Identity, public profiles, avatar management, security and destructive account actions.',
    sections: [
      s('Your public player identity', { paragraphs: [
        'The professional player profile represents the career in rankings, tournaments and social views. Other managers can open a player from Rankings and inspect the public profile.',
      ]}),
      s('Player & Account page', { bullets: [
        'Shows the fixed player name, account email, competition world and country.',
        'Shows the current avatar and avatar-replacement workflow.',
        'Password changes use a verified password-reset email.',
        'Contains account restart and permanent player/account deletion controls in the Danger Zone.',
      ]}),
      s('Avatar replacement', { paragraphs: [
        'Avatar replacement uses a review workflow. The player can provide a reference photo and requested jersey colors. Reference photos are temporary and automatically cleaned up within the configured retention window. The prepared avatar is then approved or rejected before use.',
      ]}),
      s('Private messaging from profiles', { paragraphs: [
        'Another human player\'s profile can be used to start a private Manager Inbox conversation. Only the two participating managers can read that conversation.',
      ], links: [
        { label: 'Open Player & Account', href: '/game/player-account' },
        { label: 'Open Rankings', href: '/game/rankings' },
      ]}),
    ],
  },
  {
    id: 'skills',
    title: 'Skills and Starting Player Identity',
    summary: 'Technical skills, physical skills, readiness attributes and how preferred surface/style shape a new player.',
    sections: [
      s('Technical attributes', { table: {
        headers: ['Attribute', 'Meaning'],
        rows: [
          ['Serve', 'Power, placement and service reliability'], ['Forehand', 'Primary attacking groundstroke'],
          ['Backhand', 'Quality, control and stability'], ['Return', 'Neutralizing and attacking serve'],
          ['Volley', 'Net play and finishing'], ['Slice', 'Variation and low-ball control'],
          ['Drop Shot', 'Touch and short-court variation'], ['Lob', 'Height, depth and accuracy over an opponent'],
          ['Smash', 'Overhead timing, power and finishing'],
        ],
      }}),
      s('Physical attributes', { table: {
        headers: ['Attribute', 'Meaning'],
        rows: [['Fitness', 'General athletic readiness'], ['Stamina', 'Maintaining quality in long matches'], ['Recovery', 'Recovery between matches and sessions'], ['Movement', 'Court coverage, speed and balance']],
      }}),
      s('Readiness and mindset', { table: {
        headers: ['Attribute', 'Meaning'],
        rows: [['Morale', 'Motivation and emotional state'], ['Confidence', 'Belief shaped by form and results'], ['Sharpness', 'Competitive rhythm and match readiness'], ['Focus', 'Concentration and mental stability'], ['Fatigue', 'Accumulated tiredness; lower is better']],
      }}),
      s('Starting surface profiles', { paragraphs: [
        'Hard, Clay and Grass begin from different technical distributions, but all three base profiles total exactly 450 technical points. Surface choice creates identity rather than a free overall-strength advantage.',
      ], table: {
        headers: ['Skill', 'Hard', 'Clay', 'Grass'],
        rows: [
          ['Serve', '56', '48', '62'], ['Forehand', '58', '59', '52'], ['Backhand', '55', '57', '48'],
          ['Return', '57', '60', '46'], ['Volley', '46', '42', '57'], ['Slice', '45', '48', '54'],
          ['Drop Shot', '42', '47', '38'], ['Lob', '43', '51', '38'], ['Smash', '48', '38', '55'],
          ['Base total', '450', '450', '450'],
        ],
      }}),
      s('Playing hand and matchup geometry', { paragraphs: [
        'Right-handed and left-handed players use the same starting-strength budget. Handedness does not automatically make Forehand or Backhand stronger or weaker.',
        'Its value appears during matches: serve angles, cross-court patterns and the natural relationship between one player’s forehand and the opponent’s backhand change in same-handed and opposite-handed matchups. Handedness is public opponent information and should be considered when choosing tactics.',
      ]}),
      s('Playing-style redistribution', { bullets: [
        'Aggressive Baseliner shifts points toward serve and attacking groundstrokes.',
        'Defensive Baseliner shifts points toward return, backhand stability and absorbing pressure.',
        'Serve & Volley shifts points toward serve, volley, slice and forward-court play.',
        'All-court adds no style redistribution and lets the surface profile provide most of the identity.',
      ]}),
      s('Variation and development ceiling', { paragraphs: [
        'New human players receive small deterministic per-player variation and are normalized to roughly 440-455 starting technical points. High skills develop progressively more slowly than early-career skills.',
      ], links: [{ label: 'Open Skills', href: '/game/skills' }]}),
    ],
  },
  {
    id: 'regular-training',
    title: 'Regular Training',
    summary: 'How weekly regular training works, what blocks it and how development is distributed.',
    sections: [
      s('Home-day rule', { paragraphs: [
        'Regular Training is available only when the daily calendar state is Home and the player is medically cleared. Tournament, travel, Training Camp and medically blocked days take ownership of the date and regular training does not run.',
      ]}),
      s('Weekly planner', { paragraphs: [
        'The planner lets you save different choices for Home days. The automatic daily engine processes the saved plan when the game reaches that date. Calendar ownership always wins over a saved training plan.',
      ]}),
      s('Focus distribution', { paragraphs: [
        'Focused training gives the selected attribute the main development share while distributing the remainder inside the relevant category. The current regular-training model uses an 85% selected-focus / 15% remaining-category split.',
      ]}),
      s('Development curve', { table: {
        headers: ['Current skill range', 'Development multiplier'],
        rows: [['1-59', '100%'], ['60-69', '90%'], ['70-79', '75%'], ['80-89', '55%'], ['90-94', '35%'], ['95-99', '20%']],
      }}),
      s('Recovery and results', { bullets: [
        'Day Off prioritizes recovery rather than permanent development.',
        'Training sessions record development gains, level-ups and before/after condition values.',
        'A Training Camp booking is also shown on Regular Training; camp and camp-travel dates override the weekly plan automatically.',
      ], links: [{ label: 'Open Training', href: '/game/training' }]}),
    ],
  },
  {
    id: 'training-camps',
    title: 'Training Camps',
    summary: 'Booking, costs, development advantages, cancellation, travel transitions and completion rules.',
    sections: [
      s('What a Training Camp does', { paragraphs: [
        'A Training Camp is a paid, location-based development block. Camp development is stronger than ordinary training, while longer camps use diminishing returns so repeated weeks do not scale without limit.',
      ]}),
      s('Program price structure', { table: {
        headers: ['Camp type', 'Standard', 'Advanced', 'Elite'],
        rows: [['Recovery & Mindset', '$1,200/week', '$1,800/week', '$2,700/week'], ['Physical', '$1,400/week', '$2,100/week', '$3,200/week'], ['Tennis Skills', '$1,500/week', '$2,300/week', '$3,400/week']],
      }}),
      s('Quality and duration', { bullets: [
        'Quality development multipliers are Standard 1.00x, Advanced 1.15x and Elite 1.30x.',
        'Camps can run from one to four weeks.',
        'Tennis/physical development uses 100%, 95%, 85% and 75% week multipliers across weeks 1-4.',
        'A normal camp week contains six development days and one recovery day.',
      ]}),
      s('Accommodation', { table: {
        headers: ['Accommodation', 'Base weekly cost', 'Purpose'],
        rows: [['Budget 2-star', '$350', 'Lowest price'], ['Standard 3-star', '$560', 'Balanced default'], ['Comfort 4-star', '$840', 'Better recovery/comfort'], ['Premium 5-star', '$1,260', 'Highest comfort/recovery']],
      }}),
      s('Quote and payment', { paragraphs: [
        'The quote combines training fee, destination-adjusted accommodation, player travel and selected travelling-staff costs. Career Cash available is shown before booking. Insufficient funds reject the booking before any booking or finance transaction is committed.',
      ]}),
      s('Conflict and duplicate protection', { bullets: [
        'Overlapping Training Camps are blocked.',
        'Tournament applications and accepted entries overlapping the camp period are blocked.',
        'Committed calendar activity and medical restrictions are checked.',
        'Duplicate/double-click booking attempts are serialized.',
        'Booking, finance and calendar ownership are transactional.',
      ]}),
      s('Cancellation', { paragraphs: [
        'A future camp that has not started can be cancelled for a 100% Career Cash refund. Once the camp starts, normal pre-start cancellation is no longer available.',
      ]}),
      s('Camp travel and shortened camps', { paragraphs: [
        'Tournament-to-camp and camp-to-tournament transitions route through the player\'s home city. If only one transition day exists, first-half and second-half travel can share the same date. If the previous tournament consumes the normal pre-camp travel date, the first scheduled camp day becomes the split travel day, the original camp end date remains and one development day is lost.',
      ]}),
      s('Travel no-show', { paragraphs: [
        'If the player must use a split travel day after a camp and the next tournament schedules a match before the itinerary can make the player ready, the player misses the match by travel no-show and the opponent advances. No equipment wear is charged because no match was played.',
      ]}),
      s('Completion and monitoring', { paragraphs: [
        'Camp-day results are idempotent and cannot be developed twice. A camp moves Booked -> Active -> Completed. Health interruptions on the final date no longer leave the camp stuck. Camp lifecycle and transition travel are monitored in System Health.',
      ], links: [{ label: 'Open Training Camps', href: '/game/training' }]}),
    ],
  },
  {
    id: 'readiness-recovery',
    title: 'Fatigue, Sharpness, Form and Recovery',
    summary: 'How short-term condition interacts with training, travel and match performance.',
    sections: [
      s('Fatigue', { paragraphs: ['Fatigue is accumulated tiredness and is the main condition number where lower is better. Training load, matches and travel can add fatigue; rest, recovery, accommodation quality and relevant staff effects can reduce or mitigate it.']}),
      s('Sharpness', { paragraphs: ['Sharpness represents competitive rhythm and match readiness. It is not permanent skill: a highly skilled player can still be poorly prepared when sharpness is low or fatigue is high.']}),
      s('Morale, confidence and focus', { bullets: [
        'Morale is current motivation/emotional state.', 'Confidence is shaped by form and results.', 'Focus represents concentration and mental stability.',
      ]}),
      s('Form versus permanent skill', { paragraphs: ['Skills are long-term attributes. Readiness values are short-term state. Season-form statistics are result-based indicators. Do not treat one as a substitute for the others.']}),
      s('Practical recovery planning', { steps: [
        'Check Health and fatigue before hard training.', 'Allow travel days to remain travel days.', 'Use Day Off or recovery choices when fatigue is high.', 'When events are close together, travel class, hotel and staff may matter as much as one extra training day.',
      ], links: [{ label: 'Open Training', href: '/game/training' }, { label: 'Open Health', href: '/game/injuries' }]}),
    ],
  },
  {
    id: 'health',
    title: 'Injuries, Illness and Availability',
    summary: 'The Health Center, risk drivers, medical restrictions and return-to-play logic.',
    sections: [
      s('Health Center', { paragraphs: ['Injury & Health shows current medical status, injury risk, daily illness risk, treatment status, training return, tournament return, expected full recovery and current performance penalty.']}),
      s('Injury risk drivers', { paragraphs: ['Injury risk is activity-specific and rises with combinations of fatigue, workload, match duration, heat and reduced physical condition. The page exposes current risk drivers rather than making injury completely opaque.']}),
      s('Illness risk', { paragraphs: ['Illness is rolled separately from physical injury and can be influenced by fatigue, recovery condition, travel exposure and current recovery state.']}),
      s('Medical availability', { bullets: [
        'Training return and tournament return can occur on different dates.',
        'Calendar processing respects medical blocks.',
        'Training Camps reject booking periods that overlap known health restrictions.',
        'Medical-staff effects are shown on the Health page when relevant.',
      ]}),
      s('Career health record', { paragraphs: ['Recovered injuries and illnesses remain in the career health record. The page also contains reference information for supported injuries, illness windows and treatment/rehabilitation levels.'], links: [{ label: 'Open Injury & Health', href: '/game/injuries' }]}),
    ],
  },
  {
    id: 'staff',
    title: 'Staff and Staff Market',
    summary: 'Hiring, contracts, effects, salaries, negotiation and termination.',
    sections: [
      s('Available staff roles', { table: {
        headers: ['Role', 'Primary contribution'],
        rows: [
          ['Head Coach', 'Technical development, tactics and match preparation'],
          ['Fitness Coach', 'Physical development, conditioning and workload control'],
          ['Physiotherapist', 'Fatigue recovery, injury prevention and rehabilitation'],
          ['Sports Psychologist', 'Morale, confidence, focus and pressure management'],
          ['Performance Analyst', 'Opponent scouting ranges, preparation confidence, handedness-aware observations and tactical recommendations'],
          ['Career Manager', 'Sponsorship, commercial representation and career management'],
        ],
      }}),
      s('Role and quality rules', { paragraphs: [
        'One active person fills each role. A new career starts with no staff. Candidates are grouped into Developing, Professional, Advanced, Elite and World Class quality levels.',
      ]}),
      s('Negotiation flow', { steps: [
        'Filter Staff Market by role, quality, country and salary.',
        'Open a candidate and choose contract length plus salary offer.',
        'Review acceptance chance, signing fee and full contract commitment.',
        'An accepted offer still requires final confirmation before the staff member is hired.',
        'Career Cash must cover the signing fee, and some candidates will not negotiate at insufficient sporting reputation.',
      ]}),
      s('Termination and travel', { paragraphs: [
        'Active contracts show unpaid weeks, remaining salary value, settlement rate and termination fee. Selected staff can travel to tournaments or Training Camps; travelling staff add cost, and effects that require presence apply only when that staff member travels.',
        'A Performance Analyst is an information role rather than a hidden direct-strength boost. Better analysts narrow estimated skill ranges. When the next opponent is known, preparation progresses from quick to partial, normal and full analysis over game time, reaching the full preparation stage after 24 game-hours.',
      ], links: [{ label: 'Open Staff', href: '/game/staff' }]}),
    ],
  },
  {
    id: 'calendar',
    title: 'Calendar and Competition Planning',
    summary: 'How the player calendar and tournament calendar interact.',
    sections: [
      s('Two calendar views', { paragraphs: ['Calendar combines the player\'s synchronized activity calendar with the wider Tournament Calendar. The player view shows date ownership; the tournament view is for browsing competition opportunities.']}),
      s('Player-calendar activity types', { bullets: ['Tournament', 'Travel', 'Training Camp', 'National Team', 'Health / Recovery', 'Home']}),
      s('Calendar ownership', { paragraphs: ['A date cannot be treated as Home training time when another system owns it. Tournament, travel, camp, national-team or medical activity takes priority over saved regular training.']}),
      s('Tournament browsing', { paragraphs: ['Tournament cards show date, location, category, surface, draw/points information and entry status. Sponsor objectives can also identify commercially important events.']}),
      s('Automatic travel', { paragraphs: ['Accepted commitments and saved preparation feed the shared travel engine. Travel dates then appear in the player calendar. Training Camp transitions can create two half-day travel legs on one date when timing is tight.'], links: [{ label: 'Open Calendar', href: '/game/calendar' }]}),
    ],
  },
]
