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

## Release candidate evidence (22 November 2026, commit 14a8ffc)
- Owner confirmed production build succeeded after standard npm audit fix and removal of unused Zod. Production dependency audit: 0 reported vulnerabilities; full audit: 3 moderate development dependency findings. Package manifest and lockfile committed and pushed.
- Owner ran npm run check:serve successfully: 5,040 paired fixed-seed scenarios (2,520 ATP and 2,520 WTA), covering hard/clay/grass and elite/futures. All programmed assertions passed. Candidate average aces per player: ATP 4.32, WTA 3.33; average games: ATP 23.78, WTA 23.40. Winner changed in 1,286 paired scenarios (25.52%). Independent proxy only; not production engine acceptance.
- Existing tests/serve_realism_v3_db_smoke.sql explicitly requires an isolated environment and completed match samples; no execution against paused production, which has no completed matches. Full simulation acceptance remains open.
- No production deployment triggered by these tests.

## Final build (Windows CMD, existing repository)
Stop dev server with Ctrl+C. Run:
```cmd
git pull --ff-only origin main
npm run build
npm audit
```
Record the commit and build exit status. Assess audit findings including production vs development dependency scope; do not run audit fix --force blindly.
If desired, run npm run dev for UI smoke testing on port 8001. It uses LIVE Supabase; use designated test accounts only. Do not change the launch clock or use real payments.

## Final targeted verification (22 November 2026)
- Presence fields active_players_2m, active_guest_players_2m, active_total_players_2m match the live database output and AdminAnalytics source.
- Scheduled jobs: 49 latest completed successfully, 0 failed, initial launch worker not yet due. Registration/email, Google and guest admission enabled; maintenance off; clock paused at Season 1 Jan 1 00:00, configured speed 2x; launch gate 2026-12-01 06:00 UTC.
- Security advisor returned 0 ERROR, 139 WARN, 1 INFO before the final birthday guard; this is not complete security certification.
- Birthday award and scheduled processor explicitly exclude anonymous/deleted accounts; privileged test invocation for active guest denied before any wallet or reward writes; guest reward rows and nonzero guest wallets both 0. Migration committed as d229e43.
- Official manual updated EN/DE/SR v1.1, retaining existing searchable chapters and PDF export; guest rules and starting allocation corrected against live records. Final browser/build validation still required.
- Demonstration recording plan committed as docs/HELIOS_GAMEPLAY_DEMOS.md. Footage not yet produced.
- Connected tools do not expose backup listing or latest successful recovery point; owner must verify in Supabase dashboard. No restore, live payment, clock advancement or Netlify deploy performed.
- Feature development frozen. Final local build and single deployment require owner action; no claim of production acceptance until verified.

## H22: converted Guest Player profile completion
- Added a non-blocking Overview reminder for accounts with a recorded guest-to-permanent conversion, with a link to Player & Account. Existing guest careers and non-converted permanent accounts are unaffected.
- Account completion supports confirming/replacing the generated username once; entering a missing real-world account birthday once (month/day, optional year, timezone); and choosing a home city from the player's country. “Maybe later” automatically assigns an available same-country city if none exists and dismisses the modal; the city remains editable afterward.
- Birthday immutability remains enforced by the database. A completely blank birthday can be filled once only for a registered converted guest. Previously supplied birthdays cannot be overwritten.
- DB tests in rollback passed: one-time username and birthday, second-change rejection, valid country city selection, reminder dismissal, active guest and ordinary permanent account denial, null/impossible date rejection. No persisted test modifications.
- Migration code committed; backend functions live. Frontend changes are committed but **NOT deployed by the previous Netlify production deploy**; a fresh local build and intentional single deployment are needed for this feature.
- Once deployed, verify converted-player reminder, field saving and reloading, existing saved birthday locked, and responsive mobile view before calling H22 accepted.

## H22 UX corrections after 22 November 2026 screenshots
- Converted guest's birthday confirmation uses existing GameConfirmDialog (no native window.confirm); valid-date confirmation remains one-time database-protected.
- The account-completion panel matches Player & Account type sizes and font, shows a compact completed summary once username/birthday/city are saved, and provides an edit-city action.
- Guest email conversion: post-request UI distinguishes server-confirmed account linking from a pending verification email, shows the requested address, offers resend and edit, and preserves pending state in this tab on refresh.
- OAuth redirect errors are displayed, including identity-already-linked-to-another-user; account ownership is never silently merged.
- After password or Google conversion, display saved-progress confirmation then navigate to existing career automatically; a manual Continue to player button remains.
- Supabase auth logs showed an identity-already-linked error on Google attempt and successfully converted email identities. Auth records cannot alone prove that SMTP actually delivered a confirmation email. Verify mail provider configuration, delivery and allowed redirect URL separately.
- New frontend changes require the owner's fresh local build; previous Netlify deployment does not include them. No production deployment was run for these corrections.

## Guest conversion email delivery – open provider acceptance item
- Frontend now shows requested/verified email states, resend/change-address controls, callback Google conflict messages and post-registration return to the original player, with no native birthday dialog.
- The live log showed a Google identity conflict; the UI now explains this explicitly instead of implying an account merge.
- Branded **Change Email Address** template and exact configuration checklist are prepared in [TENNIS_GUEST_EMAIL_VERIFICATION.md](TENNIS_GUEST_EMAIL_VERIFICATION.md).
- **IMPORTANT:** The Supabase connection does not expose the dashboard's email confirmation toggle, SMTP sender/delivery or redirect URL configuration, so these have not been modified. Do not claim emails are delivered or redirects work end-to-end until the owner verifies settings and completes one real mailbox test.
- Updated frontend source is committed, but a fresh local production build and an intentional single Netlify deploy are required to publish it.

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
