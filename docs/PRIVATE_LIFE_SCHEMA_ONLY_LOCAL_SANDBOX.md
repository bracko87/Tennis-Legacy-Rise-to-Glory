# Private Life — isolated localhost schema snapshot (no paid branch)

**Source branch:** GitHub `main`. **Production database and website:** unchanged.

## What this solves

The game repository contains 591 historical migrations, but its early staff migrations were not sufficient to recreate the current production database from empty tables. Consequently the normal `npx supabase start` in the project root fails before any October 26 Private Life code is reached.

This optional workflow uses a **read-only schema export** of the *existing game database*, then applies only the three unreleased Private Life migrations in a **separate local Docker database**. It does not copy player accounts, career balances or purchases, and it does not execute a DDL statement on production.

**Status: the setup script now runs an automated read-only structural SQL smoke test against the isolated LOCAL Docker database after migrations. A complete real schema restore and logged-in browser playthrough remain UNVERIFIED.** Do not interpret these instructions as a guarantee that existing account registration or tournament seed data works locally.

## Before starting

- Node.js and npm, Docker Desktop, Supabase CLI and access to your existing game Supabase project.
- Take care with production credentials. Never post a database password or full dump in chat, GitHub or a public repository.
- Only use the Supabase CLI commands shown below. In particular, **never run `supabase db push` or `supabase db reset --linked`** on the production project.

## One-command Windows setup (recommended)

I added an interactive, guarded Windows command script that does Steps 1 and 2 in order. In a Windows **Command Prompt** at the Tennis Legacy repository root:

```cmd
git pull origin main
scripts\setup-private-life-sandbox.cmd
```

**What the script does:** checks Docker Desktop and Node.js; authenticates Supabase CLI; links to the existing project; runs a **read-only schema-only dump**; creates an isolated local project; inserts minimal **local-only reference data before** the three Private Life migrations; starts local Supabase on port 54331; attempts to apply those migrations; runs `tests/private_life_career_db_smoke.sql` against the **local Docker database only** to verify the new schema/RLS and hourly job; prints its own local anon key on success. It does not run any remote reset or deploy. **Supabase login and linking may still require you to approve access or provide your database password locally. Never paste credentials into chat.** Stop and share only the first non-secret error if setup fails.

This is **not yet a certified end-to-end workflow**: the actual current production-schema dump has not been restored successfully into Docker, and local player creation/seed data may still require fixes. Passing the new local SQL smoke test does not mean the gameplay ticket is complete: the dump has schema only; the sandbox now adds a **small local-only synthetic reference seed** (nine approved jet models, one noneligible propeller plane, a watch, car, house and three cities). It still has no real player accounts, Premium entitlements, uploaded catalog images or tournament fixtures. Separate synthetic reference data and authenticated UI testing are still necessary.

If you prefer running commands individually, follow the manual instructions below.

## Step 1: download schema only (Windows CMD in Tennis Legacy root)

```cmd
git pull origin main
mkdir .private-life-schema
npx supabase login
npx supabase link --project-ref cwfznmroiqcyhfkfcrow
npx supabase db dump --linked --schema public -f .private-life-schema\existing.sql
```

`supabase link` configures how the CLI finds the project; it does **not** by itself apply migrations. `db dump` without `--data-only` generates schema, not user data. Your local files are ignored by Git.

If the dump fails, stop. Do not try `db reset --linked`. The schema may contain stored function definitions and must stay private even though it has no personal records.

## Step 2: prepare isolated migration stack

```cmd
node scripts\prepare-private-life-sandbox.mjs .private-life-schema\existing.sql
cd .private-life-sandbox
npx supabase start
npx supabase status -o env
```

The generator creates a **separate** project and copies `tests/private_life_sandbox_reference_seed.sql` as a LOCAL migration ahead of the three feature migrations. The file does not belong in the real production migration history. This sandbox has API `http://127.0.0.1:54331`, database `54332`, Studio `54333`, and mail UI `54334`. It loads the schema-only snapshot, restores the five current custom authentication triggers against the **local auth.users table**, and attempts the three new Private Life migrations.

If `supabase start` or the subsequent local SQL smoke test reports any error, do not proceed with gameplay testing or apply those migrations to production. Fix the sandbox schema mismatch first. The snapshot is a test artifact, not a replacement for a correct historical migration chain.

## Step 3: point the frontend at the local database (second CMD window, game root)

Get the local `ANON_KEY` from `npx supabase status -o env` in the sandbox terminal, then:

```cmd
set TL_SUPABASE_URL=http://127.0.0.1:54331
set TL_SUPABASE_PUBLISHABLE_KEY=PASTE_LOCAL_ANON_KEY_HERE
set TL_DEV_PORT=8001
npm run dev
```

Open **http://localhost:8001**. Do not use the live production key for this local database.

The new local database contains **no real user data**. You must create a *local-only* account and may need valid registration invites, seeded tournaments, local Premium access and test career funds to test all game interactions. The seeded catalog images are intentionally absent, and tests must never reuse real production accounts or balances. Production player accounts, purchases and balances will not appear.

## What to verify after successful startup

1. Private Life → Overview: actual morale, Home Base, current location (not an inactive preview).
2. Private Life → Buy an item: morale cap/decay; Home Base residence movement without nationality changes.
3. Marketplace: the nine approved private jets show direct-flight range/seats/operating cost; other aircraft remain lifestyle-only.
4. Schedule → Tournament Preparation: owned eligible jet carries player plus staff with **one operating charge**; an out-of-range jet automatically uses commercial flights.
5. Preferences: tournament travel choice persists after reload.
6. Profile: current Home Base appears separately from nationality.

Until every test passes with a local authenticated player and a full schema restore, the Private Life ticket is **not certified ready for production release**.

## Cleanup

Stop the frontend with Ctrl+C; in the sandbox directory run `npx supabase stop`. Your production project is unaffected. Keep the local schema dump private and delete it when no longer needed.

## Alternative

A paid development branch was approved, briefly created and **deleted on 2026-10-26** after repeatedly failing historical, data-dependent migrations. No paid QA branch remains. Avoid recreating it until the historical migration chain is made replayable.
