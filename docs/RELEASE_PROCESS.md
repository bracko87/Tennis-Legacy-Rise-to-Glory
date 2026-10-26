# Tennis Legacy — public development, main-only workflow

## Current status (effective 2026-10-20)
- Repository is **PUBLIC** during development, with all completed `staging` history safely consolidated into `main`. The old `staging` branch is left untouched as an inactive backup.
- All normal source edits, translations, bug fixes, premium modules and documentation use **`main` only**. Do NOT use `staging` for new work.
- Tennis Legacy's existing production website is hosted through Netlify. The owner confirmed **Netlify builds are stopped** so `main` commits do **not** automatically redeploy unfinished features.
- Keep Netlify builds stopped until the owner expressly approves a deployment or launch. Do NOT silently resume Netlify, bypass deployment controls, alter the Netlify production branch or update live Supabase/payment systems as a side effect of a GitHub commit.

## Everyday development
1. Read `AGENTS.md` and this document on `main`.
2. Verify the remote `main` head; make incremental, validated commits there. Leave legacy `staging` untouched.
3. Use `npm ci`, `npm run check:pt`, `npm run check:preferences`, `npm run check:seo`, `npm run build` and relevant feature tests for local validation. CI also validates public `main` pushes.
4. `.github/workflows/tennis-cpx-build.yml` provides one consolidated test/build gate; specialized workflows under `.github/workflows` remain manual (`workflow_dispatch`) only.
5. Do not store secrets, real user records, payment card data, Supabase service-role credentials or private Stripe API keys in Git.
6. Standard public-repository GitHub-hosted runners have no per-minute bill. Other GitHub usage, Netlify, Stripe or Supabase charges are independent.

## Separating source changes from publication
- **Committing code to `main` does not mean the game website has been published or updated.** Netlify builds must remain stopped during this phase.
- Before a deliberate release, inspect all outstanding main changes, run validation, review migrations/secrets and confirm correct environment configuration.
- Only with explicit owner approval may builds be resumed or a deployment triggered. Once automatic deployment of `main` is resumed, subsequent `main` pushes could publish unfinished work; settle a deployment gate first if development will continue.
- Do not apply Supabase migrations, deploy Edge Functions, alter Stripe live products/keys or send production emails as part of this source-branch migration.

## Transition back to private at launch
- Perform a secret/history and privacy audit, rotate exposed credentials if any, and have the owner switch GitHub visibility to private.
- Switching back does NOT revoke public clones or forks made during development.
- When private, re-evaluate CI schedules and GitHub Actions budget because standard-runner minutes may again be metered.

## Project isolation
These instructions apply to Tennis Legacy only, not Famioo, Airlinerra, ProPeloton Manager, Game Control Center or other repositories.
