# Tennis Legacy — Private Life ↔ career integration

**Branch:** `main` (source-only development; Netlify builds remain stopped). **Status:** source committed and GitHub build validated; database migrations **not applied to production**. Isolated DB integration tests and browser QA remain required. **Date:** 2026-10-26.

## Release readiness — current handoff (updated 2026-10-26)

- **Source and UI:** Committed to GitHub `main`. Aircraft marketplace previews, Schedule jet picker, morale/Home Base panels, profile and travel preferences are implemented. Live-connected UI explicitly warns when the feature database functions are absent.
- **Function-level integration:** Disposable PostgreSQL tests pass actual morale/relocation functions, direct-jet booking, six-person staff party charges, automatic commercial fallback, fatigue and financial idempotency, and cross-account jet ownership protection. The current application build and translation checks also pass.
- **Live-schema compatibility check (read only):** Verified that 21 existing tables referenced by the Private Life migrations exist in production, and the external public-function dependencies identified in those migrations were present. This is a prerequisite audit, **not** proof the three migrations execute successfully together.
- **Local full database blocker:** The repository's 591 historical migrations fail before the Private Life migrations because an early staff table is absent from the empty database. Do not edit already-deployed historical migrations in production to mask this.
- **New no-cost testing path:** [Schema-only local sandbox instructions](PRIVATE_LIFE_SCHEMA_ONLY_LOCAL_SANDBOX.md) and `scripts/prepare-private-life-sandbox.mjs`. The generator and its data-leak safeguards pass GitHub unit tests; it uses the existing schema from a **read-only** dump and applies just three new migrations in local Docker. **The complete full-schema restoration has not been performed yet.** Local player registration, premium ownership, seeded tournaments and browser gameplay are not certified.
- **Release:** No production migrations, Netlify deploy or paid Supabase branch has been authorized or performed. **Do not close the full feature ticket or claim the live UI is working** until the integrated database and authenticated browser scenarios pass, followed by an explicitly approved release.

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
- The fixture now verifies that changing the global travel mode causes an immediate rebuild of unfinished player itineraries; the migration uses the existing plan builder.
- `tests/private_life_ephemeral_jet_fixture.sql` and `tests/private_life_ephemeral_jet_assertions.sql`: create synthetic owned aircraft and execute **the unchanged aircraft purchase-positioning and jet quote functions extracted directly from the second migration**. Validate jet/non-jet eligibility, maximum range, operating costs, staff capacity/overflow, fatigue cap, aircraft repositioning, and planned-flight positioning.
- `scripts/extract-private-life-jet-routines.py`: extracts exactly those two business routines for execution. The entire second migration is **not** applied in this isolated fixture.
- The workflow does not exercise every production table/RLS combination, the full scheduler, private-jet debit path, multiplayer permissions, Netlify frontend or the production Supabase environment. This runtime harness is valuable but is **not a substitute for a full isolated Supabase integration test**.

Latest passing runtime + source CI: https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40310906699

## Screenshot-approved tournament aircraft (2026-10-26)

The owner selected exactly nine model names shown in the Private Airplanes marketplace; see [the approved transport specification](PRIVATE_JET_TRANSPORT_POLICY_20261026.md). All other cataloged airplanes remain lifestyle-only. The nine models use explicit game-balance range, staff seats (minimum seven), one total aircraft operating fare per flight, model-based 24–50% fatigue reduction and faster estimated private-flight duration.

When a player travels with selected staff, the aircraft carries the entire party or is unavailable: there are **no supplementary staff airfares**. Moving an aircraft to the departure city can add a repositioning flight charge, but this is one aircraft charge, not one ticket per staff member. The existing 90% automatic ownership bonus remains disabled.

