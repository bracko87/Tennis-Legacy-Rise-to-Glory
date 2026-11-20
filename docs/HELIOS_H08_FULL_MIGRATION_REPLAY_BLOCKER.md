# Helios H08 — Historical migration replay investigation

**Date:** 20 November 2026. Diagnostic performed in GitHub Actions against the repository checkout. This is repository inspection, **not** a full database replay or production change.

## Verified

- The repository contains **688** `supabase/migrations/*.sql` files.
- **16** SQL migration files mention `public.staff_members`.
- The scanner found **no `CREATE TABLE public.staff_members`** in any SQL migration file. The scanner is a textual heuristic, so it can miss split statements or dynamic SQL, but it is consistent with the previously observed migration-replay dependency error.
- The first observed reference is `supabase/migrations/20260903081216_remove_staff_ranking_requirements.sql`, **line 2**:

```sql
update public.staff_members
set required_rank_position = null
where required_rank_position is not null;
```

- The same migration also creates a trigger on `public.staff_members` and a staff hiring function referring to it. Applying it to a database without that table will fail.

## Diagnosis

The historical migration chain appears **not to be self-bootstrapping**. At least one original base table definition may have been created before migration files were tracked, or exists only in a separately maintained schema snapshot. Blindly adding `CREATE TABLE IF NOT EXISTS` to a late migration would mask the problem and risk an incorrect production structure.

## Required repair path

1. Recover the authoritative **original base schema** and database objects, not just a guessed minimal definition of `staff_members`. Source can be an existing, reviewed schema snapshot or a read-only schema-only dump of the live database, but never copy actual users/player/private data into a GitHub fixture.
2. Identify all other base objects missing before the first migration (e.g. `players`, contracts, finance and Auth functions), as well as dependencies between them.
3. Establish an **isolated baseline-plus-incremental** replay process with explicit starting-version boundaries. Do **not** apply an up-to-date live schema snapshot and then blindly replay old migrations that predate that snapshot.
4. Replay against disposable GitHub Actions PostgreSQL/Supabase containers, correct ordering only after reviewing effects, then test guest erasure against the complete schema.
5. Keep all real Auth account deletion disabled until full-schema erasure tests and approved retention decisions are complete.

## Safety and limits

The diagnostic script `scripts/helios-diagnose-staff-migration-order.mjs` only reads SQL files. It does not execute SQL or change production. It is not an automated migration repair. A source-text match is not a reliable SQL parser; treat the findings as targeted evidence and review actual DDL.

**Current release gates:** Production Guest Mode OFF. Physical guest deletion OFF. Full-schema migration replay **NOT yet passing**. The existing disposable subset integration tests do not substitute for it.
