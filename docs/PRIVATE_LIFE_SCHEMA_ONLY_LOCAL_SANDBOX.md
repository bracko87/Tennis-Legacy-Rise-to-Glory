# Private Life — isolated localhost schema snapshot (no paid branch)

**Source branch:** GitHub `main`. **Production database and website:** unchanged.

## What this solves

The game repository contains 591 historical migrations, but its early staff migrations were not sufficient to recreate the current production database from empty tables. Consequently the normal `npx supabase start` in the project root fails before any October 26 Private Life code is reached.

This optional workflow uses a **read-only schema export** of the *existing game database*, then applies only the three unreleased Private Life migrations in a **separate local Docker database**. It does not copy player accounts, career balances or purchases, and it does not execute a DDL statement on production.

**Status: preparation script is implemented and unit-tested. The complete real schema restore is NOT yet verified.** Do not interpret these instructions as a guarantee that existing account registration or tournament seed data works locally.

## Before starting

- Node.js and npm, Docker Desktop, Supabase CLI and access to your existing game Supabase project.
- Take care with production credentials. Never post a database password or full dump in chat, GitHub or a public repository.
- Only use the Supabase CLI commands shown below. In particular, **never run `supabase db push` or `supabase db reset --linked`** on the production project.

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

The generator creates a **separate** project with API `http://127.0.0.1:54331`, database `54332`, Studio `54333`, and mail UI `54334`. It loads the schema-only snapshot, restores the five current custom authentication triggers against the **local auth.users table**, and attempts the three new Private Life migrations.

If `supabase start` reports any SQL error, do not proceed with gameplay testing or apply those migrations to production. Fix the sandbox schema mismatch first. The snapshot is a test artifact, not a replacement for a correct historical migration chain.

## Step 3: point the frontend at the local database (second CMD window, game root)

Get the local `ANON_KEY` from `npx supabase status -o env` in the sandbox terminal, then:

```cmd
set TL_SUPABASE_URL=http://127.0.0.1:54331
set TL_SUPABASE_PUBLISHABLE_KEY=PASTE_LOCAL_ANON_KEY_HERE
set TL_DEV_PORT=8001
npm run dev
```

Open **http://localhost:8001**. Do not use the live production key for this local database.

The new local database contains **no real user data**. You must create a *local-only* account and may need valid registration invites, seeded tournaments and local career funds to test all game interactions. Production player accounts, purchases and balances will not appear.

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

A hosted development branch may be easier to test against the complete existing Supabase schema, but creates hourly compute charges and needs your explicit approval. No paid branch has been created.
