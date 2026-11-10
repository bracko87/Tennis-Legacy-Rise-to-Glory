# Tennis Legacy — Season 2 Week 1 human-entry recovery

Date: 2026-11-10
Status: **Staged for review; never activated in production**
Branch: main

## Why this is necessary

The 597 Season 2 tournament editions were added after Season 1's normal entry windows for early Season 2 tournaments had already closed.

Confirmed against the actual public entry functions:
- Season 2 Week 1: 22 ATP/WTA competitions, 16 draws already published, 658 AI entries, 658 AI applications and 676 scheduled/bye/cancelled singles match records; zero human applications.
- Week 1's 22 normal and 22 late-entry windows are all closed before Season 2 starts.
- Week 2's 18 normal application windows are closed; 18 late-entry windows are scheduled to be open at the first second of Season 2. Availability and real vacancies still need testing.
- Week 3's 16 normal windows are open at Season 2 start.
- `apply_to_tournament_v3` refuses entries if a draw or match is already published and checks the old normal application window.
- `get_tournament_entry_lifecycle_base_v2` also refuses human application to published draws. Merely adding another front-end button or changing the clock date does NOT solve the problem.

Crucially, existing Week 1 qualification matches run on day 1 and day 2, main draw begins on day 3, final is scheduled for day 7. Simply reopening registrations after Season 2 begins would be too late to safely support qualification/travel.

## Live safety and source archive

A non-destructive protected recovery plan was installed at:
- `control_center_private.tennis_season2_week1_recovery_plan_v1` (private and inaccessible to ordinary users)
- `control_center_private.verify_tennis_season2_week1_recovery_sources_v1()` (read-only complete-source fingerprint check)

For each of the 22 competitions, it stores the original entry timeline, application records, entries, draw publications, match records and field-cycle records. These are scoped snapshots in the SAME production DB and are **NOT a full independently restorable backup**.

Initial full-data fingerprints matched 22/22 live competitions; all 22 recovery proposals were marked `ready_for_review` after a shadow rehearsal. The live 658 applications, 658 entries, 676 matches, 16 publications and 22 field cycles were NOT modified.

There were zero linked downstream Week 1 match sets, match statistics, simulations, tactics, travel first-match links, weather rows, equipment setup rows, condition events and opponent scouting tasks at inspection.

## Recovery plan — not yet approved

1. **Verify an independent full database backup and restore** in a non-production environment; preserve a restore point before any genuine draw cleanup.
2. Preserve exact source entries and audits. Do not remove Season 1 historical results.
3. Offer a pre-season opt-in application process to the existing five human accounts *while the game is safely held at the Season 1 last second*. This avoids compressing normal registration into the first qualification day. A player should explicitly choose a tournament, subject to world, availability and one-tournament-per-week rules. No forced or invented human registrations.
4. Confirm in the signed-in player UI that all ATP/WTA users can see, submit, edit and cancel their choices. Existing AI applications must not block human entry merely because the calendar was created late.
5. In a verified, isolated production restore, **atomically** rebuild affected Week 1 competition selection states:
   - preserve current AI application pool and original ranking snapshots,
   - clear derivative published draws/matches/entry allocations and locked-field markers only after relational and downstream checks,
   - reopen normal selection for the explicit opt-in human applications,
   - rerun the original selection engine with human/AI priority, qualification and eligibility logic,
   - publish new draws with the original Week 1 match schedule intact,
   - ensure no duplicate matches, rankings, payments, or notifications.
6. Run a crash/retry test. If the attempt fails, roll back the whole database transaction and preserve all original source records.
7. Independently audit Week 2 available vacancies/normal-close behavior. Do not silently promise that its late-entry windows guarantee open seats.
8. Only after verified end-to-end tests and approval: apply to production, verify matches and fair human eligibility, and then finish the actual Season 1 → 2 migration.

## Shadow trial completed

Temporary local-to-transaction copies of five Week 1 tables were populated with live data and processed without changing production:
- 676 match rows, 16 published draws, 658 entries and 22 locked fields were removed/reset in **temporary copies only**.
- 652 accepted AI applications reverted to pending status in the copies while six previously withdrawn applications remained withdrawn.
- One existing human player was inserted into a temporary competition application, without modifying their actual account.
- Repeating the simulated reset generated zero additional changes.
- The 676 real production matches still existed afterward.

This proves basic record reconciliation and idempotent data operations, **not** full tournament draw algorithm, human login, travel, or migration certification.

## Release blockers

The release gate `control_center_private.check_tennis_season1_to2_release_gate_v1` still prevents the cutover. Week 1 human eligibility must pass on a restored non-production database before anyone clears or republishes the live draws. The full backup/restore test, two-season dry runs, migration execution, finance/contract approval and operator approval remain missing.

The next calendar must be prepared **before** its applications open—at least 21 game days before the first tournament week—so this incident does not recur in Season 3.
