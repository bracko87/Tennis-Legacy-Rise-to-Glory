# Tennis Legacy — New Player Starting Scheme

Status: **Implemented / production verified**
Date: 2026-10-02

This document is the single reference for what a newly created **human** Tennis Legacy career receives. The scheme is implemented in production through the idempotent `initialize_new_human_career_v1(player_id)` orchestration flow.

## 1. Approved master matrix

| System | Final starting rule |
| --- | --- |
| Career cash | **$25,000 USD** |
| Coins | **20 Coins**, granted once per user/career onboarding and never duplicated by refresh/retry |
| ATP/WTA | Same economic and progression starting strength; only tour-specific visuals/catalog items may differ |
| Technical skills | Existing balanced human starting model remains authoritative |
| Physical skills | Total **200**; baseline 50/50/50/50 before playing-style redistribution |
| Fatigue | **0** |
| Sharpness | **50** |
| Morale | **50** |
| Confidence | **50** |
| Focus | **50** |
| Potential | No separate stored potential value currently exists; do not invent one |
| Training | **No user training selected at career creation**. Missing plan behaves as Day Off until the user explicitly configures training |
| Staff | **None** |
| Calendar commitments | **None** |
| Regular sponsors | **None** |
| Technical/equipment sponsors | **None** |
| National Association | **Not a member**; explicit opt-in only |
| Tennis Club | **Not a member** |
| Singles ranking points | **0** |
| Doubles ranking points | **0** |
| Internal singles seed rating | Existing **45,000** human initialization may remain as an internal tiebreak/ordering value; it is not starting ranking points |
| Career statistics | Empty / zero |
| Injury / illness | None |
| Equipment | One starter **racket + shoes + apparel**, full condition, immediately equipped; **no accessories** |
| Private Life — Free | No starter property |
| Private Life — Premium | One basic starter apartment in the player's home city; no car, watch, yacht, jet, luxury property or other starter asset |
| Starter apartment resale | Starter grant should be **non-resellable/trade-locked** so Premium cannot be converted into career cash |
| Tutorial/onboarding | Normal new-career state; must not re-run starter grants |

## 2. Starting skills — authoritative distribution

Human technical starting strength is already balanced by preferred surface and playing style.

### Base preferred-surface profiles

All three base profiles total exactly **450 technical points** before deterministic player variation.

| Skill | Hard | Clay | Grass |
| --- | ---: | ---: | ---: |
| Serve | 56 | 48 | 62 |
| Forehand | 58 | 59 | 52 |
| Backhand | 55 | 57 | 48 |
| Return | 57 | 60 | 46 |
| Volley | 46 | 42 | 57 |
| Slice | 45 | 48 | 54 |
| Drop shot | 42 | 47 | 38 |
| Lob | 43 | 51 | 38 |
| Smash | 48 | 38 | 55 |
| **Base total** | **450** | **450** | **450** |

Playing style redistributes points without changing the total:

- **Aggressive Baseliner:** +1 Serve, +4 Forehand, +2 Backhand, +1 Return, -2 Volley, -1 Slice, -2 Drop shot, -2 Lob, -1 Smash.
- **Defensive Baseliner:** -3 Serve, +1 Forehand, +3 Backhand, +4 Return, -3 Volley, +1 Slice, +0 Drop shot, +2 Lob, -5 Smash.
- **Serve & Volley:** +5 Serve, -3 Forehand, -4 Backhand, -4 Return, +6 Volley, +3 Slice, -3 Drop shot, -3 Lob, +3 Smash.
- **All-court:** no style redistribution.

The production model then adds deterministic per-player variation of up to +/-3 per technical skill, clamps skills to 35–68, and normalizes the final technical total to **440–455**. This keeps careers varied without making one surface stronger overall.

### Physical skills

Human careers start with a total of **200 physical points**:

- Fitness 50
- Stamina 50
- Recovery 50
- Movement 50

Playing-style redistribution is zero-sum:

- Aggressive Baseliner: +2 Fitness, -1 Stamina, -2 Recovery, +1 Movement.
- Defensive Baseliner: -2 Fitness, +2 Stamina, +2 Recovery, -2 Movement.
- Serve & Volley: +1 Fitness, -1 Stamina, -2 Recovery, +2 Movement.
- All-court: 50 / 50 / 50 / 50.

There is no separate stored potential attribute in the current schema.

## 3. Starter equipment

Starter items are granted at **100% condition**, acquired source = `starter`, purchase price = $0, and are equipped immediately in Gear Room as well as visible in Inventory.

### Racket

Approved starter choice:

