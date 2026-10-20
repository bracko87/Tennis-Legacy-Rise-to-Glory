# Match engine realism audit — Tennis Legacy
**Date:** 2026-10-20 · **Branch:** staging · **State:** diagnostic only. No engine probability changes or replay rewrites.

## Evidence: completed singles matches in connected Supabase database

Population: 4,769 completed ATP singles matches and 4,889 completed WTA singles matches with two player-stat rows. Statistics below are averaged *per player per match*, not the sum across the two players.

| Measurement | ATP | WTA |
| --- | ---: | ---: |
| Aces | 1.20 | 1.20 |
| Double faults | 1.27 | 1.27 |
| No aces | 36.9% | 36.6% |
| No double faults | 31.1% | 31.0% |
| First serves in | 66.9% | 67.1% |
| First-serve points won | 67.0% | 67.0% |
| Second-serve points won | 49.0% | 49.1% |
| Winners | 22.9 | 22.5 |
| Unforced errors | 15.8 | 15.5 |
| Break-point chances | 7.6 | 7.5 |
| Break points converted | 39.4% | 39.3% |

Engine version comparison (per player, ATP/WTA):
- **base-v1.1** aces: ATP 1.67, WTA 1.52; double faults: ATP 1.41, WTA 1.25.
- **base-v2.0** aces: ATP 1.11, WTA 1.14; double faults: ATP 1.24, WTA 1.28.
- In **base-v2.0**, ~2.05% ATP / ~2.09% WTA of successful first serves are aces, and ~4.78% ATP / ~4.93% WTA of second-serve opportunities are double faults. Current ATP/WTA distributions are nearly identical.
- The example screenshot (Harare Futures) has aces 1 vs 0 and double faults 0 vs 0. Individual zero-ace matches can be valid, but the population-wide rates are too low.

## Evidence: currently deployed serve models

- `match_engine_ace_probability_v1` starts at 0.025, applies a serve-vs-return rating difference and surface modifier, with 0.004–0.18 clamps. `v2` adds the recorded tactical `ace_delta` and clamps 0.003–0.20.
- `match_engine_double_fault_probability_v2` has ~0.055 base rate per second-serve attempt, adjusted for serve skill, fatigue, focus and tactical `double_fault_delta`, with a 0.02–0.13 clamp.
- `match_engine_first_serve_in_probability_v2` uses the v1 first-serve model plus `first_serve_delta`, clamped at 0.47–0.78.
- Realized shot distributions depend on the serve-in rate, number of points in a match and additional classification code; don't patch counts after the simulation.
- Current ATP and WTA average serve skill in recent snapshots is similar (~43). Gender/tour-specific serving environment calibration is recommended, not automatic addition of a fixed number of aces.

## Proposed future correction — not deployed

1. **Parameterize realistic first-serve ace and second-serve double-fault probabilities** by ATP/WTA, surface, serve skill, return skill, style, risk, focus, fatigue and conditions. Calibrate the underlying point event generator so that every added ace/DF is a valid point outcome.
2. Use provisional **BO3 calibration bands**, not enforced per-match quotas: ATP ace distributions generally higher than WTA at comparable tiers; vary lower-level Futures, Challengers and elite groups. Candidate starting hypotheses: ATP 3–8 aces, WTA 2–5; double faults around 2–4 and 2–5, respectively, depending on player and match length. These are trial targets, not verified tour-wide averages. Do not cap legitimate outliers.
3. Run thousands of deterministic simulation fixtures across ATP/WTA, short/long matches, all surfaces, low/high serve skill, fatigue, styles and tactics. Use a fixed seed for every baseline and revised pair. Compare mean, median, p10/p90, zero-event share and rates per service point.
4. Check **coupled outputs**: first serve in %, points won on each serve, overall points won, break opportunities, break conversion, service games held, match length, winners, unforced errors and match winners. Reject changes that simply inflate ace/DF numbers while breaking other consistency.
5. Keep the current official completed matches, scores, rankings, payouts and historic replays untouched. Apply the reviewed correction only to newly simulated matches after explicit release approval.


## Slice 1 — Inactive v3 candidate prepared (2026-10-20)

**GitHub staging only; NOT activated.** The migration `supabase/migrations/20261020103000_match_serve_realism_v3_candidate_inactive.sql` defines three new, deliberately unused functions:

