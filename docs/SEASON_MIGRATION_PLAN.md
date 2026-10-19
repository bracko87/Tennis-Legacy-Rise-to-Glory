# Tennis Legacy — Controlled season-to-season transition (design baseline)

**Status:** Season 1 → Season 2 rules approved for design, including annual sponsor renewals and the legacy-contract exception (2026-10-19). Planning and Control Center visibility (Phase 1). **No rollover engine is authorized or deployed.**
**Project lock:** Tennis Legacy only, Supabase `cwfznmroiqcyhfkfcrow`. No ProPeloton dependencies or shared migrations.
**Source of truth:** Existing game-clock, weekly rankings, tournament, training, finance, sponsor and national-team engines. This plan cannot override live game rules without explicit approval.

## Audit, 2026-10-19

- `game_clock` is one shared clock, Season 1, at **8×**. One game season has **366 days** (the client uses a 366-day calendar including February 29). At ~game day 104, the next season is ~33 real days away.
- `tournament_editions` contains **597 Season-1 editions and zero Season-2 editions**. `tournament_schedule_slots` has **613 Season-1 slots and zero Season-2 slots**. Calendar validation is a hard prerequisite.
- Tournament entry, draws, match results, rankings, doubles, finance, training, recovery and national-team engines already use game-day and/or season-aware identifiers. They must be reviewed, not bulk-reset.
- `player_ranking_contributions` and doubles equivalents already track season, expiry and replacement. `ranking_defence_cycles` and `ranking_publication_runs` already exist.
- Existing Control Center System Health tracks tournament operations, incidents and process logs; no complete season transition audit/runner exists.
- Prior rules retained: Grand Slams use qualifications and main draws across weeks; ATP/WTA calendars stay separate and globally consistent; events with under eight accepted players at final lock cancel and 8–16 fields use an appropriately sized draw; cancelled events remain historical, with refund/cancellation handling through existing engines.

## Principles / approved invariants

1. **The game must not automatically complete a rollover without validated Season N+1 content.** Pause the season-boundary advancement safely if preflight fails; no unbounded cross-season execution. A separate safety mechanism for the clock must be designed and tested before enabling automation.
2. **No destructive reset of career identity.** Preserve player account, stable identity/avatar, attributes, skill history, nationality, game world, achievements, trophies, titles, H2H records, match history, career statistics, current inventory/equipment, clubs, player-owned private-life assets, housing and investments, wallet/coins, premium entitlements, notification preferences, and earned ledger balances.
3. **Never erase or set ranking points to zero at rollover.** Singles and doubles contributions age out/replaced according to the existing expiry/replacement engines and official weekly publication, including ranking snapshots. Ensure ATP and WTA never mix; handle season-1 defense in season 2.
4. **Seasonal sponsors, grandfathered contracts and ongoing staff:** See the approved annual sponsor policy below. All NEW main and technical sponsorships under the Season-2 policy are season-bounded, renewed through new offers (never auto-signed). ALL EXISTING signed main or technical sponsorships keep their original end date, including contracts spanning into Season 2. Staff retain their contractual term. Expired contracts close once; paid/unpaid obligations are reconciled exactly once. No double salaries, sponsor bonuses, taxes, refunds or recurring debits. USD career finances and EUR premium billing stay distinct.
5. **Carry ongoing activities forward.** Injuries/illnesses/recovery, fatigue/morale/skills, regular training/camp bookings, travel legs/hotel plans, equipment condition and weekly operations continue across the boundary under current engine rules; do not create double daily/weekly settlements.
6. **Historical records are immutable.** Season N official draws, match replays, awards/prizes, financial transactions, ranking snapshots, championship and national-team results must be queryable as Season N. No deletion/overwrite of season-1 editions to seed season 2.
7. **Season N+1 tournament plan is validated before publication.** Replicate/recreate each approved ATP/WTA event as a new `tournament_editions` row with season-specific schedule slots and linked phase calendar; keep original `tournament_series` identity. Check uniqueness, geography, eligibility, qualification/main-draw phase timing, court/weather assumptions, application windows, ranking/prize definitions, published logo references, 52/53-week boundary and scheduling conflicts. **Do not blindly copy week numbers.**
8. **National-team and association rules remain seasonal only where already established.** New association grants/standings must be reconciled through existing functions with no duplicate seasonal rewards; preserve historical appearances and titles. Confirm any annual elections/reselections separately before adding them.
9. **AI and real player parity.** Keep existing AI identities, avatars, skills and training; do not delete players or reseed 600 AI profiles when the season changes. Retirements, age progression and annual resets are **not yet approved**—no such actions should be introduced without explicit rules.
10. **Player communications are integral.** Inform users about the upcoming season, entry dates, expiring sponsor/staff contracts and confirmed rollover outcome. Essential system warnings remain deliverable even if optional notifications are off.


