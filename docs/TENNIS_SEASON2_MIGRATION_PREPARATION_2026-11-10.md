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

## Follow-up: protected release gate and atomic cutover candidate

The game was re-checked with the Season 1 safety stop armed at absolute second 31,622,399 (December 31 at 23:59:59). Season 2 has **not** begun.

### Live migration baseline drift detection
Added `control_center_private.verify_tennis_season1_transition_baselines_v1(run_id)`.
- Checks all six stored baseline values against the current finance-account, wallet, ranking, player-count, calendar and technical-contract data.
- Compares the original full signed contract records against their private registry copies.
- Verified against the planned run: **6/6 metrics unchanged, 0 missing, 0 drifted, 0 contract mismatches.**
- These are small selective audit records, not a full backup.

### Cutover release gate
Added `control_center_private.check_tennis_season1_to2_release_gate_v1(run_id)` and an asserting helper. Currently the gate returns `approved_for_cutover=false` and lists missing independent release checks (backup/restore, isolated two-season dry run, contracts/finance, tournament eligibility, operator approval, and actual cutover certification).
- A deliberate negative test verified that calling the assertion refuses an unsafe transition without modifying the game.
- The release gate intentionally retains a code-level hard blocker until the atomic runner's positive path has been tested and approved in an isolated environment.
- Anonymous and authenticated clients have no execute rights for the private cutover function.

### Atomic cutover code candidate (not certified and not run)
Created `control_center_private.execute_tennis_season1_to2_atomic_v1(run_id)` as a strictly guarded **candidate** using one PostgreSQL transaction and an advisory lock:
1. Assert backup, restore, dry-run, contracts, finance, tournament eligibility and operator approvals; refuse on failure.
2. Lock and verify the live Season 1 clock at its final second; check all six baselines unchanged.
3. Preserve player identities, skills, rankings and wallet/finance balances rather than resetting them.
4. Use existing technical sponsorship sync at absolute day 366; ensure two due contracts complete and the remaining contract preserves its original terms.
5. Change the clock to **Season 2, January 1 00:00, paused at 0×**, and arm the Season 2 end-of-year safety stop for second 63,244,799.
6. Verify Season 2 remains paused and the calendar is still present; journal the 13 steps as completed only if the entire transaction succeeds.
7. The game will require a separately controlled resume at the agreed speed after post-checks.

**Important:** The candidate's positive path has NOT been exercised; the isolated restore and two-season dry run are still missing. It is not production-approved. Invoking it in production was verified to return `Season 1->2 migration is blocked`; the live clock remained in Season 1 with all 13 steps unexecuted and the three technical contracts unchanged.

### Additional pause-safety correction
The five tournament entry/draw jobs (IDs 7, 44, 52, 53, 55) now require both:
- canonical clock speed greater than zero (the safety guard must not be holding time); and
- `public.game_clock.is_paused = false`.

This prevents new draws being published during an explicit manual pause as well as the season-end safety hold.

### Calendar arithmetic checks
Read-only tests passed for the last second of Season 1, the first second of Season 2, the last second of Season 2, and the first second of Season 3. This is **boundary arithmetic testing**, not two-season migration certification.

### Next hard blockers
- Obtain and verify a restorable full production backup without restoring over production; test restoration in a safe isolated environment.
- Exercise the candidate positive path and verify data/notification/transaction isolation and failure/retry behavior using that environment.
- Verify full player and finance rollover, eligibility timing and fair entry paths for human players at Week 1.
- Complete a Season 1→2 and Season 2→3 dry run and get explicit approval before removing the fail-closed gate.
- Never bypass the guard or manually change the production season number as a shortcut.

## Follow-up: 2026-11-10 — direct Supabase remediation (no paid browser tool)

### Confirmed and fixed cutover candidate defect
- The real `public.game_clock` constraint requires `speed_multiplier > 0`. The previous migration candidate incorrectly tried to write 0 when entering the new season. This would have failed in production.
- Corrected `execute_tennis_season1_to2_atomic_v1` to retain the configured positive speed (currently 2x), set `is_paused=true`, and verify Season 2's absolute start second without incorrectly asserting that the clock's reported configured speed is zero.
- Temporary shadow copies of the live clock and season boundary guard passed Season 1→2 and Season 2→3 rollover checks. A deliberate zero-speed write was rejected by the copied production constraint. **No live game clock changed.**

### Real-data contract/finance shadow trial
- Transaction-local copies of 3 active technical sponsorships, 5 finance accounts, and 6 coin wallets were tested.
- Season-2 first-day expiry logic completed the two due contracts and preserved the third crossing contract unchanged.
- Re-running the expiry updated zero contracts (idempotency); an injected failure in a shadow subtransaction was rolled back; finance and coin totals stayed unchanged.
- This is a small-table logical trial, **not** a restorable full project backup or full production rollover rehearsal.

