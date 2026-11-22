# Helios release acceptance and recovery runbook

Target: 1 December 2026, 07:00 CET (06:00 UTC). Season 1, January 1, 00:00, 2x.
Feature freeze: only release blockers. No Redis, Docker installation, paid infrastructure, or repeated production deployments.

## Evidence as of 22 November 2026
- Local browser guest creation, continuation, administrator return and analytics page confirmed by operator.
- Live DB: guest and permanent career initialization, wallet ownership/RLS checks, guest checkout denial and permanent checkout intent rollback passed.
- Guest retirement and deletion workers active; deletion subject to dependency holds.
- Launch worker installed; early invocation returned not_due and game remained paused. Actual due-time launch is not yet tested.
- Stripe webhook active; payment processing restricted to privileged roles. No real payment or refund has been tested.
- Production database healthy; no current career processing errors in the inspected state. Zero match simulation and training records while paused; this is not proof of gameplay execution.

## Final build (Windows CMD, existing repository)
Stop dev server with Ctrl+C. Run:
```cmd
git pull --ff-only origin main
npm run build
npm audit
```
Record the commit and build exit status. Assess audit findings including production vs development dependency scope; do not run audit fix --force blindly.
If desired, run npm run dev for UI smoke testing on port 8001. It uses LIVE Supabase; use designated test accounts only. Do not change the launch clock or use real payments.

## Mandatory remaining checks
- [ ] Guest purchase buttons disabled, free trial features accessible, conversion link works.
- [ ] Permanent player can navigate training, calendar, equipment and finances; read-only UI checks where possible before launch.
- [ ] Match engine / daily processing acceptance with existing synthetic test evidence or safe isolated tests; no live clock advancement to manufacture results.
- [ ] Payment provider test-mode checkout and authenticated webhook reconciliation; no live charge for verification.
- [ ] Review current security and dependency findings for actual release blockers.
- [ ] In Supabase dashboard Database > Backups verify latest successful backup and retention; record timestamp and recovery procedure. Do not restore over production as a test. Confirm Storage objects can be recovered separately.
- [ ] Record prior successful Netlify deploy ID and current Git commit; confirm rollback and deploy permissions.
- [ ] Deploy the approved frontend once after build and required checks pass. Verify public website, login, guest persistence, conversion, admin analytics, mobile navigation, and launch announcement on the actual production domain.
- [ ] Check Control Center source freshness and actual receipt, not merely cron dispatch.
- [ ] Before release verify registration open, launch gate exact timestamp, maintenance off, game clock paused 2x at initial state, initial-launch cron active, and no current critical job failures.

## Launch and incident handling
At 07:00 CET check the game clock is advancing at 2x and the launch receipt unpaused_at is populated once. Confirm reserved Premium trials for existing careers have seven days from launch, while guest trials retain their own deadlines. Check rankings, schedule, training and finance results as gameplay actually occurs. If the launch worker reports unexpected state, inspect and resolve the underlying issue before manually starting. Never bypass the early-start guard. If a frontend release is broken, use previously recorded Netlify deploy rollback; database migrations require a separate reviewed recovery plan. If data corruption is suspected, pause affected operations, preserve evidence, and determine recovery point before restoring. No full production restore without explicit approval.

Status: technical release candidate, NOT a final launch certification.
