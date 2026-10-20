# Tennis Legacy — Free/Premium controlled rollout

**Branch:** staging. **Latest reviewed:** 2026-10-20.
Develop in small, independently reviewable increments; no production main merge without approval.

## Master Premium feature tracker (2026-10-20)

**Status legend:** Implemented in staging = feature code exists (not necessarily browser/production QA complete); Proposed = not built; Review pending = requires visual, paid/trial and/or build checks.
**Production main:** unchanged by this tracker. All normal core gameplay and existing official statistics remain Free.

### Existing Premium benefits and commerce

| Feature | Where players find it | Access/Free visibility | Status and outstanding work |
| --- | --- | --- | --- |
| Private Life (assets, property, investments, marketplace and prestige) | Sidebar → Private Life | Free: menu and lock/upgrade page; paid/trial: module | Implemented; production gameplay QA remains separate |
| Ranking Protection (upcoming singles/doubles points expiry) | Overview and Rankings | Free: locked preview; paid/trial: expandable protection data | Implemented; verify actual expiring records |
| Statistics Intelligence (completed-match leaderboard comparison) | Statistics → near top, after filters | Free: visible locked panel; paid/trial: match win %, aces/match, winners/match | **Implemented in staging + Premium RPC deployed**; build, 8-language visual review and end-to-end paid/Free QA pending |
| 7-real-day Premium trial | First eligible game entry, Premium welcome/expiry popups | Auto offered once to eligible players; no payment card | Implemented; full browser lifecycle QA pending |
| Premium subscriptions (1/3/12-month choices) | Pro Packages | Visible to Free and Premium | Checkout and entitlements coded; real purchase/renewal/refund checks not yet confirmed |
| Paid Premium Coins reward | Pro Packages / wallet history | Paid subscribers only; trials do not receive invoice Coins | 30 monthly / 90 quarterly / 360 annually in code; payment fulfillment verification pending |

### Premium development backlog — implemented Deep Match Analysis plus remaining proposals

| Priority | Module | Proposed location | Description | Status |
| --- | --- | --- | --- | --- |
| 1 (staged) | **Deep Match Analysis** | Completed match → Match Details → below Match Statistics | Side-by-side match stats, serve/break/shot/point rates, set summary, evidence-based post-match insights | **Implemented in staging**, backend access tests passed; browser/build QA pending |
| 2 (staged) | **Player Development Intelligence — Skill History** | Skills → Player Development Intelligence | Individual attribute timelines and observed progression by technical, physical and condition skill groups | **Implemented on staging; database migration deployed and paid/Free/ownership RPC checks passed; build/UI QA pending** |
| — | Opponent Scouting Intelligence | Staff → Performance Analyst (Free gameplay, **not Premium**) | Scouting and tactical estimates require a hired analyst, with accuracy/preparation depending on staff quality and time | **Removed from Premium backlog; existing Free staff system remains** |
| 4 | Tournament Planning Intelligence | Calendar / tournament page | Compare eligibility, timing, expected prizes/points and schedule conflicts | Proposed |
| 5 | Season Planning Center | Calendar / dedicated planning view | Long-term schedule and ranking point scenarios | Proposed |
| 6 (staged) | Training Effectiveness / Training Optimization Reports | Skills → below Player Development Intelligence | Real recorded fractional gains, level-ups, efficiency, camp vs regular training, and game-week trends; advanced optimization not yet built | **Training Effectiveness slice implemented on staging; Premium RPC deployed and backend ownership/access/data checks passed; browser/build QA pending** |
| 7 | Staff Advisory Reports | Staff | Compare contract cost, effectiveness and supported contributions | Proposed |
| 8 | Sponsor Intelligence | Finance / Sponsors | Contract value, obligations and actual benefits | Proposed |
| 9 | Financial Intelligence | Finance | Budget forecasts and scenario comparison | Proposed |
| 10 | Equipment Intelligence | Equipment | Performance and equipment condition comparisons | Proposed |
| 11 | Career Intelligence | Statistics / career | Multi-season career patterns and advanced milestones | Proposed |
| 12 | Premium Convenience Tools | Premium tools / Overview | Saved comparisons, custom dashboard reports and optional advanced alerts | Proposed |

No paid report should claim unrecorded causes or hidden skills, and no Premium feature should change the match engine, core gameplay or ranking payouts. For every future module: show Free members a clear explanation and lock, serve Premium results only after server-side entitlement checks, and translate to all supported languages.

### Premium Player Development Intelligence — Slice 2: Training Effectiveness (2026-10-20)

