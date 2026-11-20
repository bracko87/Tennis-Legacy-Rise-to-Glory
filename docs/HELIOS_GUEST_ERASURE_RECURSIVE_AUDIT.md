# Project Helios H08 — Recursive account-erasure risk audit

**Verified 20 November 2026 against schema metadata in the live Tennis Legacy project, read-only.** This is an engineering risk inventory, not authorization to delete users.

| Measure | Observed |
| --- | ---: |
| Direct FK constraints referencing `auth.users` or `public.players` | 188 |
| Distinct directly dependent tables | 156 |
| All dependency paths, following downstream FKs recursively | 818 |
| Distinct reachable dependent tables | 180 |
| Tables reachable only via indirect FKs | 24 |
| Maximum chain length | 5 |

The 818 paths are schema paths, **not rows or records**. A cascade may affect fewer or more actual rows depending on the deleted account. We did not read personal player information to obtain this count.

Notable indirectly reachable tables include `public.tournament_doubles_matches`, `public.tournament_match_sets`, `public.tournament_match_weather`, `public.national_team_fixtures`, `public.national_team_division_standings`, `public.national_association_finance_transactions`, `auth.refresh_tokens`, and Auth MFA tables.

## Read-only control

`tests/helios_guest_erasure_recursive_fk_drift_guard.sql` opens a `BEGIN READ ONLY` transaction and fails when the recursive *counts* differ from 818 paths, 180 tables, or a maximum depth of five. The query is cycle-safe using OID arrays and a depth cap of 12; the current maximum is five. An identical count does **not** rule out schema changes, so direct-FK constraint signature checks, a full graph checksum, triggers, RLS, storage, and legal/policy review remain necessary. Production user tables are not queried.

The guard was executed successfully as a read-only query. The baseline is deliberately diagnostic, not a launch or deletion permission flag.

## Why physical deletion stays OFF

Deletion of a guest's `auth.users` row today may cascade through the owned `public.players` row and destroy stored tournament history, financial or social records, or be blocked by RESTRICT constraints. In particular, results, doubles matches and national-team standings can be indirectly affected. Existing retirement logic removes expired guests from active participation and grants eligible scheduled walkovers but does **not** physically delete Auth/player records.

Before implementing a deletion worker:

1. Reconcile the older history/tombstone proof in draft PR #47 with merged expiry-edge tests in PR #64. Do not merge conflicting worker fixtures blindly.
2. Explicitly approve a **table-by-table**, recursive delete/retain/anonymize/archive policy for competition history, national teams, club membership, communications, finances, Auth, and Storage. Country/history combinations may still be indirectly identifying.
3. Create neutral historic identities only with a supported retention basis and demonstrated correct winners, scores and brackets.
4. Validate full game-schema fixtures: completed singles/doubles, rankings, in-progress matches, national teams, payments, private messages, converted/paid accounts, and retry/concurrency.
5. Require an idempotent, audited, server-only erasure worker; block on schema drift and preserve expiration access guards, as JWTs may remain valid until expiry.

**No physical deletion or production migration was performed. Guest Mode remains disabled.**