Server-side preview RPC \`quote_my_private_life_jet_v1\` recalculates actual selected aircraft one-way flight costs and repositioning; the UI now shows the total charge including all staff, its expected hours and whether the flight is an **overnight-transfer candidate** (10 hours or less). A flight-time candidate is *not* a guarantee that the Sunday final / Monday first-round schedule fits: exact match times and time-zone deadlines still require separate scheduling integration.

Disposable PostgreSQL regression tests execute the nine-model catalog allowlist, the authenticated group quote function, full-team seating, prices, fatigue and range; those tests do not represent complete Supabase schema execution. Production database changes and Netlify deployments remain blocked pending explicit approval.

## Owner decision — simpler direct-flight rule (2026-10-26)

The owner rejected the proposed refuelling-stop system. It has been **removed from source**: no new airport-network table, route-finding SQL migration, multi-stop booking logic, refuelling UI or multi-stop test fixtures remain on the current `main` branch.

Only the nine screenshot-approved private jets remain eligible for tournament transport, and only when the flight is directly within the selected aircraft's range and the whole player/staff party fits. If an otherwise owned eligible jet cannot fly directly (range, staff seats or aircraft repositioning restriction), the **server and UI select normal commercial travel** instead of an error or an invented intermediate landing. The player/staff pay the usual airline fares and receive standard commercial travel fatigue; jet operational costs and discounts apply only to actual direct jet travel.

Disposable PostgreSQL regression tests exercise both an allowed direct flight and the Belgrade-to-Australia fallback. No Netlify deployment or production Supabase schema changes have been authorized.

## Full travel-day settlement and ownership checks (2026-10-26)

The automated GitHub Actions disposable PostgreSQL job now executes the **actual migration versions** of \`insert_planned_travel_leg_v1\` and \`process_travel_leg_v1\`, using synthetic players and an approved Citation M3 from the nine-aircraft catalog. It verifies:

- Booking a direct 1,600 km Citation M3 leg with **six accompanying staff members**, charging exactly one **$10,200** aircraft fare (including all staff), without additional air tickets.
- Arrival processing adds **13 fatigue** to the synthetic player after the aircraft-specific reduction, updates the player's destination and aircraft location, posts precisely one travel ledger transaction, and returns \`already_processed\` without a second debit on retry.
- Travelling onward commercially from Paris to Sydney charges the player and six staff **$3,500** in synthetic ticket fares, adds **17 normal travel fatigue**, updates the player's location to Sydney, and leaves the owned jet in Paris. It also remains idempotent.
- The test deliberately uses a **whitelisted Citation M3**, not the old synthetic test jet that the whitelist correctly marks ineligible. No legacy/hobby model was whitelisted to make the test pass.
- A second synthetic account with an entered tournament cannot quote or book the first player's aircraft through the actual authenticated \`quote_my_private_life_jet_v1\` and \`set_private_life_tournament_travel_v1\` RPCs. Denied attempts leave the legitimate player's selection unchanged.

**Verified GitHub source/build + disposable PostgreSQL run:** https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40325930372

These are genuine function executions, but they **do not prove** the complete migrations work against the full production schema, real Supabase Auth/RLS role behavior, all tournament transitions, browser interactions, or actual payment provider integration. All production release gates remain.

## Localhost readiness audit (2026-10-26)

- The feature source is already on `main`; there is no active staging-to-main promotion.
- `scripts/build.mjs` and `src/lib/supabase.ts` now accept an explicit `TL_SUPABASE_URL` plus `TL_SUPABASE_PUBLISHABLE_KEY` pair for localhost test builds. The local UI uses `http://localhost:8000`; release builds **reject** the test overrides. A frontend started without overrides warns that its existing Supabase connection is live and cannot validate this unreleased feature.
- `supabase/config.toml` defines a separate local Docker stack (Postgres 17; API 54321; database 54322). [Local testing steps](LOCAL_PRIVATE_LIFE_TESTING.md) are in the repo.
- Source build and isolated synthetic business-function tests **pass**, including jet/commercial actual travel charges, fatigue changes, state changes, idempotent processing and cross-player asset denial. Local backend substitution was compiled and verified in [GitHub CI run 40328681070](https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40328681070).
- A new isolated **full Supabase CLI stack** CI check attempted the entire 591-migration history. It **failed at historical migration `20260903081216_remove_staff_ranking_requirements.sql`**, because `public.staff_members` is missing from a fresh database. The private-life migrations have not been applied by the full-stack check. [GitHub failure evidence](https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40328987767).
- Thus **complete local gameplay is NOT yet certified**. Fix the pre-existing historical baseline, or obtain explicit approval to create an isolated Supabase development branch based on the existing project. The October 26 quote was **$0.01344/hour**, with possible additional provider usage charges. No billable branch created.
- Do not modify already-applied production migrations or push unreleased Private Life schema changes to live Supabase to bypass the local bootstrap failure.

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

The active development branch is **\`main\` only**; \`staging\` is an inactive historical backup. GitHub commits are **not production releases**, and Netlify builds must remain stopped. Do **not** deploy Supabase migrations, resume Netlify builds, or perform live Stripe/payment changes until the owner explicitly approves a coordinated release after full isolated-environment QA. Do not claim deployment before production verification.

## Balancing parameters to tune with economy data

- Morale: maximum +3, 14-day category cooldown, -1 point per 7 days per purchase
- Relocation: 2-game-day move, 30-day cooldown, $5,000 + travel
- Jets: nine approved models with direct-flight range (3,000–13,500 km), passenger capacity and travel fatigue savings (24–50%), operating cost (fixed + distance + handling + repositioning)
- Avoid pay-to-win: no direct skill boost; evaluate whether even a +3 temporary morale and 50% travel-specific fatigue reduction are sufficiently small before release