**Status: implemented in staging, not released to main.** The new read-only Premium endpoint is in `supabase/migrations/20261020150500_premium_training_effectiveness_v1.sql`; UI in `src/components/premium/PremiumTrainingEffectiveness.tsx`, mounted on the existing Free Skills page beneath Player Development Intelligence. The read-only Premium reporting RPC was **applied to the connected shared Supabase backend** after a transaction-rollback dry run. It changes no historical training data and is not a production frontend release. The UI remains on staging.

- Includes only actual completed development sessions from `player_training_sessions` (session_role=`planned_training`) and `player_training_camp_days` (day_role=`development`). Rest, recovery and day-off sessions do not distort the improvement totals.
- Displays recent 120 sessions and warns if earlier sessions are omitted. The total session count is returned separately. Reports recent sessions, average recorded efficiency multiplier, per-skill fractional gains, recorded whole-level increases, 12 newest game-week aggregates, and latest 10 session details. Uses actual game season/week data, never real timestamps.
- These are *recorded session development estimates* (not guaranteed exact credited progress after staff multipliers and skill slowdowns), not predictions or an attribution model. Confirmed whole-point level-ups are reported separately. The sum of fractional progress across different skills is **not** the player's total skill rating. Does not change Free training, gains, fatigue, career outcomes, or the match engine.
- Premium/trial + owning player only, enforced server-side by `has_active_premium_v1()` and `players.owner_user_id=auth.uid()`; anonymous and unentitled roles have no function execute privilege. Locked preview for Free; translations provided for EN, SR, DE, ES, IT, FR, RU, PT.
- **Backend checks passed (2026-10-20):** safe migration dry run; paid/trial-eligible owner report returned expected counts and consistent level-ups/fractional totals, game-week bounds verified, cross-owner and simulated Free/anonymous identities rejected; anon EXECUTE revoked. Repeatable regression `tests/premium_training_effectiveness_db_smoke.sql` executed successfully with transaction rollback. **Outstanding release gates:** paid/trial/Free browser checks, TypeScript checks `npm run check:pt`, `npm run check:preferences`, `npm run build`, all eight languages and mobile visual QA. Do not merge to `main` without validation and manual release approval.

### Scouting roadmap correction (2026-10-20)

**Opponent Scouting Intelligence is NOT a Premium module.** Existing Free gameplay already requires an active Performance Analyst for detailed opponent scouting. Staff quality determines estimated accuracy, and preparation time determines report completeness. Public opponent identity/recent results stay Free. No Premium entitlement should be required to use the Performance Analyst. Remove scouting from Premium offers and future paid report plans.

### Premium module 5 — Player Development Intelligence, Slice 1

**User authorized implementation:** 2026-10-20.
**Location:** /game/skills → below normal Skills workspace, immediately before the existing free Performance Centre.
**Frontend:** src/components/premium/PlayerDevelopmentIntelligence.tsx, src/styles/player-development-intelligence.css.
**Backend migration:** supabase/migrations/20261020114500_premium_player_development_intelligence_v1.sql.
**Source:** the existing player_skill_history snapshots recorded by the player_skills trigger. The existing free attribute cards, development matrix and free history chart remain intact.

- Premium / 7-day trial: server-entitled report for **owned player only**. Technical, physical and condition groups, selected individual-attribute history chart, earliest/latest values and point changes within the displayed period. Show strongest and smallest recorded changes without implying training causation.
- Free: explanatory locked preview with Pro Packages link, while original skill attributes and existing free history remain available.
- Response returns the latest 240 chronological snapshots; the UI explicitly states when this is a truncated history window. No full-career claims on a cropped timeline.
- No gameplay advantage, development bonus, unrecorded skill prediction or inferred coach attribution.
- Translated in EN, SR, DE, ES, IT, FR, RU, PT.
- **Status:** frontend, migration and translations committed to staging. **Supabase migration successfully applied on 2026-10-20.** An active Premium identity returned 49 owned skill snapshots; non-Premium and other-player requests correctly returned SQLSTATE 42501. Browser rendering and frontend build remain to be confirmed.
- **Release gate:** migration applied; authenticated-only grant and anonymous execute denial confirmed; paid owned-player, Free denied and other-player denied confirmed. Still check trial login, zero/one-snapshot handling, frontend build and responsive 8-language views.

**Next slices, NOT implemented:** deeper Training Effectiveness based on completed session gains; evidence-based Development Outlook when enough longitudinal data exists. No forecasts until reliable trend checks and historical coverage are validated.

### Skill history timeline / game-date correction (2026-10-20)