### Serious human entry blocker identified
The real `get_tournament_entry_timeline_v1` makes the Season 2 first-week tournament entry windows open and close **in late Season 1**. But the Season 2 calendar was created after that period.

Read-only audit `control_center_private.audit_tennis_season2_early_entry_windows_v1()` confirms:
- Week 1: 22 ATP/WTA competitions, 16 already-published draws, zero human applications; **all 22 normal and late application windows were already closed before Season 2 starts**.
- Week 2: 18 competitions; all 18 normal windows already closed, though late-entry time windows are open at the Season 2 start (actual vacancies/eligibility are not certified).
- Week 3: 16 competitions; normal application windows open at the start of Season 2.
- The lifecycle code refuses new applications for published draws.

This is a real fairness/release blocker, not merely a missing test. No Week-1 draw or player entry has been deleted or reset.

**Needed remediation, after verified restore:** agree/test a one-time Week-1 grace/application window after Season 2 starts; preserve existing AI entries and scheduling provenance as auditable evidence; rebuild or reschedule premature published draws with human entry opportunity; check travel/preparation deadlines; verify Week 2 selection and actual late-entry availability; retest the authenticated player experience. Also change preparation for later seasons so next-season calendars are present before application windows open.

The explicit Week-1 human-entry blocker was added to the fail-closed `check_tennis_season1_to2_release_gate_v1`; current approval remains false and eight release issues are reported.

### Remaining live status
At the last live check, the Season 1 boundary safety guard was still enabled, effective clock 0x at 31 December 23:59:59, 597 Season 2 editions prepared, and **zero executed migration steps**. Six stored data baselines were unchanged.

A full independently restorable backup and a complete cross-season test **remain unavailable/unverified through the current direct database connection**. The work above used the existing Supabase and GitHub plugins only.

## Fast-path verification — 2026-11-10 22:50 UTC

This update was executed using the existing connected Supabase database and GitHub tools only.

### Real Week 1 draw engine rehearsal passed
Private audit table: `control_center_private.tennis_season2_week1_rehearsal_evidence_v1`.
- 16/16 previously published Week 1 competition draws were rebuilt with the real `allocate_tournament_applications_v3` and `publish_tournament_draw_v1` functions inside a forced-rollback subtransaction.
- 676 original match records became 676 regenerated matches in the rehearsal.
- ATP and WTA human application test fixtures were both evaluated through real allocation.
- After forced rollback, all original Week 1 sources and 22 competition archive fingerprints matched exactly. No real human preferences or entries were created.
- This does **not** certify that the real human preference UI has been deployed or that a signed-in player can enter the actual Week 1 field yet.

### Real Season 1→2 cutover code rehearsal passed
Private audit table: `control_center_private.tennis_season_atomic_rehearsal_evidence_v1`.
- The real `execute_tennis_season1_to2_atomic_v1` ran to completion under a strictly transaction-local test approval helper and test-only flags.
- It completed all 13 journal steps and reported `completed_paused`; Season 2 began at January 1, 00:00 while paused with stored speed still 2x.
- Technical sponsor sync ran for one affected player; the run passed its post-cutover checks.
- Deliberate exception reversed the entire simulated cutover and restored the original fail-closed approval helper.
- After rollback, live Season 1 clock and boundary protection, all six finance/player/contract/ranking baselines, release flags and all 13 waiting journal steps were confirmed unchanged.
- **This was a positive-path code rehearsal, not a production migration; the live safety gate remains unchanged and closed.**

### Cron protection expanded
An additional 18 game-changing cron jobs were updated to require effective game speed >0 and `game_clock.is_paused=false`. Together with the five earlier tournament jobs, **23 active game-processing jobs** are now protected. Parsing/EXPLAIN verification of all guarded job statements passed. Monitoring/telemetry and external-time jobs were not blindly disabled.

### Backup position established — Pro, not individually verified
The connected Supabase organization reports `pro` tier. Supabase's documented policy says Pro projects receive automatic daily database backups retained for seven days: https://supabase.com/docs/guides/platform/backups. The direct Supabase connector does not expose individual backup timestamps or provide restore-to-test operations, so **no specific full backup or independent restore test has been verified**. Backup/restore approval flags intentionally remain false. In-database recovery archives are not independent backups.