- **Rosignol F-200 Carbon**
- SKU: `RKT-ROSIGNOL-01`
- Tier 1
- Current catalog price: $105
- Unisex
- Durability rating: 77
- Wear per match: 1.90

It is currently tied for the cheapest active racket. Use the lower catalog sort order to keep one deterministic starter SKU.

### Apparel

Use the cheapest Tier 1 BlokUV apparel for each tour; both cost $80 and have the same gameplay profile.

ATP:
- **BlokUV Guardian Court**
- SKU: `APP-BLOKUV-01`

WTA:
- **BlokUV Solar Shield 8**
- SKU: `APP-WTA-BLOKUV-01`

Both:
- Tier 1
- Durability 75
- Wear per match 1.45
- Same starter gameplay effects

### Shoes

Approved starter choice for both ATP and WTA:

- **Antta PG 7**
- SKU: `SHO-ANTTA-01`
- Tour scope: **unisex**
- Tier 1
- $80
- All Court
- Durability 76
- Wear per match 3.80
- Gameplay effects: +0.35% Movement, +0.16% Comfort, +0.09% Stamina

The lower-price ATP shoe range from $80–$400 is now unisex, so WTA players have the same Starter / Advanced / early Tour progression and identical bonus levels instead of beginning at $420 / Tier 3. Existing premium WTA-specific shoes remain unchanged.

### Accessories

**None.** No towel, cap, bag, bottle, wristband or other accessory is granted.

## 4. Money and coins

### Career money

Production already uses:
- Starting balance: **$25,000**
- Currency: **USD**
- Opening transaction key: `career-opening-balance`

This is idempotent and is the approved value.

### Coins

Production grants **20 Coins** when the first human career for the account is successfully created.

Rules:
1. Grant 20 once when the first human career for the account is successfully created.
2. Record it in `coin_ledger` as a signup/career-start reward.
3. Use an idempotency/reference key so page refresh, retry, duplicate insert attempts and account restart cannot repeatedly mint Coins.
4. Career restart must **not** be a Coin farming path.

Implemented reference: `new-career-starting-coins-v1`, unique per user. The ledger entry type is `signup_reward`.

## 5. Staff, sponsors, memberships and calendar

- No staff contracts are automatically created.
- No regular sponsor contract is automatically created.
- No technical sponsor contract is automatically created.
- National Association membership remains explicit opt-in.
- Tennis Club membership remains empty.
- No tournament/calendar commitment should be automatically created.
- No training selection is made for the user.

The daily training engine may treat a missing training plan as Day Off, but should not make it look as if the user selected a training plan.

## 6. Private Life starter state

Private Life remains Premium-only according to the product rules.

### Free user

Receives:
- no apartment/property
- no vehicle
- no watch/jewelry
- no art/collectible
- no yacht
- no private jet

### Premium user

Receives exactly one:
- `apt_home_starter`
- located in the player's selected home city
- prestige 0
- no acquisition charge
- no additional luxury asset
- starter grant should be trade-locked/non-resellable

The entitlement should be idempotent. If a career is created as Free and the user later becomes Premium, the starter apartment may be granted once at first Premium activation, provided that career has never already received it.

## 7. Property pricing — country-tier baseline + city overrides

Current production already has realistic explicit prices for selected marketplace cities (for example New York, London, Paris, Zurich, Monaco). Keep those city-specific prices as overrides.

The problem is non-core home cities: they currently fall back to roughly the same $120k apartment / $300k house baseline regardless of country.

Production now uses a **10-tier country property baseline**.

### Country baseline tiers

| Tier | Market level | Apartment base | House/Villa base |
| ---: | --- | ---: | ---: |
| 1 | Very low cost | $40,000 | $100,000 |
| 2 | Low cost | $60,000 | $150,000 |
| 3 | Lower-mid | $80,000 | $200,000 |
| 4 | Mid | $120,000 | $300,000 |
| 5 | Upper-mid | $160,000 | $400,000 |
| 6 | High | $220,000 | $550,000 |
| 7 | Very high | $300,000 | $800,000 |
| 8 | Premium | $450,000 | $1,200,000 |
| 9 | Ultra-high | $700,000 | $2,000,000 |
| 10 | Exceptional luxury | $1,200,000 | $4,000,000 |

Rules:
1. Every supported country must have exactly one property-price tier.
2. Known marketplace cities keep explicit city values; those override the country baseline.
3. A home city without an explicit marketplace record inherits its country's tier baseline.
4. Apartments use the apartment baseline; houses/villas use the house/villa baseline and the catalog item's existing multiplier.
5. The existing dynamic monthly property market may continue to move values after initialization.
6. The starter apartment continues to use the existing **60% of local apartment base** rule unless separately rebalanced.
7. No city should fall back to a universal $120k/$300k value merely because it was not individually seeded.

