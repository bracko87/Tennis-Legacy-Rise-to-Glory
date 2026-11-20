# Helios H08 — staff_members baseline recovery reference

Verified on **20 November 2026** against **schema metadata only** in the existing live Tennis Legacy database. No staff records, player records, user identities or other gameplay data were accessed.

This is the **current** table structure, **not** proof of its historical September 2026 starting structure. Do not execute a recreated current definition before old migrations: some later migrations add columns and triggers, and older migrations may fail or rewrite assumptions.

## Current columns (23)

| # | Column | PostgreSQL type | Required | Current default |
|---:|---|---|---|---|
| 1 | `id` | uuid | Yes | `gen_random_uuid()` |
| 2 | `market_serial` | bigint | Yes | none |
| 3 | `role` | text | Yes | none |
| 4 | `gender` | text | Yes | none |
| 5 | `first_name` | text | Yes | none |
| 6 | `last_name` | text | Yes | none |
| 7 | `country_code` | text | Yes | none |
| 8 | `overall_rating` | smallint | Yes | none |
| 9 | `quality_tier` | text | Yes | none |
| 10 | `specialty` | text | Yes | none |
| 11 | `attributes` | jsonb | Yes | `'{}'::jsonb` |
| 12 | `base_weekly_salary` | integer | Yes | none |
| 13 | `signing_fee` | integer | Yes | none |
| 14 | `required_rank_position` | integer | No | none |
| 15 | `status` | text | Yes | `'available'::text` |
| 16 | `current_player_id` | uuid | No | none |
| 17 | `created_at` | timestamptz | Yes | `now()` |
| 18 | `updated_at` | timestamptz | Yes | `now()` |
| 19 | `age` | smallint | Yes | none |
| 20 | `experience_years` | smallint | Yes | none |
| 21 | `education` | text | Yes | none |
| 22 | `courses` | jsonb | Yes | `'[]'::jsonb` |
| 23 | `image_path` | text | No | none |

## Current structural dependencies

**13 constraints**, including PK on `id`, unique `market_serial`, FK `country_code → public.countries(code)` (RESTRICT), FK `current_player_id → public.players(id)` (SET NULL), checks on salaries, fees, role, gender, rating, tier, status, employment relationship and optional required rank. Role values currently include `head_coach`, `fitness_coach`, `physiotherapist`, `sports_psychologist`, `performance_analyst`, `agent_manager`.

**5 indexes:** `staff_members_pkey`, `staff_members_market_serial_key`, `staff_members_country_idx`, `staff_members_market_idx`, `staff_members_specialty_idx`.

**4 application triggers:** `staff_members_set_updated_at`, `staff_members_weekly_salary_scale_v2`, `trg_staff_open_hiring`, `trg_staff_profile_defaults_v1`.

**Row-level security:** enabled (not FORCE RLS).

## Why a current schema dump is not a historical bootstrap

The earliest checked-in reference is `supabase/migrations/20260903081216_remove_staff_ranking_requirements.sql`, which updates `public.staff_members.required_rank_position`. A scanner across 688 checked-in migrations found no `CREATE TABLE staff_members`. Later migrations modify `age`, `experience_years`, `education`, `courses` and `image_path`, and update triggers. Today's final structure cannot safely be substituted for the missing original base migration.

## Next actual engineering requirement

Locate or reconstruct the **version-matched starting schema** for the earliest migration. This must include all base dependencies, not just staff_members; recover version boundaries from a historical schema-only snapshot or a deliberate migration baseline. Verify full historical replay on a disposable database before any guest-erasure full-schema test. An isolated current-schema copy is an alternative for testing future guest-erasure migrations, but it **cannot** verify the original historical migration chain.

`tests/helios_live_staff_schema_readonly_contract.sql` checks these live metadata counts and critical columns. It reads only `pg_catalog` and `information_schema`, never table rows. The GitHub Actions workflow checks its source for accidental mutating SQL, but does not connect to the production database.

**Status:** Full historical replay NOT fixed. Guest Mode OFF. Physical guest account deletion OFF. No production changes.
