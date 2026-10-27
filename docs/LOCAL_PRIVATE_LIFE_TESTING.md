# Tennis Legacy — Private Life & private-jet localhost testing

**Development source:** `main` (the old `staging` branch is inactive).  
**Production safety:** Netlify builds remain stopped. Never apply these unfinished migrations to live Supabase `cwfznmroiqcyhfkfcrow` merely to test localhost.

## Windows CMD workflow — no changes to your normal build/start commands

Your usual commands **still work as before** for existing Tennis Legacy screens:

```cmd
git pull origin main
npm run build
npm run dev
```

This is the **LIVE-connected UI preview**. `npm run build` always compiles the normal production-targeted website and **never** applies SQL migrations. Publishing remains a separate, owner-approved release step; do not unpause Netlify or upload unfinished changes to hosting.

For an **isolated Private Life local database**, make a one-time Docker Desktop/WSL 2 installation on Windows, start Docker Desktop using Linux containers, then run from the same existing CMD repo folder:

```cmd
git pull origin main
scripts\setup-private-life-sandbox.cmd
```

The sandbox script reads the current hosted `public` schema through Supabase CLI, with a **schema-only** read; all Private Life SQL changes are applied only to Docker. It may require Supabase browser authentication and a database password on the local computer. Do not share passwords, SQL dumps, or service-role keys. The first complete schema restore has **not** been independently validated and may require fixes.

If and only if the sandbox setup reports a successful local SQL smoke test, continue in your normal CMD project directory:

```cmd
npm run build
npm run dev:private-life
```

Open `http://localhost:8001`. **No manual key copying or PowerShell**: the command reads the local publishable/anon key from `supabase status -o env`, validates `http://127.0.0.1:54331`, and refuses any hosted endpoint. It never prints privileged keys. If Docker is not running, it stops with an explanation instead of accidentally accessing production.

Important: `npm run dev` is deliberately **unchanged** for ordinary existing live-connected local browsing, and `npm run dev:private-life` is the clearly distinct command for isolated local-only feature testing. When the local sandbox is stopped, re-open Docker Desktop and from `.private-life-sandbox` run `npx supabase start` before launching the Private Life testing command. The local database initially has no hosted user accounts, financial records, Premium entitlements or full tournament seed data. A successful schema restore alone is not full gameplay certification.

**Docker installation from CMD** (requires Windows 10/11 with WSL 2 and virtualization):

```cmd
winget install -e --id Docker.DockerDesktop
```

Then open Docker Desktop once, accept its terms, use the WSL 2 / Linux container backend and check with `docker info` in a **new** CMD window. If WSL is missing, open **CMD as administrator** and run `wsl --install`, then reboot when instructed. You never need PowerShell. Official setup guide: https://docs.docker.com/desktop/setup/install/windows-install/

## CMD-only owner: GitHub-hosted QA available (2026-10-27)

**You do NOT need PowerShell or Docker Desktop to run our current automated Private Life migration tests.** The hosted GitHub Actions job `private-life-combined-migrations` uses a disposable PostgreSQL database on GitHub's runner. [Latest complete PASS](https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40484644804).

It applies the three Private Life migrations unchanged to synthetic compatible schema and verifies real user-facing career/jet-booking RPCs, six-staff travel accounting, one-time settlement, commercial fallback and profile fields. Production remains untouched.

**The Docker commands below are OPTIONAL for developers**, not instructions the owner must follow. Running `npm run dev` in CMD still points at the existing live backend unless explicit local overrides are set, and the live backend **does not have** the unreleased Private Life schema. The GitHub database is a short-lived CI service and cannot be used as a persistent local browser backend. Therefore **this hosted CI success does not make the Private Life screens playable in localhost**.

To complete the release gate, a safe full-schema, full-Supabase nonproduction environment and a real authenticated browser playthrough are still required. The previous paid data-free development branch failed historical replay and was deleted. Do not create a new paid branch or deploy to production without fresh explicit authorization.

## Current integration status — 2026-10-26

- **Code is already committed to GitHub `main`** and the normal website build, Private Life booking/settlement/fatigue and cross-player ownership regression tests have passed.
- **Full fresh local database boot is currently BLOCKED** by an older migration, `supabase/migrations/20260903081216_remove_staff_ranking_requirements.sql`, which calls `update public.staff_members` before that table exists in a newly initialized database. The isolated end-to-end `supabase start` GitHub job failed at that migration, **before reaching the three October 26 Private Life migrations**: [full-stack failure log](https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40328987767).
- The instructions below explain the intended local setup, but **do not currently produce a full playable Private Life environment from a fresh clone**. Please do not mistake a successful `npm run dev` frontend build for a complete functional test.
- We are not rewriting already-applied historic migration files or applying private-life DDL to the live project as a shortcut. A production-based **isolated Supabase development branch** can avoid the missing historical bootstrap, but requires explicit billing approval (see below).

## Alternative: existing-schema local test environment (no new paid Supabase branch)

The repository now provides a schema-only local sandbox generator and Windows instructions: **[Private Life schema-only local sandbox](PRIVATE_LIFE_SCHEMA_ONLY_LOCAL_SANDBOX.md)**.

This avoids replaying all 591 historical migrations. Export only the **existing schema** with the read-only Supabase CLI dump command, keep the dump in the ignored local folder, and generate a separate Docker stack that applies just the three new Private Life migrations. Nothing is pushed to live Supabase.

