# Tennis Legacy — Approved Tournament Private-Jet Transport Policy (2026-10-26)

**Status:** Source implementation on GitHub main only, not deployed.  
**Authority:** User-provided October 26 screenshots of the Private Airplanes marketplace and clarified transport rules.  
**Scope:** Player tournament travel, selected staff, air travel pricing, aircraft-specific travel fatigue and time. Does not change player skills, the nationality/home-base model, other lifestyle purchases, tournament dates, or live Supabase.

## Exactly nine approved aircraft

Only these catalog models are eligible to transport players and staff for tournaments. Values are **game balancing specifications**, not claimed certified real-world flight specifications. Ranges are direct-leg maxima. Longer journeys can now be planned through explicit intermediate airport stops; each leg must be within **94% of aircraft range**, preserving a 6% game-routing margin. Base + per-kilometre charges are internal pricing inputs: the UI presents one total party flight cost.

| Private airplane (marketplace name) | Catalog code | Seats incl. player | One-leg range | Travel fatigue reduction | Base flight charge | Rate per km | Cruise speed |
|---|---|---:|---:|---:|---:|---:|---:|
| Citation M3 | air_cessaro_citation_m3 | 7 | 3,000 km | 24% | $2,800 | $4 | 720 km/h |
| Phenom 350E | air_emborgier_phenom_350e | 8 | 3,600 km | 27% | $3,300 | $5 | 740 km/h |
| Challenger 420 | air_bombara_challenger_420 | 9 | 4,500 km | 30% | $4,500 | $7 | 760 km/h |
| Citation Latitude X | air_cessaro_citation_latitude_x | 9 | 5,000 km | 34% | $5,800 | $8 | 780 km/h |
| Praetor 680 | air_emborgier_praetor_680 | 10 | 6,200 km | 38% | $6,800 | $10 | 800 km/h |
| Falcon 9X | air_dassier_falcon_9x | 14 | 7,600 km | 42% | $8,900 | $13 | 830 km/h |
| G650 LX | air_gulfstar_g650_lx | 16 | 9,500 km | 45% | $11,000 | $16 | 860 km/h |
| Global 8000X | air_bombara_global_8000x | 17 | 11,500 km | 48% | $14,000 | $19 | 885 km/h |
| G900 Sovereign | air_gulfstar_g900_sovereign | 19 | 13,500 km | 50% | $17,000 | $23 | 900 km/h |

All other currently catalogued private aircraft, including hobby piston aircraft, turboprops, Honda HJ-One, and retired legacy generic \`jet_*\` catalog entries, remain **lifestyle-only** even if their propulsion says "jet." Their metadata's \`tournament_travel_eligible\` flag is explicitly false. **Owning** an approved jet alone never reduces fatigue; the benefit applies only to actual flown private-jet travel legs.

## One plane, one party, one operating charge

- Selected staff count remains capped at six. A party is the player plus **all selected staff**, and must fit into the chosen aircraft. Seats cannot be split across private and commercial bookings for the same selected private-jet flight.
- In a successful private-jet booking the **staff air ticket cost is $0**, and the flight cost is not multiplied by staff count. Accommodation, staff salaries and other non-flight expenses are unchanged.
- Total charge for each one-way journey is **base aircraft charge + ceil(total routed kilometres × model's per-km rate) + $1,000 airport/operations allowance + $1,800 per refuelling stop + any required aircraft repositioning**, paid once for the whole party. Repositioning is a separate distance/flight requirement and is not free. A round trip generally involves two whole-aircraft flight charges; repositioning is charged only where required. No individually itemized fuel/pilot/maintenance invoice.
- The selected aircraft must be **owned, unsold, on the allowed list, within its range on every individual flight leg and repositioning leg, and large enough for the entire party**. Server-side quotes and booking reject impossible flights. Other commercial travel options remain available where a jet cannot cover the route.

## Flight fatigue and travel timing

- Model-specific comfort reduces **the fatigue from that actual travel leg**, not tennis skills or permanent energy. Base comfort rates progress from 24% to a capped 50%, replacing the legacy automatic 90% jet-ownership reduction. **Each additional refuelling stop reduces the effective fatigue reduction by 3.5 percentage points**, down to a 5% minimum for a valid long journey. Staff do not generate additional flight ticket costs.
- Estimated journey duration = **total routed distance / model cruise speed + model handling allowance + 1.8 hours per fuel stop + 6 hours of rest for each additional required game travel day** (0.8–1.2 hours starting handling allowance depending on aircraft). One game travel day supports at most 18 hours of the initial flight/handling estimate. Private flights avoid normal commercial connecting/check-in assumptions. Quotes show one estimated total flight duration and the full-party one-way operating charge.
- Flights of **10 hours or less** are tagged as *overnight-transfer candidates*. This enables a realistic potential Sunday-to-Monday transfer after a tournament. It **does not guarantee schedule eligibility**: the match-time travel synchronizer now compares estimated jet journey duration against scheduled first matches and previous-match departure buffers, can reserve multiple travel days, and classifies missed connections as at risk. An explicit jet booking is rejected when the multi-day window is too short or its synced connection is at risk. Production-equivalent scheduling and fixture tests remain outstanding, including edge cases around time zones and mid-tournament schedule changes. There is no instantaneous teleporting.

## Refuelling routes and the Serbia → Australia example

The new SQL migration \`20261026123000_private_jet_multistop_v1.sql\` contains a bounded graph of representative major airports and a shortest-feasible-path search. Each flight leg must remain within 94% of the selected aircraft's nominal game range, and the search permits no more than 18 intermediate stops. If a route cannot be built, the private-jet choice is unavailable and the player can choose a commercial itinerary instead. Aircraft positioning uses the same route constraints.

**Disposable database regression case:** An owned Citation M3 based in Belgrade, carrying the player and six staff, can plan a Belgrade–Sydney journey of approximately **17,250 km**, with **seven refuelling stops** and **three game travel days**. On the current game values, the illustrative one-way cost is **$85,400** ($2,800 base + 17,250 × $4/km + $1,000 operations + 7 × $1,800 stops), if the aircraft starts in Belgrade. Effective fatigue reduction in this particular seven-stop journey is the 5% lower bound rather than the M3's 24% non-stop reduction. A more capable long-range aircraft can reduce stops and preserve more of its fatigue benefit.

**Important reality boundary:** Airport coordinates and refuelling hubs are game-design estimates, not certified operating authorizations or validated aircraft flight plans. Wind, runway limits, overflight rights, visas, curfews, fuel availability and aviation regulations are not verified by this simulator. Actual routes and game schedules must pass the final isolated-environment QA.

## Verification and release boundaries

The first foundation migration, the selected jet quote/aircraft-positioning functions, and the multi-stop route and pricing functions are exercised against disposable PostgreSQL in CI. The extended scheduling function is grammar-checked and has source contract tests; full end-to-end tournament fixture timing has not yet been executed. The explicit nine-model whitelist is executed against synthetic catalog data and rejected legacy aircraft are checked. SQL/PLpgSQL grammar, source contracts, frontend build and the other existing CI gates must pass.

**Remaining release gate:** run all migrations in a full isolated Supabase environment and perform authenticated browser/finance/travel lifecycle verification. Neither live Supabase migrations nor Netlify production deployment is authorized by this document.
