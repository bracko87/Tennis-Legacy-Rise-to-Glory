# Tennis Legacy — Private Life ↔ career integration

**Branch:** `main` (source-only development; Netlify builds remain stopped). **Status:** source committed and GitHub build validated; database migrations **not applied to production**. Isolated DB integration tests and browser QA remain required. **Date:** 2026-10-26.

## Design rules

1. Nationality/passport/national-team eligibility continue to use immutable \`players.country_code\`. The original \`players.home_city\` is retained. A chosen residential asset is stored separately as Home Base in \`player_lifestyle_state\`. Actual whereabouts remain in \`player_location_state\`.
2. Travel planning starts from actual current location, chains directly between commitments when appropriate, and returns to the chosen Home Base (not the nationality country). Training camp quotes already use \`resolve_player_origin_before_day_v1\` and therefore inherit the residence fallback. Completed travel legs and past charges are never rebuilt.
3. Purchase triggers give temporary morale +1 to +3, with a combined +3 cap; one point wears off every 7 game days and new purchases in the same category are blocked from generating further morale for 14 game days. This does not increase serve, recovery skill, fitness or other tennis attributes.
4. Relocation only to an owned apartment/house/villa, when at home, with no immediate booked departure. Pending moves complete after 2 game days; a 30-game-day relocation cooldown applies. Relocation costs $5,000 plus the one-way travel engine fare. An active/pending residence may not be sold/listed before choosing another home.
5. Private aircraft retain their original asset prices and monthly maintenance. Propeller/turboprop hobby planes remain lifestyle-only. Eligible jets have per-model/tier max range, seat capacity, fixed cost, per-km operating cost, capped travel-fatigue reduction (22–50%) and repositioning. An out-of-range jet never flies the route; commercial remains available. No free 90% fatigue benefit for mere jet ownership.
6. Flight choice is booked per entered tournament or chosen through Preferences (Ask every time, Commercial, Cheapest, Best owned jet). Tournament planning previews and planned travel legs use those choices. Player plus selected staff count against seats; staff in the jet are not charged separate commercial fares, overflow staff are charged for their own commercial tickets. Sold jets fall back to commercial flights and full staff fares. Flight finance uses the existing career transaction idempotency key keyed to travel leg.
7. Preview prices and ranges are gameplay approximations, not real aircraft safety/performance specifications. Refueling stops are not simulated; routes beyond range use commercial alternatives. The game does not automatically relocate an aircraft for free; it calculates a repositioning fee subject to range.
8. Existing Premium access restrictions for Private Life remain unchanged.

## Files

Database, in migration order:
- \`20261026093000_private_life_career_foundation_v1.sql\`
- \`20261026094500_private_life_jet_travel_integration_v1.sql\`
- \`20261026095500_private_life_profile_residence_v1.sql\`

Frontend:
- \`src/components/private-life/LifestyleCareerPanel.tsx\` — career facts and preferences
- \`src/components/private-life/TournamentJetPicker.tsx\` — private-vs-commercial booking
- \`src/components/private-life/CareerLocationPreview.tsx\` — compact Overview
- \`src/components/private-life/TravelPreferenceSettings.tsx\` — Preferences
- \`src/lib/lifestyleCareerI18n.ts\` — EN/SR/DE/ES/FR/IT/RU/PT copy
- Updated \`PrivateLife.tsx\`, \`Schedule.tsx\`, \`Overview.tsx\`, \`PlayerProfile.tsx\`, \`GamePreferences.tsx\`
- \`src/styles/private-life-career.css\`

## Validation update — 2026-10-26

- Repository instructions confirmed: `main` is the active source-development branch; `staging` is an inactive backup. Netlify builds remain stopped.
- A newly added CI test parses all three migration files and the DB smoke SQL using PostgreSQL's grammar and parses PL/pgSQL function bodies using pinned `pglast==8.7`.
- CI exposed malformed dollar quoting in `lifestyle_prevent_home_listing_v1`; the source was corrected. **Latest successful parse:** 76 PostgreSQL statements and 19 PL/pgSQL routine bodies.
- Six Private Life source-contract tests pass, including Premium-only private-jet controls and accurate jet/staff labels in the tournament summary.
- Production-mode website build, translation audits, SEO and CPX integration pass in GitHub Actions.
- Read-only production query verified that `player_lifestyle_state`, `set_private_life_home_base_v1` and `player_travel_legs.jet_asset_id` are not present: **the Private Life schema has not been deployed**.
- Parsing proves **syntax only**. It does not validate referenced relations/columns at function runtime, game transactions, RLS, migration execution order, cron execution, or browser behavior.
- Isolated DB integration QA is still a hard release gate. Supabase development branching incurs extra compute charges and needs user confirmation before creation. Do not apply migration DDL to the live project as a substitute.

Latest successful CI:
https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40305723957

### Additional code audit (2026-10-26)

- Server-side booking now checks that the **specific selected jet** can fly the entered tournament route and be repositioned within its range. An impossible flight raises an error instead of silently saving a jet selection.
- Aircraft position is recorded at purchase; an additive backfill initializes existing owned jets from the player's recorded location. Moving Home Base does not teleport the aircraft or waive repositioning costs.
- Tournament booking previews now read the saved hotel, travel-class and staff selections, and compute commercial prices separately even when a jet is selected. Staff tickets are not mistaken for jet fares.
- A new contract test covers server flight eligibility and persistent aircraft position.
- **Important limitation:** Source CI verifies SQL and PL/pgSQL grammar, not actual execution against the Supabase schema or end-to-end gameplay. Isolated database validation remains mandatory.

## Disposable PostgreSQL runtime integration — 2026-10-26

In addition to static grammar and React build validation, the consolidated GitHub Actions pipeline now starts a temporary **PostgreSQL 16 container**. This consumes standard public-repository GitHub CI resources and does **not** connect to production or require a billable Supabase branch.

- `tests/private_life_ephemeral_fixture.sql`: creates synthetic players, clock, locations, asset catalog and stubbed dependencies.
- `tests/private_life_ephemeral_assertions.sql`: applies the **actual first migration** and exercises purchase-based morale boosts, maximum +3, category purchase cooldown, expiry after game days, owned-residence relocation, two-game-day settlement, fee idempotency, nationality preservation, active-home sale protection, relocation cooldown and future travel-plan rebuilding on preference changes.
- `tests/private_life_ephemeral_jet_fixture.sql` and `tests/private_life_ephemeral_jet_assertions.sql`: create synthetic owned aircraft and execute **the unchanged aircraft purchase-positioning and jet quote functions extracted directly from the second migration**. Validate jet/non-jet eligibility, maximum range, operating costs, staff capacity/overflow, fatigue cap, aircraft repositioning, and planned-flight positioning.
- `scripts/extract-private-life-jet-routines.py`: extracts exactly those two business routines for execution. The entire second migration is **not** applied in this isolated fixture.
- The workflow does not exercise every production table/RLS combination, the full scheduler, private-jet debit path, multiplayer permissions, Netlify frontend or the production Supabase environment. This runtime harness is valuable but is **not a substitute for a full isolated Supabase integration test**.

Runtime integration CI: https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40310128704

## Database verification on an isolated non-production database

Supabase Branching requires separate compute charges and cost approval. Do not run these DDL migrations against production as a substitute for a development database. Once an isolated test database is available:

1. Apply all three migrations in order. Ensure function replacements preserve existing grants and don't regress established travel jobs.
2. Run \`tests/private_life_career_db_smoke.sql\` in the **development** database.
3. Execute a real test-player flow in a development world: buy watch + car + villa; check morale bonus cap, category cooldown and game-day decay; buy property in another country; schedule home move; verify current location/home/nationality separated; verify a sale listing of current home is rejected.
4. Enter consecutive tournaments in three countries. Test actual location → next tournament, direct transition, return home, and completed-leg immutability. Repeat with a training camp.
5. Purchase prop plane and jet. Ensure plane cannot book travel; jet with insufficient range offers commercial only; test both light and long-range jets, repositioning fees, selected staff counts 0/6, seat overflow, outbound/return fare and fatigue. Selling a jet before departure must fall back to commercial without keeping a jet fatigue perk.
6. Retry \`process_travel_leg_v1\` for the same leg to verify no duplicate charges; process an interrupted schedule rebuild; check original country/flag/national-team eligibility; check no injection of permanent skill points.
7. Confirm Premium/non-Premium permissions, denied access to other players' assets, and all eight-language UI displays.

## Frontend/build checks

From repository root on main:
- \`node --test tests/lifestyleCareerContract.test.mjs\`
- \`npm ci\`
- \`npm run check:pt\`
- \`npm run check:preferences\`
- \`npm run build\`

Check desktop/mobile Private Life Assets and Marketplace, residence selection and pending move, Overview, public player profile, Preferences, Schedule tournament preparation. Check loading, empty account, insufficient funds, repeated booking and error states.

## Release constraints

Do **not** push to \`main\` or change the production Supabase schema until isolated QA passes. Release in the established manually approved staging → main window with coordinated frontend and Supabase migrations. Existing unrelated staging commits must remain included. Do not claim deployed before the production release is actually verified.

## Balancing parameters to tune with economy data

- Morale: maximum +3, 14-day category cooldown, -1 point per 7 days per purchase
- Relocation: 2-game-day move, 30-day cooldown, $5,000 + travel
- Jets: tier-based range (2,600–12,500 km), passenger capacity and travel fatigue savings (22–50%), operating cost (fixed + distance + handling + repositioning)
- Avoid pay-to-win: no direct skill boost; evaluate whether even a +3 temporary morale and 50% travel-specific fatigue reduction are sufficiently small before release
