# v0.29-C18 — operational integration closure audit
Scope: isolated review branch only. No production migration or activation.

## Evidence boundary
C1–C15 workflow success verified; C16–C17 final workflows pending at audit. The isolated scheduling projection, discovery and outbox are removed before recovery rehearsal. They are not installed production authority.

## Authentic compatibility contract
The November 17 Legacy scheduling routines read tournament match slots, simulation totals and live end, competition edition, season, category, phase weeks, court count and game clock. The restored-catalog contract now requires these columns and exact routine signatures, and captures game_clock metadata (not rows). Internal scheduling functions must not be executable by anon/authenticated. Existing reference comparison remains fail closed and always production_ready=false.

## Remaining blockers
- Actual approved current reference and isolated restored database catalog, including routine definitions by hash, grants, triggers, policies, cron inventory and migration history.
- Authentic phase/court/duration and participant evidence; physical venue identity; global inventory coverage. Current phase and duration binds are synthetic/manual.
- Shared atomic scheduling authority across Legacy and Ace, including unadmitted/external targets and coordination with admission/start. Review-only advisory locks do not cover all writers.
- Coordinated downstream rescheduling rather than simply rejecting invalid feeder chronology.
- Worker service deployment, observability, reconciliation review resolution, and recovery of real production obligations.
- Authentic shadow results, career/reward settlement and approval remain mandatory.

No release authorization inferred from CI. Next phase D begins with approved metadata capture and comparison, not production writes.
