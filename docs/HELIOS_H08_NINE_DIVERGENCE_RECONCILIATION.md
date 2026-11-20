# Helios H08 — Evidence-backed review of nine applied/repository SQL differences

**Status: unresolved full historical migration replay blockers.** Evidence gathered using read-only schema catalog and migration-registry queries. No migration was run, altered or marked safe for replay. The original nine fingerprint differences remain in `tests/recovered-migrations/known-applied-sql-divergences.json`.

| # | Migration | Evidence from later applied migrations/current schema | Status |
|---:|---|---|---|
| 1 | `harden_tournament_entry_cancellation_and_alerting` | Applied SQL has an extra system-incident cleanup loop; repository source omits it. No equivalent later applied migration proven in this investigation | REVIEW_REQUIRED |
| 2 | `run_critical_incident_reminder_check_every_minute` | Applied SQL additionally resolves a stale cron incident, whereas repository SQL ends after scheduling. Later `resolve_cron_incidents_from_terminal_runs` is present but equivalence of this specific cleanup not established | REVIEW_REQUIRED |
| 3 | `training_camp_reliability_balance_health_v1` | Applied SQL uses alias `r`; repository uses `pr`. Applied follow-up `20261002112307_fix_training_camp_health_alias` explicitly replaces `r` with `pr` and reinstalling the function. Current `check_training_camp_health_v1` exists. **Later correction is verified**, not replay equivalence | REVIEW_REQUIRED |
| 4 | `game_manual_system_health_v1` | Applied manual path was static PDF; repository uses `/game/manual?download=pdf`. Applied `20261002141436_game_manual_generated_pdf_route_v1` explicitly updates `game_manual_runtime_settings.pdf_path` to that browser-generated route | REVIEW_REQUIRED |
| 5 | `allow_authenticated_curated_player_portrait_reads` | Repository additionally removes an existing `admin_player_avatar_authenticated_read` policy. Current live `storage.objects` **still has** that policy. Differences in policy ordering or CREATE/DROP behavior remain consequential | REVIEW_REQUIRED |
| 6 | `control_center_dynamic_disk_capacity_v1` | Applied original is only an added `disk_used_bytes` column; repository file adds extensive functions. Applied `20261012155713_control_center_dynamic_disk_capacity_payloads_v1` explicitly installs the disk-capacity and resource-metrics functions. Current `control_center_disk_capacity_bytes_v1` exists and is STABLE | REVIEW_REQUIRED |
| 7 | `tennis_system_incident_direct_push` | Applied and repo function SQL differ; current `control_center_private.gcc_notify_new_system_incident_v1` exists. Function existence does not prove either historical source is interchangeable | REVIEW_REQUIRED |
| 8 | `public_tennis_home_gallery_20_read` | Repository adds `DROP POLICY IF EXISTS`; applied creates policy. Current storage policy `public_tennis_home_gallery_20_read` exists for `anon` and `authenticated`. Different behavior if policy preexists | REVIEW_REQUIRED |
| 9 | `premium_statistics_intelligence_v1` | Applied initial function is STABLE, repository declares VOLATILE. Applied `20261020063247_premium_statistics_intelligence_volatility_fix` explicitly runs `ALTER FUNCTION ... VOLATILE`. Current function `get_premium_statistics_intelligence_v1` has `provolatile='v'` | REVIEW_REQUIRED |

## Engineering interpretation

For items **3, 4, 6 and 9**, the *intended final state* is corroborated by a named later migration, but this **does not remove the discrepancy** in an ordered historical replay. Running the repository replacement early may produce a different intermediate state, fail on a missing dependency, or collide with the later corrective migration. Keep all nine blocked until a version-matched sandbox replay verifies the exact sequence.

For items **1, 2, 5, 7 and 8**, no complete replacement/equivalence proof has been established. In particular, adding/reordering RLS policies or incident-processing logic requires separate security and business behavior review.

## Read-only verification contract

`tests/helios_h08_divergence_current_state_readonly.sql` checks a **small set of current-state facts**, not the full migration history: Premium statistics VOLATILE, disk-capacity function STABLE, training-camp function exists, and both reviewed storage read-policy names exist. It uses `BEGIN READ ONLY` and `ROLLBACK` and reads only PostgreSQL catalog metadata. It does not query user rows, modify policies or execute application functions.

**Release gate:** All nine remain explicitly `REVIEW_REQUIRED` and full historical replay **BLOCKED**. Retention approval, original missing-name migration recovery and complete isolated database replay remain pending. Guest Mode and physical Auth deletion stay OFF.
