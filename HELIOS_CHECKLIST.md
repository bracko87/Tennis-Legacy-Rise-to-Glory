# PROJECT HELIOS — LIVE IMPLEMENTATION CHECKLIST
Tennis Legacy: Rise to Glory **only**. Project Saturn applies to ProPeloton Manager.

Updated: 20 November 2026. Checked = code/DB task complete, **not** automatically live-deployment verified.

## Status legend
- [x] Implementation merged into main, source validated (live deployment may still be pending)
- [ ] Not completed. In progress or discovery status is shown in parentheses.
- Every row must pass: design / implementation / automated tests / deployment / authenticated production verification before declaring fully live.

## Registration and onboarding
- [ ] **H01** Play as Guest / test player — design and abuse safeguards pending.
- [ ] **H02** Guest-to-permanent account conversion without progress loss — design pending.
- [ ] **H03** Google Sign-In — OAuth linking and setup pending.
- [ ] **H04** Passkey authentication — compatibility/recovery review pending.
- [ ] **H05** Apple or additional providers — evaluation pending.
- [ ] **H06** Optional date of birth, no date = no reward — UI and database not yet changed.
- [ ] **H07** Simplify registration UX — pending.
- [ ] **H08** Guest abuse and duplicate identity protection — pending.

## Analytics and Control Center (current workstream)
- [ ] **H09** Accurate site analytics — **implemented in DB/code:** 60-second automatic refresh, last reload, three-table page-view reconciler, recent event timestamp. **Still needed:** live authenticated UI verification, tracking through browser to DB and dashboard.
- [ ] **H10** Registration conversion — **implemented in live DB and code:** independently measured stages AND time-ordered browser-linked journey (homepage → registration → profile → human player → session ≥24h later), excluding browser IDs associated with multiple authenticated accounts. **Still needed:** CI/merge, authenticated production browser verification, cookie/consent/privacy audit and robust first-touch attribution. Browser identity is not person identity; no definitive conversion rates.
- [ ] **H11** Active authenticated players/guest sessions — **implemented in live DB and code:** authenticated human-player, foreground-interaction presence updates; 2-minute rolling active-player count with no personally identifying details in the admin UI. **Still needed:** CI, merge, deployment, authenticated browser test, cross-tab/idle/expiry validation, and guest monitoring when H01 launches. This measures recent activity, not an open websocket connection.
- [ ] **H12** Meaningful gameplay events — pending.
- [ ] **H13** Economy and transaction monitoring — pending.
- [ ] **H14** Searchable event and audit history — pending.

## Technical infrastructure/security
- [ ] **H15** PostgreSQL architecture/performance review — pending.
- [ ] **H16** Redis feasibility if measured need — pending, not a launch requirement.
- [ ] **H17** Security — **partial:** designated admin's stale account mapping repaired, server-side Admin Analytics permission confirmed with negative check, sidebar link admin-gated. Wider audit outstanding.

## Gameplay and presentation
- [ ] **H18** UI/visual polish — pending detailed UX review.
- [ ] **H19** External gameplay tests — pending.
- [ ] **H20** New-player guidance — pending.
- [ ] **H21** Highlight unique game mechanics — pending.

## Completed Helios deliveries
- **Nov 20 · PR #24:** Helios roadmap, 60-second refresh, last-loaded UI in existing Admin Analytics; automated CI passed, merged into main. Live UI deployment unverified.
- **Nov 20 · PR #25:** designated admin current ID corrected in Supabase; admin-only sidebar entry; last-seen events, five-minute recorded activity and three-source reconciliation; CI passed, merged into main. DB admin and non-admin permissions verified, live UI deployment unverified.

## Current delivery
- **H10 continuation (current):** admin RPC now exposes browser-linked, time-ordered stages without exposing visitor or account IDs. Dashboard component displays counts and limitations. At database test: 36 homepage browser IDs, 1 registration browser, 1 linked account, 1 linked player, 1 return after 24h (seven-day window ending Nov 20). Counts may change as traffic arrives. Awaiting CI, merge and authenticated UI verification.
- **H11 current task:** secure presence heartbeat RPC, restricted presence table, active-player dashboard summary. A DB update must reflect actual human foreground interaction; no background or admin-page updates. 2-minute TTL with per-user deduplication. Automated and browser verification pending.
- **H10** Registration and player creation activity totals: live database RPC migration applied, source/UI migration and tests in Helios feature branch; release and live UI checks are pending.
- Baseline for 7-day window ending Nov 20 (Berlin): 35 homepage visitors, 1 registration-page visitor, 2 accounts created, 2 human player accounts created, 1 registered account seen returning after 24h. They are *independent period counts*, not a causal funnel. Do not calculate a conversion percentage from them.
- Next: verify H10 linked-browser CI and merge, browser test and account recovery/consent review; then investigate H12 game activity event monitoring while finishing H09 and H11 production tests.
