# Helios H08 — Direct foreign-key classification and deletion blockers

Verified by read-only Supabase inspection on 20 November 2026. **The classification is a triage aid, not a legally approved retention schedule or a safe deletion worker.**

## Baseline

188 direct foreign keys target `auth.users` or `public.players`: 146 CASCADE, 23 SET NULL, 18 RESTRICT, 1 NO ACTION. The full recursively reachable dependency graph may be larger. The database contains several financial, communication, tournament, national-team, and other gameplay relationships.

The inventory script `tests/helios_guest_erasure_readiness_audit.sql` emits every direct FK and labels it **REVIEW_REQUIRED**. Its grouping by table name is a preliminary triage heuristic only, not an automated erase/retain decision. If the baseline changes, the erasure plan must be reviewed again. The script is read-only and does not read account, match or message contents.

## Review groups

| Area | Proposed handling to investigate | Key safety concern |
| --- | --- | --- |
| Official tournament and ranking history | Retain only minimally identifying historical records; preserve winner, draw, match score and points history as justified | Deleting player/team rows cascades to results or nulls participants |
| Doubles, national teams, clubs | Separate historical competition relationships from current membership and private communication | RESTRICT FKs and downstream team ownership |
| Billing, coins, finance, entitlements | Retain legally necessary payment/transaction audit information; erase needless identifying or game-only account balances | Financial records currently CASCADE with Auth/player deletion |
| Messaging and private communications | Remove or redact private guest content according to documented privacy policy; preserve counterpart's necessary experience | Content may contain directly identifying text |
| Other career/gameplay state | Delete disposable private state unless retention is required for an independent history invariant | Many tables CASCADE, potentially containing more downstream FKs |
| Auth, identities, sessions, Storage | Coordinate secure server-side cleanup; Storage files via Storage API, and continue expiry access guards because JWTs may remain valid | Auth deletion alone does not immediately invalidate JWTs |

## Required before implementing deletion

1. Build an **explicit** approved table-by-table mapping of direct *and recursive* FKs, distinguishing archive/retain/anonymize/erase, with a review of RLS, triggers, functions and storage.
2. Preserve necessary historical player/team identifiers and outcomes in staging before removing any auth identity. Do not treat country/match metadata as automatically anonymous.
3. Demonstrate full-schema test results for completed singles/doubles, ranking snapshots, national-team and club references, finance and messaging.
4. Ensure deletion never targets converted guests, non-expired guests, paid accounts or registered users, and implement an auditable, idempotent server-only worker with a fail-closed schema baseline.
5. Resolve existing full migration replay blocker (`public.staff_members` dependency ordering) and validate a truly isolated full staging schema.
6. Maintain Guest Mode disabled and do not schedule physical account deletion on production prior to all approvals and tests.

**Current state:** Tests on a minimal disposable schema pass; history-safe hard deletion against the full database is **not implemented**.
