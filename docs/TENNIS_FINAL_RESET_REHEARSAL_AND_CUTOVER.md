# Tennis Legacy — Final Season 1 restart: safety and rehearsal gate

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
