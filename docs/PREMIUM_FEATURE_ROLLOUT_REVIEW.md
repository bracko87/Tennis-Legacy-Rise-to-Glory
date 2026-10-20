# Tennis Legacy — Free/Premium controlled rollout

**Branch:** staging. **Latest reviewed:** 2026-10-20.
Develop in small, independently reviewable increments; no production main merge without approval.

## Master Premium feature tracker (2026-10-20)

**Status legend:** Implemented in staging = feature code exists (not necessarily browser/production QA complete); Proposed = not built; Review pending = requires visual, paid/trial and/or build checks.
**Production main:** unchanged by this tracker. All normal core gameplay and existing official statistics remain Free.

### Existing Premium benefits and commerce

| Feature | Where players find it | Access/Free visibility | Status and outstanding work |
| --- | --- | --- | --- |
| Private Life (assets, property, investments, marketplace and prestige) | Sidebar → Private Life | Free: menu and lock/upgrade page; paid/trial: module | Implemented; production gameplay QA remains separate |
| Ranking Protection (upcoming singles/doubles points expiry) | Overview and Rankings | Free: locked preview; paid/trial: expandable protection data | Implemented; verify actual expiring records |
| Statistics Intelligence (completed-match leaderboard comparison) | Statistics → near top, after filters | Free: visible locked panel; paid/trial: match win %, aces/match, winners/match | **Implemented in staging + Premium RPC deployed**; build, 8-language visual review and end-to-end paid/Free QA pending |
| 7-real-day Premium trial | First eligible game entry, Premium welcome/expiry popups | Auto offered once to eligible players; no payment card | Implemented; full browser lifecycle QA pending |
| Premium subscriptions (1/3/12-month choices) | Pro Packages | Visible to Free and Premium | Checkout and entitlements coded; real purchase/renewal/refund checks not yet confirmed |
| Paid Premium Coins reward | Pro Packages / wallet history | Paid subscribers only; trials do not receive invoice Coins | 30 monthly / 90 quarterly / 360 annually in code; payment fulfillment verification pending |

### Premium development backlog — implemented Deep Match Analysis plus remaining proposals

| Priority | Module | Proposed location | Description | Status |
| --- | --- | --- | --- | --- |
| 1 (staged) | **Deep Match Analysis** | Completed match → Match Details → below Match Statistics | Side-by-side match stats, serve/break/shot/point rates, set summary, evidence-based post-match insights | **Implemented in staging**, backend access tests passed; browser/build QA pending |
| 2 (staged) | **Player Development Intelligence — Skill History** | Skills → Player Development Intelligence | Individual attribute timelines and observed progression by technical, physical and condition skill groups | **Implemented on staging; database migration deployed and paid/Free/ownership RPC checks passed; build/UI QA pending** |
| — | Opponent Scouting Intelligence | Staff → Performance Analyst (Free gameplay, **not Premium**) | Scouting and tactical estimates require a hired analyst, with accuracy/preparation depending on staff quality and time | **Removed from Premium backlog; existing Free staff system remains** |
| 2A (staged) | **Development Outlook** | Skills → beneath Training Effectiveness | Verified skill trends and session comparisons; insufficient-data protections, no future guarantees | **Implemented on staging; frontend/build/browser QA pending** |
| 4 (staged) | **Tournament Planning Intelligence** | Calendar → Tournament Calendar, beneath month summary | Compare up to 3 tournaments: actual winner/finalist ranking points and prize amounts, entry status, health and competing-entry advisories | **Implemented on staging; read-only Premium RPC deployed and SQL access/data smoke test passed. Frontend/build/mobile/browser QA pending.** |
| 5 (staged) | **Season Planning Center** | Calendar → Calendar tab, below the monthly calendar grid | 52-week season map, private saved target shortlist, configurable finishing-stage ranking-point/prize scenarios, overlap warnings | **Implemented on staging; secure RLS table and Premium RPCs deployed; rollback DB checks passed. Browser/build/mobile QA pending.** |
| 6 (staged) | Training Effectiveness / Training Optimization Reports | Skills → below Player Development Intelligence | Real recorded fractional gains, level-ups, efficiency, camp vs regular training, and game-week trends; advanced optimization not yet built | **Training Effectiveness slice implemented on staging; Premium RPC deployed and backend ownership/access/data checks passed; browser/build QA pending** |
| 7 (staged) | **Staff Advisory Reports** | Staff → My Staff, below Free staff profiles | Expense history, salary scenarios, payroll share, contract expiry, quality/cost comparison, configured effect context | **Implemented on staging. Premium RPC deployed and backend checks passed; full frontend build and browser QA pending.** |
| 8 (staged) | **Sponsor Intelligence** | Finance → Sponsors, below Free sponsorship management | Compare currently available offers, guaranteed-versus-conditional income, objective deadlines and recorded payouts | **Implemented on staging; Premium read-only RPC deployed, ATP/WTA and access SQL checks passed; browser/build QA pending.** |
| 9 (staged) | **Financial Intelligence** | Finance → Overview, after Free cash-flow dashboard | Read-only 13-week scheduled cash outlook, staff/sponsor/travel cash drivers, 4/8/13-week adjustable what-if budgets and cash shortfall alerts | **Implemented on staging; owner/Premium RPC deployed and ATP/WTA DB smoke passed. Frontend build and browser/mobile QA pending.** |
| 10 (staged) | **Equipment Intelligence** | Equipment → Inventory, after existing Free item list | Owned equipment value, estimated remaining uses, condition risk, eligible resale retention and current same-category replacement cost-per-nominal-use comparisons | **Implemented on staging; Premium read-only RPC deployed, ATP/WTA SQL regression passed. Frontend build/browser QA pending.** |
| 11 (staged) | **Career Intelligence** | Statistics → Career, below existing Free career records | 24-week observed rank/points trend, season-over-season changes, surface-by-season patterns, first verified career milestones | **Implemented on staging; Premium RPC deployed and ATP/WTA SQL regression passed. Full frontend build/browser QA pending.** |
| 12 | Premium Convenience Tools | Premium tools / Overview | Saved comparisons, custom dashboard reports and optional advanced alerts | Proposed |

No paid report should claim unrecorded causes or hidden skills, and no Premium feature should change the match engine, core gameplay or ranking payouts. For every future module: show Free members a clear explanation and lock, serve Premium results only after server-side entitlement checks, and translate to all supported languages.

