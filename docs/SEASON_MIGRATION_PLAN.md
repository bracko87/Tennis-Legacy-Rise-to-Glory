# Tennis Legacy — Controlled season-to-season transition (design baseline)

**Status:** Planning and Control Center visibility (Phase 1). **No rollover engine is authorized or deployed.**
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
4. **Contracts and finance persist by their actual terms.** Staff, main sponsors and technical sponsors remain active when their absolute-day term extends beyond the boundary; expired contracts are closed once, outstanding payments reconciled once. No double wages, sponsor bonuses, taxes, refunds or recurring debits. USD career finance and separate EUR premium billing remain distinct.
5. **Carry ongoing activities forward.** Injuries/illnesses/recovery, fatigue/morale/skills, regular training/camp bookings, travel legs/hotel plans, equipment condition and weekly operations continue across the boundary under current engine rules; do not create double daily/weekly settlements.
6. **Historical records are immutable.** Season N official draws, match replays, awards/prizes, financial transactions, ranking snapshots, championship and national-team results must be queryable as Season N. No deletion/overwrite of season-1 editions to seed season 2.
7. **Season N+1 tournament plan is validated before publication.** Replicate/recreate each approved ATP/WTA event as a new `tournament_editions` row with season-specific schedule slots and linked phase calendar; keep original `tournament_series` identity. Check uniqueness, geography, eligibility, qualification/main-draw phase timing, court/weather assumptions, application windows, ranking/prize definitions, published logo references, 52/53-week boundary and scheduling conflicts. **Do not blindly copy week numbers.**
8. **National-team and association rules remain seasonal only where already established.** New association grants/standings must be reconciled through existing functions with no duplicate seasonal rewards; preserve historical appearances and titles. Confirm any annual elections/reselections separately before adding them.
9. **AI and real player parity.** Keep existing AI identities, avatars, skills and training; do not delete players or reseed 600 AI profiles when the season changes. Retirements, age progression and annual resets are **not yet approved**—no such actions should be introduced without explicit rules.
10. **Player communications are integral.** Inform users about the upcoming season, entry dates, expiring sponsor/staff contracts and confirmed rollover outcome. Essential system warnings remain deliverable even if optional notifications are off.

## Steps and gates — all must be independently retryable

| # | Step key | Purpose | Completion evidence / gate |
|---|---|---|---|
| 01 | discover | Preflight and clock safety | Clock, admin lock, next season calendar, blockers measured; no execution while invalid |
| 02 | lock | Acquire exclusive transition lease | One run for each N→N+1, lock owner, no competing day processors |
| 03 | settle | Settle final day and tournament lifecycle | Draws/results/rewards/refunds and obligations reconciled, no unfinished *due* work |
| 04 | snapshot | Immutable backup and baseline | Recoverable database backup + season-level audit totals and checksums |
| 05 | rankings | Singles/doubles point-defence reconciliation | Official publication/snapshots, no unintended expiry or reset |
| 06 | contracts | Staff/main/technical sponsor carryover | Paid once, correct end dates, offers refreshed only under existing rules |
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
- **Phase 4:** Test N→N+1, N+1→N+2, interrupted/replayed runs, ATP/WTA + singles/doubles, incomplete Grand Slams, cancellations/refunds, contracts crossing boundary, open camps/travel/illness, 366-day and week-boundary cases.
- **Phase 5:** Production release through validated staging→main PR, followed by explicit admin enablement only when ready. Neither GitHub deployment nor the passage of Dec 31 should implicitly authorize migration.

## Control Center dashboard requirements

Create a dedicated **Season Migration** section beside Tournament Operations. It must show current season/day/speed, time until boundary, target season, next-season edition and slot coverage, blocker count, ordered checkpoint states, evidence and timestamps, refresh, and a conspicuous **read-only / engine not installed** state until Phases 2–4 pass. Later add a dry-run and an explicitly confirmed manual execution action restricted to administrators and protected against repeated clicks. All failures create System Health incidents and a persistent history; never report green merely because no migration has run.

## Unresolved decisions (must not become code defaults)

- Should age/retirement be introduced; if so at what ages? Existing players do not have an approved annual age rule.
- Are there any annual sponsor renewal windows or staff contract rules beyond their existing end dates?
- Should the world championship/national-team calendar be copied annually unchanged or revised before Season 2?
- Should major season awards and end-of-season newsletters be introduced? Preserve historical records either way.
- Confirm the boundary and tournament week alignment on a 366-day game season and ensure end of Season 1 cannot outrun readiness at 8×.

## Immediate blockers discovered

**0 Season-2 tournament editions and 0 Season-2 schedule slots** as audited on 2026-10-19; thus preflight is blocked. **Critical:** The existing shared game clock computes Season 2 automatically once its 366-day counter expires. The current Phase-1 UI does not pause that clock or protect the boundary; that safeguard is an urgent independent engineering requirement. No automated safety stop, journal, backup/restore flow or step execution system is currently installed. The Control Center must state this plainly rather than implying migration is ready.
