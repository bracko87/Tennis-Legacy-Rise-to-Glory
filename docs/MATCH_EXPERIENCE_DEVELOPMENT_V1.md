# Match experience and permanent skill development (v1)

Status: committed to **staging only**. The Supabase migration is **not applied** to the live database. Deploy the migration as part of a separately validated, manual release; do not deploy UI from staging to production automatically.

## Design

- Each legitimately completed **singles** match rewards both players, whether they win or lose.
- Each legitimately completed **doubles** match rewards all four players, whether their team wins or loses.
- No reward for singles without a recorded played-match condition event/simulation, or doubles without a condition event and actual minutes/sets/games.
- Match rewards are **fractional** and feed the existing `apply_player_development_progress_v1` accumulator. Ratings increase only after a fractional skill reaches 1.0000. Existing level-based slowdown applies.
- A normal singles match provides a total base progress budget of **0.12** (doubles **0.085**), modified modestly by duration, actual games played, opponent's skill and a 5% win bonus. The final per-match total is capped at **0.16**. Losing a match **still awards progress**.
- Gains are distributed across all 13 permanent technical and physical attributes. Serve, forehand, backhand and return are emphasized in singles; volley, serve, return and smash in doubles. Clay/grass and Serve & Volley playing style modestly adjust weighting.
- `player_match_development_events` stores **one row per (match kind, match ID, player)** with raw progress, actual game season/week and whole-level gains. Unique primary key and transactional insert-before-apply guard prevent repeat awards after replay/status toggles.
- Private trigger helpers have no PUBLIC/anon/authenticated execute permission; ledger rows can only be read by the owning human player through RLS. AI opponents can also develop normally.
- Dates are based on the **in-game clock**, never the wall-clock. The previous weekly Skills UI is already committed to staging.
- **No historical backfill**: 39 older matches for the investigated player do not magically become earned skill levels, and no previously recorded player skills change from merely deploying this migration.

## Validation plan (disposable environment, before production release)

1. Apply the migration to an isolated test database that contains the earlier Skills, match and game-date migrations. Ensure tables, policies, functions and both triggers create successfully.
2. Play one normal singles match to completion. Verify exactly two `player_match_development_events` rows; both winners/losers must receive >0 earned progress, with expected source and no unexpected whole-number jumps.
3. Complete one normal doubles match. Verify four experience rows.
4. Replay/re-submit each completed result, and toggle an already completed match status if supported in the test fixture. Event counts and fractional totals must not increase for an already rewarded match/player.
5. Complete a bye/walkover and a doubles match without valid played statistics. Neither must award permanent progression.
6. Verify match duration, opponent strength and surfaces affect gains within the specified cap, and wins and losses have modest reward differences.
7. Finish enough simulated test matches to cross a fractional threshold; the permanent skill rating must increase exactly once and be reflected in in-game weekly history.
8. Test with an unentitled signed-in user, anonymous user and owner. Only the owner can SELECT own experience ledger; no client can manually INSERT/UPDATE ledger or EXECUTE trigger helpers.
9. Run `npm run check:pt`, `npm run check:preferences`, and `npm run build` with the complete staging branch in the normal release validation flow.

## After deployment: useful read-only checks

```sql
select match_kind, outcome, count(*) as events
from public.player_match_development_events
group by match_kind, outcome
order by match_kind, outcome;

select match_kind, match_id, player_id, game_season, game_week,
       earned_progress, level_ups
from public.player_match_development_events
order by created_at desc limit 20;

select match_kind, match_id, player_id, count(*)
from public.player_match_development_events
group by match_kind, match_id, player_id
having count(*) > 1;
```

The final query must always return zero rows. Check these results and the running-game screen before manually releasing `staging` to `main`.
