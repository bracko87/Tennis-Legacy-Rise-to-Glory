# Project Helios H08 — First 10 applied migration source comparisons

**20 November 2026.** Source SQL was retrieved read-only from the existing Tennis Legacy `supabase_migrations.schema_migrations` table. No account, payment, game, or staff records were read. Applied SQL snapshots are archived outside the auto-deployed `supabase/migrations` folder at `tests/recovered-migrations/same-name-applied-sources-first-ten.json`.

## Verified examples

| Applied migration name | Result comparing production-applied SQL to timestamp-renamed repository file |
|---|---|
| `player_identity_assets_and_countries` | SQL tokens equal; countries data is formatted in different rows |
| `link_player_country_reference` | Equivalent after trimming trailing newline |
| `game_clock_foundation` | Byte-identical |
| `harden_game_clock_read_access` | Byte-identical |
| `allow_authenticated_tennis_logo_read` | Equivalent after trimming trailing newline |
| `switch_dashboard_logo_asset` | Equivalent after trimming trailing newline |
| `avatar_catalog_and_reservation` | Equivalent after trimming trailing newline |
| `harden_avatar_catalog_availability` | Equivalent after trimming trailing newline |
| `continuous_monday_sunday_competition_weeks` | SQL tokens equal; function-body comments and layout differ |
| `limit_training_history_to_three_days` | Equivalent after trimming trailing newline |

Results: **2 byte-identical, 6 trailing-whitespace differences, 2 additional formatting/comment differences with matching SQL token sequences**.

The test `scripts/helios-verify-applied-sql-token-equivalence.mjs` rechecks these exact ten applied-source snapshots against the current repository versions. The scanner treats string literals as atomic tokens, recursively tokenizes PL/pgSQL dollar-quoted function bodies, and ignores whitespace and comments. Any token sequence change causes CI failure.

## What this does and does not prove

For this first batch, there is no detected SQL token difference despite the different migration version timestamps. This does **not** establish semantic equivalence for arbitrary SQL (for example, the scanner is not a full PostgreSQL parser), original execution ordering, database state after each migration, or the other **209 same-name timestamp-renamed migrations**.

An additional **227 migration names** exist in applied history but not in the repository by exact name or version. Those require source recovery or explicit mapping. The original staff-market foundation was separately recovered in PR #74.

Do not rename deployable migration files merely to make their version strings match; the recorded applied versions and new migrations would then diverge further. Keep all recovered applied SQL under nondeployable test directories until a version-aligned plan is verified in disposable PostgreSQL.

**Current safety:** no production SQL executed or changed in this comparison, no additional Supabase project, full historical migration replay still NOT complete, Guest Mode OFF, and physical guest deletion OFF.
