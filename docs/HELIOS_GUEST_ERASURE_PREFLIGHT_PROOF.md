# Helios H08 — Fail-closed deletion preflight (disposable test only)

This work provides a **non-destructive prototype** of an eligibility and safety check for expired guest erasure. It does **not** implement or enable Auth deletion.

## Test fixture

The standalone SQL in `tests/fixtures/helios_guest_erasure_preflight_fixture.sql` creates a restricted, SECURITY INVOKER function in a disposable PostgreSQL service. It only inspects synthetic identities and returns non-identifying blocker codes. It always returns `hard_delete_ready=false`, including when an expired anonymous guest is otherwise a possible future review candidate.

Checks include:

- unknown identity, still-active anonymous guest, unretired/converted identity;
- any synthetic billing transaction or active/unsettled paid membership;
- in-progress singles and doubles, plus completed singles/doubles requiring a history-preservation strategy;
- final unconditional `full_schema_erasure_not_approved` stop.

`tests/helios_guest_erasure_preflight_ephemeral_db.sql` verifies the blockers for synthetic active, expired, converted, paid and historically participating accounts, then rolls all test records back.

## Known limits

The financial tables in this harness are **minimal fixture tables**, not the actual application tables. This prototype does not cover all 180 dependent tables, charged-back purchases, Storage objects, user-generated private messages, national teams, retention approval, JWT/session revocation, concurrency, or a complete isolated Supabase Auth/browser test.

It **must not** be deployed as a production RPC or substituted for a real account deletion worker. In particular, matching these limited checks is not proof that an account is safe to erase. A full-schema staging test and approved per-table retention plan are mandatory.

Current production status: public Guest Mode is OFF, 14-day retirement exists, physical Auth deletion is OFF.
