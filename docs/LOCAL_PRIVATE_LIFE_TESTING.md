# Tennis Legacy — Private Life localhost testing (current)

**Updated 27 October 2026.** Development branch: `main`. Netlify builds remain STOPPED and publication still requires the owner's separate approval.

## The usual Windows CMD workflow — unchanged

Open your normal Command Prompt in `C:\Users\Aleks\Desktop\Tennis\Tennis`:

```cmd
git pull origin main
npm run build
npm run dev
```

Open `http://localhost:8000` unless your `TL_DEV_PORT` is configured differently (the terminal prints the actual address).

This remains the approved and simplest everyday development/testing workflow. No Docker, PowerShell, Supabase CLI, test branch, or second frontend command is required to inspect the now-enabled Private Life implementation.

**Important:** `localhost` is only where the FRONTEND runs. Without backend overrides, it connects to the **LIVE** Supabase database. Purchases, morale, home relocation, tournament travel bookings, and finance actions can therefore modify **real game data** even before anything is published to Netlify. Test deliberately; do not assume localhost actions are throwaway.

## Private Life rollout status

On **27 October 2026**, after explicit owner authorization, all three existing Private Life migration files were applied directly to Supabase project `cwfznmroiqcyhfkfcrow`, in order, without running a database reset or changing Netlify:

| Source SQL migration (GitHub main) | Recorded Supabase migration version |
| --- | --- |
| `20261026093000_private_life_career_foundation_v1.sql` | `20261027114153` |
| `20261026094500_private_life_jet_travel_integration_v1.sql` | `20261027114229` |
| `20261026095500_private_life_profile_residence_v1.sql` | `20261027114259` |

The Supabase migration API recorded **new deployment timestamp versions**; the source files retain their earlier creation timestamps. Preserve this mapping when reconciling later CLI migration history. **Do not try to `supabase db push` these three files again or manually alter migration history** to make them match.

Post-deployment read-only checks passed for:

- All four new lifestyle/jet tables; row-level security enabled with authenticated-only read permissions and no anonymous read permission.
- The new career, residence and tournament flight RPCs; nine eligible jet models out of 28 airplanes.
- No change in the existing count of **839** players or **2,418** historical planned travel legs at deployment verification.
- Seven privileged internal travel helper functions no longer directly executable by `anon` or `authenticated` roles.
- Active hourly lifestyle reconciliation scheduled in `cron.job`.

**Not yet certified:** authenticated manual gameplay from a real browser using the upgraded live database. This is the immediate next QA step before any Netlify publication. Note that a legacy backlog of 2,418 old travel legs was found before deployment; it was preserved, not processed or repaired as part of this Private Life release. Investigate separately before performing broad travel reconciliation.

The three unchanged SQL files and synthetic gameplay have already passed the GitHub Actions CI flow: https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/actions/runs/40484644804. That alone is not a substitute for manual browser QA.

## Suggested localhost QA — test cautiously

1. Start with a **read-only inspection** of Private Life → Overview and Player Profile. The previous yellow "Unavailable until the Private Life career database update is deployed" preview message should no longer appear, and Morale, Home Base and Current Location should show values.
2. Verify Private Life → Marketplace displays private aircraft and the new specifications. Browsing and inspecting details is safe.
3. Check Schedule → Tournament Preparation displays an owned private-jet option (only if the account owns a compatible jet and has a valid tournament).
4. Only after the read-only screens look correct, deliberately test purchases or travel actions on the **live** game; they alter player funds, fatigue and other career records and should not be executed as throwaway test cases.
5. If any screen still says the database update is unavailable after pulling current main, do a hard refresh (Ctrl+F5), capture its error and stop; do not rerun migrations.

## Optional developer-only isolated environment

Docker Desktop and `scripts/setup-private-life-sandbox.cmd` were created earlier for *offline* schema testing. They are **not necessary** for your current CMD-to-live-Supabase test process. If you later choose to test experimental database changes without affecting existing players, read [PRIVATE_LIFE_SCHEMA_ONLY_LOCAL_SANDBOX.md](PRIVATE_LIFE_SCHEMA_ONLY_LOCAL_SANDBOX.md), which still describes an unverified isolated schema-restore workflow.

A separate `npm run dev:private-life` command is available ONLY after that local sandbox is successfully initialized. Your existing `npm run dev` is unchanged.

**Release gate:** GitHub source updates and Supabase migrations do not authorize a Netlify build, FTP upload or production website publication. Continue to require explicit final owner approval for that separate step.
