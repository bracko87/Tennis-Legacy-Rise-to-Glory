# Project Ace — Live Match Engine
Established 2026-11-26.

## Recovery baseline
- Production source baseline: fba2971f53236ce9cc3a0c074e5a4fd30811be4d.
- Recovery branch: backup/pre-ace-2026-11-26. Do not modify it.
- All experimental work belongs on project-ace; no production merge, database migration, preview deployment or scheduler changes without explicit release approval.
- Production database recovery is a separate gate: record the successful backup timestamp and verify restore availability in Supabase Dashboard. A healthy DB is not proof of a backup. Before production changes obtain a fresh recovery point, retain a secure off-site export if needed, and rehearse restore in isolation. Never put production dumps, credentials or personal identifiers in this public repository. Storage objects and deployment configuration require separate preservation as applicable.
- Do not restore the live database as a routine code rollback: it can discard legitimate player progress.

## Local-first pilot
- Reuse the designated existing ATP human administrator identity as the test persona; configure its local identity at runtime, not in committed source. Use a local Supabase instance or isolated synthetic fixtures, never production write credentials. Do not copy auth secrets or reset the real account password.
- UI visibility requires an explicitly enabled local Ace flag plus verified admin status and a designated test user. Server authorization must independently check authenticated user ID against a server-controlled allowlist, existing app_admins membership and fixture ownership. Default deny for anonymous, other administrators and ordinary users; no email-only or client-only security.
- Add a private Ace test match scheduled on demand or at a selected local time, against a synthetic ATP AI opponent. Keep fixture outside official tournament matches, calendar, rankings, money, equipment, injury, travel and notifications. No effect on the real player. Local test entry may appear in an admin-only test calendar. No production schedule writes.
- Existing matches and historical replays retain legacy engine and semantics. New test engine version must be opt-in per fixture.
- No additional paid hosted database branch is required for the initial local prototype.

## Milestones
- [x] Record source baseline and create recovery and development branches.
- [x] Confirm designated production account has admin role and ATP human player using read-only lookup.
- [ ] Verify successful database backup dated 2026-11-26 (dashboard confirmation pending).
- [ ] Audit current SQL point/scoring formulas and scheduling contracts.
- [ ] Build deterministic resumable game-by-game engine; no precomputed winner.
- [ ] Add private local fixture schedule, admin-only authorization and negative access tests.
- [ ] Add live score and condition indicators; both own and opponent observable metrics.
- [ ] Add coaching command validation, next-game activation and replay log.
- [ ] Test same-seed control vs intervention, legal scoring, retry/reconnect, offline progress, no duplicate events, no unauthorized visibility or writes.
- [ ] Verify scheduler isolation and no official side effects.
- [ ] Only after local acceptance and verified fresh database recovery: review production integration, performance, migration/rollback and explicit release approval.

## Migration preparation (v0.24-A)
- See experiments/project-ace/PRODUCTION_MIGRATION_PREPARATION.md for known mutation paths, disabled-default ownership policy and rollback design.
- Backup/restore proof, current schema audit, real ownership guards, source-ID health parity, authoritative career effects and explicit production authorization remain open.

## Acceptance
Admin can schedule and complete an isolated match, issue tactical changes during play, inspect live state and view recorded replay. Past events remain immutable, new commands affect only subsequent games, and non-designated identities are denied even via direct API. No real tournament data or account progression changes. Feature remains disabled outside the pilot.
