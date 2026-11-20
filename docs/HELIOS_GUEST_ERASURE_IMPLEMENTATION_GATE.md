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

## Minimal-schema implementation proof (PR #47)

The new `tests/helios_guest_tombstone_proof_ephemeral_db.sql` runs transactionally in the disposable PostgreSQL workflow. It models the live `players.owner_user_id ON DELETE CASCADE` relationship, retains and anonymizes an expired guest's public player row, detaches its Auth ownership, removes the synthetic Auth account, and asserts a completed singles match still references the same winner and participant. A converted permanent account is a negative control and must remain unmodified. The entire transaction ends with ROLLBACK.

This is **not** a production migration, full-schema test, legal retention decision, or confirmation that real Auth deletion is safe; actual dependent tables and stored private fields remain to be handled. Results must be confirmed from GitHub CI before claiming the proof passed.

## Additional retirement edge-case regression (PR #47)

`tests/helios_guest_retirement_edge_cases_ephemeral_db.sql` invokes the actual snapshot retirement worker and bracket functions against a disposable PostgreSQL schema, and checks: two expired singles opponents cause cancellation without a fabricated winner; two unavailable doubles teams withdraw and cancel; already in-progress singles stays in-progress; completed historical result/winner stays unchanged; both expired users retire once; re-running the worker does nothing. This fixture is registered in the dedicated GitHub Actions workflow. **Do not call it passed until its new CI run completes.**

An in-progress match being left unchanged during retirement is current worker behavior, **not** a finalized long-term rule for how an active match should conclude after expiry. That policy and any later reconciliation job still require separate design, tests, and full-schema validation.

## Verified read-only live schema inspection — 20 November 2026

Read-only queries against the **Tennis Legacy** Supabase project (no user rows returned and no data mutations) independently confirmed direct FKs referencing `auth.users` or `public.players`: **188 total** = 146 CASCADE, 23 SET NULL, 18 RESTRICT, 1 NO ACTION. These are *direct FK constraints*, not all recursively reachable dependencies. The player's `owner_user_id` column is nullable; both `first_name` and `last_name` are NOT NULL, which makes a neutral history tombstone technically possible, but does not constitute a safe deletion migration.

Material direct references include:
- `public.tournament_matches` (3 SET NULL participant/winner FKs) and `public.tournament_doubles_teams` (2 CASCADE player FKs): do not delete the public historical player row or its doubles teams.
- `public.tournament_match_simulations` (RESTRICT), `public.player_tournament_results` / `public.player_doubles_tournament_results` (CASCADE): preserve official outcome/statistical history before modifying any ownership.
- `public.billing_transactions`, `public.coin_ledger`, `public.user_wallets` (CASCADE Auth FKs) plus `public.career_finance_transactions` (CASCADE player FK): classify legal financial retention and private balances separately before deleting any Auth identity.
- `public.national_team_squad_members`, `public.national_captain_terms`, `public.tennis_clubs`, `control_center_private.tennis_season2_week1_preentries_v1` (RESTRICT): a blanket Auth deletion can fail, even after a player tombstone.
- `public.player_messages`, `public.national_team_chat_messages`, `public.tennis_club_chat_messages`: account erasure must address private communications and potential references or quoted identity in message payloads.
- Supabase Storage object ownership may block Auth user deletion; remove assets through the Storage API, not raw table deletions. Auth user deletion does not immediately revoke already issued JWTs; guest expiry access guards remain necessary.

**Decision:** maintain Guest Mode OFF, prohibit direct Auth deletion, and do not ship a worker based solely on the minimal fixture. The next full-schema implementation requires explicit per-table retention/erasure mapping, an automated schema-drift check, complete isolated validation, and separate operational review. For account privacy, an apparently neutral public player tombstone can still be linkable through country, match history, and other stored metadata; minimize fields and document retention basis.

Official platform references:
- https://supabase.com/docs/guides/auth/managing-user-data
- https://supabase.com/docs/guides/storage/management/delete-objects

## Direct-FK triage audit added

`tests/helios_guest_erasure_readiness_audit.sql` now produces the live direct-FK inventory with review-area groups and a drift signal against the confirmed 188-relationship baseline. Every row remains explicitly `REVIEW_REQUIRED`, and its final readiness status is `NOT_READY_FOR_HARD_DELETE`. Policy details are in `docs/HELIOS_GUEST_ERASURE_FK_CLASSIFICATION.md`. These are **read-only** tools, not an erasure implementation or approval. Full recursive mapping and staging tests still remain.

## Full direct-FK review ledger

The exact 188 direct constraints and their `pg_get_constraintdef()` definitions were read from the live Tennis Legacy **schema metadata only** and committed to `docs/HELIOS_GUEST_ERASURE_DIRECT_FK_LEDGER.md`. The ledger explicitly marks all 188 entries `REVIEW_REQUIRED`. It is more detailed than earlier heuristic summary tables, but is not a full recursive dependency graph or approved deletion policy. Physical guest Auth deletion remains blocked until each dependency is classified and the full-schema fixture passes.

## Exact direct-FK drift gate (2026-11-20)

The schema-only SQL query against the Tennis Legacy Supabase project confirmed 188 direct FKs and the deterministic MD5 signature `846107417041388f01cd703985f631d1`. The checksum is built from sorted parent table, dependent table, constraint name, deletion action and `pg_get_constraintdef`, not user records. The new `tests/helios_guest_erasure_fk_drift_guard.sql` fails with an exception if either the count or the full signature changes. It runs in a read-only transaction and contains no deletion statements.

This baseline is **diagnostic and fail-closed**, not authorization to erase users. Any migration that changes the schema requires a deliberate baseline refresh and repeat safety review. The guard does not cover transitive dependencies, triggers, storage files, GDPR retention requirements, or completed-match integrity, so passing it alone must never activate deletion.


## Recursive FK audit update — 20 November 2026

A second **read-only** production-schema inspection followed indirect constraints
starting from `auth.users` and `public.players`, using a cycle-safe OID path:

| Metric | Verified |
|---|---:|
| Direct foreign-key constraints | 188 |
| Distinct directly dependent tables | 156 |
| Paths through direct and indirect FK chains | 818 |
| Distinct dependent tables reached recursively | 180 |
| Tables reached only through indirect relationships | 24 |
| Longest dependency chain | 5 |

These are **schema paths**, not affected row counts. Examples of newly reached
tables include `tournament_doubles_matches`, `tournament_match_sets`,
`national_team_fixtures`, `national_team_division_standings`,
`national_association_finance_transactions`, `auth.refresh_tokens`,
and MFA records. A naive Auth delete risks more than the 188 direct FK edges.

`tests/helios_guest_erasure_readiness_audit.sql` now prints the full
reachable-path summary and indirect-only table list. The new
`tests/helios_guest_erasure_recursive_fk_drift_guard.sql` throws if the
818-path / 180-table / depth-5 baseline changes. It currently checks counts
rather than a reviewed whole-graph checksum, so matching counts **do not
prove** schema equivalence. The existing direct FK signature guard remains
necessary. Both queries were executed read-only against the Tennis Legacy
schema without accessing player rows or modifying production data.

**Release status remains BLOCKED.** No function or SQL migration now in this
PR physically deletes Auth users or public player records. A treatment
decision is still required for every affected table plus all private
credentials, storage assets and historical records; then full-schema
isolation and end-to-end checks are mandatory.
