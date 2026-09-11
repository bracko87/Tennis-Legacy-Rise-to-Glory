# Injury, Illness & Recovery System — Implementation and Handoff

Date: 2026-09-11
Project: Tennis Legacy - Rise to Glory
Supabase project ref: `cwfznmroiqcyhfkfcrow`
GitHub: `bracko87/Tennis-Legacy-Rise-to-Glory` (`main`)

## Purpose

This document records the completed end-to-end injury, illness, recovery, health-risk, tournament-availability, AI injury, notification, surrender, and Health UI work completed on 2026-09-11. It is intended as the authoritative handoff for continuing work in a new chat/session.

## Test career

- User ID: `0b88bb1b-797a-4c40-b7ca-d9155a1fd713`
- Human player ID: `e1293428-8bd1-4857-bbdc-21e0768e3841`
- Current tournament: Christchurch Challenger
- Competition ID: `0ec89482-874d-4fc8-8983-912345b426ba`
- Current semifinal match ID: `d1a7de2c-8beb-4716-86b1-c27cc6666e3e`

## Current safe production state at handoff

Verified immediately before creating this document:

- Fatigue: 35
- Sharpness: 64
- Fitness: 50
- Recovery: 50
- Active injuries: 0
- Active illnesses: 0
- Christchurch tournament entry: `active`
- Semifinal: `scheduled`
- Semifinal winner: null
- Semifinal completion reason: null
- Career finance balance: $27,500

This is the safe baseline. Do not assume an earlier temporary 90-fatigue test state is still active.

## Important simulation history still stored

The live UI sequence was tested case-by-case and the following simulation records remain in history unless explicitly cleaned up later:

1. Minor injury
   - ID: `afb400db-a5ad-4c54-9d20-639419e362d1`
   - Code: `hamstring_tightness`
   - Severity: minor
   - Status: recovered
   - Created: 2026-09-11 12:51 UTC

2. Severe injury
   - ID: `574fd17a-4acd-46bf-9662-6dbf181843bc`
   - Code: `rotator_cuff_injury`
   - Severity: severe
   - Status: recovered
   - Created: 2026-09-11 13:01 UTC

The associated test notifications also remain visible, including risk warning, injury detected, training clearance, competition clearance, nearly fit, and fully recovered notifications. These are intentionally documented so a future session can decide whether to leave them as test history or clean them up.

## Implemented health lifecycle

The production system now supports a unified lifecycle covering:

- Healthy
- At risk
- Injury
- Illness
- Recovering
- Training cleared while competition still blocked
- Competition cleared while not fully fit
- Nearly fully fit
- Fully recovered

Injury and illness are separate event types but share a unified health summary/dashboard and availability model.

## Risk logic

The health engine considers contextual risk rather than only a generic static number. Factors include:

- fatigue
- recovery condition
- training intensity
- match duration
- match workload
- heat / environmental conditions where supported
- current recovery state
- recent travel for illness risk
- medical/staff modifiers

High fatigue increases risk but does not automatically injure the player. A player may remain competition-eligible while being shown as `At risk`.

A key example validated in production:

- fatigue 90
- 150-minute match
- no active injury
- match injury risk about 1.22% (`Elevated`)
- illness risk about 0.25% (`Elevated`)
- player still allowed to compete
- health concern flag true

## Injury severity / staged return

A severe rotator-cuff injury was used to test the complete staged lifecycle. The engine correctly produced separate dates for:

- training return
- tournament/competition return
- full recovery

The player can therefore enter these states:

1. Injured — training and competition blocked
2. Recovering — training allowed, competition blocked
3. Not fully fit — training and competition allowed, performance penalty remains
4. Nearly fit — reduced remaining performance penalty
5. Fully recovered — penalty returns to zero

Recovery progress is date-driven and was verified to progress consistently rather than relying only on a stale stored UI value.

## Notifications

Canonical notification flow now includes:

- injury risk increased
- injury detected
- illness detected
- cleared for training
- cleared for competition
- nearly fully fit
- fully recovered
- medical walkover / surrender-related notices where appropriate

Notifications use unique event keys to prevent duplicate messages.