- **User screenshots:** Skills and Premium charts were showing real-world Sep/Oct 2026 dates, and Free Development History showed every change as a dot. These are now corrected to use **in-game Season / Week** and at most one representative (last-recorded) snapshot per game week.
- **Historical provenance:** `20261020131500_skill_history_game_week_metadata_v1.sql` adds nullable game_season/game_week to `player_skill_history`, captures the in-game clock on **future** insert, and backfills legacy records only when an exact same-player training session is within ±15 seconds and already contains an authoritative season/month/day. Never reconstruct a past game week from today's game speed or real-world date.
- **Display:** `src/lib/skillGameWeeks.ts` groups by (season,week) and retains the last snapshot. Both `Skills.tsx` and `PlayerDevelopmentIntelligence.tsx` use it for weekly charts, season/week endpoints and no calendar dates. Undated old records remain stored and are explicitly omitted from dated charts, with a visible notice.
- **Production example audit:** matching 105-snapshot player had only **one distinct technical/physical skill profile** while condition changed 100 times. The records include **38 processed training days, 31 day_off and 7 active sessions**, with fractional development but no `level_ups`: Fitness +0.665, Serve +0.288, Forehand +0.216 and Stamina +0.366 across the active sessions. **No whole-point gain was recorded.** The previous Free sidebar "Recorded development: 104" was a snapshot counter and is now actual gained whole-level skill points (0 in this example).
- **Migration applied and verified** in connected Tennis Legacy Supabase on 2026-10-20: 37 of the 105 snapshots have reliable game dates, covering **13 in-game weeks in Season 1** (Week 2–Week 16). The remaining old rows are not misdated. Current paid RPC returned 105 total / 37 game-dated snapshots. Authentication/owner checks and Free access restriction remain in place.
- **Still to verify in browser:** Skills and Premium skill timelines, eight languages, small screens, and the complete `npm run build`. No training mechanics or payouts were changed.

### Development order and release gates

1. Validate Statistics Intelligence in localhost (build, visual and paid/trial/Free access, real sample comparison).
2. Validate Deep Match Analysis in localhost: completed-match replay, paid/trial report, Free lock, empty-stat case, all languages and full build.
3. Validate and deploy the server-side Player Development Intelligence report in staging, then test owned-player scope, active membership, sample history coverage and all languages.
4. Ask for review after each newly added Premium module before starting the next.
5. Complete `npm run check:pt`, `npm run check:preferences` and `npm run build` before staging → main release; no production release without explicit approval.

## Free gameplay contract

All existing Free Statistics (ATP/WTA season/all-time leaderboards, tournament statistics and career records) remain Free, as do match results, tournament participation, ordinary training, equipment, finance, rankings and other core gameplay. Premium must not modify match outcomes, hidden skills, or ranking payouts.

## Homepage layout (2026-10-20)

The current preview is text-only: upcoming area 70%, latest result 30%; the upcoming area divides between Next Tournament and Next Match when both are known. No large player or tournament images. This replaces the older homepage image-based proposal.

## Premium feature 1 — Statistics Intelligence

**Approved for implementation by the user on 2026-10-20.**
**Location:** /game/statistics → Statistics Intelligence, below ATP/WTA and season/all-time selectors.
**Source:** src/pages/dashboard/Statistics.tsx; src/styles/statistics.css.
**Backend:** get_premium_statistics_intelligence_v1(world, period), defined in
supabase/migrations/20261020063000_premium_statistics_intelligence_v1.sql;
volatility correction for already migrated databases:
20261020070100_premium_statistics_intelligence_volatility_fix.sql.

- Compare the active player's win percentage, aces per match and winners per match with the displayed top-50 sample of completed matches in the selected world/period.
- Exclude the user's own entry from peer totals. Use sum of wins/aces/winners divided by sum of completed matches, not averages of individual percentages.
- If the user's player is not in the sample, display peer averages without inventing personal period statistics.
- The sample is not the whole playing population; no predictive gameplay or hidden inputs.
- Paid Premium and valid seven-day trial can see results. Free players see the section title, explanation, lock and Pro Packages link.
- The dedicated RPC uses has_active_premium_v1(), which checks paid entitlement and eligible active trials, and is callable only by authenticated users.
- Existing get_world_statistics_v1 remains available to Free accounts. The *report endpoint* is gated; raw published statistics are intentionally still public to game players.
- UI translated in EN, SR, DE, ES, IT, FR, RU and PT.

