# Tennis Legacy — Free/Premium controlled rollout

**Branch:** staging. **Latest reviewed:** 2026-10-20.
Develop in small, independently reviewable increments; no production main merge without approval.

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

## Proposed Premium feature 2 — Deep Match Analysis

**Status:** user suggested on 2026-10-20; proposal recorded, NOT IMPLEMENTED yet.

**Proposed location:** Tournament → completed match → Match Replay/Result view → Premium "Deep Match Analysis" section. Keep the normal final score, basic match statistics and existing replay access Free.

For a player's own completed matches only (all stats must come from actual recorded results):
1. Side-by-side player vs opponent comparisons: aces, double faults, first serves in/attempted, first-serve points won/played, second-serve points won/played, break points converted/chances, winners, unforced errors, total points won.
2. Calculated percentages: first-serve-in %, service points won %, first-/second-serve points won %, break-point conversion %, winner/error difference, and point share when both rows are present.
3. Set-by-set scoring summary and ranking/court/round data *only where recorded*; never invent historical tactics, fatigue, player attributes or point causes.
4. Evidence-based observations, e.g. "Your first-serve points won rate was 14 percentage points lower than your opponent's" and "You committed five more double faults." These highlight differences rather than claiming the actual cause of a win or loss.
5. Missing match-stat rows render "Not recorded", not zero.
6. Paid/trial Premium members get the full analysis; Free players see a short lock explanation and link to Pro Packages. Server-side entitlement required before returning the derived report.

**Implementation in three small parts after the first module is reviewed:**
- A: Read-only Premium-gated RPC for completed matches played by the signed-in user's player; missing-data handling and test fixtures.
- B: Match Replay/Result comparison panel with proper Free preview and responsive design.
- C: Evidence-based post-match observations, all-eight-language localization, validation for wins/losses and absent stats.

## Development/release tests

Before a production release run:
- npm run check:pt
- npm run check:preferences
- npm run build

Verify SQL access control (anon denied, Free denied, paid/trial authorized), and compare staging results against completed-match source data. GitHub source checks are not substitutes for the visual browser tests.
