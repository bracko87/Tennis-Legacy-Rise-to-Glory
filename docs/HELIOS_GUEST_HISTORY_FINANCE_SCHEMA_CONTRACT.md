# Helios H08 — Live-schema history and finance structural contract

Checked 20 November 2026 using the **read-only metadata** of the existing Tennis Legacy PostgreSQL project. No guest accounts, player history, billing transactions or other personal records were queried or modified.

## Verified boundaries

The SQL file `tests/helios_guest_history_finance_schema_contract.sql` verifies exactly **20 foreign keys** and **24 columns** relevant to guest account erasure. In particular, it confirms the expected `ON DELETE` behavior of player ownership; singles and doubles participants and winners; set scores, tournament results and ranking snapshots; and billing, wallet, coin, Premium, and career finance links.

Examples of hazardous behavior that this contract catches changing unexpectedly:

- `players.owner_user_id` cascades on `auth.users` deletion. Retain the player history separately before considering Auth erasure.
- `tournament_matches` participant and winner links are `ON DELETE SET NULL`, which could erase the historical identity of winners.
- `tournament_doubles_teams` and published singles/doubles result rows cascade when a player is deleted, risking broken official history.
- `billing_transactions`, `coin_ledger`, `user_wallets`, `premium_memberships` cascade on Auth deletion, and must be reviewed for charged payments, legal records, and entitlements.
- The private guest status has converted/retired/expiry fields, which are needed to prevent treating a permanent account as an expired anonymous guest.

## Verification result

The SQL contract was executed successfully against the **existing production schema in a READ ONLY transaction**. The separate offline Node check can verify that the SQL remains read-only and continues to name all critical relationships. The SQL checks the **actual database catalog** when run by an authorized operator.

**It is not full-schema deletion validation.** It does not simulate actual deletion, assert that private content has been erased, inspect all 180 linked tables, verify a live Auth conversion, or guarantee compliance with a retention policy.

Full-schema isolated staging and real browser tests are still necessary. This check adds **no** migrations, views, public RPCs, background jobs or changes to production data. Physical guest account deletion is NOT implemented; Guest Mode remains disabled.
