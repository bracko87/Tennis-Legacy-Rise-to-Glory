# Tennis Legacy — 24-hour real-time maintenance for future season transitions

**Policy established:** November 11, 2026  
**Applies to:** Future Season N → N+1 rollovers.  
**Current Season 1 → Season 2:** In progress; **do not activate maintenance retroactively**. The game's clock is already held at Season 1's boundary and the remaining release checks are separate.

## Player-facing policy

1. Tell players the **actual date, time and time zone** when the next season maintenance will begin.
2. Plan **24 consecutive real-world hours**, not 24 in-game hours. The game clock remains paused and is managed independently.
3. On the homepage, show an advance warning with the start and expected reopening times.
4. At the scheduled start, show a dedicated page to visitors and signed-in players: **Season X migration in progress**, with estimated reopening time.
5. Hide login and gameplay routes while the window is active. Existing browser sessions are signed out locally when they encounter the active gate. Players cannot continue using the site's gameplay UI.
6. If the work takes longer, keep the game offline; update the estimated reopening time and message. **Never reopen automatically merely because 24 hours elapsed.**
7. Reopen only when the actual migration journal, backups, player carryover and post-release tests have been verified and an authorized operator approves reopening.

The homepage should remain publicly reachable during maintenance as the maintenance notice, not as a playable page. No passwords, game operations or account actions should be exposed by that notice.

**Important limitation:** The deployed React route gate is website-level protection. Direct Supabase Auth / REST / RPC access from custom clients is **not globally disabled** by this gate. Before using this as a full production maintenance lock, the operator must also secure the game's server-side write endpoints and background producers. The current game-clock pause guards 23 known jobs but is not proof that all authenticated mutation APIs are blocked.

## Implemented, disabled by default

Database:
- Private singleton: `control_center_private.tennis_season_maintenance_control_v1` (RLS enabled, no direct anon/player access)
- Public *read-only* status: `public.get_tennis_public_maintenance_v1()`, callable by `anon` and `authenticated`; returns no player/account data.
- The database enforces `planned_reopen_at = starts_at + interval '24 hours'` for scheduled and active windows. An extension is stored separately and must be later than the planned reopening.
- `off` = normal operation; `announced` = public warning before start, automatically blocks the website at start; `active` = website blocked; `extended` = website remains blocked with revised reopening time.
- **No automatic reopening** after the estimated time. The operator must set `status='off'` only after successful release checks.
- The real production singleton was verified `status='off'` after all temporary rollback tests.

Website:
- `src/components/season/SeasonMaintenanceBoundary.tsx` checks the database status before loading the authenticated game routes; polls every 15 seconds and rechecks on focus.
- When blocked, renders a maintenance notice showing the target season and expected reopening time in the visitor's local time zone. Current browser sessions are locally signed out.
- When announced, `src/pages/Home.tsx` displays the advance warning without restricting the game before the scheduled start.
- If the status cannot be fetched, website access fails closed temporarily until the status endpoint recovers.
- `tests/seasonMaintenanceWindow.test.mjs` and the release-validation workflow cover the gate, warning and no-direct-game-write safety contract.

## Operating procedure — use only when a season transition is scheduled and authorized

### A. Before the maintenance window

- Prepare the next season's calendar *before the outgoing season ends*, including tournament application windows.
- Verify an independently restorable recovery snapshot and all migration preflight checks.
- Select the exact **real-world start time** and communicate it publicly in advance. Avoid announcing an unapproved start time.
- Schedule the website notice by changing the private singleton using the Supabase SQL Editor or a future restricted operator tool. Example for a **hypothetical future Season 2 → 3** rollover (dates must be chosen at that time):

```sql
begin;
update control_center_private.tennis_season_maintenance_control_v1
set status = 'announced',
    source_season = 2,
    target_season = 3,
    starts_at = '2027-01-01T08:00:00Z'::timestamptz,
    planned_reopen_at = '2027-01-02T08:00:00Z'::timestamptz,
    revised_reopen_at = null,
    notice = 'Season 3 migration is scheduled. Please check this page for updates.',
    updated_at = now()
where id = true and status = 'off';
commit;
```

**The dates above are illustrative only; they are not the game's actual next rollover dates.** Never use this example to activate maintenance without checking the intended season and clock.

### B. At the planned real-world start

- The website automatically enters its maintenance display if the operator previously announced the window. The actual game clock/cron and database write gates must be separately verified as stopped.
- Confirm ordinary browser sessions see the maintenance page and cannot navigate to `/login` or `/game/...`.
- Confirm background game processors cannot mutate player data and that direct authenticated API writes are blocked by the operator's server-side protections.
- Take or recheck the independent restoration point before irreversible writes.
- Run the guarded season transition once, validate the 13 step journal and execute post-migration tests.
- Do not mark all steps complete just because the website is offline.

### C. When more than 24 real hours are needed

```sql
update control_center_private.tennis_season_maintenance_control_v1
set status = 'extended',
    revised_reopen_at = '2027-01-03T08:00:00Z'::timestamptz,
    notice = 'Maintenance is taking longer than expected. The new target reopening time is displayed here.',
    updated_at = now()
where id = true and status in ('announced','active','extended');
```

This example is illustrative only. Announce the revised expected reopening time on the homepage and through the game's normal player communication channels. Never promise a confirmed reopening time until verified.

### D. Reopen safely

- Verify migration journal completion, source/target season clock, Week 1 eligibility, ATP/WTA rankings, player balances/coins, sponsorships, careers and all critical jobs.
- Re-enable server-side gameplay writes and schedulers **only after** post-transition checks pass.
- Set `status='off'` to release the website maintenance gate, and clear the previous schedule:

```sql
update control_center_private.tennis_season_maintenance_control_v1
set status='off', source_season=null, target_season=null,
    starts_at=null, planned_reopen_at=null, revised_reopen_at=null,
    notice=null, updated_at=now()
where id=true;
```

- Confirm public homepage, sign-in and game dashboards all work. Publish a concise "Season X is now live" announcement.

## Verification and safety limitations

The status routine was tested in a real PostgreSQL transaction with `off`, `announced`, elapsed scheduled start, overdue/extended and manually reopened states; the transaction was rolled back and production remained `off`.

**Not yet completed:** end-to-end browser testing of the maintenance page on a staging or local website; a complete audit/lockdown of direct player-write API access; automatic notifications beyond the website notice; an operator-facing activation/reopening console. Those tasks must be completed before relying on this as a full security-level maintenance lock.

No additional fee or plugin is required for the deployed code. This feature does not itself provide an independent production database backup or restore.