Legacy duplicate notification codes were deactivated; canonical `training_clear` / `competition_clear` paths remain active.

## AI injuries

Weekly AI short-injury processing is implemented and idempotent.

Validated behavior:

- 3–5 AI injuries per game week target
- test week produced 4 AI injuries
- injuries are minor/short
- typical recovery 3–6 game days
- rerunning the weekly processor returns `already_processed` and does not duplicate that week's injuries

## Tournament / calendar integration

Health is integrated with tournament participation.

### Entry eligibility

- If projected tournament return date is on/before tournament start: future entry may remain allowed.
- If projected return date is after tournament start: application/late-entry is medically blocked.
- Backend validates this directly; it is not UI-only.

### Field lock

If a player was accepted while healthy but becomes medically unavailable before the tournament begins, the field-lock process can withdraw the entry so the slot does not become a guaranteed walkover.

### Match day

If the player is medically unavailable on match day, health walkover logic resolves the match and advances the opponent.

Exact recovery-day behavior was validated: competition becomes available on the competition-return date itself.

## Match health choice / surrender

A match health control is shown in the tournament match modal.

When there is no meaningful concern, it is informational only.

When there is a concern but the player is still allowed to play:

- `Play anyway` is available
- `Surrender match` is available until simulation is prepared
- surrender is NOT automatic
- the user must explicitly choose surrender
- surrender then requires a confirmation dialog

Backend surrender action: `surrender_tournament_match_v1`.

The surrender outcome uses `completion_reason = 'health_surrender'` rather than abusing scheduling fields.

Automatic medical walkovers use `completion_reason = 'health_walkover'`.

## Reusable in-game confirmation dialog

Native browser `window.confirm()` was removed from the health surrender flow.

Reusable component added:

- `src/components/common/GameConfirmDialog.tsx`
- `src/styles/game-confirm-dialog.css`

This should be reused for future destructive/important confirmations such as:

- surrender
- withdrawal
- cancel
- delete
- similar yes/no actions

The component includes:

- game-styled modal
- dimmed backdrop
- title, eyebrow, message and detail
- Cancel and destructive confirm buttons
- Escape-to-cancel
- backdrop-click cancel when not busy
- focus on Cancel by default
- busy/processing state

The health surrender screen now uses this custom dialog.

## Match modal freeze bug fixed

A serious Chromium freeze was found and fixed.

Cause:

`TournamentMatchHealthControl` and `TournamentMatchTacticStatus` each used a MutationObserver and repeatedly tried to remain the immediate sibling before the same tactic section. They continually displaced/reinserted one another, creating an infinite DOM mutation loop and causing Chrome to show `This page isn't responding`.

Fix:

Each enhancement now creates/reuses its host without continually fighting over immediate sibling position.

This resolved the main-thread freeze.

## Health UI / visual design

The Injury & Health page was redesigned to follow the Overview visual language while preserving the production health logic:

- white cards
- soft blue/green accents
- lighter borders
- subtle shadows
- Overview-style hierarchy
- clearer status colors

Condition values now use visual good-to-bad bands:

- green
- light green
- amber
- orange
- red

Fatigue is inverted because lower is better. Sharpness, Fitness and Recovery use higher-is-better logic.

## Cross-page consistency

Verified/fixed surfaces include:

- Injury & Health page
- Overview
- Training
- Calendar
- Tournament entry
- Tournament match modal
- Notifications

Training now considers unified health state, fatigue, injury risk and illness risk rather than showing a green clearance based only on injury risk.

Calendar visible wording uses `Health / Recovery`; the internal legacy activity key may still be `injured` for compatibility.

## Important production migrations

The following health-related migrations exist in production:

