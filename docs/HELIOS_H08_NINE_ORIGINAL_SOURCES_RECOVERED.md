# Helios H08 — Nine historical migration divergences: authoritative sources recovered

**Recovery completed:** Nine original applied SQL texts have been recovered from the production **migration registry**, not from any game or user data. Each one is archived under `tests/recovered-migrations/applied-divergences/` with its original 14-digit applied version, exact source text and recorded MD5.

## Recovered sources

| Original applied version | Migration |
|---|---|
| 20261001163441 | harden_tournament_entry_cancellation_and_alerting |
| 20261001165622 | run_critical_incident_reminder_check_every_minute |
| 20261002112227 | training_camp_reliability_balance_health_v1 |
| 20261002140831 | game_manual_system_health_v1 |
| 20261002182344 | allow_authenticated_curated_player_portrait_reads |
| 20261012155514 | control_center_dynamic_disk_capacity_v1 |
| 20261013052226 | tennis_system_incident_direct_push |
| 20261019122133 | public_tennis_home_gallery_20_read |
| 20261020062737 | premium_statistics_intelligence_v1 |

`tests/recovered-migrations/applied-divergences/manifest.json` maps each to its original version, file, source length and fingerprint. `scripts/helios-verify-recovered-divergence-sources.mjs` runs in credential-free GitHub Actions and fails if any archive differs from its authoritative SQL hash, is renamed to an unsafe path or loses its `REVIEW_REQUIRED` blocker status.

## Exactly what was resolved

The **source-provenance question for all nine** is resolved: what SQL was originally applied is now reproducible and byte-verified. Previous research documents four later fixes that explain observed present-day behavior, and the remaining five have exact applied source too.

**Still unresolved:** The full 812-entry historical replay must use version-correct original sources and needs a complete, safe starting schema with all missing original migration sources. The 9 differences between original SQL and the GitHub variants are still history/replay blockers until the full sequence is tested. Recovered SQL is not automatically deployed, and it would be unsafe to overwrite existing `supabase/migrations` files or run archives against production.

## Required next steps

1. Recover or map the other 227 applied migration names not found in the checked-in repository by version or name, verify source authenticity, avoid secrets and private data in archives.
2. Define an isolated, version-ordered replay path for all originally applied migrations (and any GitHub-only sources separately) with suitable Supabase Auth, Storage, extensions and role initialization.
3. Run full-schema integration tests, including guest retention/erasure and conversion, with synthetic accounts only; approve legal/financial retention rules first.
4. Keep Guest Mode and physical guest account deletion OFF until tests and production access/security reviews pass.

**No production tables, Auth rows, player records, cron jobs or storage policies were changed. No additional paid database was created.**
