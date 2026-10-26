# Premium Tournament Watchlist — application-opening reminders (2026-10-20)

## User experience
- **Calendar → Tournament Calendar:** Premium players get a Star control beside each future tournament. A separate watchlist card shows saved tournaments, when the official normal application window opens/closes (always in-game dates), and open/closed/already-applied/canceled states. Players can remove watches at any time while Premium is active.
- **No duplicate Premium reports:** this is a compact extension beside Tournament Planning Intelligence, not a second application form. The official tournament detail screen remains the only place to submit an application.
- **Free:** sees a small Premium explainer; all normal calendar browsing, tournament entry, results and tactics stay available as before.
- **Notifications:** game-wide unread badge and Notifications inbox receive a single warning when a starred tournament's *normal* application period opens, with a deep link to the actual tournament and the window's in-game date metadata.
- **Offline:** a Postgres scheduled processor checks due watched events every 5 real minutes. No browser needs to be open for the entry to be created. After login the persistent notification is visible. At 2x game speed this implies up to about 10 in-game minutes of scheduling delay.
- **Not included:** email or device push notifications; automatic application; guaranteed admission; late-entry opening alerts. Watching only future normal application windows avoids misleading reminders for events already open. Removing a watch does not erase a previously delivered notification.
- **Limits:** 60 watches per current game season. Old-season watches are not displayed. One notification per owner+player+competition (enforced by existing `user_notifications` unique event-key index).
- **Internationalization:** watchlist and reminder notifications in EN, DE, SR, ES, IT, RU, PT. Premium marketing gives Tournament Watchlist its own translated named benefit in the shared homepage, public pricing dialog and signed-in Pro Packages guide; the purchase-page comparison table and plan summary also list it.

## Security and backend
- Migration: `supabase/migrations/20261020235000_premium_tournament_watchlist_v1.sql`.
- RPCs: `get_premium_tournament_watchlist_v1` / `set_premium_tournament_watch_v1` require authenticated owner, human career, appropriate ATP/WTA world and active Premium/trial. No direct anon/authenticated table permissions; RLS enabled.
- Server cron invokes `process_premium_tournament_watch_openings_v1` as a trusted database role. No unauthenticated RPC permission. The producer checks paid/trial entitlement when the reminder becomes due, skips canceled and already-applied tournaments, uses `get_tournament_entry_timeline_v1` for exact official open/close game seconds, and emits through existing `emit_notification_v1`. A unique event key prevents repeat messages from concurrent/repeated runs.
- No changes to match engine, rankings, schedule, training, Stripe or player finances.

## Release gate — IMPORTANT
**Source committed to public `main`; not deployed.** Tennis Legacy's Netlify builds remain stopped. The new Supabase migration and scheduled job have **NOT** been applied to live Supabase. Repository policy requires explicit owner authorization before migrations, Netlify deployment or production publication.

Before activating: review migration in a nonproduction database, run `tests/premium_tournament_watchlist_db_smoke.sql` in a rollback transaction, verify cron is permitted, check Supabase security/performance advisors and an exact in-game opening boundary, test concurrent idempotency and applied/expired Premium edge cases. Then run `npm ci`, `npm run check:pt`, `npm run check:preferences`, `npm run check:seo`, `npm run build`, and signed-in Free/Premium/trial desktop and mobile browser flows. Confirm that the notification appears once in-game while the user is signed out. Production deployment needs separate authorization.
