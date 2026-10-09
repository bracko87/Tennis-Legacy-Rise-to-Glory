# Serbian localization rollout

English remains the source language. Serbian uses Latin script (`sr-Latn-RS`) and falls back to English only when a Serbian key is genuinely unavailable during development.

## Already localized / wired

- Public home and marketing surfaces
- Login / registration / player creation
- Main navigation, header and footer
- Game Preferences language selector and account persistence
- Notifications, including backend notification template rendering
- Help Center, Forum / Discord and Contact
- Full Game Manual (Serbian edition)
- Complete first-login tutorial
- Overview
- Skills
- Training
- Training Camps
- Staff
- Staff Market
- Rankings
- Premium & Billing
- Manager Inbox
- Invite Friends / referral program

## Core gameplay still to migrate from hardcoded English

- Calendar
- Tournament Calendar
- Schedule / Tournament Preparation
- Tournament pages / match modals / doubles
- Equipment
- Gear Room / Inventory / Marketplace
- Technical Sponsors
- Finance
- Financial Sponsors
- Injury & Health
- Statistics
- Player Profile
- National Team / National Association
- Private Life
- Tennis Club

## System / dynamic text review

- Notification templates: localized through notification code + payload, English fallback retained
- Tutorial: Serbian resource complete
- Game Manual: Serbian content complete
- Referral dynamic statuses: localized
- Remaining backend-generated sponsor, training, equipment, staff, private-life and tournament text must be converted from stored prose to stable codes/translation keys where applicable.

## Serbian terminology baseline

- Ranking: Rang-lista / plasman (context dependent)
- Ranking points: Poeni za rang-listu
- Tournament: Turnir
- Qualification: Kvalifikacije
- Main draw: Glavni žreb
- Round: Kolo
- Training: Trening
- Training Camp: Trening kamp
- Staff: Stručni tim
- Sponsor: Sponzor
- Technical Sponsor: Tehnički sponzor
- Equipment: Oprema
- Inventory: Inventar
- Prize money: Nagradni fond / nagradni novac (context dependent)
- Coins: Coini
- Contract: Ugovor
- Fatigue: Umor
- Freshness: Svežina
- Recovery: Oporavak
- Injury: Povreda
- Private Life: Privatni život
- Premium: Premium

## QA before Serbian is marked production-ready

1. No raw translation keys.
2. No unexpected English leakage on player-facing pages.
3. Serbian plural forms checked for 1, 2, 5, 11 and 21.
4. Dates/numbers/currency use `sr-Latn-RS`.
5. Dynamic variables preserve Serbian grammar and order.
6. Desktop and mobile layouts checked for overflow/truncation.
7. Backend notifications and dynamic descriptions checked against the Serbian UI.
8. Player, tournament, sponsor and fictional brand proper names remain unchanged.