**Status:** staging UI/RPC committed; migrations applied to connected Tennis Legacy Supabase project on 2026-10-20.
**Backend validation:** Active trial report returned 3 metrics for ATP/season and WTA/all-time; non-Premium request was rejected (SQLSTATE 42501); anonymous execute privilege denied. These checks were run on 2026-10-20 without persisting simulation/test changes.
**Still to validate:** npm build, all eight language views, paid account UI, Free lock screen in a browser, and sample arithmetic against a known player. The hosting container cannot download the private repository to build it.

## Premium feature 2 — Deep Match Analysis

**Status:** implemented in staging on 2026-10-20. Backend RPC migration applied to connected Tennis Legacy Supabase. Full build and user browser review are still outstanding.

**Location:** Tournament → completed match → Match Details modal → beneath Match Statistics → Premium "Deep Match Analysis" section. Keep the normal final score, basic match statistics and existing replay access Free.

For a player's own completed matches only (all stats must come from actual recorded results):
1. Side-by-side player vs opponent comparisons: aces, double faults, first serves in/attempted, first-serve points won/played, second-serve points won/played, break points converted/chances, winners, unforced errors, total points won.
2. Calculated percentages: first-serve-in %, service points won %, first-/second-serve points won %, break-point conversion %, winner/error difference, and point share when both rows are present.
3. Set-by-set scoring summary and ranking/court/round data *only where recorded*; never invent historical tactics, fatigue, player attributes or point causes.
4. Evidence-based observations, e.g. "Your first-serve points won rate was 14 percentage points lower than your opponent's" and "You committed five more double faults." These highlight differences rather than claiming the actual cause of a win or loss.
5. Missing match-stat rows render "Not recorded", not zero.
6. Paid/trial Premium members get the full analysis; Free players see a short lock explanation and link to Pro Packages. Server-side entitlement required before returning the derived report.

**Implemented in controlled slices:**
- **A — Backend:** `get_premium_deep_match_analysis_v1(uuid)` in migration `20261020090500_premium_deep_match_analysis_v1.sql`, restricted to completed matches involving the signed-in player. Missing stat rows remain null.
- **B — UI:** `src/components/tournament/PremiumDeepMatchAnalysis.tsx` integrated into completed `Tournament.tsx` match-details modal, removed from Replay, with responsive `src/styles/premium-deep-match.css`. Free players get a lock/upgrade explanation.
- **C — Observations and localization:** Serve/break/shot/point comparisons with evidence-based observations and translations for EN, SR, DE, ES, IT, FR, RU and PT.

**Validation completed (2026-10-20):** paid account own completed match returns match statistics and sets; successful win and loss cases each returned correctly oriented records; a historical completed match with missing stats returned null values instead of zero; Free account, non-owned match and unfinished match were rejected (SQLSTATE 42501). No match outcomes, scores or payouts changed.
**Remaining:** `npm run build`, `npm run check:pt`, `npm run check:preferences`, browser paid/Free/trial checks, missing-row appearance, and eight-language visual QA.


### Match-details UX corrections and historical-factor explanation (2026-10-20)

- Rank, handedness and seed badges occupy one horizontal row in the player identity cards (horizontal scroll fallback on narrow screens).
- The analysis appears **below the existing Free Match Statistics**, in the normal Match Details modal, not in the Match Replay modal.
- Pre-match simulation snapshot is preserved in `tournament_match_simulations.metadata.profile_snapshot`. The report now returns whitelisted effective match ratings (overall, serve, return, rally, net and physical), fatigue, focus, sharpness, confidence, morale, surface adjustment, equipment, staff, tactical modifier, injury penalty, style and recorded weather. These represent the values captured at simulation time and must not be confused with the player's present attributes or double-added bonuses.
- Premium analysis summarizes historical factor differences and match-stat contrasts with explicit uncertainty. Missing historical snapshots yield an honest unavailable state rather than invented values.
- Backend migration `20261020094500_premium_deep_match_historical_factors_v1.sql` applied to connected Supabase and a paid completed match returned real captured ratings/fatigue/weather.
- **Engine realism audit:** `docs/MATCH_SERVE_REALISM_AUDIT_20261020.md`. Aces/DFs low and near-identical across ATP/WTA. No match-engine probabilities changed; benchmark and controlled simulation validation must precede an engine release.
- **Pending:** full browser QA (both badges layouts and modal), `npm run build`, translation visual checks, end-to-end trial check.

## Development/release tests

Before a production release run:
- npm run check:pt
- npm run check:preferences
- npm run build

Verify SQL access control (anon denied, Free denied, paid/trial authorized), and compare staging results against completed-match source data. GitHub source checks are not substitutes for the visual browser tests.
