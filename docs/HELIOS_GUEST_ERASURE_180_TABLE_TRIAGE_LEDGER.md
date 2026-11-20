# Helios H08 — Complete reachable-FK table triage inventory

Generated from **read-only schema metadata** of the production Tennis Legacy Supabase PostgreSQL database on 20 November 2026. No player, payment, message, or Auth record contents were read. **This is an engineering triage list, NOT an approved deletion/retention policy or permission to run deletion.**

Baseline: **188 direct foreign keys** linking to `auth.users` or `public.players`, **156** directly dependent tables, **818** unique traversed FK paths, **180** dependent tables overall, **24** indirect-only dependent tables, max chain depth **5**. A table may be reached by several paths; these figures are not affected row counts.

## Provisional review groups (all unapproved)

| Area | Tables | Interpretation |
|---|---:|---|
| COMPETITION_HISTORY | 66 | Candidate grouping from TABLE NAME only |
| FINANCIAL | 25 | Candidate grouping from TABLE NAME only |
| IDENTITY_AUTH | 18 | Candidate grouping from TABLE NAME only |
| PERSONAL_GAMEPLAY | 53 | Candidate grouping from TABLE NAME only |
| PRIVATE_COMMUNICATION | 18 | Candidate grouping from TABLE NAME only |

Suggested handling is **not a deletion decision**. Final treatment is `REVIEW_REQUIRED` for *every one* of the 180 tables. Investigate FKs, columns, legal retention basis, active historic public display, joined user identity and transitive deletion effects, triggers, RLS, and Storage before any migrations. Blank/indirect action means only that the table is not directly attached to Auth/player; it is still reachable.

## Every reachable dependent table