Example:
- New York keeps its explicit city-specific market value.
- Novi Sad uses Serbia's country tier if no explicit Novi Sad market override exists.

Country-to-tier mapping is stored in `private_life_country_property_tiers`; all 250 supported countries are mapped exactly once.

## 8. Current production audit

| Area | Current production | Compared with target |
| --- | --- | --- |
| Money | $25,000 USD | **Correct** |
| Human technical skills | Balanced surface/style system, total 440–455 | **Correct** |
| Physical skills | Total 200 | **Correct** |
| Fatigue / mental state | 0 / 50 / 50 / 50 / 50 | **Correct** |
| Coins | 20 Coins granted once through `new-career-starting-coins-v1` | **Implemented** |
| Equipment | Exact racket + shoes + tour-specific apparel granted at 100% and equipped | **Implemented** |
| Accessories | No starter accessories | **Implemented** |
| Staff | No automatic starter staff trigger | **Correct** |
| National Association | Explicit opt-in | **Correct** |
| Tennis Club | No automatic membership | **Correct** |
| Sponsors | No starter sponsor contract | **Correct** |
| Calendar | No automatic tournament commitment | **Correct** |
| Private Life | Free: no starter property. Premium: one trade-locked starter apartment | **Implemented** |
| Property fallback | 10-tier country baseline with explicit city overrides | **Implemented** |
| Training | No plan created at insert, but daily engine lazily creates Day Off if missing | **Acceptable only if UI still treats training as not configured** |
| Singles points | 0 | **Correct** |
| Doubles points | 0 | **Correct** |

## 9. Implementation architecture

Production uses one idempotent human-career initializer as the orchestration point instead of allowing unrelated systems to invent their own defaults.

Production entry point:

`initialize_new_human_career_v1(player_id)`

It orchestrates:
1. finance opening balance
2. 20-Coin one-time account grant
3. player skills / ranking initialization
4. exact starter equipment grant + equip
5. explicit empty staff/sponsor/membership state checks
6. Premium-only starter-home entitlement
7. initialization audit record

All substeps must be idempotent.

Production records initialization in `new_player_initialization_audit`, including:
- player_id
- scheme_version
- initialized_at
- money_granted
- coins_granted
- equipment_granted
- starter_home_granted
- result/details

Career creation must be safe to retry but must never duplicate value.

## 10. Completion tests

A new ATP Free career, ATP Premium career, WTA Free career and WTA Premium career should each be created in a test transaction/environment and verified against this matrix.

Minimum assertions:
- exactly $25,000 opening cash once
- exactly 20 starting Coins once
- correct balanced skills
- zero fatigue and 50 mental/readiness values
- exactly one starter racket
- exactly one starter shoe
- exactly one starter apparel item
- zero accessories
- all three starter items visible in Inventory and equipped in Gear Room
- zero staff
- zero sponsor contracts
- zero national association memberships
- zero tennis club memberships
- zero calendar commitments
- no user-selected training plan
- Free: zero starter properties
- Premium: exactly one starter apartment
- 0 singles and doubles ranking points
- retry/refresh does not duplicate any starter resource


## 11. Production verification — 2026-10-02

The complete creation flow was verified with rollback-only database tests so no test accounts remained in production.

Tested combinations:
- ATP Free
- ATP Premium
- WTA Free
- WTA Premium

Verified results:
- $25,000 Career Cash
- 20 starting Coins with exactly one ledger grant
- technical starting total within the approved 440–455 range
- physical total 200
- Fatigue 0; Sharpness/Morale/Confidence/Focus 50
- exact three starter equipment items at creation
- ATP apparel: `APP-BLOKUV-01`
- WTA apparel: `APP-WTA-BLOKUV-01`
- racket: `RKT-ROSIGNOL-01`
- shoes: `SHO-ANTTA-01`
- all three equipment slots populated in Gear Room
- zero starter accessories
- zero staff
- zero regular sponsors
- zero technical sponsors
- zero National Association memberships
- zero Tennis Club memberships
- zero committed calendar entries
- zero configured training plans
- singles and doubles ranking points 0
- Free careers receive zero starter homes
- Premium careers receive exactly one trade-locked starter apartment
- explicit city pricing works (New York retained its city-specific market value)
- country-tier fallback works (Serbia Tier 4 test produced a $120,000 apartment base / $72,000 starter-home value)
- Free → Premium upgrade grants the starter apartment once
- rerunning the career initializer returns `already_initialized` and does not duplicate Coins, equipment, home or audit records
- no rollback-only test users remained after verification
