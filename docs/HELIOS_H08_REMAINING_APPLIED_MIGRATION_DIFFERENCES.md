# Helios H08 — Broad applied-vs-repository SQL comparison

20 November 2026 — source-only comparison. **No production schema or player data was modified.**

## Coverage

The live Supabase migration registry has 812 applied versions; the repository has 688 checked-in migration files. The earlier source comparison in PR #75 proved SQL token equivalence for the first 10 same-name/timestamp-renamed migrations.

This stage captures token fingerprints of the **remaining 211** applied sources that have a repository file with the same name but a different migration timestamp. Only source fingerprints, source MD5, token counts and filenames are committed; the original SQL texts and all gameplay/user records are excluded.

## Verified diagnostic results

| Result | Number |
|---|---:|
| Remaining renamed applied SQL sources compared | 211 |
| Same SQL token sequence | 202 |
| SQL token mismatch, requiring review | 9 |
| Missing checked-in SQL files among these 211 | 0 |
| Total name-matched, timestamp-renamed sources covered across this and PR #75 | 221 |

The prior history-gap diagnostic reported 219 name matches based on a different snapshot/listing state and filtering method; the current re-query of repository filenames and live migration history yielded 221. **Do not assume all counts share one frozen repository snapshot.** The manifests are the reproducible per-source inputs for these checks.

### Nine explicit migration replay blockers

| Original applied migration name | Nature of detected SQL difference |
|---|---|
| `harden_tournament_entry_cancellation_and_alerting` | Applied incident cleanup loop absent from repository version |
| `run_critical_incident_reminder_check_every_minute` | Applied version contains additional incident resolution statement |
| `training_camp_reliability_balance_health_v1` | Different pricing-rule alias in a function/query |
| `game_manual_system_health_v1` | Different manual PDF link |
| `allow_authenticated_curated_player_portrait_reads` | Repo adds another storage policy removal |
| `control_center_dynamic_disk_capacity_v1` | Applied migration only adds an initial column; repository version also defines substantial functions |
| `tennis_system_incident_direct_push` | Function SQL/statement structure differs; investigate before replay |
| `public_tennis_home_gallery_20_read` | Repo adds `DROP POLICY IF EXISTS` before policy creation |
| `premium_statistics_intelligence_v1` | Applied function marked `STABLE`; repo uses `VOLATILE` |

All nine are recorded as **REVIEW_REQUIRED** and `replay_blocker=true` in `tests/recovered-migrations/known-applied-sql-divergences.json`. No change was made to deployable migrations.

The GitHub CI check explicitly distinguishes a **successful discrepancy audit** from a **safe full migration replay**. It succeeds only if all 202 matching fingerprints and all nine unchanged, known blocked mismatches remain consistent with the checked-in reference. New divergences, missing files, disappearance of a known mismatch without reconciliation, or changed reviewed fingerprints fail the check.

**Do not interpret green source-fingerprint CI as approval to replay all migrations.** No full-schema replay has yet succeeded, the 227 source-migration names absent from GitHub still need a recovery strategy, and these nine mismatches require review.

## Next priorities

1. Reconcile the nine discrepancies against later applied migrations and current schema; retain original applied SQL in a nondeployable archive if necessary, without modifying historical deployable migrations prematurely.
2. Recover version-matched missing foundational migration SQL (especially the staff and scheduling chain), using source metadata and explicit privacy/security review.
3. Build a disposable full-schema PostgreSQL/Supabase replay with a verified initialization boundary, then run guest history-preserving erasure tests.
4. Complete the approved data-retention plan and real browser guest account conversion/expiry tests before enabling anything.

**Safety:** Guest Mode OFF, physical account deletion OFF, no paid test environment, no production data changes.
