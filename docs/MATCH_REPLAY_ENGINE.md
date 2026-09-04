# Tennis Legacy — Match Engine → Live Replay Contract

The match-strength formula is intentionally separate from the replay/lifecycle system.

## Lifecycle

1. Match remains `scheduled` while the engine prepares a sealed simulation.
2. The engine registers one immutable simulation with `register_tournament_match_simulation_v1`.
3. When the game clock reaches the scheduled tournament match time, the server changes the simulation to `live` and the match to `in_progress`.
4. The first/live occurrence runs at real-time 1× for `replay_duration_seconds` (8–30 minutes). The client cannot seek, pause, rewind, accelerate, skip a game/set, or request the hidden result.
5. The server finalizes the match even when nobody is watching.
6. Only on finalization are `winner_id`, sets, player statistics and `completed` status published. Existing tournament triggers then handle advancement, elimination, equipment wear, finance/ranking consequences and travel replanning.
7. Completed simulations remain permanently available as historical replays. Historical replay controls may pause, restart, use 1×/2×/4×, jump to the next game/set, or reveal the final result.

## Required simulation payload

A future Match Engine must produce:

- `final_winner_id`
- `final_score`
- completed set rows (`sets_payload`)
- player 1 match statistics
- player 2 match statistics
- ordered point/replay events
- total points
- total games
- replay duration (or metrics from which `calculate_match_replay_duration_v1` can derive it)
- engine version and deterministic seed

The database seals these values after registration.

## Event contract

Each replay event must contain a monotonically increasing `offset_seconds` between 0 and the replay duration.

Recommended event kinds:

- `match_start`
- `point`
- `game_end`
- `changeover`
- `set_end`
- `match_end`

Recommended scoreboard fields on every visible event:

- `p1_sets`, `p2_sets`
- `p1_games`, `p2_games`
- `p1_points`, `p2_points`
- `set_number`
- `game_number`
- `description`

Point descriptions can later include ace, double fault, forehand winner, backhand winner, forced error, unforced error and other match-engine outcomes.

## Privacy rule

`tournament_match_simulations` is not readable by clients. During LIVE, `get_tournament_match_replay_v1` returns only events whose `offset_seconds` have already elapsed. It does not return the hidden final winner or final score. After completion it returns the full immutable event log and official result.

## Replay duration

Current v1 limits are 480–1800 seconds (8–30 minutes). The helper `calculate_match_replay_duration_v1` scales duration using points, games, sets, deuces, tiebreaks and long rallies. The final Match Engine may use the helper or supply an equivalent duration within those bounds.