**Important:** This preparation has passed unit tests and the underlying game functions have passed disposable PostgreSQL integration tests, but the actual full production-schema dump → restore → browser workflow has not yet been verified. Stop if the schema restore reports an error; never run remote database reset or migrations to fix local testing.

## Prerequisites

- Node.js 22 and npm
- Docker Desktop running (or a supported Docker-compatible runtime)
- Supabase CLI ([official local-development instructions](https://supabase.com/docs/guides/local-development/cli/getting-started))
- An up-to-date checkout of `bracko87/Tennis-Legacy-Rise-to-Glory`

The repository now contains `supabase/config.toml` for a local-only project. It does **not** link to production, copy production user records, or contain service-role credentials.

## 1. Pull the finished source code

From a PowerShell terminal opened in your existing Tennis Legacy project:

```powershell
git switch main
git pull origin main
npm ci
```

These source changes are **already on main**. No staging-to-main merge is needed.

## 2. Start an isolated Supabase stack

Docker Desktop must be running.

```powershell
npx supabase --version
npx supabase start
npx supabase status
```

The Supabase CLI attempts the repository's migration chain **locally** against a Docker database. This repository currently contains **591 migrations**, and as of October 26 **a fresh run is known to fail** at the September 3 `public.staff_members` dependency described above. Do not proceed to functional gameplay testing unless this historical schema bootstrap is fixed and `supabase start` completes successfully. Local services normally use:

- API: `http://127.0.0.1:54321`
- Database: `127.0.0.1:54322`
- Supabase Studio: `http://127.0.0.1:54323`
- Local email inbox: `http://127.0.0.1:54324`

Run `npx supabase status -o env` to get the **local** `ANON_KEY` (or the locally generated publishable key if your CLI provides one). Do **not** use the production project's key for an isolated local test.

If the 591 migrations fail, **stop and report the error**; the missing early staff table is already tracked. Do not run `supabase db push`, `supabase link`, or any production SQL operation as a workaround. `supabase db reset --local` destroys **only your local** data; do not run that command if you have created local test accounts you need to keep.

## 3. Point the website at local Supabase

In the **same PowerShell window** where you will start the frontend:

```powershell
$env:TL_SUPABASE_URL = "http://127.0.0.1:54321"
$env:TL_SUPABASE_PUBLISHABLE_KEY = "PASTE_YOUR_LOCAL_ANON_KEY_HERE"
npm run dev
```

Open **http://localhost:8000**.

The browser build now substitutes your local API URL and publishable/anon key at compile time. It leaves production credentials and configuration unchanged. Login, signup and game records are **separate** from production, so you must create a **local test account**; you cannot expect your live account, private jet or tournament records to exist locally. Auth confirmation emails, when enabled, go to the local inbox.

Important: running `npm run dev` **without both variables** retains the existing live Supabase connection for backwards compatibility, and prints a strong warning. That is **not** a valid environment for testing these unfinished Private Life features. Configuring only one variable fails rather than silently mixing backends. `npm run build` refuses a test-backend override, to protect production bundles.

When you finish, press Ctrl+C in the frontend terminal, then use `npx supabase stop` to stop the local database.

## 4. What to test

1. **Private Life / Assets:** buy a lifestyle item and verify the temporary morale benefit; check the +3 cap. Own a residential asset and initiate a Home Base move. Home Base must not change nationality.
2. **Schedule → Tournament Preparation → Travel:** buy an approved private jet and select it for an eligible direct journey. Player plus all selected staff must fit onboard and use **one aircraft operating charge**.
3. **Long route fallback:** select a 3,000 km Citation M3 for Serbia → Australia. The UI should say **normal commercial flights**, show the player-and-staff return-ticket estimate, and not show a jet fatigue benefit.
4. **Travel processing:** verify costs, fatigue, location and idempotent completion. The disposable PostgreSQL CI covers these server transitions even if you do not yet have the required local tournament seed data.
5. **Other player ownership:** do not allow one player to access another player's aircraft.

A new local account may not have Premium entitlements, starting cash, airport/world configuration or seeded tournament entries needed to reach every screen. The source/database tests validate the key business logic without requiring a production dataset. **No full manual browser playthrough has yet been certified.** If any prerequisite is missing, do not modify production to work around it.

## 5. Developer-only checks

```powershell
node --test tests/lifestyleCareerContract.test.mjs
npm run check:pt
npm run check:preferences
npm run check:seo
```

GitHub Actions runs the application build, syntax checks, purchase/travel settlement scenarios and denied foreign-jet bookings against disposable Postgres. Passing those checks is not proof that an end-to-end seeded Supabase session or real browser scenario works.

## If you cannot run Docker

A hosted **Supabase development branch**, created from the existing full production schema without user data where supported, is the recommended alternative while the historical local migration chain is broken. The project-specific branch estimate obtained on October 26, 2026 was **$0.01344 per hour**, subject to service billing conditions. I have **not** created or authorized a billable branch. Ask for an isolated branch explicitly, approve that cost, and use its **development** API URL and publishable key with the same build overrides.

## Release boundary

Changes are on GitHub `main`, but neither Netlify production deployment nor production Supabase migration has been authorized. These local instructions are **for testing**, not permission to publish.
