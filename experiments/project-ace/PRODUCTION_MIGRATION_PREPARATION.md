# v0.24-A — production integration preparation (not authorized for deployment)

Recovery source baseline fba2971f53236ce9cc3a0c074e5a4fd30811be4d; preserve backup/pre-ace-2026-11-26. Checked-in schema audit only, not a claim about the current live database. No files in supabase/migrations added or changed.

## Required current-schema audit
Run cutover-preflight-readonly.sql against a restored, isolated database first, then compare routine/trigger hashes, role privileges, cron inventory and state counts with authorized production read-only output. Review all callers, including Edge Functions and external workers; catalog pattern matching alone is insufficient. Backup timestamp, restore availability, actual restore rehearsal, storage/config preservation and current migration drift remain mandatory. Do not save credentials, identity rows or production dumps in Git.

## Known mutation paths and owners
- prepare_tournament_match_simulation_v1 and process_due_match_engine_v1: legacy preparation, medical/travel resolution and existing simulation exclusion.
- start_due_match_replays_v1 / finalize_match_replay_v1 / finalize_due_match_replays_v1: 20261117112500; retain feeder safety, shared court/player scheduling and existing live replay completion. Current code locks simulation before match; agree one shared transaction lock order before introducing claims.
- run_tournament_operations_watchdog_v1: 20261115181500; bye repair, starts/finalization and overdue rankings. Preserve normal watchdog semantics.
- control_center_private.retire_expired_tennis_guests_v1: 20261120194500 and subsequent guest fixes; direct scheduled-match mutation and bracket propagation. Coordinate guest conversion/expiry and cancellation before Ace accepts a match. No deletion of history.
- Health surrender, travel no-show, admin repairs, cancellation/redraw, season closeout and national-team/doubles bridges require complete live definition and caller audit. Do not treat these as merely legacy engine operations.
- Terminal status update can invoke legacy advancement, rewards, health, condition and equipment triggers. Exactly one effect owner per type. Never run both projected and official effects.
- Monthly tax and ranking publication are global career processors; do not run per-competition proposed taxes independently. Source-ID deterministic injury/illness rules must be resolved before official gameplay because synthetic outcomes may change eligibility.

## Additive migration design (draft only)
1. Create private server-owned engine claim + checkpoint persistence, no client grants, default legacy. Keep historical match and replay tables unchanged. Bind claim to actual official participants and feeder state.
2. Route only explicitly approved new singles competitions, initially none. Existing prepared/live/completed or unrecognized states stay legacy. Reuse shared lock and safe-start contracts; prevent either engine racing preparation/ownership. Verify an actual ownership guard at every mutation path, not only finalization.
3. Integrate one authoritative finalizer with trigger coverage and exact source-ID health inputs; normal official career/ranking/tax processors remain source of truth unless explicitly replaced and tested. Preserve official replay/detail contracts, access and legacy matches.
4. Deploy disabled, exercise shadow mode on restored data, then verify full isolated cutover and rollback. No real canary until explicit approval and fresh recovery proof.

## Rollback rehearsal
Disable new Ace admissions (legacy becomes default). Never transfer an already claimed Ace match to legacy or regenerate its winner. Keep Ace worker/finalizer available to drain owned matches, or use a separately reviewed owner-aware recovery path. Preserve completed effects and audit records; do not reverse player progress by blanket DB restore. Remove new runtime only when no unresolved Ace claims remain. Additive data can remain dormant. Verify legacy starts new matches and all side effects occur once. Restore database only for disaster recovery after assessing lost writes.

cutover-ownership.cjs is a pure policy rehearsal; it does NOT enforce real SQL ownership or implement handoffs. No production migration or scheduler changes. Next: actual restored-schema migration draft and concurrent rollback rehearsal after full verification. The preflight query assumes the listed tables and pg_cron exist and is not run against a live DB in this checkpoint.