## Exact end-of-season carryover contract — Season 1 day 366 → Season 2 day 1

These rules apply to *all* players (human and AI) and both ATP/WTA worlds. They are expected outcomes for the future runner, **not an existing executable migration**. A fresh official match/ranking/finance processing cycle may subsequently change totals according to normal game rules.

| Domain | Season 1 last day | Season 2 first day | Required operation |
|---|---|---|---|
| Game clock | Season 1 · Dec 31 · 23:59 | Season 2 · Jan 1 · 00:00 | Controlled, one-time clock boundary after all gates pass. The existing clock still advances without protection. |
| Player / account | Player name, avatar, country, game world, credentials | Unchanged | Preserve IDs, authentication, preferences, premium trial/subscription, coins and account history. |
| Abilities and condition | Skills, experience, fitness, fatigue, morale, confidence, injury status | Same state before normal daily simulation | Carry value and treatment/recovery timers. Do not grant reset bonuses. |
| Ranking (ATP/WTA singles and doubles) | Official ranking with active contributions | Ranking carried over, **not zero** | Continue weekly ranking publication, point-defence/replacement at the next edition, and expiry on absolute game day. No ad-hoc new-season recalculation. |
| Career match statistics | Lifetime wins, losses, H2H, titles, awards, career winnings | Unchanged and searchable | Preserve historical career data and individual Season 1 results. |
| Season-only statistics | Season 1 wins/losses, titles, prize/winnings totals | New Season 2 counters begin at zero | Snapshot Season 1 at closure; create separate Season 2 counters rather than truncating history. |
| Tournament calendar | Season 1 events, entries, draws, qualifiers, singles/doubles matches, prizes, replays | Entirely new Season 2 editions and applications | Keep tournament series identity/logo; generate distinct edition and world competition IDs, new phase slots, registration windows and draws; do not clone outcomes. |
| Career cash and finance | Wallet/account balance and Season 1 transactions | Identical opening cash balance; new-season income/expense counters at $0 | Settle prior due entries idempotently; preserve all ledger rows with original season. No free money or unearned tax reset. |
| Main / technical sponsors | Final-year obligations, active agreements, objectives and equipment benefits | Annual renewed contracts only when signed; existing cross-season contract keeps exact end date | Follow the approved exception and seasonal rule below. |
| Staff and club | Staff, weekly salaries, club membership, associated benefits | Unchanged while valid | Respect absolute end dates; no automatic termination or signing. |
| Training and health | Active training blocks, scheduled camp, accommodation, travel, injuries | Continue the same obligations | Preserve time windows and avoid double daily/weekly effects. |
| Equipment / Private Life | Owned items, condition, purchased homes/cars/luxury assets, property returns | Unchanged | No inventory purge, free maintenance, resale reset or erased assets. |
| National associations / championships | Season 1 country representation, teams, medals, rankings and prize records | Preserve achievements, create new-season fixtures/standings only where already supported | Avoid duplicate annual association grants, rewards and medal awards. |
| Inbox and notifications | Messages, mandatory warnings, preferences | Unchanged, plus one transition announcement | Persist previous communication and send new-season confirmation only once. |

### Rankings — point continuity and tournament resets

- **Ranking is not a seasonal scoreboard.** A player finishing with 1,800 points still begins Season 2 with 1,800 points, absent a separately due weekly publication/expiry.
- In the current published **singles and doubles ranking processors**, Season-1 contributions are replaced when the same tournament series' Season-2 event results publish; for missing/delayed editions, contributions expire at their `expires_absolute_day` (typically awarded + 366 game days). This happens at official processing time, not arbitrarily at midnight.
- Example: 1,800 old points including 500 at Monte Carlo → Season 2 starts at 1,800 → when the new Monte Carlo publishes a 300-point result, 1,800 - 500 + 300 = 1,600 if no other changes occurred.
- Season 1 Monte Carlo draws/replays/medals remain immutable historical records. New Monte Carlo uses a new edition and competition IDs, new applications, draw, qualification, results and payouts. A prior champion is not automatically re-entered or awarded the new title.
- Keep separate ATP/WTA, singles/doubles ranking contributions and snapshots. Validate ranking publication isn't triggered twice on the same game day.

## Approved sponsor transition — **annual renewal with existing-contract protection** (confirmed 2026-10-19)

**Two rules apply simultaneously:**