### Remaining release blockers
1. Confirm a specific restorable database backup and run an independent restore or equivalent recovery verification. Do not fabricate a backup approval.
2. Deploy the built Week 1 pre-registration UI so real players have a fair opportunity to choose a tournament. The database has **zero real human preferences** so far.
3. Review the real human choices, then reconcile and republish the 16 early Week 1 draws using the tested algorithm and the protected archives; keep the other six underfilled events under review.
4. Complete and approve release checks covering the wider game economy, full two-season testing, and recovery of a crash/repeated execution.
5. Then authorize the already rehearsed atomic cutover to **Season 2 Jan 1, 00:00, paused**, inspect results and resume 2× only after Week 1 player eligibility is satisfied.

**The live game was NOT moved to Season 2 in these tests.**

## November 11 update — atomic Week 1 recovery, combined migration and first-day processing

**Verified using the existing connected Supabase project and GitHub main. No paid third-party browser.**

### Week 1 actual recovery procedure implemented
- Private, execution-restricted `control_center_private.reconcile_tennis_season2_week1_draws_v1(run_id)` creates ordinary tournament applications from **explicit** human Week 1 preferences.
- It atomically resets stale AI selection, relevant entry/match/draw/qualifier rows, reruns the game's true allocator for all 22 Week 1 competitions and republishes the 16 previously-published draws.
- The six underfilled events remain undrawn if they do not meet existing field requirements.
- New private receipts record original and regenerated source fingerprints. `verify_tennis_season2_week1_reconciled_draws_v1()` checks all 22 receipts, regenerated draw statuses, source provenance and human-choice reconciliation.
- The recovery routine checks the live year-end safety hold, all 22 approved recovery plans, unchanged original source archives and verified backup **and independent restoration** before doing any real writes. All client roles are denied EXECUTE. Repeat execution is idempotent; partial or failed SQL transactions roll back.
- At present it is deliberately inactive because real restoration is not certified, plans are not approved and **zero human preferences have been submitted**.

### Combined end-to-end cutover inside forced rollback
A single transaction used temporary test approval flags and ATP/WTA human application fixtures:
1. Reconciled all 22 competition fields.
2. Republished 16 draws and regenerated 676 match rows.
3. Evaluated two explicit test human applications through real allocation rules.
4. Verified 22 post-reconciliation fingerprints and human application status.
5. Called the unmodified, real season-switch function. It completed 13 journal steps and set Season 2 to January 1 at 00:00, paused, stored speed 2x.
6. Forced rollback and confirmed original competition archives, season clock and user data/approval flags returned to their starting state.

Audit: `control_center_private.tennis_season_atomic_rehearsal_evidence_v1`,
scenario `week1_recovery_and_cutover_combined_rollback`, `passed` and `rollback_confirmed=true`.
This is **not** a production switch, a real player registration, an independent restore or a full two-season dry run.

### Season 2 Day 1 finance/career/staff rehearsal
Another transactional trial moved to Season 2 Jan 1, ran career-day progression, human finance, weekly staff salary processing and ranking processing, then repeated the processors before full rollback.

Verified:
- 5/5 human careers advanced to absolute day 366 with **zero errors**.
- 5/5 human finance accounts processed absolute day 366.
- A second run advanced zero additional career days, wrote zero duplicate financial transactions or staff-salary events, and coins were unchanged.
- Season 2 January 1 did not publish a weekly ranking cycle early.
- Entire trial was rolled back and original six player/finance/contract/ranking baselines stayed unchanged.

Audit: `control_center_private.tennis_season2_day1_finance_career_rehearsal_v1`, scenario `day1_career_finance_staff_idempotency`, passed/rolled back.

The migration plan flags `finance_verified=true` and `contracts_verified=true` now reflect those verified live-code, rollback-only boundary rehearsals, **not** a production finance posting or a full independent backup.

### Production state and release blockers

The release gate now uses evidence:
- Positive atomic switch rehearsal checked from the private journal.
- Original archive consistency before recovery; **post-recovery receipts** after legitimate draw regeneration, rather than permanently rejecting moved records.
- Finance/contract certification recorded based on the specific successful replay tests.

At the last live checks, `check_tennis_season1_to2_release_gate_v1` still returned **`approved_for_cutover=false` with 5 remaining blockers**:
1. Final execution approval/enabling has not happened.
2. A specific independent, restorable full backup and restore test has not been verified.
3. Full isolated two-season (Season 1→2 and Season 2→3) migration rehearsal is missing.
4. Final operator approval has not been recorded.
5. Real human Week 1 registration and certified live draw reconciliation have not been completed (UI still not verified deployed).

The live Season 1 boundary is unchanged: December 31 23:59:59 at effective speed zero, configured 2x. No real Season 2 draw or finance data was changed; no migration step has been executed.

SQL review snapshot: `docs/sql/TENNIS_SEASON2_WEEK1_ATOMIC_RESELECTION_2026-11-11.sql`.

**Do not set backup, restore, two-season or operator approval flags merely to satisfy the release gate. They must be supported by genuine evidence.**