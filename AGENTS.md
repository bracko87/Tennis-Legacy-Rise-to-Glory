# Agent instructions — Tennis Legacy: Rise to Glory

These repository instructions are the **source of truth for every coding assistant**, including ChatGPT conversations, Codex, and connected agents. Read this document and `docs/RELEASE_PROCESS.md` before editing code or workflows.

## Public development — MAIN ONLY (effective 2026-10-20)

- The repository is deliberately **PUBLIC for the development phase**. **`main` is the ONLY active development branch.** All ordinary bug fixes, new features, translations, tests, and documentation must target the latest `main`, not `staging`.
- `staging` remains as an INACTIVE, read-only historical backup. Do not push to `staging`, open PRs against it, or merge it into `main` again. Do not delete it unless the owner explicitly asks.
- Fetch the latest `main` SHA immediately before modifying GitHub files. Synchronize with other workers and do not force-push or reset away existing commits.
- **Public GitHub code is NOT authorization to publish unfinished changes on the Tennis Legacy website.** The owner confirmed that Tennis Legacy's Netlify builds are STOPPED during public main-only development. Keep them stopped. Do not unpause builds, trigger manual production deploys, change the Netlify site production branch or deploy Supabase migrations/functions without explicit owner authorization.
- Main-only development plus an automatically deploying Netlify production branch is unsafe for unfinished work. If builds are ever resumed while development continues, first agree on a deliberate deployment-gating policy with the owner. Do not assume `main` pushes are safe to publish.
- Never commit credentials, live Stripe/Supabase secrets, personal information, user records or payment card details to this PUBLIC repository or its history. Use protected service environment variables and database access controls. Making this repository private again will not revoke public copies/forks.
- Standard GitHub-hosted runners are free while the repository is public. Storage, special runners, Netlify builds, Supabase and other services may still incur costs. If the repository becomes private after launch, review Actions workflow frequency and the spending budget before continuing CI.
- GitHub's default branch is already `main`. Specify `branch: main` explicitly in automated write tools; never rely on a stale staging convention.

## Owner-directed LIVE operational alert change — 2026-10-27

- The owner explicitly directed: **STOP Tennis Legacy system incident alert emails; keep incident alerts via Game Control Centre push only.** This was applied **directly in the live Tennis Legacy Supabase project** `cwfznmroiqcyhfkfcrow`, independently of the Netlify deployment/build freeze.
- All rows of `public.system_monitor_processes` now have `email_alerts_enabled=false`. Two pg_cron jobs were disabled in place: `tennis-system-alert-email-dispatch-v1` (job 43) and `tennis-critical-incident-reminders-v1` (job 47). There were zero unprocessed `public.system_alert_email_outbox` messages at the time of the change. This prevents both new queued system incident emails and recurring reminders. **Do not silently restore these flags or cron jobs** during incident/watchdog work.
- **Do not disable monitoring or Control Centre push:** `tennis-system-health-watchdog-v1` (job 27) remains active; the `gcc_direct_system_issue_push_v1` trigger on `public.system_incidents` remains enabled and delegates to `control_center_private.gcc_notify_new_system_incident_v1()`. Other transactional/gameplay email flows, including `tennis-birthday-email-dispatch-v1`, were deliberately left intact.
- The independent underlying watchdog incident reported `connection failed` and remains to be diagnosed; turning off email is not a claim that the health issue is fixed. A future code release must preserve these owner-selected channels and avoid recreating incident-email schedules.

## Validation and release safeguards

- Preserve all existing game features and premium modules. Continue critical checks: `npm run check:pt`, `npm run check:preferences`, `npm run check:seo`, `npm run build`, and the CPX Earn Free Coins assertion in CI.
- The consolidated workflow `.github/workflows/tennis-cpx-build.yml` runs on pushes/PRs to `main` and on manual dispatch; specialized test workflows remain manual-only. Passing CI is a source check, NOT authorization to deploy production.
- Run local tests before meaningful pushes when possible. Do not reduce test coverage to save Actions minutes; routine standard-runner CI is free while public.
- The owner must explicitly authorize any production Netlify deployment, Supabase migration, Edge Function, Stripe/payment change or transition back to private. Do not confuse source-code commits with release approval.
- Read and follow `docs/RELEASE_PROCESS.md` on `main` for the release and deployment gate.

## Cross-chat scope

These rules apply to every Tennis Legacy chat/agent. Do not edit Airlinerra, Famioo, ProPeloton Manager, Game Control Center or other repositories as part of a Tennis Legacy task. Written rules alone are not technical enforcement of Netlify settings.
