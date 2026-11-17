# Tennis Legacy — Final Season 1 restart: safety and rehearsal gate

## STATUS UPDATE — DIRECT TEST-GAME RESTART COMPLETED (17 November 2026)

**This supersedes the older separate-project and backup/rehearsal prerequisites below for the disposable TEST season only.** The owner explicitly authorized restarting the existing game directly, and no new Supabase project or charge was incurred.

A full Season 1 reset was first executed within a database transaction ending in ROLLBACK and passed its postconditions. The same reset was then committed on the Tennis Legacy database `cwfznmroiqcyhfkfcrow`. The original 33 controlled cron jobs were paused; 26 had been active and were restored afterward. An additional Premium tournament watcher was also paused and restored. The game clock resumed at 6× speed from Season 1, January 1, 00:00.

Verified after commit and resume:
- Game active at Season 1, January 1, with 6× clock; no other-season editions.
- 834 AI players, 597 Season 1 editions, 1,194 competitions and 613 calendar slots.
- 0 old matches, 0 draw publications, 0 tournament entries or applications; 0 old human test characters.
- AI profile totals match starting values; singles and doubles ranking points reset.
- 6 Auth login records, 6 Premium membership rows, 6 wallets with a total 650 coins, 12 coin ledger rows and 1 billing record preserved; 1 website review preserved.
- 26 previously active game cron jobs restored and the separate Premium watcher resumed; no job failures observed in the immediate post-restart check.
- Public signup still disabled; existing testers can log in and create fresh tennis characters.

**Still unverified:** a complete January–February runtime test after the restart, live browser onboarding, and production public signup. Do not mistake this test restart for final public launch approval.

---


Updated: 2026-11-17. **Preparation only. This is not permission to reset production.**

## Goal
Restart the *gameplay* at Season 1, January 1, 00:00, initially paused, with a clean tournament and ranking history and AI starting values. Leave public signup closed. Do not delete Auth logins, paid memberships, Stripe events, coin balances/ledger, referral Premium benefits or website analytics.

## Changes already prepared in `main`
- The protected static tournament seed layouts are excluded from all gameplay truncation.
- The reset inventory has 149 tables. The dependency analysis on November 17 found **0 foreign keys from preserved tables into that inventory**.
- Five old tournament repair diagnostic rows must be archived to a persistent private evidence table before their referenced matches/results are removed. The script archives them as part of its atomic transaction.
- Referral reward/Premium grant records and website analytics are **excluded from the reset**.
- The script no longer requires 40,000 historical matches, exactly six accounts or a particular historical invoice. Instead it checks structural AI/calendar snapshots and **requires documented final owner approval plus backup-restore and January–February rehearsal references**.
- Restart speed is no longer hardcoded to 2×. Owner selection is required. Current observed live speed was 6×, but that does **not** authorize 6× at release.
- The script compares important account, payment, wallet and referral counts before and after the reset and aborts if these change.

## Mandatory evidence before the destructive final reset
1. **Real backup and restore.** In Supabase: Database → Backups. Verify a current backup, then *restore to a separate project*, not over the active Tennis Legacy database. Verify data, authentication records and initial schema. Record the restore/project reference. A backup being listed is not enough.
2. **Isolated game test with real starting data.** A normal Supabase development branch starts without production data. It is **not sufficient** for this full rehearsal. Use a separately restored project with side effects disabled: billing, emails, webhooks, external alerts, public login and any production job endpoint.
3. **Dry-run the reset there** while the isolated game clock and all game jobs are stopped. Verify 834 initial AI players, 597 Season 1 editions, 1,194 competitions, 613 schedule slots, correct draw-seeding groups, fresh player rankings, empty match histories, and preserved auth/payment/referral evidence.
4. **Simulate January 1–February 28** on the isolated game. Test both ATP/WTA qualifying and main-draw weeks, same-player overlapping singles/doubles prevention, realistic match durations, automatic rescheduling, travel, hotel costs, finances, rankings, injuries, fatigue and morale. Recheck that Grand Slam and Doha timing do not drift one week earlier.
5. **Website smoke test** on an isolated website pointing at that isolated project. Login, account creation with invited testers, tennis calendar, training, match replay, sponsors, Premium visibility and travel overrides must behave normally. Keep Netlify auto-builds paused.
6. **Owner authorizes** a specific final date/time, chosen game speed, test-account treatment and maintenance message. Public signup stays blocked until the final gate is signed off.

## Final-cutover operator guard (do NOT enter on production yet)
The reset SQL requires the following local settings, with real independently verified references, **inside the same transaction immediately after BEGIN**:

```sql
-- Replace placeholders only after evidence review and explicit owner approval.
SET LOCAL tennis_prelaunch.owner_approved = 'yes';
SET LOCAL tennis_prelaunch.backup_restore_reference = '<validated-restore-reference>';
SET LOCAL tennis_prelaunch.rehearsal_reference = '<validated-jan-feb-rehearsal-reference>';
SET LOCAL tennis_prelaunch.target_speed = '<owner-selected-positive-speed>';
```

The operator must also pause the game clock and all 33 registered reset-controlled jobs *before* the transaction, with a maintenance screen shown to players. A failed reset must remain locked while investigated; never quietly resume an unverified state. Never run a second reset automatically.

## Where to check
- `scripts/tennis_release_readiness_readonly.sql` — current preflight. Safe to execute repeatedly.
- `scripts/tennis_prelaunch_reset_preflight.sql` — original read-only inventory.
- `scripts/tennis_prelaunch_season1_reset.sql` — destructive script. Do not run on the active project until all gates are satisfied.
- `tests/tennisFinalResetSecurityReadiness.test.mjs` — source-level guards.

