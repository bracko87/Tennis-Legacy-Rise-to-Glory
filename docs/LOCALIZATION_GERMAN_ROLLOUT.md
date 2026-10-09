# German localization rollout

English remains the source language. German uses `de-DE` locale formatting and falls back to English only when a German key is genuinely unavailable during development.

## Production scope completed

- Public homepage and marketing header
- Login, password recovery and player creation
- Referral landing and public review submission
- Navigation, header, footer and settings
- Overview, Skills and Training
- Training Camps
- Staff and Staff Market
- Calendar and Tournament Calendar
- Schedule and Tournament Preparation
- Tournament pages, match details and doubles
- Doubles partner marketplace and doubles match tactics
- Rankings and player profiles
- Equipment, inventory/marketplace and technical sponsors
- Finance and financial sponsors
- Injury & Health
- Statistics
- National Team / National Association
- Private Life
- Tennis Club
- Notifications and backend notification templates
- Player & Account, including avatar replacement workflow
- Premium & Billing
- Manager Inbox and Invite Friends
- Help Center, Forum / Discord and Contact
- Full Game Manual
- Complete first-login tutorial

## QA results

- English source leaves: 5,126
- German leaves: 5,126
- Missing German keys: 0
- Extra German keys: 0
- Dynamic placeholder mismatches: 0
- Active routed player-facing pages audited for obvious hardcoded English leakage
- German number/date/currency formatting uses `de-DE`
- Production build passed after the final localization changes

## German terminology baseline

- Ranking: Rangliste / Weltrang
- Ranking points: Ranglistenpunkte
- Tournament: Turnier
- Qualification: Qualifikation
- Main draw: Hauptfeld
- Round: Runde
- Training: Training
- Training Camp: Trainingscamp
- Staff: Team / Betreuerteam (context dependent)
- Sponsor: Sponsor
- Technical Sponsor: Technischer Sponsor
- Equipment: Ausrüstung
- Inventory: Inventar
- Prize money: Preisgeld
- Coins: Coins
- Contract: Vertrag
- Fatigue: Ermüdung
- Freshness: Frische
- Recovery: Erholung
- Injury: Verletzung
- Private Life: Privatleben
- Premium: Premium

Proper player, tournament, sponsor and fictional brand names remain unchanged.