- `20260902113106_fatigue_and_injury_notifications`
- `20260907154937_injury_system_foundation_v1`
- `20260907155518_injury_tournament_availability_walkovers_v1`
- `20260907182258_proactive_injury_risk_notifications_v1`
- `20260911093105_health_illness_recovery_lifecycle_v1`
- `20260911094959_unified_health_lifecycle_ai_injuries_and_match_surrender_v1`
- `20260911095028_fix_ai_weekly_short_injury_selector_v2`
- `20260911095050_fix_ai_weekly_injury_vulnerability_rounding_v3`
- `20260911095122_align_ai_weekly_injuries_to_existing_source_types_v4`
- `20260911095308_unified_health_dashboard_and_consistency_v5`
- `20260911102422_health_notification_catalog_compatibility_v6`
- `20260911102457_health_live_progress_and_setbacks_v7`
- `20260911102712_wire_health_setbacks_and_medical_activity_blocks_v8`
- `20260911102804_live_health_state_and_recovery_progress_v9`
- `20260911102849_illness_progression_under_recovery_stress_v10`
- `20260911102954_align_health_surrender_notification_v11`
- `20260911105752_fix_health_walkover_zero_duration_v12`
- `20260911110700_health_match_completion_reason_and_walkover_resolution_v13`
- `20260911111054_align_high_fatigue_health_state_and_medical_walkover_notice_v14`
- `20260911112127_tournament_entry_health_eligibility_and_field_lock_v15`
- `20260911112249_expose_tournament_health_eligibility_in_entry_lifecycle_v16`
- `20260911113337_deactivate_legacy_duplicate_health_notification_codes_v17`

## Relevant frontend files

- `src/pages/dashboard/Injuries.tsx`
- `src/components/dashboard/OverviewInjuryEnhancement.tsx`
- `src/components/training/TrainingHealthStatus.tsx`
- `src/components/tournament/TournamentMatchHealthControl.tsx`
- `src/components/tournament/TournamentMatchTacticStatus.tsx`
- `src/components/common/GameConfirmDialog.tsx`
- `src/styles/injury-health-dashboard.css` or current Injury page stylesheet used by the page
- `src/styles/tournament-match-health-control.css`
- `src/styles/game-confirm-dialog.css`
- `src/pages/dashboard/Calendar.tsx`

## Recent key GitHub commits

- `e792249c09a4d6b78835e4a93e52ab75b588e999` — Add reusable in-game confirmation dialog
- `7873a97e4fbf6f42e5af40323d7e649ce206827d` — Style reusable in-game confirmation dialog
- `64c071c2e9aef37687fcbef315751c66e0fd66f1` — Use in-game confirmation dialog for health surrender
- `dfe998645655a20195bb8ff7cc4fa2240c0956c6` — Refine match health action button sizing
- `b60db11209bcfeb3036063388a2f2366376898a4` — Remove temporary game confirmation build workflow

Earlier important fixes:

- `f7f154de137a27a3713f2daf9c7bf9928a180b43` — Make health surrender an explicit player choice
- `1f29db83135d936a9bea053508896ff4eb378384` — Clarify play-or-surrender health choice
- `8715b5e14210486dba7d64acacc511b76d526e2e` — Match health visual spacing/readability
- `1a9ed7c01011c352dfeb2c5d14579f02cb0c14a2` and `c73cd509ede0fe3ae87527178890d8c046658e17` — Fix modal MutationObserver host loop/freeze

## Build verification

The latest reusable confirmation-dialog implementation was verified with GitHub Actions:

- `npm ci` — passed
- `npm run build` — passed

Temporary CI workflow was removed after successful verification.

## Recommended next-session actions

1. Read this document first.
2. Inspect current Supabase state before changing the test career.
3. Confirm the new custom health surrender dialog visually in the local dev environment.
4. If testing surrender live, create a fresh snapshot immediately before pressing Confirm because surrender changes bracket/entry/result/finance/equipment/travel state.
5. After the surrender test, restore the baseline exactly if requested.
6. Decide whether to remove the two simulation injury-history rows and their related test notifications. Do not delete them automatically without user approval.
7. For future confirmation popups, reuse `GameConfirmDialog` instead of `window.confirm()`.

## Working rules

- Work from the actual production Supabase project; do not guess.
- Keep production migrations mirrored to GitHub `supabase/migrations`.
- Use rollback transactions for backend lifecycle tests whenever a persistent live state is not explicitly required.
- For visible UI-state testing, snapshot every downstream table that the action can modify before changing production test data.
- Keep GitHub `main` aligned with production code/migrations.
- Run `npm ci` + `npm run build` after frontend changes and remove temporary workflow afterward.