| # | Table | Min FK hops | Paths | Direct FKs | Direct ON DELETE | Review group | Proposed investigation (NOT APPROVED) | Status |
|---:|---|---:|---:|---:|---|---|---|---|
| 1 | `auth.identities` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 2 | `auth.mfa_amr_claims` | 2 | 1 | 0 | indirect-only | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 3 | `auth.mfa_challenges` | 2 | 1 | 0 | indirect-only | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 4 | `auth.mfa_factors` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 5 | `auth.mfa_recovery_code_sets` | 1 | 2 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 6 | `auth.mfa_recovery_codes` | 2 | 2 | 0 | indirect-only | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 7 | `auth.oauth_authorizations` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 8 | `auth.oauth_consents` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 9 | `auth.one_time_tokens` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 10 | `auth.refresh_tokens` | 2 | 1 | 0 | indirect-only | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 11 | `auth.scim_users` | 1 | 1 | 1 | SET NULL | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 12 | `auth.sessions` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 13 | `auth.webauthn_challenges` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 14 | `auth.webauthn_credentials` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 15 | `avatar_replacement_request_history` | 2 | 6 | 0 | indirect-only | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 16 | `avatar_replacement_requests` | 1 | 6 | 2 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 17 | `billing_transactions` | 1 | 1 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 18 | `birthday_email_outbox` | 1 | 6 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 19 | `birthday_rewards` | 1 | 6 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 20 | `bug_report_admin_reads` | 2 | 3 | 0 | indirect-only | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 21 | `bug_report_notes` | 2 | 3 | 0 | indirect-only | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 22 | `bug_reports` | 1 | 3 | 2 | SET NULL | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 23 | `career_finance_transactions` | 1 | 2 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 24 | `career_tax_periods` | 1 | 4 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 25 | `coin_ledger` | 1 | 1 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 26 | `commerce_checkout_intents` | 1 | 1 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 27 | `contact_requests` | 1 | 3 | 2 | CASCADE, SET NULL | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 28 | `control_center_private.tennis_active_player_presence_v1` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 29 | `control_center_private.tennis_guest_trials_v1` | 1 | 1 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 30 | `control_center_private.tennis_season_transition_technical_contract_registry_v1` | 2 | 4 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 31 | `control_center_private.tennis_season2_week1_preentries_v1` | 1 | 3 | 2 | RESTRICT | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 32 | `control_center_private.tournament_qualification_nocontest_repairs_v1` | 1 | 16 | 1 | NO ACTION | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 33 | `cpx_tennis_reward_balances` | 1 | 1 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 34 | `cpx_tennis_reward_transactions` | 1 | 1 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 35 | `national_association_contributions` | 1 | 7 | 1 | RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 36 | `national_association_events` | 2 | 1 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 37 | `national_association_finance_transactions` | 2 | 1 | 0 | indirect-only | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 38 | `national_association_funds` | 2 | 1 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 39 | `national_association_memberships` | 1 | 4 | 2 | CASCADE, SET NULL | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 40 | `national_association_recognitions` | 1 | 4 | 2 | CASCADE, SET NULL | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 41 | `national_association_treasuries` | 2 | 1 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 42 | `national_associations` | 1 | 1 | 1 | SET NULL | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 43 | `national_captain_candidates` | 1 | 8 | 2 | RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 44 | `national_captain_elections` | 2 | 8 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 45 | `national_captain_runoff_candidates` | 2 | 16 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 46 | `national_captain_terms` | 1 | 24 | 2 | RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 47 | `national_captain_votes` | 1 | 21 | 1 | RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 48 | `national_team_callups` | 1 | 8 | 2 | CASCADE, RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 49 | `national_team_chat_messages` | 1 | 4 | 2 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 50 | `national_team_chat_presence` | 1 | 8 | 2 | CASCADE, RESTRICT | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 51 | `national_team_division_entries` | 2 | 1 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 52 | `national_team_division_standings` | 2 | 1 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 53 | `national_team_engine_competitions` | 3 | 4 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 54 | `national_team_fixture_match_slots` | 1 | 31 | 4 | SET NULL | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 55 | `national_team_fixtures` | 2 | 4 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 56 | `national_team_friendly_invitations` | 1 | 8 | 2 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 57 | `national_team_friendly_listings` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 58 | `national_team_lineup_slots` | 1 | 8 | 1 | RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 59 | `national_team_lineups` | 1 | 6 | 1 | SET NULL | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 60 | `national_team_player_appearances` | 1 | 7 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 61 | `national_team_squad_members` | 1 | 8 | 2 | RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 62 | `new_player_initialization_audit` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 63 | `notification_preferences` | 1 | 1 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 64 | `player_avatar_reservations` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 65 | `player_calendar_commitments` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 66 | `player_career_day_processing_state` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 67 | `player_career_finance_accounts` | 1 | 2 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 68 | `player_conversations` | 1 | 4 | 2 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 69 | `player_daily_activity` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 70 | `player_direct_transfer_morale_state` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 71 | `player_doubles_equipment_wear_events` | 1 | 14 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 72 | `player_doubles_match_condition_events` | 1 | 14 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 73 | `player_doubles_match_tactics` | 1 | 14 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 74 | `player_doubles_ranking_contributions` | 1 | 14 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 75 | `player_doubles_ranking_snapshots` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 76 | `player_doubles_rankings` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 77 | `player_doubles_tournament_results` | 1 | 6 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 78 | `player_equipment_accessory_loadout` | 1 | 4 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 79 | `player_equipment_broken_starters_v1` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 80 | `player_equipment_inventory` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 81 | `player_equipment_loadouts` | 1 | 10 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 82 | `player_equipment_match_setup_accessories` | 2 | 10 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 83 | `player_equipment_match_setups` | 1 | 8 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 84 | `player_equipment_wear_events` | 1 | 8 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 85 | `player_health_setback_events` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 86 | `player_homepage_reviews` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 87 | `player_illness_risk_events` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 88 | `player_illnesses` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 89 | `player_injuries` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 90 | `player_injury_risk_events` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 91 | `player_lifestyle_morale_events` | 1 | 8 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 92 | `player_lifestyle_state` | 1 | 14 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 93 | `player_location_state` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 94 | `player_match_condition_events` | 1 | 8 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 95 | `player_messages` | 1 | 6 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 96 | `player_opponent_scouting_tasks` | 1 | 12 | 2 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 97 | `player_premium_season_targets` | 1 | 2 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 98 | `player_premium_tournament_watches` | 1 | 2 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 99 | `player_private_jet_positions` | 1 | 8 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 100 | `player_ranking_contributions` | 1 | 6 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 101 | `player_ranking_snapshots` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 102 | `player_rankings` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 103 | `player_skill_history` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 104 | `player_skills` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 105 | `player_sponsor_contracts` | 1 | 4 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 106 | `player_sponsor_objectives` | 1 | 8 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 107 | `player_sponsor_offers` | 1 | 4 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 108 | `player_sponsor_renewal_reservations_v1` | 1 | 10 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 109 | `player_staff_contracts` | 1 | 4 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 110 | `player_technical_sponsor_contracts` | 1 | 4 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 111 | `player_technical_sponsor_offers` | 1 | 2 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 112 | `player_tournament_match_equipment_setups` | 1 | 8 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 113 | `player_tournament_match_tactics` | 1 | 8 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 114 | `player_tournament_preparation_plans` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 115 | `player_tournament_results` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 116 | `player_tournament_transfer_preferences` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 117 | `player_tournament_travel_selection` | 1 | 8 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 118 | `player_training_camp_bookings` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 119 | `player_training_camp_days` | 1 | 4 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 120 | `player_training_camp_staff` | 2 | 8 | 0 | indirect-only | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 121 | `player_training_plans` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 122 | `player_training_progress` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 123 | `player_training_sessions` | 1 | 2 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 124 | `player_travel_legs` | 1 | 14 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 125 | `player_tutorial_progress` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 126 | `player_weekly_training_plan_days` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 127 | `players` | 1 | 1 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 128 | `premium_memberships` | 1 | 1 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 129 | `private_life_asset_events` | 1 | 10 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 130 | `private_life_asset_sale_listings` | 1 | 10 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 131 | `private_life_investment_positions` | 1 | 2 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 132 | `private_life_investment_trades` | 1 | 4 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 133 | `private_life_player_assets` | 1 | 6 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 134 | `profiles` | 1 | 1 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 135 | `referral_activity_days` | 1 | 1 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 136 | `referral_admin_audit` | 1 | 1 | 1 | RESTRICT | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 137 | `referral_admins` | 1 | 1 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 138 | `referral_clicks` | 1 | 1 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 139 | `referral_codes` | 1 | 1 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 140 | `referral_contest_awards` | 1 | 2 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 141 | `referral_contest_prizes` | 2 | 1 | 0 | indirect-only | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 142 | `referral_contests` | 1 | 1 | 1 | RESTRICT | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 143 | `referral_premium_grants` | 1 | 2 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 144 | `referral_reward_adjustments` | 1 | 5 | 2 | CASCADE, RESTRICT | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 145 | `referral_rewards` | 1 | 6 | 2 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 146 | `referral_user_badges` | 1 | 2 | 1 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 147 | `referral_user_devices` | 1 | 1 | 1 | CASCADE | IDENTITY_AUTH | Erase/auth-safe cleanup; review sessions | REVIEW_REQUIRED |
| 148 | `referrals` | 1 | 3 | 3 | CASCADE, SET NULL | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 149 | `registration_invites` | 1 | 1 | 1 | SET NULL | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 150 | `staff_financial_events` | 1 | 6 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 151 | `staff_members` | 1 | 2 | 1 | SET NULL | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 152 | `staff_negotiation_offers` | 1 | 12 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 153 | `staff_negotiations` | 1 | 8 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 154 | `system_alert_email_outbox` | 1 | 3 | 1 | SET NULL | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 155 | `system_incident_admin_reads` | 1 | 3 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 156 | `system_incidents` | 1 | 2 | 2 | SET NULL | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 157 | `technical_sponsor_equipment_claims` | 1 | 10 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 158 | `tennis_club_chat_messages` | 1 | 4 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 159 | `tennis_club_chat_read_state_v1` | 1 | 4 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 160 | `tennis_club_memberships` | 1 | 4 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 161 | `tennis_club_requests` | 1 | 8 | 3 | CASCADE, SET NULL | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 162 | `tennis_clubs` | 1 | 2 | 1 | RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 163 | `tennis_premium_trials_v1` | 1 | 1 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |
| 164 | `tournament_applications` | 1 | 3 | 2 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 165 | `tournament_doubles_matches` | 2 | 12 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 166 | `tournament_doubles_partner_invitations` | 1 | 4 | 2 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 167 | `tournament_doubles_partner_listings` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 168 | `tournament_doubles_teams` | 1 | 4 | 2 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 169 | `tournament_entries` | 1 | 2 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 170 | `tournament_match_player_stats` | 1 | 8 | 1 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 171 | `tournament_match_sets` | 2 | 6 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 172 | `tournament_match_simulations` | 1 | 8 | 1 | RESTRICT | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 173 | `tournament_match_surrenders` | 1 | 10 | 2 | CASCADE | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 174 | `tournament_match_weather` | 2 | 6 | 0 | indirect-only | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 175 | `tournament_matches` | 1 | 6 | 3 | SET NULL | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 176 | `tournament_qualifier_slots` | 1 | 2 | 1 | SET NULL | COMPETITION_HISTORY | Preserve justified outcomes via neutral historical reference | REVIEW_REQUIRED |
| 177 | `user_interface_preferences_v1` | 1 | 1 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 178 | `user_language_preferences` | 1 | 1 | 1 | CASCADE | PERSONAL_GAMEPLAY | Provisional erase personal state; inspect shared dependencies | REVIEW_REQUIRED |
| 179 | `user_notifications` | 1 | 3 | 2 | CASCADE | PRIVATE_COMMUNICATION | Remove or redact private content; protect other participants | REVIEW_REQUIRED |
| 180 | `user_wallets` | 1 | 1 | 1 | CASCADE | FINANCIAL | Retention law review; then minimize/pseudonymize | REVIEW_REQUIRED |

## Blocking safety contract

- Keep `Guest Mode` **OFF** in production. Existing 14-day retirement of guest gameplay is separate from actual erasure.
- Retain completed match participants/winners/score and doubles/national-team history only after an approved minimally identifying historical model exists. The simplified rollback-only tombstone prototype in PR #66 is **not** a production erasure implementation.
- A real physical deletion worker must exclude all unexpired, converted, registered and paid accounts; verify authorization and schema drift, and be auditable and idempotent.
- Auth account/session/Storage cleanup must use approved privileged APIs; do not run raw destructive SQL against `auth.users` on production.
- **No final retention/erasure choice has yet been approved.** This ledger is a finite review queue, not a compliance judgment.

## How this inventory was calculated

Cycle-safe `pg_constraint` `contype='f'` graph walk, starting at parents `auth.users` and `public.players`, following every dependent child FK up to a depth of 12. In this schema the deepest path has 5 hops. Direct ON DELETE actions are read from `confdeltype`. Category and candidate investigation are based on table names, not inspected personal data. Re-run read-only drift checks after schema migrations.