### Calendar Premium module placement (2026-10-20)

- **Calendar tab:** normal monthly calendar first, then the collapsed **Season Planning Center**.
- **Tournament Calendar tab:** monthly tournament information with collapsed **Tournament Planning Intelligence** in its original position.
- Placement only. Season targets, Premium access, reports, and official Free tournament entries are unchanged. The frontend was not released to `main`.

### Premium Career Intelligence — Slice 1 (2026-10-20)

**Staging frontend completed and read-only Premium RPC deployed; no production `main` merge.**

- **Placement:** `Statistics → Career`, after the full normal Free Career Records view, collapsed by default. The Free tabs, career totals, by-category, surfaces, season tables, ranking information and tournament/profile history are unchanged. The new Premium module fetches only when opened and entitled.
- **Recent ranking trajectory:** a 24-in-game-week fixed-tick timeline of *observed* weekly ranking positions or ranking points, selectable in the header. Thin vertical grid lines represent weeks from the real **in-game** 52-week tennis season, not dates on the wall clock. Weekly points come from existing `player_ranking_snapshots`: select the latest snapshot within a week. Missing weeks are **gaps**, not interpolated or silently inferred. Switching rank/points is visualization only, not gameplay. Rank numbers are better when lower; points are better when higher.
- **Advanced season comparisons:** official singles match win rates versus the previous season, best observed rank change, confirmed tournament titles and recorded singles prize money per season. These **add** to Free season totals instead of hiding them. No fake seasons, simulated historic matches or invented values. The connected game presently has only **Season 1**, so previous-season changes show unavailable until additional seasons are played.
- **Surface-by-season split:** per-season hard/clay/grass match win percentage and W-L counts from completed official singles matches, rather than only the existing all-career surface records in Free.
- **Milestone timeline:** first recorded completed official singles match, first win, first final match, first tournament title confirmed by tournament result, first observed Top 100, Top 50, Top 10 and world No. 1 ranking snapshots (only if reached). Milestones display in-game season/week, not real dates; first observed threshold is not claimed to be the exact crossing date. Milestones have no rewards or gameplay effects. No fabricated badges for unmet milestones.
- **API:** `supabase/migrations/20261020213000_premium_career_intelligence_v1.sql` adds read-only `get_premium_career_intelligence_v1(p_player_id uuid)`, a `STABLE SECURITY DEFINER` RPC with fixed `search_path`, active Premium/trial entitlement, actual `auth.uid()` and player ownership checks, revoking `PUBLIC/anon` execute. It reads completed official singles facts, official tournament results and existing snapshots; **does not** invoke `capture_world_ranking_snapshot_internal_v1`, process matches, award milestones or change ranking points.
- **Frontend/localization:** `src/components/premium/PremiumCareerIntelligence.tsx`, `src/styles/career-intelligence-premium.css`, `src/lib/careerIntelligenceI18n.ts` cover EN, DE, SR, FR, ES, IT, RU, PT. Subscription benefits updated. The graph uses fixed weekly guide lines and does not connect gaps. Empty/unranked careers are supported.
- **Validation:** successful DDL and complete regression run inside `BEGIN … ROLLBACK`. After deploying the RPC to the connected Supabase database, `tests/premium_career_intelligence_db_smoke.sql` passed again. Verified ATP and WTA Premium players, season total W-L against the source singles view, 24-sample rank limit, valid in-game weeks, earned confirmed titles nonnegative, milestone game weeks, other-player ownership rejection, simulated Free and anonymous rejection and anonymous EXECUTE revocation. An issue caught during static inspection of the TypeScript graph builder (closure flow-narrowing) was fixed immediately in staging. A separate Premium career with **zero completed official singles matches** was also validated, including a no-fabricated-matches/no-fabricated-milestones assertion now incorporated into the repeatable regression SQL. The updated post-deployment regression passed again. No player data changed.
- **Pending release QA:** full TypeScript/React build, responsive browser review, eight language visual checks, actual paid/trial/Free sessions, rank-gap chart display, no-ranked-history case, Season 2 or later data including actual season deltas, and title/milestone display in the live user interface. Do not merge to `main` until the approved consolidated release check.

### Premium Equipment Intelligence — Slice 1 (2026-10-20)

**Implemented in `staging`, read-only Premium backend deployed. `main` remains untouched.**

