# Helios H08 — Recovering authoritative historical migration sources

**20 November 2026.** Verified using read-only queries against `supabase_migrations.schema_migrations` in the existing Tennis Legacy database. These queries retrieved migration **source SQL and version metadata only**, not account, player, staff market, message, or payment rows.

## Major discovery

The production migration history currently has **812 applied entries**, while an earlier read-only GitHub scan found **688** `supabase/migrations/*.sql` files. This is evidence that the checked-in repository may lack migration sources required to start from an empty database. **Do not assume exactly 124 absent versions:** some checked-in migrations might not appear in the applied history, and the two totals need a version-by-version comparison.

The previously missing `staff_members` CREATE TABLE statement **does exist** in the original applied migration:

- Version: `20260903072608`
- Name: `staff_market_contracts_effects_and_scouting_foundation`
- Size: **25,975 bytes**
- Original SQL MD5: `d510f7741eb0959317c9534d1a7a5c14`

The applied migration also creates related staff contracts, finance and support objects. Its original SQL has been copied **without executing it** into:

`tests/recovered-migrations/20260903072608_staff_market_contracts_effects_and_scouting_foundation.sql`

It is **intentionally not** in `supabase/migrations`, so it cannot be accidentally picked up by normal deployment migration discovery. The archived file includes a provenance comment before the original SQL; the offline source-fidelity test removes this comment and validates the MD5 over exactly the original stored SQL.

The applied migration version/name snapshot is archived at:

`tests/recovered-migrations/applied-migration-manifest-20261120.json`

It contains **no account or game data**. The script `scripts/helios-compare-applied-migrations.mjs` compares applied versions to repository file versions and prints missing and repo-only versions plus a source-fidelity test in a credential-free GitHub Action.

## Engineering next steps

1. Identify the exact missing source migration versions from the CI diagnostic, not count subtraction alone.
2. Recover missing migration SQL from applied history **only after source inspection** for secret strings, private data literals, and executable effects. Keep recovered sources outside `supabase/migrations` until a safe replay path has been reviewed.
3. Determine whether all foundational migrations, Supabase-managed Auth/storage schema objects, extensions and required roles can be bootstrapped in free disposable PostgreSQL testing, or need a more faithful isolated Supabase container.
4. Add an explicit replay boundary and dependency order; do **not** apply all old migrations to today's live database or rerun the already-applied staff foundation.
5. Once full-schema replay succeeds, verify history-preserving erasure and real guest conversion using synthetic players. Approval of retention rules and end-to-end testing remain necessary.

**No production schema/data changes. No account deletion. No new paid Supabase project. Public Guest Mode and physical guest deletion remain OFF.**

## Limitations

Applied migration history proves a migration was recorded as applied, not necessarily that the current schema is identical to every historical intermediate state. The archived SQL should be treated as sensitive source code and not executed unreviewed. MD5 is used here as a simple byte-fidelity check against the recorded source, not a security signature.

## Version-by-version comparison — GitHub Actions verified

The credential-free diagnostic finished successfully and exposed additional migration-history divergence:

| Metric | Count |
|---|---:|
| Applied versions in production migration registry | 812 |
| SQL migration files currently checked into GitHub | 688 |
| Exact matching version IDs | 366 |
| Applied version IDs absent from GitHub | 446 |
| GitHub version IDs absent from applied registry snapshot | 322 |
| Missing applied versions with a **same-name** GitHub file at a different version | 219 |
| Applied migration names absent from GitHub **both by version and exact name** | 227 |
| Missing by version and name before the first 3 September staff reference | 10 |

The 219 same-name matches must be compared by SQL content and order; a matching name is **not** proof that their code is identical or safe to replay. The 227 remaining absences are source recovery candidates, not a definitive count of independently missing database features: migrations may have been renamed, consolidated, replaced, or otherwise reconstructed. Likewise, 322 repo-only version IDs do not necessarily mean 322 unapplied database changes.

Among the earliest high-priority missing sources are the staff foundation, staff-market seeding, staff effects, staff dashboard, and training-camp migrations. The original staff foundation has been archived and its SQL fingerprint has passed the automated check. The full migration chain has **not** been replayed and remains blocked for deletion release.

For reproducibility, the tool prints the first missing versions and the first renamed-timestamp examples in GitHub Actions logs for this PR.
