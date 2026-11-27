# D4-E — authentic trigger and permission review

Read-only live catalog inspection found authenticated has TRUNCATE, but not INSERT/UPDATE/DELETE on the three match tables; RLS only permits authenticated reads. TRUNCATE is not governed by RLS. Proposed remediation (NOT authorized or applied): revoke only TRUNCATE from authenticated on public.tournament_matches, public.tournament_match_sets, public.tournament_match_player_stats. Preserve SELECT, RLS, service_role permissions and all policies. Review on authentic isolated restore before release. Synthetic regression demonstrates the privilege pattern only, not full live client compatibility.

Deployed routine definition hashes observed 2026-11-27:
- apply_equipment_wear_on_completed_match_v1: 72ad0756371a609c9de954f95f07c7ce — skips health_walkover, health_surrender, travel_no_show; applies human equipment wear using match identity.
- apply_match_condition_effects_v1: befc8c6efc3baeb15de1bab4ac486e16 — completed transition, simulation required, existing per-match/player condition event check, reads estimated_match_minutes metadata, sets, games and staff.
- finalize_completed_tournament_match_v1: 8ab13c720e70092c7c78120923c4eca8 — completed transition, loser and main-draw final winner; existing trigger excludes national team engine.
- revalidate_doubles_after_singles_schedule_change_v1: a53b5825ef8f5b57517fae721f9f68bb — scheduled shared-player doubles matches on new singles day rescheduled through official function.
- roll_match_injury_on_completion_v1: bbcaf30d65c461f1d16a936439b335bb — simulation required, schedule_reason walkover exclusion, weather/estimated duration, health setback before injury.
- sync_completed_tournament_status_v1: 2a74d00f02ce7f64ebd866ef7734767b — final winner terminal status closes competition and edition when appropriate.

Ace must stage official simulation before completed status transition and retain exactly one official effect authority. No direct second fatigue, wear, injury, ranking or prize write. Must verify special completion reasons, authentic metadata duration, condition event constraints and called routines on independent restore. Doubles and national competition authority remain open. No live changes.