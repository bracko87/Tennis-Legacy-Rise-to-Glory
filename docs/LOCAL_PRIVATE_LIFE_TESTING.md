# Tennis Legacy — Private Life & private-jet localhost testing

**Development source:** `main` (the old `staging` branch is inactive).  
**Production safety:** Netlify builds remain stopped. Never apply these unfinished migrations to live Supabase `cwfznmroiqcyhfkfcrow` merely to test localhost.

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

The Supabase CLI should run the repository's migration chain **locally** against a Docker database. This repository currently contains **591 migrations**, so the first initialization can be substantial; do not assume everything is ready unless the command finishes without errors. Local services normally use:

- API: `http://127.0.0.1:54321`
- Database: `127.0.0.1:54322`
- Supabase Studio: `http://127.0.0.1:54323`
- Local email inbox: `http://127.0.0.1:54324`

Run `npx supabase status -o env` to get the **local** `ANON_KEY` (or the locally generated publishable key if your CLI provides one). Do **not** use the production project's key for an isolated local test.

If the 591 migrations fail, **stop and share that error**. Do not run `supabase db push`, `supabase link`, or any production SQL operation as a workaround. `supabase db reset --local` destroys **only your local** data; do not run that command if you have created local test accounts you need to keep.

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

A hosted **Supabase development branch** would be required for equivalent backend testing. The project-specific branch estimate obtained on October 26, 2026 was **$0.01344 per hour**, subject to service billing conditions. I have **not** created or authorized a billable branch. Ask for an isolated branch explicitly, approve that cost, and use its **development** API URL and publishable key with the same build overrides.

## Release boundary

Changes are on GitHub `main`, but neither Netlify production deployment nor production Supabase migration has been authorized. These local instructions are **for testing**, not permission to publish.
