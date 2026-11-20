# Project Helios H08 — Competition history and finance: proposed guest-erasure policy

**Status: engineering proposal requiring privacy/legal and product approval. NOT an approved retention schedule.** Prepared 20 November 2026 from read-only catalog inspection of the live Tennis Legacy schema; no player/payment rows were read or modified.

This refines the **180-table provisional inventory** in `docs/HELIOS_GUEST_ERASURE_180_TABLE_TRIAGE_LEDGER.md`. Every table remains `REVIEW_REQUIRED`. The public Guest Mode gate and physical Auth deletion MUST remain disabled.

## Product invariants (proposed acceptance criteria)

- A **completed** singles/doubles match must retain match ID, competition, round, status, scores, winner and opponent references, independent of expired guest account erasure. Historical results, ranking points and brackets must not silently disappear.
- For a guest who did **not** convert before 14 days: separate the **Auth identity and private account data** from only the minimal historical competition identity. A public display label such as `Retired Guest` is proposed, but a combination of country, matches, timestamps and opponent may still permit re-identification; treat as pseudonymous until reviewed.
- A guest who converted to a registered identity stays untouched by expiry cleanup. Likewise current registered, active guest and paid accounts.
- Keep at most what is justified for historical play or a legal financial retention obligation; delete or redact unrelated private guest data and remove public access to private accounting data. Do **not** assume guest accounts cannot have purchased products; check financial transactions, paid subscriptions and disputed payments before any deletion.
- Before Auth deletion, preserve approved history and reconcile all references **atomically** where possible. Use a guarded, idempotent, auditable server-side process, fail closed on missing migration, unexpected FKs or incomplete archive.
- No approval is implied for retention duration, legal basis, public access or archive structure; those remain decisions for the application operator and any necessary legal review.

## Competition history: provisional treatment matrix

| Table | Verified columns and FK risks | Proposed handling to review | Required validation |
|---|---|---|---|
| `public.tournament_matches` | `player1_id`, `player2_id`, `winner_id` reference `players` with **SET NULL** | Retain final matches with stable, non-auth historical participant references and outcomes | Completed singles winner, loser, round, match status unchanged |
| `public.tournament_match_sets` | `match_id` points to matches with **CASCADE** | Preserve score set rows when match is historical; never delete parent match | All set scores and tiebreak values unchanged |
| `public.tournament_doubles_teams` | Both player IDs reference `players` with **CASCADE** | Preserve historical team ID and minimally identifying participants; separate current team status | Team and partner relationships survive |
| `public.tournament_doubles_matches` | Team1/team2/winner team FKs **SET NULL** | Retain completed doubles bracket/winner/team IDs | No erased winner or broken bracket |
| `public.player_tournament_results` | `player_id` **CASCADE** | Preserve completed official standings and awarded ranking points via historical player | Result code, competition, points, payout values reconcile |
| `public.player_doubles_tournament_results` | `player_id` and `team_id` **CASCADE** | Preserve official doubles result and ranking points | Winner/partner and points survive |
| `public.player_ranking_snapshots` | `player_id` **CASCADE** | Determine how much historical position/point data is essential; minimize exact history where possible | Official prior published standings are not retroactively reshuffled |
| `public.national_team_fixtures` | Fixture and national association standings linked through additional FK chains | Preserve completed country/team outcomes, not private guest selection messages | National-team outcome unaffected |
| `public.players` | `owner_user_id` has **ON DELETE CASCADE** in live system; personal name, image and home city can be identifying | Investigate detached neutral history record and strict control of other personal columns; **do not run existing Auth delete** | Entire real player schema reviewed; other private player-linked tables separated |

These rows are examples, **not** a complete classification of the 66 competition-history tables. The other entries in the 180-table ledger continue to require one-by-one review. The rollback-only tombstone proof in `tests/helios_guest_tombstone_proof_ephemeral_db.sql` establishes only minimal-schema feasibility.

## Finance and entitlement: provisional treatment matrix

| Table | Verified columns and FK risks | Proposed handling to review | Required validation |
|---|---|---|---|
| `public.billing_transactions` | `user_id` **CASCADE**; EUR amounts and Stripe invoice/session/payment/customer IDs | Do not destroy records necessary for accounting, legal obligations or disputes; store such records in restricted retention-controlled form, sever unnecessary Auth link; redact needless personal/provider IDs | Payout/refund reconciliation and legal requirements, no public leaks |
| `public.premium_memberships` | `user_id` **CASCADE**; Stripe subscription/customer IDs, payment terms | Ensure termination/cancellation/reconciliation of any paid entitlement before Auth erasure; retain only what is lawfully needed | Paid user or active subscription never accidentally deleted |
| `public.coin_ledger` | `user_id` **CASCADE**; `birthday_rewards` FK to ledger **RESTRICT** | Differentiate purchased coins and free trial/earned coins; preserve only necessary financial evidence, not gameplay wallet history by default | Ledger sums, refunds and downstream RESTRICT resolution |
| `public.user_wallets` | `user_id` **CASCADE**; game coin balance and lifetime totals | Usually gameplay state, candidate for erase after paid-transaction reconciliation; final decision needs payment review | No outstanding value/refund/financial discrepancy |
| `public.career_finance_transactions` | `player_id` **CASCADE**; game cash, free-text description, JSON metadata, internal source ID | Candidate erase of personal career finances unless subset of official public prize history is essential; inspect free-text and JSON | Do not lose official historical tournament prize accounting |
| `public.tennis_premium_trials_v1` | `user_id` **CASCADE**; claim hash and notices | Trial entitlement expires; retain only minimal abuse-prevention proof if lawful and necessary, with bounded expiry | No second trial extension or repeat signup loophole |

No legal retention length or tax rule is asserted. The database may have **real monetary transactions**; never treat all `finance` tables as disposable game currency.

## Prioritized decision gates before implementation

1. **Historical record scope:** Decide what public match result, country, ranking and doubles information can remain when a guest identity is erased, and the lawful purpose/retention period. Neutral labels alone may not anonymize a person.
2. **Account and payment classification:** For each guest, distinguish free-only trials vs purchased goods, active subscription, disputed charge or pending refund. Escalate any financial ambiguity; don't delete blindly.
3. **Real schema-preserving migration:** Design separate history ownership/identity or compatible tombstone structure across ALL dependent tables. Avoid changing signed-off past outcomes.
4. **Restricted finance retention:** Identify ledgers requiring preservation and mechanisms to separate personally identifying Auth/Stripe data from necessary receipts, with access control and deletion windows.
5. **Disposable full-schema testing:** Test past/active singles and doubles, national-team results, bracket advancements, full rankings, paid purchases and converted accounts, errors/rollback, races and retries.
6. **Gate and rollout:** Only after approved review, explicit migration, regression and security testing consider a server-only cleanup worker. Keep public Guest Mode OFF until a complete browser E2E also passes.

## Explicit prohibition

**Do not enable `public.delete_tennis_legacy_account_v1()` as an expired-guest cleanup routine.** It currently deletes Auth and cascades to player-dependent tables. No SQL in this task deletes Auth users, changes account fields, or schedules a job.