1. **Newly offered/signed main and technical sponsorships under the new policy** must be **season-bounded**. They may end no later than the current season's last absolute day, and must be offered again for the next season. Do not extend them automatically by changing an end date. Price and benefits for a late-season contract must transparently reflect the shortened duration before acceptance; do not retroactively devalue a signed deal. An offer window before season end should be implemented, with exact opening day configurable and separately verified.
2. **All contracts already signed before this policy is activated are grandfathered.** Preserve their original `start_absolute_day`, `end_absolute_day`, guaranteed installments, objectives, discounts, used and unused equipment/replacement allowances and other promised benefits **until the actual contractual end day**, even if that is in Season 2. Do not modify a signed contract to fit a calendar. On its natural expiry, make the player eligible for a new season-bound offer. Record/flag legacy contracts explicitly at policy activation, not by guessing from `season` or date alone.

**Observed Season 1 data on 2026-10-19:** 2 active main contracts end at absolute day 365. There are 3 active technical contracts; at least 1 ends at day 386, *after the Season-1 boundary (day 366)*. That technical contract must stay active through its existing term. These are audit observations, not assumed stable counts for the future.

**Main sponsorship:**
- Close/settle Season-1 contractual objectives and prize obligations according to the original contract and their individual deadlines. No unpaid earned reward disappears; no unearned bonuses are manufactured. Preserve objective and payment history by contract ID, season and idempotency key.
- Season-2 offer generation should use current ATP/WTA ranking, performance and reputation. The player must **accept** the offer; never auto-sign or substitute another company at rollover. Existing legacy main contracts in a future season still take precedence until their contractual end date.
- Do not create two concurrently active exclusive main sponsors for one player or pay the same performance milestone twice.

**Technical sponsorship (per equipment category):**
- For a new season's offer, re-evaluate brand/discount/equipment benefits and restrictions on actual player results and eligibility. Present renewal, renegotiation or switching options. No silent acceptance.
- Grandfathered technical agreements continue with their originally promised discounts, equipment allowances, replacements and maintenance benefits until natural expiry. The counters `free_equipment_allowance_used` and `free_replacements_used` are **not reset** at midnight and may not exceed the contract's original entitlement.
- Equipment already owned remains player property after sponsorship expiry or brand change unless an explicit existing equipment rule says otherwise. Prevent incompatible overlapping exclusive agreements in the same technical sponsor category.
- Keep historical technical sponsor offers and signed contracts as archive; new Season-2 offers get fresh IDs and are clearly marked as a different season.

**Contract migration checklist for each player and sponsor category:**
- Reconcile `player_sponsor_contracts`, `player_technical_sponsor_contracts`, their accepted offers, `player_sponsor_objectives`, payments and finance ledger exactly once at the correct absolute day.
- Snapshot active agreements with end date before and after the rollover. **Zero unexpected end-date changes.**
- Identify contracts ending by the boundary versus grandfathered crossing agreements; verify each grandfathered contract is still active on Season 2 day 1 and ends only on its real expiry day.
- Verify a new offer is available only when the player is eligible, no exclusive overlap is introduced, and no payment or bonus is duplicated.
- Record totals, contract IDs/counts and per-player exceptions in the permanent migration journal. Errors block the sponsor checkpoint and trigger an admin incident.
- Deliver pre-expiry/renewal notifications without duplicating the same reminder on retries.
- On re-run, payment and entitlement reconciliation must be idempotent; never reset all sponsor records with a season-wide UPDATE.

**Illustrative boundary:**
- Main Sponsor A: contract ends on Season 1 day 365 → settled and archived by closure; player may choose a Season 2 offer.
- Technical Sponsor B: grandfathered contract ends absolute day 386 → remains active on Season 2 day 1, including remaining equipment benefits, and expires naturally in Season 2. Do not grant new Season 2 technical benefits on top of it.

### Mandatory preflight and dry-run assertions

1. Every Season-2 tournament edition has correct world, slots, entries/draw windows and point/prize schedule; no missing/duplicate event IDs or unexplained ATP/WTA calendar gaps.
2. All pre-boundary mandatory results, rewards and invoices are settled; no material balances silently change when starting Season 2.
3. Singles and doubles ranking contributions do not globally reset; Season-1 ranking snapshots remain queryable; point defense is tested using an actual returning tournament series.
4. All signed legacy sponsors retain exactly their contractual terms; due main/technical contracts are settled once; new unsigned offers cannot themselves pay bonuses or equip gear.
5. Seasonal counter snapshots exist for Season 1; Season 2 starts new counters without overwriting lifetime totals or history.
6. Simulated failure/retry at every checkpoint is safe; double-run causes zero duplicate ledger payments, training effects, ranking publication, champion awards or sponsor allowances.
7. Transition cannot be approved until backups/restoration, preflight, Season-2 calendar, clock-boundary guard, and the Control Center step journal are all implemented and tested.

## Steps and gates — all must be independently retryable

