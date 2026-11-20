# Project Helios H08 — history-safe guest erasure implementation gate

Status: **investigation/implementation in progress; guest deletion NOT enabled** (20 November 2026).

## Contract

The 14-day server worker already removes an unconverted guest from active participation. That is *retirement*, not personal-data erasure. Scheduled unstarted singles and doubles receive walkovers, while completed match results and bracket history remain immutable.

Do **not** call `public.delete_tennis_legacy_account_v1()` on an expired guest until a separate, verified erasure workflow exists: today that function cascades through `auth.users -> players`. Do not change existing registered-player deletion behavior as a shortcut.

## Next migration design

1. Create a minimal, durable **public competition history identity** distinct from Auth and private player data. Prefer an immutable surrogate ID and a neutral label (for example, "Retired guest"), not name, email, device identifier, or username. Retain only lawful, necessary competition attributes and outcomes.
2. Inventory *all* direct and recursively reachable FKs (not just the 188 direct FKs already observed), triggers, RLS policies and materialized/public views. Use `tests/helios_guest_deletion_fk_audit.sql` on staging/read-only; re-run after every migration.
3. For completed and in-progress records, preserve bracket references, winner, round, score, opponent and status through an explicit history identity or snapshot. Decide how unfinished matches are finalized without editing completed outcomes.
4. Classify each referencing table as **retain with surrogate**, **archive**, **anonymize**, **erase**, or **retain under legally required retention** (e.g., transaction ledgers). Review financial, messages, national-team and doubles relations separately.
5. In one idempotent and audited server-only process, atomically archive/pseudonymize allowed history and erase unnecessary guest data. Only then delete the Auth identity, after constraints have been safely migrated. Constrain the worker to users with an expired, unconverted guest trial; never apply to registered accounts.
6. Block activation when the schema differs from the reviewed FK inventory, privacy retention basis is undecided, or any history-integrity assertion fails. Keep Guest Mode OFF until real anonymous signup/conversion E2E and all expiry edge cases pass.

## Acceptance tests (must run in disposable full-schema staging)

- Anonymous expired guest with no matches: active identity and private records erased; no unintended rows deleted.
- Guest with a **completed singles match**: winner/loser, score and opponent remain intact with anonymous public historical identity.
- Guest with **completed doubles match**, active doubles team, national-team entries and ranking snapshots: no bracket or public history corruption.
- Guest with **scheduled singles/doubles**: existing retirement walkover remains correct after erasure; advances once.
- **Both opponents expired**, and a match **in progress**: deterministic competition-safe decision, no completed-result rewrite.
- Guest with equipment, coins, messages, sponsor/finance/payment-related records: erase personal data while preserving only retention-required ledgers.
- Converted user and paid/registered user: absolutely no deletion, even if a guest trial once existed.
- Repeated worker, concurrent worker and partial failure: idempotent, recoverable, audited.
- Schema drift / missing archival record: fail closed with no deletion.
- Full migration replay fixed (existing `public.staff_members` order blocker), CI and production authenticated smoke tests green.

**Existing evidence:** PR #46 proves scheduled singles/doubles walkovers and result preservation in a minimal disposable PostgreSQL harness; it does not prove account deletion safety.

**Release gate:** This document and FK audit are preparation, **not** a claim that history-safe hard deletion has been implemented or approved.
