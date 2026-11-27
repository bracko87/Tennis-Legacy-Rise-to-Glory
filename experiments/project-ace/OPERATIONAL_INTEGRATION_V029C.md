# v0.29-C — operational integration source review (first increment)
Base c1483035bb1d6c2bce19165fe72dfdb700582feb. All three v0.29-B runs passed: 46022654766, 46022654656, 46022654880. Review only; no production authorization.

## Scheduling
Compared schedule-gate.cjs (Ace) with 20261117111500_simulated_match_duration_and_safe_start.sql (Legacy). Both use 366-day seasons with +2 day offset, phase-bounded scheduling, 15-minute court and 60-minute player buffers, and same-day cross-competition restrictions. Differences requiring explicit regression evidence:
- Legacy searches from the original scheduled minute, even if off the half-hour grid; Ace searches from 600 in 30-minute increments for reschedules and uses current minute for due admission.
- Legacy can return ready for the original elapsed slot; Ace requires current-day opening hours and waits for actual live completion instead of relying on projected end.
- Legacy defaults missing court and phase settings; Ace rejects invalid supplied phase/court values. Source mapping must resolve the defaults explicitly.
- Ace additionally checks feeder readiness and pauses at zero speed. Preserve these safety guards; do not blindly copy the Legacy behavior.
- A live resource remains reserved until authoritative completion. Cross-competition and court reservations require a shared transactional authority, not just a pure planner.

## Follow-up reconciliation
20261117113000_reschedule_followups_after_long_match.sql invokes the safe-start guard for scheduled matches sharing either participant, in the inclusive window from played scheduled start through actual duration plus 60 minutes, only when actual duration exceeds estimated duration (default 150). Ordered by absolute start and match ID. The official finalizer writes sets, stats, winner, actual duration and completion before attempting follow-up scheduling; it reports scheduling failures without rolling back the completed result. Ace needs an equivalent durable retry/reconciliation obligation and must never pay again on reschedule retry.

## Settlement
official-settlement-review.cjs currently projects and reconciles official rows, participant ordering, point statistics, career condition events, ranking results and taxable gross prize transactions. It is explicitly review-only and production_ready=false. The existing November finalizer expects replay rows, live deadline, locked simulation and match rows, eligible status and feeder readiness. Do not invoke it against synthetic data in production. Verify subsequent routine definitions and trigger wiring before selecting an adapter.
Preserve the existing competition/player prize idempotency key, gross payment and monthly tax separation. No duplicate Legacy/Ace writers. Do not treat missing statistics or medical evidence as successful settlement.

## Acceptance gate for next increment
1. Execute pinned current SQL in a disposable network-isolated schema with representative matches, including non-grid starts, overdue matches, paused clock, live overrun, exact 15/60-minute boundaries and phase exhaustion.
2. Compare decisions and explicitly approve intentional stricter differences; test cross-competition and multi-court cases.
3. Exercise follow-up candidate selection, failure isolation and repeat reconciliation without duplicated official effects.
4. Audit current career/reward/trigger sources and verify authentic schema, grants and deployed routine identity separately under v0.29-D.
5. No live route switch or public writes. This document is a source-review increment, not an implemented adapter or completed v0.29-C.
