# Project Helios — Retired Guest Account Deletion Safety

**Status (20 Nov 2026):** Guest Mode disabled. Retirement from active competition is implemented. Real walkover and bracket propagation tests pass in a disposable PostgreSQL fixture. **Hard deletion of Auth/player records is deliberately NOT enabled.**

## Why direct deletion cannot be turned on yet

`public.delete_tennis_legacy_account_v1()` simply deletes the current `auth.users` row. The player is linked via `players.owner_user_id ON DELETE CASCADE`. Downstream tournament match participants and winners use `ON DELETE SET NULL`, while many other career, financial, ranking, result and equipment tables use `ON DELETE CASCADE` or `RESTRICT`.

The actual live-schema dependency count (read-only inspection) is:

| FKs referencing auth.users or players | Count |
|---|---:|
| Total | 188 |
| ON DELETE CASCADE | 146 |
| ON DELETE SET NULL | 23 |
| ON DELETE RESTRICT | 18 |
| ON DELETE NO ACTION | 1 |

Direct deletion could **erase completed match participant identities, historical rankings/results or financial records** and can also be blocked by RESTRICT relationships. Removing a guest from active game listings is not the same thing as irrevocably deleting account data.

## User-approved gameplay rules

1. Guest is eligible for **14 calendar days** from the original server timestamp; seven-day Premium expires independently.
2. Before the 14-day deadline, the guest can register to retain the same authenticated user ID and all career assets.
3. At expiry without completed registration, the server minute-job retires the guest, withdraws applications/entries, and grants opponent walkovers for scheduled matches not started (or cancels if no eligible opponent).
4. Matches already in progress and completed results are not rewritten; those records are retained for the game history.
5. Retired guest is excluded from active rankings; future guest gameplay and same-identity conversion are blocked.
6. Repeated retirement is idempotent.

## Required privacy-safe hard-delete design

- [ ] Define a minimal **non-identifying tournament history representation** for retired players: historical player reference/name policy, country, rounds, opponent, win/loss/walkover and score. Avoid email, session IDs, Google identity tokens, home city, financial balances and private communications.
- [ ] Decide whether history uses tombstone player records, immutable archive snapshots, or history-specific surrogate IDs; understand joins for every singles/doubles/national match and ranking history UI.
- [ ] Separate actual **account authentication data erasure** from durable competition history, and choose an approved retention/legal basis for necessary records.
- [ ] Audit each of the 188 FKs and all triggers/jobs. Document which child rows should be deleted, anonymized, archived, or deliberately retained (billing/transaction records may have separate legal obligations).
- [ ] Stage every required archive and FK migration **before** deleting a single real guest identity. Prove no match winner, bracket, ranking or public history is accidentally lost.
- [ ] Test account deletion after completed and walkover matches, double-expiry, active and future doubles teams, national-team involvement, messages, sponsor contracts, equipment and paid transactions.
- [ ] Ensure erasure has a bounded, idempotent, audited worker and never applies to registered users; don't create cleanup jobs on the live service until passing tests.

## Testing performed

The workflow `Helios H08 disposable guest walkover integration` loads a clean PostgreSQL schema and snapshots of the current live retirement function, the live singles bracket-advance trigger function, the live doubles bracket-advance trigger function and live doubles-opponent eligibility helper.

The rolled-back fixture `tests/helios_guest_retirement_ephemeral_db.sql` **passed**:
- 14-day expiry selection and one-time retirement;
- unstarted singles opponent wins a walkover;
- next-round singles bracket advances that opponent;
- unstarted doubles team is withdrawn and opposing team wins;
- previously completed match winner unchanged;
- second retirement pass processes zero accounts.

**Limitations:** This is an isolated minimal-schema integration test, not a full product browser E2E. It doesn't cover two expired opponents simultaneously, in-progress match interruption, complex qualification matches, national-team matches or a real Auth deletion. The separate full historical Supabase migration replay CI is blocked by a pre-existing `public.staff_members` migration-order issue. A proper complete-schema staging test is still required before Guest Mode can be launched.