| # | Step key | Purpose | Completion evidence / gate |
|---|---|---|---|
| 01 | discover | Preflight and clock safety | Clock, admin lock, next season calendar, blockers measured; no execution while invalid |
| 02 | lock | Acquire exclusive transition lease | One run for each N→N+1, lock owner, no competing day processors |
| 03 | settle | Settle final day and tournament lifecycle | Draws/results/rewards/refunds and obligations reconciled, no unfinished *due* work |
| 04 | snapshot | Immutable backup and baseline | Recoverable database backup + season-level audit totals and checksums |
| 05 | rankings | Singles/doubles point-defence reconciliation | Official publication/snapshots, no unintended expiry or reset |
| 06 | contracts | Staff carryover, annual sponsor renewal, grandfathered contract protection | Signed legacy terms respected; Season-1 objectives settled exactly once; no overlap; Season-2 sponsor offers remain unsigned until player accepts; no double payments/allowances |
| 07 | finance | Close season accounts and carry balances | Historical ledger remains; reconciled USD balances, premium untouched |
| 08 | development | Training, health, travel, camps | No duplicate day/week, ongoing plans valid across boundary |
| 09 | identity | Player/AI/club/private-life and national teams | Inventory/assets/achievements retained; association grants idempotent |
| 10 | calendar | Verify and publish Season N+1 editions | Complete ATP/WTA events and linked slots, none missing/duplicated |
| 11 | switch | Controlled next-season clock switch | Exactly N+1 day 1 and retained correct time; only after all gates |
| 12 | postcheck | Verify live services and send report | Registrations, entry, rankings, finance, training, national teams, no critical errors |
| 13 | close | Complete run and release lease | Immutable report, admin incident/status and notification, replayable run history |

Order matters: `calendar` validation is part of the initial preflight **before any lock or clock switch** even though final publication is step 10. A rollback restores from the validated backup only with an explicit recovery playbook, not by deleting history. Step 11 must be idempotent; never advance time twice.

## Operational stages

- **Phase 1 — this PR:** Document rules, current gaps, block conditions, preview checklist in Control Center. No execution controls.
- **Phase 2:** Implement per-season run and step audit journal (attempt count, actor, timestamps, input hash, checkpoint, status, error, evidence), admin-only RPCs, reliable preflight and dry-run. Run on an isolated clone/snapshot.
- **Phase 3:** Add one-step-at-a-time idempotent processors, season-N archive/snapshot, calendar generation and backfill, guarded clock transition, recovery and admin review. Add notifications and alerts.
- **Phase 4:** Test N→N+1, N+1→N+2, interrupted/replayed runs, ATP/WTA + singles/doubles, incomplete Grand Slams, cancellations/refunds, annual main/technical sponsor renewal, grandfathered cross-season terms (including day 386), sponsor payment/benefit idempotency, open camps/travel/illness, 366-day and week-boundary cases.
- **Phase 5:** Production release through validated staging→main PR, followed by explicit admin enablement only when ready. Neither GitHub deployment nor the passage of Dec 31 should implicitly authorize migration.

## Control Center dashboard requirements

Create a dedicated **Season Migration** section beside Tournament Operations. It must show current season/day/speed, time until boundary, target season, next-season edition and slot coverage, blocker count, ordered checkpoint states, evidence and timestamps, refresh, and a conspicuous **read-only / engine not installed** state until Phases 2–4 pass. Later add a dry-run and an explicitly confirmed manual execution action restricted to administrators and protected against repeated clicks. All failures create System Health incidents and a persistent history; never report green merely because no migration has run.

## Unresolved decisions (must not become code defaults)

- Should age/retirement be introduced; if so at what ages? Existing players do not have an approved annual age rule.
- Define and test the configurable **pre-season sponsorship offer window**, including how late-year contracts are valued and proration is disclosed. Annual renewal, no auto-signing, and grandfathering of existing terms are approved; the exact offer-opening day is not yet established. Staff terms remain unchanged.
- Should the world championship/national-team calendar be copied annually unchanged or revised before Season 2?
- Should major season awards and end-of-season newsletters be introduced? Preserve historical records either way.
- Confirm the boundary and tournament week alignment on a 366-day game season and ensure end of Season 1 cannot outrun readiness at 8×.

## Immediate blockers discovered

**0 Season-2 tournament editions and 0 Season-2 schedule slots** as audited on 2026-10-19; thus preflight is blocked. **Critical:** The existing shared game clock computes Season 2 automatically once its 366-day counter expires. The current Phase-1 UI does not pause that clock or protect the boundary; that safeguard is an urgent independent engineering requirement. No automated safety stop, journal, backup/restore flow or step execution system is currently installed. The Control Center must state this plainly rather than implying migration is ready.