- **Placement:** `Equipment → Inventory`, directly below the existing Free owned-equipment section, not in the Free Marketplace or Gear Room. New module starts **collapsed by default**. Accessible Show/Hide button. Data is fetched only when opened and entitled; report refreshes after existing Free inventory purchases, sales, discards, equipment changes or marketplace/sponsor price changes. A button navigates to the original Free Marketplace without adding Premium purchase mechanics.
- **Existing Free functionality preserved:** equipment stats, item condition, current bonus values, equipment wearing out, all purchasing/selling/equipping, marketplace catalogue, sponsor discounts and free sponsor claims remain free. The Premium report aggregates and compares, it does not modify equipment, grant any increased stats, alter durability or improve purchases.
- **Owned equipment intelligence:** owned item count, equipped count, number below 40% condition, historical purchase money attached to **still-owned** items (NOT total equipment spending), and the existing rule-based resale value estimate across owned items. Per item: nominal matches/uses remaining based on current condition and its own advertised base wear rate, original paid price, eligible resale estimate and percentage of paid price retained. Starter/sponsor/reward equipment is clearly not counted as paid/resellable where the Free data disallows resale; ineligible retention has no numerical percentage.
- **Comparable marketplace choices:** select an owned item to view up to five presently available/limited catalog alternatives of its same equipment category; accessories further match their specific accessory kind. Candidates are sorted by **current configured price / advertised catalog estimated uses** (not by actual competitive effectiveness). Shows market price, estimated uses, durability, surface and tier. Sponsorship discount/current price is computed using the same Free backend formula and currently valid sponsor-contract rows; possible free sponsor item claims are flagged rather than fabricated as free normal market prices.
- **Important limitations:** nominal uses remaining = floor(condition / item's configured wear per match) and is only a transparent arithmetic indicator. Surface mismatch, weather, gear protection, match duration, equipment effects and tournament-specific mechanics can change real wear. Cost per nominal use does not mean actual lifetime return, expected performance or best choice. Purchasing and final price checks always happen through the normal Free Marketplace.
- **Implementation:** new `src/components/premium/PremiumEquipmentIntelligence.tsx` and `src/styles/equipment-intelligence-premium.css`; localized `src/lib/equipmentIntelligenceI18n.ts` supports EN, DE, SR, FR, ES, IT, RU and PT. Subscription comparison listing updated. RPC `get_premium_equipment_intelligence_v1(p_player_id)` in migration `supabase/migrations/20261020195000_premium_equipment_intelligence_v1.sql` explicitly checks `auth.uid()`, active Premium/trial, owner/human player and return-player integrity; reads the same authoritative equipment inventory, catalogue, valid technical-sponsor contracts, and immutable Free resale formula without invoking the mutable Free dashboard routine. `STABLE SECURITY DEFINER` with pinned search path; `anon` EXECUTE revoked. No updates to equipment tables, finances, bonus calculations or simulation.
- **Backend validation:** dry-run DDL passed; full `tests/premium_equipment_intelligence_db_smoke.sql` passed within same rollback transaction. Applied migration to connected Supabase, reran the regression successfully. Verified ATP and WTA Premium careers, report integrity, owned item count vs Free dashboard, reconciled aggregate purchases and resale, valid wear/condition fields, available catalog only, denied other-player/Free/anonymous access and anon function privileges. No test state persisted.
- **Release blockers:** TypeScript/React production build, responsive browser review, eight-language visual layouts, genuine Premium/Free/trial browser entitlements, inventory changes while report expanded, sponsor free-claim pricing and equipment performance on different surfaces. **Never merge to `main` without approved consolidated release validation.**

### Equipment Intelligence — Production RPC 405 correction (2026-10-20)

- **Incident evidence:** a real browser request `POST /rest/v1/rpc/get_premium_equipment_intelligence_v1` returned HTTP **405** at 15:47:40 UTC. PostgreSQL logged `25006 cannot execute UPDATE in a read-only transaction`, specifically `sync_player_technical_sponsor_contracts_v1` called via `get_equipment_dashboard_unfiltered_v1` → `get_equipment_dashboard_v1` → the newly added Premium STABLE RPC. The original writable-transaction smoke test had missed this.
- **Correction:** `supabase/migrations/20261020221500_fix_premium_equipment_intelligence_readonly_v2.sql` replaces the original RPC body, retaining its Premium and owner guards, with **pure SELECTs** from the same authoritative inventory, catalogue, loadout and current valid sponsor-contract records. It uses the actual Free resale function and sponsor price formula, but never calls any equipment/sponsor/finance synchronization or writes. The function remains `STABLE` so PostgREST can safely dispatch it in a read-only transaction.
- **Verification:** deployed the corrected function to connected Supabase after rollback dry-run and successful original regression. `tests/premium_equipment_intelligence_readonly_db_smoke.sql` then passed with `SET TRANSACTION READ ONLY` across **all five** currently Premium/trial careers in ATP and WTA, reconciling the correct inventory counts and catalogue arrays. A separate rollback comparison verified that every eligible career's Premium inventory item condition, paid price, resale value and equipped status, plus all returned alternative catalogue prices, match the normal Free dashboard values. This fix does not change existing player equipment, salaries, sponsors, or item effects.
- **Remaining:** actual browser reload with a signed-in Premium user and responsive/UI smoke after updating staging; no `main` merge or production frontend deployment occurred during this repair.

### Premium Financial Intelligence — Slice 1 (2026-10-20)

**Code committed to `staging`; Premium backend deployed to connected Supabase. `main` unchanged.**

- Placement: `Finance → Overview`, below the normal Free financial dashboard; collapsed by default with an accessible Show/Hide toggle, lazy fetch only after Premium user expands. The existing Free Finance overview, ledger, tax tab, transactions, charts and Sponsor tab remain unchanged.
- Baseline report: `get_premium_financial_intelligence_v1(p_player_id)` returns verified **last 13 in-game weeks** of income/expense ledger totals (excluding opening balance), current career-account cash balance and next 13 in-game weeks of known scheduled main-sponsor installments, active staff payroll payments, and estimated planned travel departures. Cash projections are calculated from today's balance forward; **never** apply or post actual money. Charts show equal-width weekly guides across the selected horizon.
- Client-only scenarios: players choose a 4-, 8- or 13-week horizon and edit hypothetical additional weekly expenses, hypothetical additional weekly income and an up-front one-time expense. The UI compares baseline and custom closing cash, full weekly table, line chart, and negative-balance warning. Input changes produce a computed scenario **only**, never update the DB, player balance, sponsor contracts, training, staff bonuses or match outcomes. Reset restores zero assumptions.
- Measurement limits: contractual sponsor installments are scheduled, not guaranteed transfers. The known-schedule baseline **does not forecast** prize money, uncertain sponsor bonuses, monthly future tax settlements, hotel fees, lifestyle costs, training purchases, new contracts, or changes to bookings. Uncertain income is never silently presented as guaranteed; user-supplied additional income is explicitly hypothetical. No prediction of wins or cash benefits for Premium.
- Data access: migration `supabase/migrations/20261020194000_premium_financial_intelligence_v1.sql` creates a read-only `STABLE SECURITY DEFINER` RPC with pinned search path and explicit checks for `auth.uid()`, active Premium/trial entitlement and ownership of the human player. No exposed extra tables, no direct client ledger access, explicit revocation of anonymous execution.
- Eight supported languages via `src/lib/financialIntelligenceI18n.ts`; responsive module `src/components/premium/PremiumFinancialIntelligence.tsx`, stylesheet `src/styles/financial-intelligence-premium.css`.
- Validation: DDL dry-run and `tests/premium_financial_intelligence_db_smoke.sql` together passed inside a rollback transaction. Deployed Supabase migration; ran the same regression after deployment, **passed** for ATP/WTA Premium owner data, 13 historic and 13 future weekly rows, opening cash matching actual account, historical totals, known-schedule totals, consistent weekly net math, cross-player access denial, Free/anonymous denial and SQL privilege checks.
- Additional independent SQL audit: for active ATP and WTA Premium career fixtures, independently recomputed every 13-week future staff salary installment, sponsor installment and planned travel cost plus historical ledger income/expense directly from source tables. All matched the new RPC totals. This was executed inside a rollback transaction and caused no player data changes.
- Security-advisor review: Supabase flags the authenticated `SECURITY DEFINER` RPC as a review warning. The intended API design requires explicit Premium and player ownership checks; the regression confirms the cross-player/Free/anonymous requests are rejected and `anon` lacks SQL `EXECUTE` privilege. Privileged RPC exposure should remain in security review before release.
- **Release blockers:** full frontend/TypeScript build, mobile and desktop browser checks, actual Free/paid/trial view tests, cash transitions across a new in-game day and season, staff/sponsor changes while report open, debt/negative projection scenarios, checking boundary behavior for known travel costs and sponsor schedules. Do not merge to `main` without consolidated validation and approval.

### Premium Sponsor Intelligence — Slice 1 (2026-10-20)

**Staging only frontend, deployed read-only Premium reporting RPC; no `main` release.**

- Placement: `Finance → Sponsors`, below the existing Free sponsor offer and active-contract panels. An accessible **collapsed-by-default** Show/Hide report button appears in the Premium header. The existing Free sponsor negotiations, offer list, signing, objective cards, weekly sponsor payments and equipment technical sponsorships remain unchanged.
- More than Free: side-by-side **currently open offer** comparison (guaranteed contract amount, weekly installment, conditional performance bonus pool, maximum *only if all objectives are earned*, conditional share of maximum, number of proposed objectives, days remaining to offer expiration). The normal Free offer signing buttons remain the only way to accept a sponsor. Signed careers typically have no open offers; the report clearly shows the empty-offer state instead of inventing alternatives.
- For an active main sponsor: separates **guaranteed money actually credited** (positive `sponsor_contract` finance-ledger transactions), remaining guaranteed scheduled amount, bonus rewards attributed to completed objectives, bonus payments actually credited to the ledger for that contract, unresolved conditional bonuses and failed/expired bonus value. No expected-value modeling or false forecast.
- Objective attention queue: unresolved upcoming/active objectives sorted by recorded status and deadline, with reward and days remaining. Non-ranking objectives can display recorded target-progress percentage; ranking peak and season-finish ranking objectives are correctly treated as **binary milestones** and never shown as a misleading linear percentage. Highlights deadlines within 28 in-game days; uses the in-game clock only.
- Backend: `supabase/migrations/20261020190000_premium_sponsor_intelligence_v1.sql` defines `get_premium_sponsor_intelligence_v1(p_player_id uuid)`, a read-only `STABLE SECURITY DEFINER` RPC with explicit `auth.uid()`, active Premium/trial entitlement, human-career owner guard, pinned search path and explicit revoke of `anon`/`PUBLIC` execution. It reads existing sponsor contracts/offers/objectives and posted USD finance transactions. It **never calls the existing mutable sponsor dashboard refresh routines** and never issues payouts, signs contracts, updates goals, or changes gameplay.
- Frontend: `src/components/premium/PremiumSponsorIntelligence.tsx` inside `src/components/finance/FinanceSponsorEnhancement.tsx` beneath the Free section (which already mounts in Finance/Sponsors via its existing portal). It is refreshed upon documented Free sponsor dashboard changes. Eight-language translation bundle `src/lib/sponsorIntelligenceI18n.ts` (EN, DE, SR, FR, ES, IT, RU, PT) and responsive CSS.
- Validation: successful rollback DDL test followed by `tests/premium_sponsor_intelligence_db_smoke.sql` in the same rolled-back transaction. Applied migration to connected Supabase and reran the smoke test successfully. Both ATP and WTA Premium player paths, money reconciliation, objective counts, rank milestone accuracy, cross-owner denial, simulated Free/anonymous denial, and anon SQL privileges passed. A small historical mismatch exists between the total posted sponsor objective transaction count and rows currently linked to stored sponsor objectives; only explicitly linked payments are attributed to the current contract, avoiding overstatement.
- Additional verification: a genuine Premium career with no active main sponsor returned a valid null-contract/empty-offer report without fictitious values. Supabase security advisor reports a review warning for the authenticated SECURITY DEFINER RPC (intentional for guarded access), and the backend tested explicit Premium/ownership checks plus the revoked anonymous role. The current test snapshot has no *open* sponsor offers, so the multi-offer comparison must be tested later with an isolated fixture.
- **Outstanding release gates:** local React/TypeScript build; mobile/browser visual checks; paid/trial/Free entitlement tests with actual browser sessions; multi-offer comparison and expiry boundaries; sponsor signing/decline updating the panel; live objective refresh and 28-day deadline transitions. Do not merge to `main` before the approved consolidated release check.

### Premium Staff Advisory Reports — Slice 1 (2026-10-20)

**Committed to staging; Premium read-only Supabase endpoint deployed. No merge to `main`.** Free Staff retains all hiring, firing, contract terms, staff bonuses and ordinary staff profiles.

- Placement: `Staff → My Staff`, below the Free staff role/profile cards. The Premium panel is **collapsed by default**, with a localized accessible Show report / Hide report header control. The report is fetched only when expanded; Free accounts see a nonintrusive locked explanation.
- New analyses: 4-week and 13-week unchanged-salary scenarios, estimated remaining salary commitment across active contracts, actual posted staff financial ledger totals (all-time and last 28 in-game days for active contracts), payroll share and salary comparison per employee, approaching expiries within 28 in-game days, and a descriptive quality-to-cost ratio (staff overall rating per US$1,000 per week). Displays up to two current configured engine staff effects per employee **alongside their costs** to contextualize tradeoffs.
- Critical distinction from Free: the Free page already exposes current employment, individual wages, and engine effect values. Premium adds payroll scenarios, contract-liability aggregation, actual recorded spending analysis and side-by-side cost/quality/role-effect context. It does **not** increase staff quality or impact and it does not conceal fundamental employment mechanics.
- Measurement integrity: no false ROI claim or assigning permanent skill gains to a specific staff member. The game stores team-level staff snapshots but does not prove individual historical causal impact. Configured engine effects shown next to costs are not audited historical delivered bonuses. The remaining wages estimate rounds to whole weeks and is NOT a termination fee or an actual invoice. Run-rate figures assume existing salaries continue unchanged, without adding new hires or contract renewals.
- Backend: `supabase/migrations/20261020175500_premium_staff_advisory_reports_v1.sql`. `get_premium_staff_advisory_v1(p_player_id uuid)` requires actual user authentication, Premium/trial entitlement and ownership of the human player. The report uses real current staff contracts, staff ratings, public Free role-effect summaries and `staff_financial_events` rows with status `posted`. The RPC is read-only, enforces `search_path`, denies anonymous execution and never changes gameplay, staff contracts or player balances.
- Eight languages supported: EN, DE, SR, FR, ES, IT, RU, PT, using `src/lib/staffAdvisoryI18n.ts`; responsive report in `src/styles/staff-advisory-premium.css`.
- Database validation: migration applied only after a successful rollback dry-run including the full regression. `tests/premium_staff_advisory_db_smoke.sql` passed again after deployment; tested ATP and WTA Premium career ownership, exact weekly/4-week/13-week payroll arithmetic, ledger/nonnegative rating checks, owner-only access, Free/anonymous denial and RPC privileges. Both tour worlds had an active-staff Premium fixture. No player/staff data changed.
- Additional validation: the Premium/no-active-staff case passed a rollback test (zero members, zero projected commitments, and no phantom salary entries). In the Staff page integration, the report automatically reloads after Free staffing changes via a stable contract fingerprint.
- Outstanding release gates: full TS/React build, mobile browser visual check, eight-language layout, paid/trial/Free actual browser flow, browser verification of staff hire/termination refresh, and comparison under expiring contracts. Do not merge to `main` until release validation and user-approved staging-to-main merge.

### Season Planning Center — Slice 1 (2026-10-20)

**Implemented on `staging`; database migration deployed; production `main` remains unchanged.**

- Location: `Calendar → Calendar` tab, below the regular monthly calendar grid and its bottom navigation. Tournament Planning Intelligence remains in the separate `Calendar → Tournament Calendar` tab. The Premium module is **collapsed by default**, with a local-language Show/Hide header toggle. The Free Tournament Calendar, tournament detail page, official application/entry, draw and rewards remain available as before and are not duplicated.
- Full season: all 52 in-game competitive weeks for the current game season and the player's own ATP/WTA world, rather than only the calendar's selected month. Calendar buttons highlight the current week and saved targets; click a week to see scheduled tournaments. Search by name/city, filter by surface and category. Links go to ordinary tournament detail pages.
- Target editor: **up to 20 privately saved planned tournaments**, with priority High/Medium/Low and **hypothetical** finishing-stage scenario Quarterfinal, Finalist or Winner (only options configured in the backend for that tournament). Select, edit and remove targets without registering for a tournament. A locked/past event cannot be newly selected or edited; removal remains possible. Changes persist in the database across devices/sessions.
- Rewards and strategy: points and USD prize amount for configured finishing stages, full-season **gross illustrative** totals for saved choices; **not** expected points, net ranking changes, financial forecasts or guaranteed future results. An unavailable stage payout displays a dash; scenarios must never be interpreted as ranking replacement simulations. This report does not estimate probabilities.
- Conflicts: overlaps among the user's own saved targets plus warnings based on accepted singles entries and pending singles applications. Future double entries, national teams, training camps and travel time are not yet exhaustively included; callers must use the normal calendar and tournament eligibility process. The existing player and staff mechanics are unchanged.
- Database: `supabase/migrations/20261020170500_premium_season_planning_center_v1.sql`. New `player_premium_season_targets` table with row-level security enabled, no direct anon/authenticated table privileges, player/competition foreign keys, category/check constraints and compound primary key. Security-definer RPCs `get_premium_season_planning_v1` and `save_premium_season_target_v1` verify actual `auth.uid()`, the player's ownership, active paid/trial entitlement, current in-game season and player-world competition. Save serializes on the owned player row, limits targets to 20 and validates the requested stage against configured ranking-point stages. Anonymous RPC execution revoked. Both functions expose planning only and never mutate entries, matches, actual ranking points or prize payouts.
- Eight-language localization: `src/lib/seasonPlanningI18n.ts` for English, German, Serbian, French, Spanish, Italian, Russian, Portuguese.
- Validation: migration and full report/save/remove tests were first run inside a rollback transaction. The migration was then applied to the connected Supabase project; `tests/premium_season_planning_db_smoke.sql` passed **after** deployment, checking both ATP and WTA, full-season data consistency, saving/removing a plan and reading it back, opposite-world rejection, owner-only read/write, Free and anonymous rejection, privilege restrictions and transaction rollback. No test target rows persisted.
- Calendar consistency: follow-up migration `supabase/migrations/20261020171600_premium_season_planning_active_series_guard.sql` excludes inactive tournament series exactly as the Free Tournament Calendar does. Post-migration ATP/WTA smoke test passed.
- Server-side 20-target limit and edit-in-place behavior passed a dedicated 21st-target rejection test within a rolled-back transaction; repeatable `tests/premium_season_planning_limit_db_smoke.sql` is committed to staging.
- Security advisor intentionally notes RLS enabled without table policies (no direct table privileges); the SECURITY DEFINER RPCs accept the `authenticated` role only to perform explicit Premium/ownership checks. These warnings are expected for this RPC-only design. Preexisting public-schema RLS findings are a separate audit item.
- **Still required before release:** local React build and TypeScript checks, browser visual review (desktop/mobile), Free/paid/trial interaction checks, simultaneous multi-request contention testing for the 20-target cap, past-tournament browser edge cases, and current-season transition validation. Do not merge to `main` until approved and validated.

### Premium Tournament Planning Intelligence — Slice 1 (2026-10-20)

**Staging code, backend deployed, no release to main.** Adds `src/components/premium/TournamentPlanningIntelligence.tsx` to `Calendar → Tournament Calendar`, immediately beneath the selected month's summary. Premium section is collapsed by default. Accessible Show/Hide button in the header; report loads only when the owner expands it. Free sees a short locked explanation and keeps the entire existing calendar, tournament detail, entry eligibility, draws and application actions.

**Existing source data, no invented numbers:** `get_tournament_calendar_v2` (official calendar and entry status), `tournament_ranking_point_rules` (winner/finalist stage points), `tournament_prize_pools` and `tournament_prize_payouts` (official announced pools and potential winner/finalist payouts), `player_tournament_blocked_by_health_v1` (health warning), currently active `tournament_entries` and pending `tournament_applications` (overlapping weeks). Detects alternative tournaments with overlapping week windows. No expected-return probabilities, unsupported rank thresholds, or claimed guarantees of entry, winnings or title.

**New endpoint:** `supabase/migrations/20261020161500_premium_tournament_planning_intelligence_v1.sql` defines a read-only, `STABLE SECURITY DEFINER` RPC `get_premium_tournament_planning_v1(p_player_id,p_season,p_month)`. Checks `auth.uid()`, active paid/trial entitlement, human career ownership, valid current in-game season and month. Anonymous execution denied and authenticated execution permitted. Restricts analysis to player's own ATP or WTA world. No direct client read permissions are added to private game data and no game mutations.

**Presentation:** selectors allow side-by-side comparison of up to three distinct tournaments within the selected in-game month; table shows category/surface, start–end weeks, winner/finalist points, total prize pool, possible stage payouts, main/qualifying capacities, current entry, health and conflict advisories, other overlapping tournament choices. Each column links to the normal Free tournament page for official entry actions. Offers all eight supported languages via `src/lib/tournamentPlanningI18n.ts`.

**Important limitations:** advisory indicators are not official eligibility approval. Ranking, main-draw qualification and final entries are determined by the normal tournament entry system, not this report. Scheduling warnings currently cover known competing singles active entries and pending singles applications; doubles, flights/travel and national-team obligations require independent validation. Category points are configured rewards for those finishing stages, never projected or expected points. Dollar values denote official prize pools or stage payouts, never guaranteed income.

**Checks:** initial migration creation and owner/non-owner/Free simulation passed under a rollback transaction. Read-only endpoint deployed to connected Supabase, and regression `tests/premium_tournament_planning_db_smoke.sql` passed: report shape and month matching, point and week constraints, owner-only access, Free and anonymous denial, RPC privilege checks and owned-world isolation for both ATP and WTA Premium careers. Historical player/tournament data unchanged. No staging → main merge.

**Pending gates:** actual React/frontend build; browser visual responsiveness; paid/trial/Free manual access on both ATP and WTA careers; race conditions changing calendar month; edge cases with zero entries or canceled tournaments; all eight language layouts. Only merge with explicit approval and full consolidated release validation.

### Skills page follow-up — Free history layout and Premium collapse (2026-10-20)

**Staging implementation, frontend/browser QA pending.**

- Player Development Intelligence starts collapsed, matching Training Effectiveness and Development Outlook. The Premium badge at top right has become a translated accessible Show report / Hide report button. Report data loads only after expansion.
- Free Development History remains a three-line aggregate overview (Technical, Physical and Readiness); the Premium individual-attribute history has selectable separate skill timelines, change tables, and training intelligence. They are not the same chart duplicated as two pay tiers.
- Development History shows the most recent **up to 24** actual in-game weeks. Before a full 24-week recorded span exists, start at the earliest available verified snapshot rather than reserving blank pre-game weeks at the left. The plotted line and week grid occupy the complete width.
- Each displayed week receives one evenly spaced vertical gridline and small numeric tick; season names appear in a separate row below. This replaces the overlapping full-length Season/Week text labels. No real-world dates or invented skill snapshots.
- For the currently shown example, Season 1 Weeks 2 through 16 produce 15 evenly spaced full-width tick positions. After 24 historical weeks are available, the chart becomes a rolling 24-week window.
- Backend week-index formula was previously checked across 1,098 game-days and matched all season transitions. Production merge and full frontend build remain pending.

### Skills UI refinement + Premium Player Development Intelligence Slice 3: Development Outlook (2026-10-20)

**Staging only:** both UI adjustments and Development Outlook code are committed, without merging to `main`.

- **Free Development History:** the Skills chart displays the latest **up to 24** actual game weeks from the first verified observation through the present, anchored to `get_game_clock_v1()`. Each week has one full-height vertical line and its numeric week label, with the localized season name displayed below the sequence. There are no blank pre-game slots. The values plotted are only recorded snapshots, not guessed history. Game weeks are 0–52 and roll correctly across seasons. The exact clock formula matches `absolute_game_day_v1`: week 0 covers the first two in-game days, week 1 begins on day index 2. SQL checked the formula over 1,098 in-game days (three complete seasons) with zero mismatches. Historical undated snapshots remain excluded.
- **Premium Training Effectiveness:** starts collapsed; the old chart icon is removed, replaced in the same header position with accessible Show/Hide report button. The table, summary metrics and charts are rendered only when expanded. Translated toggle controls in all eight supported languages.
- **Development Outlook:** a separate, collapsible, fully Premium-gated report directly below Training Effectiveness. Uses existing entitlement-protected `get_premium_training_effectiveness_v1` and `get_premium_player_development_v1` RPCs, both verifying owner and subscription/trial; no new database function or game-engine change. It reports technical-vs-physical saved session gains, strongest/lowest gains among trained attributes, verified whole-level changes between documented weekly snapshots, and a conservative suggestion based only on available lowest-rated trained attributes.
- A recent-vs-older session trend is shown **only** if at least 8 completed development sessions from 3 distinct game weeks are available; two equal 4–6-session cohorts are compared by saved mean gain per session (8% difference threshold). Otherwise a clearly labelled insufficient-data state is shown. This is descriptive, not a future projection or a causal attribution. A paid user with only 7 development sessions must see no directional recent-session trend.
- All modules remain available to Free players as normal base gameplay; only the optional analytical interpretations require Premium. UI strings are provided in EN, SR, DE, ES, IT, FR, RU and PT. Backend reports have 120-session/240-snapshot limits and disclose truncated windows.
- **Pending release checks:** full React/TypeScript build, live game-clock/browser boundary review, screenshot visual review, eight-language layout review, mobile expand/collapse check and paid/trial/Free browser entitlement checks. Only merge staging → main in a user-approved manual release window.

### Premium Player Development Intelligence — Slice 2: Training Effectiveness (2026-10-20)

**Status: implemented in staging, not released to main.** The new read-only Premium endpoint is in `supabase/migrations/20261020150500_premium_training_effectiveness_v1.sql`; UI in `src/components/premium/PremiumTrainingEffectiveness.tsx`, mounted on the existing Free Skills page beneath Player Development Intelligence. The read-only Premium reporting RPC was **applied to the connected shared Supabase backend** after a transaction-rollback dry run. It changes no historical training data and is not a production frontend release. The UI remains on staging.

- Includes only actual completed development sessions from `player_training_sessions` (session_role=`planned_training`) and `player_training_camp_days` (day_role=`development`). Rest, recovery and day-off sessions do not distort the improvement totals.
- Displays recent 120 sessions and warns if earlier sessions are omitted. The total session count is returned separately. Reports recent sessions, average recorded efficiency multiplier, per-skill fractional gains, recorded whole-level increases, 12 newest game-week aggregates, and latest 10 session details. Uses actual game season/week data, never real timestamps.
- These are *recorded session development estimates* (not guaranteed exact credited progress after staff multipliers and skill slowdowns), not predictions or an attribution model. Confirmed whole-point level-ups are reported separately. The sum of fractional progress across different skills is **not** the player's total skill rating. Does not change Free training, gains, fatigue, career outcomes, or the match engine.
- Premium/trial + owning player only, enforced server-side by `has_active_premium_v1()` and `players.owner_user_id=auth.uid()`; anonymous and unentitled roles have no function execute privilege. Locked preview for Free; translations provided for EN, SR, DE, ES, IT, FR, RU, PT.
- **Backend checks passed (2026-10-20):** safe migration dry run; paid/trial-eligible owner report returned expected counts and consistent level-ups/fractional totals, game-week bounds verified, cross-owner and simulated Free/anonymous identities rejected; anon EXECUTE revoked. Repeatable regression `tests/premium_training_effectiveness_db_smoke.sql` executed successfully with transaction rollback. **Outstanding release gates:** paid/trial/Free browser checks, TypeScript checks `npm run check:pt`, `npm run check:preferences`, `npm run build`, all eight languages and mobile visual QA. Do not merge to `main` without validation and manual release approval.

### Scouting roadmap correction (2026-10-20)

**Opponent Scouting Intelligence is NOT a Premium module.** Existing Free gameplay already requires an active Performance Analyst for detailed opponent scouting. Staff quality determines estimated accuracy, and preparation time determines report completeness. Public opponent identity/recent results stay Free. No Premium entitlement should be required to use the Performance Analyst. Remove scouting from Premium offers and future paid report plans.

### Premium module 5 — Player Development Intelligence, Slice 1

**User authorized implementation:** 2026-10-20.
**Location:** /game/skills → below normal Skills workspace, immediately before the existing free Performance Centre.
**Frontend:** src/components/premium/PlayerDevelopmentIntelligence.tsx, src/styles/player-development-intelligence.css.
**Backend migration:** supabase/migrations/20261020114500_premium_player_development_intelligence_v1.sql.
**Source:** the existing player_skill_history snapshots recorded by the player_skills trigger. The existing free attribute cards, development matrix and free history chart remain intact.

- Premium / 7-day trial: server-entitled report for **owned player only**. Technical, physical and condition groups, selected individual-attribute history chart, earliest/latest values and point changes within the displayed period. Show strongest and smallest recorded changes without implying training causation.
- Free: explanatory locked preview with Pro Packages link, while original skill attributes and existing free history remain available.
- Response returns the latest 240 chronological snapshots; the UI explicitly states when this is a truncated history window. No full-career claims on a cropped timeline.
- No gameplay advantage, development bonus, unrecorded skill prediction or inferred coach attribution.
- Translated in EN, SR, DE, ES, IT, FR, RU, PT.
- **Status:** frontend, migration and translations committed to staging. **Supabase migration successfully applied on 2026-10-20.** An active Premium identity returned 49 owned skill snapshots; non-Premium and other-player requests correctly returned SQLSTATE 42501. Browser rendering and frontend build remain to be confirmed.
- **Release gate:** migration applied; authenticated-only grant and anonymous execute denial confirmed; paid owned-player, Free denied and other-player denied confirmed. Still check trial login, zero/one-snapshot handling, frontend build and responsive 8-language views.

**Further work:** richer training optimizations and longitudinal studies are not implemented. Training Effectiveness and a cautious Development Outlook are on staging; they avoid deterministic skill forecasting until longitudinal coverage supports it.

### Skill history timeline / game-date correction (2026-10-20)

- **User screenshots:** Skills and Premium charts were showing real-world Sep/Oct 2026 dates, and Free Development History showed every change as a dot. These are now corrected to use **in-game Season / Week** and at most one representative (last-recorded) snapshot per game week.
- **Historical provenance:** `20261020131500_skill_history_game_week_metadata_v1.sql` adds nullable game_season/game_week to `player_skill_history`, captures the in-game clock on **future** insert, and backfills legacy records only when an exact same-player training session is within ±15 seconds and already contains an authoritative season/month/day. Never reconstruct a past game week from today's game speed or real-world date.
- **Display:** `src/lib/skillGameWeeks.ts` groups by (season,week) and retains the last snapshot. Both `Skills.tsx` and `PlayerDevelopmentIntelligence.tsx` use it for weekly charts, season/week endpoints and no calendar dates. Undated old records remain stored and are explicitly omitted from dated charts, with a visible notice.
- **Production example audit:** matching 105-snapshot player had only **one distinct technical/physical skill profile** while condition changed 100 times. The records include **38 processed training days, 31 day_off and 7 active sessions**, with fractional development but no `level_ups`: Fitness +0.665, Serve +0.288, Forehand +0.216 and Stamina +0.366 across the active sessions. **No whole-point gain was recorded.** The previous Free sidebar "Recorded development: 104" was a snapshot counter and is now actual gained whole-level skill points (0 in this example).
- **Migration applied and verified** in connected Tennis Legacy Supabase on 2026-10-20: 37 of the 105 snapshots have reliable game dates, covering **13 in-game weeks in Season 1** (Week 2–Week 16). The remaining old rows are not misdated. Current paid RPC returned 105 total / 37 game-dated snapshots. Authentication/owner checks and Free access restriction remain in place.
- **Still to verify in browser:** Skills and Premium skill timelines, eight languages, small screens, and the complete `npm run build`. No training mechanics or payouts were changed.

### Development order and release gates

1. Validate Statistics Intelligence in localhost (build, visual and paid/trial/Free access, real sample comparison).
2. Validate Deep Match Analysis in localhost: completed-match replay, paid/trial report, Free lock, empty-stat case, all languages and full build.
3. Validate and deploy the server-side Player Development Intelligence report in staging, then test owned-player scope, active membership, sample history coverage and all languages.
4. Ask for review after each newly added Premium module before starting the next.
5. Complete `npm run check:pt`, `npm run check:preferences` and `npm run build` before staging → main release; no production release without explicit approval.

## Free gameplay contract

All existing Free Statistics (ATP/WTA season/all-time leaderboards, tournament statistics and career records) remain Free, as do match results, tournament participation, ordinary training, equipment, finance, rankings and other core gameplay. Premium must not modify match outcomes, hidden skills, or ranking payouts.

## Homepage layout (2026-10-20)

The current preview is text-only: upcoming area 70%, latest result 30%; the upcoming area divides between Next Tournament and Next Match when both are known. No large player or tournament images. This replaces the older homepage image-based proposal.

## Premium feature 1 — Statistics Intelligence

**Approved for implementation by the user on 2026-10-20.**
**Location:** /game/statistics → Statistics Intelligence, below ATP/WTA and season/all-time selectors.
**Source:** src/pages/dashboard/Statistics.tsx; src/styles/statistics.css.
**Backend:** get_premium_statistics_intelligence_v1(world, period), defined in
supabase/migrations/20261020063000_premium_statistics_intelligence_v1.sql;
volatility correction for already migrated databases:
20261020070100_premium_statistics_intelligence_volatility_fix.sql.

- Compare the active player's win percentage, aces per match and winners per match with the displayed top-50 sample of completed matches in the selected world/period.
- Exclude the user's own entry from peer totals. Use sum of wins/aces/winners divided by sum of completed matches, not averages of individual percentages.
- If the user's player is not in the sample, display peer averages without inventing personal period statistics.
- The sample is not the whole playing population; no predictive gameplay or hidden inputs.
- Paid Premium and valid seven-day trial can see results. Free players see the section title, explanation, lock and Pro Packages link.
- The dedicated RPC uses has_active_premium_v1(), which checks paid entitlement and eligible active trials, and is callable only by authenticated users.
- Existing get_world_statistics_v1 remains available to Free accounts. The *report endpoint* is gated; raw published statistics are intentionally still public to game players.
- UI translated in EN, SR, DE, ES, IT, FR, RU and PT.

**Status:** staging UI/RPC committed; migrations applied to connected Tennis Legacy Supabase project on 2026-10-20.
**Backend validation:** Active trial report returned 3 metrics for ATP/season and WTA/all-time; non-Premium request was rejected (SQLSTATE 42501); anonymous execute privilege denied. These checks were run on 2026-10-20 without persisting simulation/test changes.
**Still to validate:** npm build, all eight language views, paid account UI, Free lock screen in a browser, and sample arithmetic against a known player. The hosting container cannot download the private repository to build it.

## Premium feature 2 — Deep Match Analysis

**Status:** implemented in staging on 2026-10-20. Backend RPC migration applied to connected Tennis Legacy Supabase. Full build and user browser review are still outstanding.

**Location:** Tournament → completed match → Match Details modal → beneath Match Statistics → Premium "Deep Match Analysis" section. Keep the normal final score, basic match statistics and existing replay access Free.

For a player's own completed matches only (all stats must come from actual recorded results):
1. Side-by-side player vs opponent comparisons: aces, double faults, first serves in/attempted, first-serve points won/played, second-serve points won/played, break points converted/chances, winners, unforced errors, total points won.
2. Calculated percentages: first-serve-in %, service points won %, first-/second-serve points won %, break-point conversion %, winner/error difference, and point share when both rows are present.
3. Set-by-set scoring summary and ranking/court/round data *only where recorded*; never invent historical tactics, fatigue, player attributes or point causes.
4. Evidence-based observations, e.g. "Your first-serve points won rate was 14 percentage points lower than your opponent's" and "You committed five more double faults." These highlight differences rather than claiming the actual cause of a win or loss.
5. Missing match-stat rows render "Not recorded", not zero.
6. Paid/trial Premium members get the full analysis; Free players see a short lock explanation and link to Pro Packages. Server-side entitlement required before returning the derived report.

**Implemented in controlled slices:**
- **A — Backend:** `get_premium_deep_match_analysis_v1(uuid)` in migration `20261020090500_premium_deep_match_analysis_v1.sql`, restricted to completed matches involving the signed-in player. Missing stat rows remain null.
- **B — UI:** `src/components/tournament/PremiumDeepMatchAnalysis.tsx` integrated into completed `Tournament.tsx` match-details modal, removed from Replay, with responsive `src/styles/premium-deep-match.css`. Free players get a lock/upgrade explanation.
- **C — Observations and localization:** Serve/break/shot/point comparisons with evidence-based observations and translations for EN, SR, DE, ES, IT, FR, RU and PT.

**Validation completed (2026-10-20):** paid account own completed match returns match statistics and sets; successful win and loss cases each returned correctly oriented records; a historical completed match with missing stats returned null values instead of zero; Free account, non-owned match and unfinished match were rejected (SQLSTATE 42501). No match outcomes, scores or payouts changed.
**Remaining:** `npm run build`, `npm run check:pt`, `npm run check:preferences`, browser paid/Free/trial checks, missing-row appearance, and eight-language visual QA.


### Match-details UX corrections and historical-factor explanation (2026-10-20)

- Rank, handedness and seed badges occupy one horizontal row in the player identity cards (horizontal scroll fallback on narrow screens).
- The analysis appears **below the existing Free Match Statistics**, in the normal Match Details modal, not in the Match Replay modal.
- Pre-match simulation snapshot is preserved in `tournament_match_simulations.metadata.profile_snapshot`. The report now returns whitelisted effective match ratings (overall, serve, return, rally, net and physical), fatigue, focus, sharpness, confidence, morale, surface adjustment, equipment, staff, tactical modifier, injury penalty, style and recorded weather. These represent the values captured at simulation time and must not be confused with the player's present attributes or double-added bonuses.
- Premium analysis summarizes historical factor differences and match-stat contrasts with explicit uncertainty. Missing historical snapshots yield an honest unavailable state rather than invented values.
- Backend migration `20261020094500_premium_deep_match_historical_factors_v1.sql` applied to connected Supabase and a paid completed match returned real captured ratings/fatigue/weather.
- **Engine realism audit:** `docs/MATCH_SERVE_REALISM_AUDIT_20261020.md`. Aces/DFs low and near-identical across ATP/WTA. No match-engine probabilities changed; benchmark and controlled simulation validation must precede an engine release.
- **Pending:** full browser QA (both badges layouts and modal), `npm run build`, translation visual checks, end-to-end trial check.

## Development/release tests

Before a production release run:
- npm run check:pt
- npm run check:preferences
- npm run build

Verify SQL access control (anon denied, Free denied, paid/trial authorized), and compare staging results against completed-match source data. GitHub source checks are not substitutes for the visual browser tests.
