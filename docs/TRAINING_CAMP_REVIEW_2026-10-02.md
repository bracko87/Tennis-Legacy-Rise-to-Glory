# Training Camp Review — 2026-10-02

Status: **Technical audit completed, fixes live, production health monitoring active**

Rollback-only test player: **Ana Lolic — WTA, Serbia**
No test booking, finance change, activity, travel leg or notification was left on the player.

## Economy and balance

Starting Career Cash reference: **$25,000**.

Training fees remain tiered by program quality:

| Program | Standard | Advanced | Elite |
| --- | ---: | ---: | ---: |
| Recovery & Mindset | $1,200/week | $1,800/week | $2,700/week |
| Physical | $1,400/week | $2,100/week | $3,200/week |
| Tennis Skills | $1,500/week | $2,300/week | $3,400/week |

Training multipliers: **1.00 / 1.15 / 1.30**.

Accommodation remains separate and destination-adjusted:
- Budget 2★: $350 base/week
- Standard 3★: $560 base/week
- Comfort 4★: $840 base/week
- Premium 5★: $1,260 base/week

For Ana Lolic, one-week / Standard-hotel / no-staff quotes across the current 150 active programs range from about **$2,000 to $5,820**, average about **$3,308**.

A four-week Premium-hotel camp ranges from about **$9,340 to $20,900**, average about **$13,382**.

This keeps entry camps affordable from the $25,000 starting balance while making long/elite camps a substantial financial decision.

Tennis/physical camps keep the existing diminishing return schedule:
**100% / 95% / 85% / 75%** over weeks 1–4.

Recovery-camp fatigue reduction was not increased. Normal Day Off recovery is already competitive with camp fatigue reduction; recovery camps mainly add mental/readiness benefits.

## Reliability fixes

1. Future camp cancellation now provides a **100% refund**. Cancellation is only allowed before the camp starts.
2. Cancellation emits a dedicated `training.camp.cancelled` notification.
3. Per-player advisory locking protects against concurrent/double-click booking races.
4. Tournament conflicts are checked against both applications and accepted tournament entries.
5. Generic committed calendar conflicts are blocked.
6. Medical restrictions overlapping the requested camp period are blocked.
7. Invalid/inactive locations fail explicitly.
8. Duplicate travelling-staff IDs are rejected.
9. Quotes expose Career Cash and affordability before booking.
10. Booking remains transactional: insufficient funds leave no booking/payment/calendar residue.
11. Hotel fatigue mitigation is applied once, not twice, for tennis/physical development days.
12. A final camp day converted to an injury/medical day can still close the camp lifecycle correctly.
13. Completion and cancellation notifications use idempotent event keys.
14. Quote origin/destination country codes are ISO alpha-2 again so the shared flag UI renders correctly.

## Rollback-only tests

### Ana — Belgrade standard camp quote
Season 1 Week 11, 1 week, Standard 3★, no staff:
- training: $1,500
- hotel: $620
- travel: $100
- total: **$2,220**
- Career Cash: $25,000
- affordable: yes

### Book → duplicate → cancel
- balance before: $25,000
- balance after booking: $22,780
- duplicate/overlap booking: rejected
- cancellation refund: $2,220
- balance after cancellation: $25,000
- booked notification: 1
- cancelled notification: 1
- remaining camp calendar rows: 0
- remaining planned camp travel rows: 0

### Insufficient funds
With rollback-only balance temporarily set to $100:
- booking rejected before commit
- bookings added: 0
- finance rows added: 0

### Conflict / invalid setup
- conflicting tournament activity: rejected
- invalid program ID: rejected with explicit message

### Daily camp processing
- first day processing: completed
- booking moved to active
- camp-day result stored once
- second processing attempt: already_processed
- development gains stored
- Comfort 4★ fatigue mitigation applied exactly once

### Final-day health interruption
- final day converted to medically blocked/injured activity
- booking still completed
- completed_at stored
- completion notification emitted once
- completion reason recorded as `final_day_health_blocked`

## System Health / Control Center

Registered:
- `cron:tennis-training-camp-health-v1`
- `check:training_camp_lifecycle`

The checker validates:
- active program/location/pricing configuration
- accommodation configuration
- overdue camp bookings
- overlapping live bookings
- missing calendar ownership
- unprocessed past camp days
- finance/payment mismatch
- cancellation/refund mismatch
- safe automatic completion of overdue bookings when all camp days already have an outcome

Critical failures are eligible for the standard Control Center + administrator email alert path.

## Remaining acceptance check

Only rendered UI/browser acceptance remains:
- open Training Camp
- visually inspect quote, flags, hotel/staff selectors and affordability state
- make one real booking when desired
- refresh and verify it remains shown
- verify cancellation/full-refund wording if cancelling a future camp

Backend/game-state testing is complete.


## Camp visibility and tournament-transition rules

Implemented after UI acceptance review:

- A booked or active Training Camp is now shown on **Regular Training** as well as on the **Training Camps** tab.
- The Regular Training banner explains that camp and camp-travel days override the weekly regular-training plan automatically.
- The banner shows the effective number of camp days and explicitly reports if the camp has been shortened by a travel day.
- Tournament → Training Camp and Training Camp → Tournament transitions now route through the player's home city instead of jumping directly between destinations.
- If there are two or more transition days, return-home and onward travel use separate days.
- If only one transition day exists, both legs use the same day as a first-half / second-half split.
- If the previous tournament ends on the normal pre-camp travel day, the first scheduled camp day becomes the split travel day. The camp keeps its original end date and loses one camp-training day.
- If the next tournament requires travel on the day immediately after camp, the player travels camp → home in the first half and home → tournament in the second half.
- If the tournament's first match is on that same split-travel day, travel readiness is `impossible` and the player misses the match by `travel_no_show`; the opponent advances.
- Travel no-show matches do not apply equipment wear because no match was played.
- Split transition pairs and shortened-camp calendar ownership are monitored by `check:training_camp_transition_travel` in System Health / Control Center.

Rollback-only verification:
- inbound tournament → Zrenjanin → Barcelona split produced two ordered half-day legs and shortened the camp by one day;
- outbound Barcelona → Zrenjanin → tournament split produced two ordered half-day legs on one date;
- a human player arriving at 23:59 for a same-day scheduled match was classified `impossible`, the match resolved with `completion_reason=travel_no_show`, and exactly one user notification was emitted;
- all test mutations rolled back.