- `match_engine_ace_probability_v3_candidate(server,receiver,surface,world)` — starts from v2's real serve/return/surface/tactical model, adds a preliminary ATP/WTA environment adjustment plus a small serve-skill/style response, clamped to legal probabilities.
- `match_engine_double_fault_probability_v3_candidate(profile,world)` — starts from the existing October v2 calibration and increases second-serve fault probabilities, preserving serve-skill, fatigue, focus and tactical input effects.
- `simulate_tournament_match_raw_v3_candidate(match_id,seed)` — an isolated clone of the complete v2 point simulator with only its ace/DF calls replaced. Same input seed can compare v2 versus v3 with valid point outcomes (not retroactively adding ace/DF counts). **No dispatch, published replay, ranking or result function calls it.**

The candidate functions are inaccessible to ordinary players (service role only). **The existing v2 simulator is unchanged.** No migration has been applied to the connected game database for this slice because SQL execution permission is currently unavailable. Do not silently auto-activate the candidate in production.

### Reproducible tests

- `npm run check:serve` runs `scripts/check-serve-realism-candidate.mjs`: 12 deterministic cohorts (ATP/WTA × hard/clay/grass × elite/Futures), 420 paired match-score simulations per cohort = **5,040 matched seeds**, compares source-equivalent v2 serving probabilities with proposed v3 rates. It checks valid first/second serve point accounting, zero-event rates, aces/DFs, break outcomes, and score length. This is an **independent model-level simulator**, not a live game-engine run.
- **User-local Windows CMD validation (2026-10-20):** `git pull --ff-only origin staging` fast-forwarded successfully to commit `0f54f92`; `npm run check:serve` completed and printed all 12 cohorts / 5,040 seeded matches with no assertion failure. The numbers below are taken from that completed local run, not an earlier exploratory run.

| Metric per player per match | ATP baseline | ATP v3 candidate | WTA baseline | WTA v3 candidate |
| --- | ---: | ---: | ---: | ---: |
| Aces | 1.89 | 4.32 | 1.84 | 3.33 |
| Double faults | 1.43 | 2.06 | 1.40 | 2.20 |
| First serves in | 69.12% | 69.14% | 69.19% | 69.25% |
| Zero-ace matches | 29.84% | 4.25% | 31.07% | 8.69% |
| Average total games per match | 23.73 | 23.78 | 23.59 | 23.40 |
| Breaks per player per match | 2.62 | 2.50 | 2.66 | 2.65 |

**Important winner-change observation:** the output reports 687 / 2,520 ATP matches (27.26%) and 599 / 2,520 WTA matches (23.77%) with a different winner in v3. Combined: **1,286 / 5,040 = 25.52%**. Some changes are expected when point probabilities differ and random draws are consumed differently. Nevertheless, average game length alone is insufficient to certify gameplay balance. Before any v3 activation, compare win probability by absolute effective skill gap, first-/second-serve point conversion, break rates, upset rates, scoreline distributions, best-of-five matches, and replay event consistency across both versions. A large number of flipped outcomes should never be dismissed solely because means look plausible.

**These proxy baselines are not the same as the actual historical database averages above:** they use synthetic player profiles, a fixed-seed point-scoring proxy and 50/50 Futures/elite fixture balance. Do not infer that the candidate has reached real-tour calibration targets or passed the deployed point engine.

- `tests/serve_realism_v3_db_smoke.sql` is an **unexecuted** read-only seeded v2-v3 comparison of actual game simulator functions for small representative samples. Run only in a dedicated staging/test environment with service-role access, then expand coverage to thousands of game-engine simulations if results are consistent.

### Release blockers

1. Restore controlled SQL test access and deploy the **inactive** candidate to a staging/test database only.
2. Validate SQL syntax, privileges, fixed-seed full game-engine outputs and event consistency (each ace/DF is a real point and all statistics sum correctly). Re-run win/loss, scoring, tie-break, replay eligibility, and payout invariants.
3. Confirm realistic rates by tour, surface, tournament class, serving ability, first-/second-serve points and zero-event frequency. Compare medians and tails, not just means; zero-ace outcomes must remain possible.
4. Only after review, create a **separate** approved activation migration that moves the match dispatcher to v3. Do not rewrite any existing result or replay.

## References

- ATP Tour serve leaderboard documents ace and double-fault per-match metrics: https://www.atptour.com/en/stats/leaderboard?boardType=serve&formerNo1=false&surface=all&timeFrame=2025&versusRank=all
- WTA 2025 season aces totals and best aces-per-match records: https://www.wtatennis.com/news/4406894/the-2025-stats-wrap-part-3-aces-tiebreaks-the-longest-matches-and-more
- Query methods: aggregate `tournament_matches` completed + `tournament_match_player_stats` by `tournament_world_competitions.world`, plus `tournament_match_simulations.engine_version`. No player names or sensitive records included in this audit.
