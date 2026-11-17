# Tennis Legacy — Seven-day Premium trial and official launch

Updated 17 November 2026. Public registration is open and the game is **paused** at Season 1, January 1, 00:00, with configured speed **2×**.

## Rule

The first official game-clock unpause on or after **Monday, 23 November 2026 at 07:00 CET** is the real start of the Premium trial for players who already created a tennis player before launch.

- A player created before the clock begins gets seven **full real days** from the actual unpause, not account creation. If unpaused on 23 November at 07:00 German time, the free trial ends on **30 November at 07:00 German time**.
- If launch is delayed, the start and end move with the **actual** first unpause. A popup disappearing at 07:00 does not start the trial.
- Prelaunch characters may preview Premium features while the clock is paused, but trial time does **not** count down and no trial-start/expiry notifications are sent.
- Players who create their first tennis character **after launch** receive their own full seven real days from their first eligible Premium trial request.
- Accounts created earlier without a character at launch do **not** lose time merely because registration was open.
- Later maintenance pauses do not restart or extend a trial. Premium remains optional; trials never trigger automatic card charges.
- Existing paid Premium and historical billing transactions/coins are kept unchanged. Historical expired free-trial rows from the discarded test season are reserved for an eligible fresh free trial. Purchasers with paid Premium invoices are not re-granted trials.
- One-time trial claims remain protected by the existing pseudonymous email-hash uniqueness.

## Technical implementation

`supabase/migrations/20261117181500_defer_premium_trials_until_real_launch_unpause.sql` adds a private launch-control row with scheduled and actual start timestamps, protected reservation flags on `tennis_premium_trials_v1`, and a trigger on the real `game_clock` first-unpause transition. The trigger refuses accidental unpauses before the scheduled release hour. At the first valid unpause, it anchors eligible prelaunch-player trials to the actual timestamp, with `expires_at=started_at+interval '7 days'`. It never runs on later pauses/resumes.

The Premium trial RPC returns `state: pending_launch`, `seconds_left: 604800` and no fake start/expiry dates during prelaunch. The server-side `has_active_premium_v1` entitlement allows preview only while the launch clock remains paused, and paid benefits take precedence. After actual launch, the RPC uses the saved launch anchor for prelaunch players; new postlaunch characters start from their own first visit.

The Premium page shows a clear “trial reserved” message instead of claiming that trial time is already expiring. The start/end dates remain blank until the trial actually begins.

## Verification

Tested in a rolled-back database transaction: three old free-trial rows were reserved, previously paid membership/invoice/coin totals did not change, early unpause was blocked, an isolated simulated unpause recorded the launch timestamp, and accounts without characters did not consume trial days. Subsequent pause/resume did not re-anchor trials. All writes were rolled back.

The full migration should be applied on the live database only after matching the GitHub production build and regression tests; its application and postconditions must be verified separately. The game clock must stay paused for now.
