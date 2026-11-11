# Tennis Legacy — two real-day transition protocol (11 Nov 2026)

## Release state

The two database migrations are installed in the **Tennis Legacy** project:
- `20261111120000_season_transition_two_real_days_v1.sql`
- `20261111121000_season_transition_preseason_january_applications_v1.sql`

The controller `tennis-season-transition-two-day-v1` runs every minute.
As checked 11 Nov 2026, status was `off`, Season 2 clock remained at 2x,
and the current Season 1→2 migration was not restarted.

Frontend changes are committed to `main` and pass the protected release
validation. **Netlify publication remains stopped** under `AGENTS.md`.
The site release must be coordinated before the next boundary.

## Phase A — boundary to migration unlock (minimum 24 actual hours)

- Boundary is Season N, Dec 31 23:59:59 **game time**.
- The official game clock freezes, the web access boundary blocks sign-in
  and dashboard for both new and already-signed-in browser sessions.
- The maintenance screen displays a **real-world** reopening timestamp,
  formatted in each visitor's device time zone.
- The authoritative timestamp is stored in UTC in the private maintenance row.
- The migration operator must run the verified N→N+1 migration with the
  actual approved step runner. The scheduler **does not invent or execute**
  an unfinished migration.
- If a complete run with operator approval, financial/contract validation,
  and the postcheck is not present when the 24 hours expire, the game stays
  locked. The website displays a delay notice instead of a false promise.

## Phase B — full 24 actual hours of frozen preseason

- Can start **only** after Phase A has lasted at least 24 real hours and the
  migration is recorded as completed with its postcheck.
- Game time is Season N+1, January 1, 00:00, effective speed 0.
- Player sign-in / dashboard returns, and a dismissible preseason popup shows
  the **actual local date/time** the game clock will resume.
- All undrawn January Weeks 1–4 competitions have a new-season application
  window. Week 1 normal close: January 2 at 16:00; late close: 18:00;
  draw publication: 22:00. First matches are scheduled no earlier than
  January 3. Regular eligibility, rank and commitment checks still apply.
- Existing published draws, finance transactions and rankings are not
  rewritten by the new transition controller.

## Phase C — normal play

- After a **full** additional 24 real hours, the private cron scheduler
  resumes the current season's game clock at 2x.
- Public maintenance status returns to `off`, so the temporary popup and
  announcement disappear.
- The end-of-season guard is advanced to protect the next season's December 31.

## Security and deployment boundaries

- The website access gate is a UI/session boundary; database permissions,
  server-side mutations, and external API clients still require the operator's
  protected production maintenance access checklist before migration.
- Cron jobs that depend on the official game speed see effective speed 0
  during both paused periods. Real-world monitoring/telemetry may continue.
- A general automatic **season migration executor is not installed by this
  feature**; the verified existing operator runner remains a required step.
- No Netlify deploy or Stripe changes are authorized by the DB migration.
- Do not simulate or roll the current production clock to demonstrate a
  future year. Test with rollback transactions or isolated data only.
- Keep all changes in `main`; do not merge other projects or Supabase instances.

## Production readiness checklist

1. Before the next end-of-year boundary, publish the verified website UI in a
   coordinated owner-approved release (Netlify currently paused).
2. Certify an N→N+1 runner and a complete transition rehearsal, particularly
   ranking carryover, contracts, player assets and purchases.
3. Ensure the next season calendar exists and is usable at reopening.
4. Enforce the operator's server-side write lock for external/API clients
   during the 24-hour migration window.
5. Test a full cycle with a controlled clock: boundary lock, migration overrun,
   verified completion, 24-hour paused January access, and automatic 2x resume.
6. Inspect cron history and Control Center incidents after each phase.

## Live Season 2 preparation exercise — 11 November 2026

Owner requested a full real-world 24-hour freeze **after** the already-executed
Season 1→2 migration, **without rerunning migration or resetting player state**.

- Started: 11 Nov 2026 11:22:24 UTC (12:22:24 Germany).
- Scheduled resume: 12 Nov 2026 11:22:24 UTC (12:22:24 Germany).
- Actual in-game freeze: Season 2, January 1, **04:00**, the current time
  at activation; this was deliberately not reset to 00:01.
- Database state: `maintenance.status=preseason`;
  `game_clock.is_paused=true`; effective game speed `0`.
- Access state: public `maintenance_active=false` and
  `preseason_active=true`, so existing players can sign in.
- The minute-scheduled controller has succeeded after activation.
- During the first monitored minutes, **zero** new career-finance
  transactions, tournament results, or ranking awards were posted.
- This was **not** a second migration. The preexisting completed run contains
  13 of 13 completed steps; an isolated backup restore was **not** tested.

### Read-only migration audit taken during this exercise

- Six recorded baseline metrics; four remain identical (coin wallets,
  player population, rankings and Season 2 calendar counts).
- Financial baseline differed by **-$5,722**: recorded Season 2 day-one costs
  **-$2,122 private-life costs** and **-$3,600 taxes**, all five balances
  reconciled to their most recent transaction.
- Two technical sponsor contracts originally expiring at the boundary have
  status `completed`; the surviving contract remains `active`.
- Season 1: 0 unfinished matches, 0 unclosed editions, 12 completed finals,
  616 year-end ranking results. Source ranking contribution history remains.
- Player inventory: 29 equipment records owned by five human players;
  seven private-life asset records for human players; no player population or
  coin-balance reset was detected.
- Season 2 calendar: 597 editions, 613 slots, 1,194 competitions, 52 weeks.
  A strict pre-migration readiness checker now fails by design because
  already-generated Week 1 matches exist and one scheduled competition
  (Lima Challenger ATP) was cancelled.
- Week 1: 16 draws published, 5 competitions undrawn, one cancelled.
  Three original post-cutover fingerprints differ due to subsequent
  application/field changes; a historical receipt is not an immutable
  live-state guarantee.
- Backup inventory existed but **independent restore certification and
  isolated two-season simulation were not performed**.

### Website publication

The old "active development" beta popup is removed from `MarketingHeader`
on GitHub `main`, and the new timed Season 2 preparation popup is ready in
`SeasonMaintenanceBoundary`. The Netlify automatic release gate remains
stopped: **the new popup is not independently confirmed as published live**.
The live database phase may therefore precede the website UI release.