## Not yet verified
- Successful restore into a separate project.
- Successful full reset on that restored project.
- 59-day January–February replay with zero impossible match overlaps.
- Actual live website test against that isolated project.
- Final owner authorization or launch speed.

**Do not confuse successful GitHub CI, SQL preflight or rolled-back migrations with a completed season restart rehearsal.**


## Current January–February test-history baseline (read-only, November 17)

Run `scripts/tennis_january_february_integrity_readonly.sql`. This report is safe to execute repeatedly and **does not repair or rewrite completed test records**.

| Existing test-history discrepancy | Count |
|---|---:|
| Qualification matches outside configured qualification week | 130 |
| Main-draw matches before configured main-draw week | 335 |
| Same-player overlapping singles match pairs | 80 |
| Same-player singles/doubles overlapping match pairs | 42 |
| Same-player doubles/doubles overlapping match pairs | 0 |
| Completed matches without valid winner | 0 |
| Completed simulated matches without stored actual duration | 3,590 |
| Duplicated finance idempotency keys | 0 |

These are measurements of a season generated substantially **before** the scheduling and actual-duration corrections. These numbers are not proof that the new code is broken; historical results are not to be modified just to lower them.

**Acceptance criteria for the independent clean January 1 – February 28 rehearsal:** all 10 integrity metrics must report PASS, including all new completed simulated matches having realistic recorded duration. The run must actually produce qualifying, main-draw, singles and doubles matches; an empty database returning zeros is not a meaningful pass. Also check rank publications, player location/travel, finances, fatigue, injuries and full browser behavior separately.

## Public security review after November 17 hardening

A total of 24 privileged functions still accept anonymous requests as of the last recorded security check; this number includes deliberate public APIs, not necessarily 24 vulnerabilities.

- **Public read endpoints** include calendar, rankings, public player profiles, commerce catalog, registration status/invite verification, maintenance notice, home page statistics/reviews and current game clock.
- **Public-write endpoints requiring external abuse/rate-limit review** include visitor analytics, cross-game referral events, referral clicks and guest homepage review submissions. They are public intentionally. Do not disable them without adapting their website flows.
- **Additional read helpers** such as tournament window and health eligibility need review for least-privilege grants and unintended cross-player disclosures.

Supabase also reports mutable search paths for some functions and an Auth leaked-password protection advisory. These deserve follow-up; an advisor warning is not proof of exploitation.

Do not classify the security review as finished until public-write rate limits, least-privilege access and Auth/account settings have been verified.

## Legacy two-week tournament calendar repair (November 17)

13 unplayed future Season 1 tournaments used the legacy `full` label for the qualifying week, followed by an explicit `main_draw` second week. The strict new scheduler could have rejected their qualifying matches. The repair changes these 13 first-week labels to `qualification` in both live Season 1 calendar definitions and the original Season 1 reset snapshot. Future-season generators with old `full` labels are supported by a compatibility fallback for match phases, effective player availability, and doubles entry weeks.

The reset now checks that all **16** Season 1 two-week events have exactly one qualification week and one main-draw week, and refuses execution if they drift. The read-only readiness report has an 18th explicit check for these phases. Existing published matches and results are not modified.

## Preserve submitted website reviews at final reset

The `public.player_homepage_reviews.player_id` foreign key has `ON DELETE CASCADE`. Deleting a test character could inadvertently delete that person's published or pending review. The final-reset script now unlinks human test-character IDs from reviews **before** deleting those characters and verifies the total review count remains unchanged. The submitted review content, author account, status and rating are retained. This change is in the final-reset script only and does not change live reviews.

## Anonymous public-write abuse limits (prepared, not yet deployed)

Four intentionally public endpoints write visitor/referral/review records: `record_site_analytics_event_v1`, `register_referral_click_v1`, `record_cross_game_referral_event_v1` and `submit_public_homepage_review_v1`.

Proposed database safeguard: `20261117170500_public_rpc_budget_foundation.sql` and `20261117171000_apply_public_rpc_write_budgets.sql`. The first installs private hashed fixed-window counters plus six-hour cleanup; the second adds per-visitor, referral-code, review-email and global limits. These settings reduce write amplification but **cannot identify anonymous users reliably**, since visitor IDs and referral codes can be rotated. Edge/WAF throttling and CAPTCHA for guest reviews remain advisable.

The public review form is updated to treat only `status: pending` as success. A rejected `status: rate_limited` response now shows an error rather than an incorrect success message.

**Deployment order matters.** The database rate-limit changes should not be applied to the active game until the updated website review form is also deployed. Website publication is paused for the prelaunch test. The migrations have been transactionally tested and committed for deployment later; do not report them as active prematurely.

Rollback tests included anonymous guest-review submission, analytics and cross-game events, limit exhaustion and unchanged row counts. All test data was rolled back.

## Last public RPC exposure review (November 17)

The read-only audit `scripts/tennis_public_rpc_access_readonly.sql` checks every privileged function that anonymous visitors can execute. Prior to the final helper lockdown it identified **24** such functions: 16 public-information functions, four public-write functions awaiting coordinated rate-limit deployment, and four requiring closer access review. Two of those four are internal health eligibility/doubles timing helpers and have now been prepared for direct-access revocation. The other two are calendar/tournament entry functions; do not deny anonymous access before verifying any public website dependency.

The release-readiness report includes a nineteenth check: rate-limit deployment remains **PENDING_DEPLOYMENT** until the new private budget table exists, and even then requires website verification. The current normal website should not be automatically republished.
