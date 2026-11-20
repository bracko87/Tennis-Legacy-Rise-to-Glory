# PROJECT HELIOS — Guest Mode file-level delivery status
Updated: 20 November 2026. Tennis Legacy: Rise to Glory **only**. This is an engineering tracker, not proof of production deployment.

## Release overview

| Workstream | Status | Evidence |
|---|---|---|
| PR #46: isolated guest retirement and walkover tests | MERGED to main; CI passed | https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/pull/46 |
| PR #47: deletion safeguards, audits and edge-case tests | DRAFT PR, **not merged**; latest CI passed | https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/pull/47 |
| Guest Mode | DISABLED | Pending end-to-end and deletion safety work |
| Permanent Auth deletion of expired guests | NOT IMPLEMENTED | Must preserve historical results and comply with privacy/retention decisions |

## File-level changes in PR #46 (merged)

| Path | Function | Status |
|---|---|---|
| `tests/helios_guest_retirement_ephemeral_db.sql` | Expiry, singles/doubles walkovers, next-round advancement, prior results and idempotency | MERGED, CI PASS |
| `tests/fixtures/helios_guest_retirement_schema.sql` | Minimal disposable PostgreSQL fixture schema | MERGED, CI PASS |
| `tests/fixtures/helios_guest_retirement_worker.sql` | Production function snapshot for test harness | MERGED, CI PASS |
| `tests/fixtures/helios_guest_retirement_singles_bracket.sql` | Singles advancement snapshot | MERGED, CI PASS |
| `tests/fixtures/helios_guest_retirement_doubles_bracket.sql` | Doubles advancement snapshot | MERGED, CI PASS |
| `tests/fixtures/helios_guest_retirement_doubles_helper.sql` | Doubles eligibility snapshot | MERGED, CI PASS |
| `.github/workflows/helios-guest-retirement-integration.yml` | Dedicated disposable DB workflow | MERGED, CI PASS |
| `docs/HELIOS_GUEST_ACCOUNT_DELETION_SAFETY.md` | Deletion hazard analysis | MERGED |
| `HELIOS_CHECKLIST.md` | Project-wide checklist update | MERGED |

## File-level changes in PR #47 (draft, not merged)

| Path | Function | Status |
|---|---|---|
| `tests/helios_guest_retirement_edge_cases_ephemeral_db.sql` | Two expired opponents, two unavailable doubles teams, in-progress match unchanged | WRITTEN, CI PASS |
| `tests/helios_guest_tombstone_proof_ephemeral_db.sql` | Synthetic historical identity survives unlink/deletion in minimal schema | WRITTEN, CI PASS; NOT full-schema proof |
| `tests/helios_guest_deletion_fk_audit.sql` | Read-only recursive FK inspection | WRITTEN; staging execution pending |
| `tests/helios_guest_erasure_readiness_audit.sql` | Read-only categorized direct-FK inventory | WRITTEN |
| `tests/helios_guest_erasure_fk_drift_guard.sql` | Fail-closed direct-FK signature check | WRITTEN; verified read-only against live schema |
| `docs/HELIOS_GUEST_ERASURE_DIRECT_FK_LEDGER.md` | Exact 188 direct FK constraint definitions | WRITTEN; live catalog verified |
| `docs/HELIOS_GUEST_ERASURE_FK_CLASSIFICATION.md` | Retention/erasure triage categories | WRITTEN; all policies remain REVIEW_REQUIRED |
| `docs/HELIOS_GUEST_ERASURE_IMPLEMENTATION_GATE.md` | Safety gates, test scope and known blockers | WRITTEN |
| `.github/workflows/helios-guest-retirement-integration.yml` | Extended integration workflow | UPDATED; CI PASS on PR #47 |

## Remaining functional implementation — files not yet delivered

These are work products to be designed/created, not existing paths:

- [ ] Reviewed direct **and recursive** dependency retention/erasure mapping with legal retention decisions, triggers, Storage and RLS.
- [ ] Full-schema historical identity and privacy-safe player/team archive/anonymization migration (not production-applied).
- [ ] Private communication, finance, equipment, national-team and club reference cleanup.
- [ ] Auth erasure worker with strict anonymous, expired and unconverted eligibility; revocation, retries, audit and safe Storage API handling.
- [ ] Tests using complete staged Supabase schema and realistic synthetic guest data, including financial and historical records.
- [ ] Repair full migration replay blocker involving historical `public.staff_members` ordering.
- [ ] Real anonymous signup and same-identity conversion end-to-end tests, 14-day boundary and browser production verification.
- [ ] Explicit Guest Mode release review and activation.

## Interpretation of status

**MERGED** means committed to main; **WRITTEN** means file committed to draft PR; **CI PASS** means the test workflow passed within its stated scope; **Pending** means required work or verification not done. A passing minimal-schema test does not prove production deletion safety.

Do not physically delete expired guest Auth accounts or enable Guest Mode on the basis of PR #47. The 188 direct FK snapshot is a review baseline, **not** an approved deletion plan.
