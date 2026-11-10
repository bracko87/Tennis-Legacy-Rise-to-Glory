# Tennis Legacy — Season 1 to Season 2 preparation
Date: 2026-11-10 (production database inspection, UTC)

## Safety: no live migration executed
- Season 1 reached 31 December 23:59:59 and is held by the existing `season_transition_boundary_guard_v1`.
- `get_game_clock_v1()` reports effective speed 0 while the guard is held. The saved speed setting is 2x.
- Season 2 has NOT started. The transition status API still reports `execution_enabled: false` and no migration run.
- Never bypass the guard or flip the season number before the restore test and complete rollover approvals.

## Completed: Season 1 closeout
- The final 12 competitions and their rankings were closed.
- 616 ranking results were published; 616 contributions activated; 12 ranking cycles recorded.
- Season 1's 597 tournament editions are completed or canceled. No unfinished singles/doubles matches remained at the closeout check.

## Completed: Season 2 core calendar records
Using Season 1's existing, active series as the approved game template:
- 597 Season 2 tournament editions created with fresh scheduled status.
- 613 Season 2 schedule slots created, matching the established source weeks, phases, and ordering.
- 1,194 Season 2 ATP/WTA competitions created with scheduled status.
- Coverage: 52 weeks, 10 categories. Original Season 1 records and statuses were preserved.
- Initial one-transaction parity check succeeded (counts, schedule-slot equivalence, and fresh competition statuses).
- `control_center_private.verify_tennis_season2_calendar_v1()` is installed for independent read-only checking. It currently does NOT certify the full calendar as release-ready because automatic scheduling generated additional next-season records (see below).
- The authenticated `get_tournament_calendar_v2` API was not end-to-end tested with a signed-in player; calling it without authentication correctly fails.

## Important next-season preparation finding
After adding the calendar, the previously existing tournament cron jobs generated early Season 2 content around 20:55 UTC, while the end-of-season clock remained held:
- 1,334 tournament applications
- 658 tournament entries
- 16 draw publications
- 676 Week 1 singles match records (636 scheduled, 38 bye, 2 cancelled; no completed results found)
These were not copied from Season 1. They must be reviewed for correct player eligibility, draw timing, and ranking basis before launch. **Do not delete or reset them without an audited reconciliation.**

To prevent additional automatic tournament pipeline processing while effective game speed is zero, the following production pg_cron jobs were updated to run their existing commands only when `get_game_clock_v1().speed_multiplier > 0`:
- 7 `tennis-entry-lifecycle-v2`
- 44 `tennis-tournament-entry-auto-repair-v1`
- 52 `tennis-draw-publication-v1`
- 53 `tennis-tournament-draw-auto-repair-v1`
- 55 `tennis-tournament-operations-v1`

These jobs remain scheduled and active; their processing automatically resumes once the effective game clock is intentionally running. The conditions were verified in `cron.job`. Other cron jobs were left unchanged.

## Completed: journal infrastructure, not execution
Private tables:
- `control_center_private.tennis_season_transition_runs_v1`
- `control_center_private.tennis_season_transition_steps_v1`

There is now one planned (non-executable) migration run with 13 waiting steps; there are no executed migration steps. Data is inaccessible to anonymous/authenticated Data API roles. Enabling a run requires checked fields for backup, restore test, two-season dry run, contracts, finance, and operator approval. A status of `running` or `completed` cannot be declared without the execution flag.

## Blockers to an approved production migration
1. Complete full eligibility/integration certification for generated Season 2 applications, entries and draws (structural checks have passed).
2. Implement the protected, idempotent migration runner with an actual step journal, rollback/recovery behavior, and clock lock.
3. Verify full project backup and a real restore exercise. The journal is not a backup.
4. Implement and validate season rollover for player ranking expiry/defence, development and identity, finances, sponsorship renewal and grandfathering.
5. Verify the now-installed original-terms technical sponsorship registry in the final simulated migration: 1 contract crosses the boundary and 2 due contracts need expiry processing.
6. Conduct isolated Season 1->2 and 2->3 end-to-end dry runs; pass post-migration checks.
7. Only after explicit approval, execute the transition and then resume the game clock.

As of the recorded snapshot, all final Season 1 closeout records were present, but the season transition was still **disabled**.

Do not confuse *calendar populated* with *migration approved*.

## Preparation audit update — 2026-11-10, about 21:12 UTC

### Confirmed structural checks (read-only)
`control_center_private.verify_tennis_season2_early_preparations_v1()` is installed and returns `structural_preflight_passed: true`.

- Published draws: 16, all based on Season 1's final ranking snapshot, absolute day 365, after the 12-finals closeout.
- Applications: 1,334 (AI only, no duplicate competition/player pairs, no missing ranking snapshots).
- Entries: 658 (AI only, no duplicate competition/player pairs, no missing ranking snapshots).
- Week 1 singles match records: 676 (636 scheduled, 38 byes, 2 cancellations).
- No actual completed Season 2 matches; byes may record a winner/completion without a played match.
- No Season 2 singles or doubles tournament results, and no player-world mismatches found.
- Full authenticated player UI integration and all tournament eligibility rules are **not** certified.

`control_center_private.verify_tennis_season2_calendar_v1()` still conservatively reports `coverage_verified: false` because it treats any pre-generated match record as an obstacle; its underlying core calendar parity checks pass. The new migration preflight distinguishes the two questions.

### Financial and player baseline
- 5 human players and 5 live career finance accounts, each matching its latest recorded transaction balance; no duplicate finance idempotency keys.
- 6 coin wallets with no negative balances.
- No Season 2 finance transactions or ranking publications recorded.
- Ranking contributions with expiration after the boundary: 36,252 active singles and 2,508 active doubles.
- Existing `process_weekly_rankings_v1` contains next-edition replacement and scheduled expiration logic; this is code inspection, not end-to-end certification.

### Technical sponsorship protection
- Two active technical contracts (shoes and racket) have end day 365 and should complete when advancing to absolute day 366 via the established contract sync routine.
- The third active contract (apparel) ends on day 386 and must remain unchanged across the migration.
- A protected `control_center_private.tennis_season_transition_technical_contract_registry_v1` now stores each existing contract's original terms and proposed handling (2 completion-on-expiry, 1 grandfathered carryover). All three were verified unchanged after capture. These stored terms are not a new contract and do not extend, complete or renew any agreement.

### New internal audit/guard infrastructure
- `control_center_private.build_tennis_season2_migration_preflight_v1()`: read-only diagnostic, reports clock hold, closeout, calendar core parity, draw anomalies, sponsorship counts, ranking carryovers and hard release blockers.
- `control_center_private.tennis_season_transition_runs_v1`: one `planned` run, `execution_enabled=false`.
- `control_center_private.tennis_season_transition_steps_v1`: 13 waiting steps; no step has run.
- `control_center_private.tennis_season_transition_baselines_v1`: 6 verified key comparison baselines (finance accounts, wallets, contracts, rankings, players and calendar).
- Baselines and contract registries are protected private audit evidence, **not** a full database backup or proof of successful restore.

### Release status
At the latest check the effective game speed remains zero and the Season 1 boundary guard is enabled. The migration is not executable and Season 2 has not started. Still mandatory before the real switch: full restorable database backup; complete and tested rollover runner including rollback/replay journal; financial, ranking, development, and sponsorship end-to-end checks; authenticated UI checks; isolated Season 1→2 and 2→3 dry runs; explicit operator approval.
