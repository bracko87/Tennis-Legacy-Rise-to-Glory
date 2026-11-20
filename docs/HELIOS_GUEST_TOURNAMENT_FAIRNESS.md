# Project Helios H01 — Tournament Selection, Draw, Seeding & Match Verification

Status: final draw ranking fix **implemented in live Supabase, Guest Mode remains OFF**. No real guest tournament has been staged or played.

## Actual code paths reviewed

1. **Entry:** `apply_to_tournament_v3` and `apply_late_tournament_entry_v1` check the original player's authenticated ownership, game clock application window, world, tournament-week conflicts, qualification preference and the H08 server-owned 14-day guest expiry gate. Older `apply_to_tournament_v1/v2` wrappers call V3.
2. **Selection:** `allocate_tournament_applications_v3` orders pending entrants by canonical `get_player_world_rank_position_v1`, checks scheduling conflicts and current field capacities, then assigns main draw, qualification or rejection. This uses the zero-point guest-last tie-break introduced in PR #43.
3. **Final singles draw:** `publish_tournament_draw_v1` had an **independent world-ranking sort** that previously omitted the guest tie-break and could re-promote the zero-point guest when it regenerated entry snapshots at publication. Migration `20261120190500_helios_guest_draw_seeding_fairness.sql` inserts the canonical zero-point guest tie-break after ranking points and before seed_rating, creation time and ID. Existing configured seeding groups, bracket slots, minimum field and byes remain unchanged. Both main-draw and qualifying seeds are derived from the resulting rank snapshots.
4. **Doubles:** `allocate_doubles_entries_v1` and `publish_doubles_draw_v1` rank teams based on team entry-strength and combined ranking points snapshots; the H01 singles zero-point tie-break is not directly applied to this independent team-scoring system. Prior H01 ranking changes align doubles world ranking, snapshots and partner matching. Guest/regular team equivalence must be proven in staging.
5. **Matches and points:** `get_due_unsimulated_matches_v1` returns scheduled matches where both participants exist and no simulation record exists. Tennis matches use the established simulation and result-publication functions. The current database contains no tournament applications, draws or matches, so actual participation, seed placement, result calculation and ranking publication cannot be verified against a live guest yet.

## Verification performed Nov 20, 2026

- 11 prior player/world rank functions and final singles draw now use the same zero-point guest tie-break.
- Canonical selection reads `get_player_world_rank_position_v1`.
- All 836 existing players previously retained their rankings after H01 changes (0 differences).
- Current database: **zero** anonymous users, guest trials, tournament applications, draws and matches; game clock paused.
- No player ranking points, draws, tournament entries, match results or game-clock records were written by this fix.

## Required isolated guest end-to-end tests before activating Guest Mode

- [ ] Create dedicated anonymous test identity and player in a **staging or transactionally isolated** environment with name/country/appearance, and no city, after explicitly enabling guest Auth only there.
- [ ] Verify new player has 0 singles/doubles points and sits last behind all preexisting zero-point players.
- [ ] Apply during an open window and inspect whether guest receives precisely their earned world-rank priority, including first-open and final-vacancy pathways.
- [ ] Run actual `allocate_tournament_applications_v3` and `publish_tournament_draw_v1` on a **synthetic staging competition** with adequate participants. Check main-draw/qualification capacity, seeded players, number of distinct seeds, brackets, byes and fair seeded order.
- [ ] Run match simulation and actual ranking-publication jobs; verify points accrue only from completed legitimate matches. Check doubles entry/seeding separately.
- [ ] Test conversion to permanent account during tournament commitment, preserving ownership and earned ranks without giving a second introductory Premium.
- [ ] **Decide game policy and implement** the handling of an unconverted guest when the 14-day deadline falls between a successful tournament application and its scheduled match. Current H08 access restrictions block **player-initiated** mutation RPCs but automatic scheduled match simulation can still operate, so simply relying on the UI modal is not sufficient for complete guest fairness.
- [ ] Audit all remaining RPC, background scheduler, storage and edge write paths for guest expiry.
- [ ] Verify duplicate-account farming, invitation/referral abuse and email/Google identity-link conflicts.
- [ ] Check desktop/mobile entry and expiry screens; turn on real Guest Mode **only after** all checks pass.

No real account or tournament must be created in production to satisfy this checklist. Use the existing ephemeral-database CI for migration/application logic and a dedicated staging tournament fixture for the full simulation.
