# Helios H08 — Cross-domain guest deletion hazard fixture

This scenario is an **isolated, representative PostgreSQL fixture**, not a full production-schema restoration, production deletion worker, migration or approval of any retention rule.

Read-only inspection of the actual live Tennis Legacy schema confirmed these relationships:

| Domain | Production relationship | Risk |
|---|---|---|
| Player ownership | `players.owner_user_id` → `auth.users`, CASCADE | Deleting Auth can delete player and cascade onward |
| Completed singles | `tournament_matches.winner_id` → `players`, SET NULL | Deleting player clears winner reference |
| National squad | `national_team_squad_members.player_id` and `nominated_by_user_id`, RESTRICT | Deletion can fail due to still-linked historical nomination |
| Billing | `billing_transactions.user_id` → `auth.users`, CASCADE | Unreviewed delete may destroy financial evidence |
| Coins | `coin_ledger.user_id` → `auth.users`, CASCADE | Unreviewed delete may destroy necessary transaction ledger |
| Career finance | `career_finance_transactions.player_id` → `players`, CASCADE | Individual career records may be destroyed |
| Equipment | `player_equipment_inventory.player_id` → `players`, CASCADE | Personal equipment state is dependent on career/player |
 
The synthetic test `tests/helios_guest_cross_domain_erasure_ephemeral_db.sql` models these deletion actions with small representative tables (named `h08_*`), then asserts:

1. Unreviewed Auth deletion throws an FK violation and rolls back atomically because a national squad nomination still references the guest.
2. An eligible synthetic expired-and-retired guest's public player can be unlinked from Auth and renamed `Retired Guest` while a completed match and national squad keep their historical IDs and results.
3. Equipment inventory, game finances, coin ledger, billing and the Auth record remain untouched during the simulation. There is deliberately no successful permanent deletion.
4. A second Auth deletion still fails while the historical nomination is unreviewed.

Every change is performed on a disposable PostgreSQL service and ends in `ROLLBACK`. The production game is not touched.

**What remains:** decide actual per-field retention/erasure treatment and legal basis; implement and validate a history-safe data model over all 180 dependent tables, include all national-team routes, messages, match scoring, storage, billing, Auth, background jobs, and session invalidation; then full-schema isolated staging and real browser signup/conversion tests. This is **not full-schema account deletion verification**.

**Safety:** Guest Mode stays OFF. Physical guest deletion stays OFF. Existing scheduled retirement and walkovers are unaffected.
