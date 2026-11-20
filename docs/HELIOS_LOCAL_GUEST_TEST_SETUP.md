# Project Helios — Isolated real-Auth guest testing (Windows CMD)

**Status:** Setup scripts committed; the complete local schema restore and actual anonymous browser session have **not yet been executed**. This is not a production deployment or sign-off for expired-account hard deletion.

## Purpose and boundaries

This project uses a distinct Supabase Docker stack with **local anonymous Auth enabled only there**, local port 54341, and a local browser frontend on 8002. It never uses production user data. Existing public Tennis Legacy website (and ordinary `npm run dev`) remain connected to the production Supabase instance; **only `npm run dev:helios-guest` uses the local sandbox**. Do not test guest creation on 127.0.0.1:8001 when ordinary `npm run dev` is running: that build may connect to production.

Requirements: Windows CMD, Node.js/npm, Docker Desktop, Supabase CLI, valid Supabase login for a schema-only read of the Tennis Legacy project. These commands are a schema-only export and LOCAL Docker writes; no account records, finance or tournament data are copied.

## Step 1 — obtain the schema-only snapshot

From the Tennis Legacy repository folder (use normal CMD and confirm the correct Git repository):

```cmd
git pull --ff-only origin main
mkdir .helios-guest-schema
npx supabase --version
npx supabase db dump --help
```

Verify the CLI's dump flags. Recent Supabase CLI versions use `--remote` to select the linked project; older versions use `--linked`. If the project is not already linked, run `npx supabase link --project-ref cwfznmroiqcyhfkfcrow` first after login. Confirm the linked project is **Tennis Legacy**, not Airlinerra or ProPeloton.

With a CLI version supporting `--remote`:

```cmd
npx supabase db dump --remote --schema public,control_center_private --file .helios-guest-schema\schema.sql
```

For older versions, use `--linked` instead of `--remote`, if shown in help. The dump is schema-only by default; **DO NOT USE `--data-only` or `--role-only`**. Never commit or upload this schema file. Although no data is included, stored function definitions can contain internal settings.

Do not run any `db push`, `db reset --linked`, `db reset --remote`, or `apply_migration` commands on the linked production project.

## Step 2 — generate a fresh local sandbox

```cmd
node scripts\prepare-helios-guest-sandbox.mjs .helios-guest-schema\schema.sql
```

The generator refuses an existing `.helios-guest-sandbox` folder and refuses any dump missing guest dependencies or showing data sections. It creates a *different Supabase project ID* and a separate port range from the existing Private Life sandbox.

```cmd
cd .helios-guest-sandbox
npx supabase start
```

The first start imports the schema-only snapshot, recreates the seven reviewed Auth triggers for local GoTrue, and enables anonymous login and the guest gate **only in local Docker**. It will stop if the schema doesn't restore cleanly; save the **first error** and report it instead of applying changes to production. The old historical `staff_members` migration-order issue may affect older migration replays, but a fresh schema-only snapshot avoids replaying the entire historical migration chain. Other full-schema dependencies might still prevent restore.

## Step 3 — start the safe local website

Use a **second CMD window** in the original Tennis Legacy repository folder:

```cmd
npm run dev:helios-guest
```

This launcher reads the running *local Supabase status*, extracts only the browser-safe public key, and refuses any backend URL other than `http://127.0.0.1:54341`. It does not print the local service-role key.

Open `http://127.0.0.1:8002` in a private/incognito browser. **Do not use your regular signed-in production browser tab**, and do not reuse 127.0.0.1:8001.

## Step 4 — acceptance checks (run on local data only)

- [ ] Local Supabase starts with no schema errors and no existing `auth.users` records
- [ ] Local homepage shows **Try as Test Player**, while public production website does not
- [ ] Create local anonymous Auth identity, 14-day guest enrollment and 7-day Premium entitlement
- [ ] Create human test player with first/last name, country and selected appearance, without city or birthday
- [ ] Verify original Auth user ID, no extra welcome/referral credits, starting game finances and ranking bottom position
- [ ] Verify equipment, staff, calendar and tournament application using **synthetic** local tournament seed; no real production player data
- [ ] Register existing guest via local email/password link; same Auth/user/player ID and retained progress
- [ ] Verify session recovery, expired/no-conversion blocking and walkover against synthetic local fixtures
- [ ] Verify doubles, in-progress matches, read-only historic matches and repeated expiry
- [ ] Check zero production database writes before any public launch

Google OAuth linking cannot be tested locally until a separate **test OAuth provider and callback configuration** are created. No real OAuth client secrets should be committed.

**Not included:** Actual hard deletion of `auth.users` (still blocked by FK retention review). Guest trials currently retire players after 14 days; that is not physical deletion. Do not enable a deletion job to make local E2E easier.

## Current handoff / blockers

1. Schema-only snapshot must be produced by an authenticated local operator; no remote account data should be exported.
2. Run local Supabase start and resolve any schema-only restore error on the **local** stack.
3. Add synthetic reference and tournament data if game onboarding depends on catalogs.
4. Run true browser Auth conversion, gameplay and expiration E2E using the local stack.
5. Finish PR #47's history/finance-aware erasure design separately.

No paid Supabase branch has been created, and the production guest switch is unchanged.
