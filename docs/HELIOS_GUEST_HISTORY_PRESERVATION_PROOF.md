# Helios H08 — History identity preservation prototype

**Status:** disposable schema test only; no production account erasure, migration, or automatic deletion worker.

## What is actually tested

The isolated PostgreSQL test `tests/helios_guest_tombstone_proof_ephemeral_db.sql` replays the important `players.owner_user_id ON DELETE CASCADE` risk in a minimal fixture. It creates an expired, already-retired anonymous guest with a completed singles match where the guest won, and a completed doubles match where a team containing the guest won.

Inside a **transaction that ends with ROLLBACK**, the test:

1. Verifies guest eligibility using server-backed anonymous/expired/retired/unconverted flags.
2. Replaces the guest's public player identity with the placeholder **Retired Guest**, drops the Auth owner and clears the avatar/home city on the synthetic row.
3. Simulates deleting this synthetic Auth user.
4. Asserts the original singles participant and winner UUIDs, completed result, doubles team participant UUID and winner team UUID still match the public retained player row.
5. Asserts a converted permanent user and a still-active guest are **not eligible** for the unlink operation.

The fixture keeps the public historical player ID stable, allowing match references to survive Auth removal **in this simplified graph**. The placeholder label does not automatically anonymize historical match metadata, scores, country, or other associated records.

## Why it is not ready for production

The actual Tennis Legacy schema has **188 direct FKs and 818 reachable FK paths**, not the small fixture subset. Other tables may preserve direct identity data, hold legal financial records, or block deletion. The existing history/erasure audit is in `docs/HELIOS_GUEST_ERASURE_RECURSIVE_AUDIT.md`.

No account deletion worker should be deployed until:

- Every FK and dependent field is classified under an agreed retention/erasure policy, including doubles, national teams, messages, finance, storage, and Auth sessions.
- A complete isolated full-schema replay verifies completed singles/doubles results, the entire ranking and competition history, conversion safeguards, and all negative controls.
- Actual Auth erasure is orchestrated by a privileged server-only worker with retries, audit, no broad public grants, expiry checks and non-replayable access guards.
- Privacy implications of public player pseudonyms and historical match combinations are reviewed.

**Guest Mode remains OFF; this PR changes no production tables or real account data.**
