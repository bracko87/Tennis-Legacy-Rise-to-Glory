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

## Implementation update — authenticated pre-season preference feature

**Implemented, but NOT deployed to the production website.** Netlify builds remain deliberately stopped. No production tournament draw has been changed.

### Backend already installed in the Tennis Legacy Supabase project
- Private, RLS-enabled `control_center_private.tennis_season2_week1_preentries_v1` stores at most one preference per human player for Season 2 Week 1. The signed-in owner can change or withdraw that preference.
- `control_center_private.tennis_season2_week1_preentry_open_v1()` only permits registration while Season 1 is held at the protected year-end second, the guarded migration plan is unapproved, and all 22 recovery plans are marked ready for review.
- `public.get_tennis_season2_week1_preentry_v1()` returns only the signed-in human player's tournament choices (ATP or WTA). It checks existing tournament conflicts and projected health.
- `public.set_tennis_season2_week1_preentry_v1(uuid,boolean)` saves, switches or withdraws the preference under a player-level transaction lock. It verifies the signed-in account, world, recovery plan, competition status and availability. It does **not** write to `public.tournament_applications`, `tournament_entries`, draw or match tables.
- `control_center_private.audit_tennis_season2_week1_preentries_v1()` shows how many preferences remain unreconciled with real entries.
- Both public RPCs are executable only by authenticated users. The private preference table cannot be directly selected by authenticated or anonymous roles.

### Player UI on GitHub main
- `src/components/season/Season2Week1PreRegistration.tsx`: choice, qualification opt-in, change, withdraw and clear disclaimer that preference is NOT accepted entry.
- `src/styles/season2-week1-preregistration.css`: responsive layout.
- `src/pages/dashboard/Overview.tsx` mounts the component alongside the year-end notice.
- No Netlify website deployment was requested or performed. The GitHub release-validation workflow passed on the dashboard commit.

### Tests performed
- Transaction-rolled-back authenticated ATP: list, save, read back, idempotent save, switch choice, withdraw.
- Transaction-rolled-back authenticated WTA: list of 11 available-world competitions, save and read back.
- Cross-world selection by an ATP player was rejected.
- Anonymous RPC execute rights are revoked; authenticated roles have no direct private table access.
- Database test transactions were rolled back. No user was auto-enrolled and no real preference was created by testing.
- Future end-to-end real-browser test is still needed after authorized website deployment.

### Explicit limitation
Existing early-season draws have not been rebuilt; the protected migration gate still denies execution. A saved preference alone does not enter any tournament. In an independently restored non-production database, the recovery routine must turn choices into bona fide applications, rerun capacity/ranking/eligibility allocation and publish corrected draws. Only after all audit, restore and migration tests pass can the live Season 2 transition be approved.

## Additional complete-source archive and release-gate verification

A review of foreign-key dependencies identified two additional sources required for any future Week 1 draw reconciliation:
- 60 existing `tournament_qualifier_slots` across 12 competitions;
- 16 `tournament_draw_publication_attempts` audit records.

They are now preserved privately in `control_center_private.tennis_season2_week1_qualifier_snapshot_v1`, alongside the previously archived Week 1 match/draw/entry/application/field-cycle records. This is still inside the production database, **not an independent backup**.

The read-only `control_center_private.audit_tennis_season2_week1_extended_recovery_v1()` verified all 22 competition source fingerprints, 60 qualifier-slot rows and 16 draw-attempt records against the live originals.

A follow-up query confirmed there are **zero** Week 1 completed singles/doubles results, tournament doubles matches, match sets/statistics, match simulations, match tactics, match equipment setups, travel match links, player tournament preparation plans, or calendar commitments for the affected competitions. No production draw was deleted or rebuilt.

The fail-closed migration release gate now also blocks execution if any recovery archive fingerprint changes. Its final check remains **blocked (8 blockers)**: full independent backup/restore, Week 1 human entry acceptance/rebuild, complete rollover certification, two-season rehearsal, final approval and atomic cutover certification are incomplete.

The administrator-only migration status RPC now reads the real private journal and confirms the populated Season 2 calendar rather than presenting stale design-stage messaging. The UI source was updated separately on GitHub main; it was not deployed to the live website.
