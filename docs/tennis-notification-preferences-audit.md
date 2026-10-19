# Tennis Legacy — Notification Inventory and Preferences Audit

Audited on 19 October 2026 against the live Supabase `notification_catalog`.

## Scope and decisions

- **72 total catalog entries; 70 active; 2 inactive legacy entries.**
- **27 optional** active entries can be switched individually or by category; **43 required** entries always deliver in-game. The database rather than UI controls essential protection.
- Notification events go to the in-game **Notifications Center** via `emit_notification_v1`. The **Inbox** is direct player-to-player messaging (`get_player_inbox_v1`), not a duplicate copy of notifications.
- Each notice is currently an **in-game** event. Email/push fields exist but are not wired to guaranteed delivery/opt-out. Do not display email/push switches yet.
- Delivery is checked centrally *before* writing optional `user_notifications`. Required events bypass stored overrides, including old preference rows.
- No Youth/U23, Transfers, Staff Advisory, staff-contract, scouting or financial-risk notification catalog entries currently exist in Tennis Legacy. Do not add empty settings for cycling-only systems.
- Default optional events are **on**, matching the catalog; only deviations need user rows. Restore Defaults deletes optional overrides without affecting required alerts.
- Per-player Inbox and Tennis Club chat unread badges are independent of this catalog.

## Potential duplicates or overlaps to watch

- `player.health.competition_clear` and `player.health.competition_cleared` describe the same lifecycle event. Only `competition_clear` is active; the `...cleared` legacy alias is inactive.
- `player.health.training_clear` and `player.health.training_cleared` follow the same pattern; only `training_clear` is active.
- `doubles.partner.invitation`, `doubles.invitation.accepted`, `doubles.partnership.confirmed` are distinct lifecycle steps, but can appear close together; keep separate event keys and monitor duplicates.
- `training.camp.booked` and `travel.planned` may be produced by the same booking but represent distinct decisions (camp reservation versus journey itinerary).
- The `account.birthday_gift` notification is a direct core transaction confirmation and required; it is not an optional general update.
- `player.fatigue.tired`, `...day_off_recommended`, `...critical` are severity thresholds rather than duplicate events; critical alerts are required.

## Complete catalog

For every entry, the destination is **Notifications Center** (not the player Inbox).

### account — 10 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `account.birthday_gift` | The account holder reaches their stored real-world birthday.. Stored birthday matches the current date in the account birthday timezone and no reward exists for that calendar year. | success | Required | Active |
| `avatar.request.cancelled` | Player cancels avatar request. A signed-in player cancels one of their active avatar replacement requests. | info | Required | Active |
| `avatar.request.completed` | Player approves replacement. The player approves the prepared replacement image. | success | Required | Active |
| `avatar.request.ready` | Admin marks replacement ready. A replacement preview has been prepared by an administrator. | success | Required | Active |
| `avatar.request.rejected` | Admin rejects request. An administrator marks the request as unable to process. | warning | Required | Active |
| `avatar.request.revision` | Player requests revision. The player asks for a limited revision to a prepared replacement. | warning | Required | Active |
| `avatar.request.submitted` | Avatar request submitted. A signed-in player submits a valid private avatar request. | info | Required | Active |
| `premium.trial.expired` | First trial check after expiry. Trial ended and user has no active paid Premium | info | Required | Active |
| `premium.trial.reminder` | Trial check within 24 hours of expiry. Trial active and reminder not yet sent | info | Required | Active |
| `premium.trial.started` | First game dashboard entry. Eligible free player with an unclaimed seven-day trial | success | Required | Active |

### club — 1 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `club.invitation.received` | A new Tennis Club invitation is submitted. Valid pending invitation for a human player | info | Required | Active |

### equipment — 4 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `equipment.technical_sponsor.expired` | technical_sponsor_contract_expired. Technical sponsor contract end date has passed. | info | Required | Active |
| `equipment.technical_sponsor.expiring` | technical_sponsor_contract_expiring. Technical sponsor contract has 28 or fewer days remaining. | warning | Required | Active |
| `equipment.technical_sponsor.offer` | technical_sponsor_offer_generated. Eligible technical sponsor offers were generated. | info | Optional | Active |
| `equipment.technical_sponsor.signed` | technical_sponsor_contract_signed. Player accepts a technical sponsor offer. | success | Optional | Active |

### national_team — 9 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `national.association.renewal` | Annual national association renewal opens.. An activated association reaches 1 January of a new season and its renewal fund is created. | warning | Required | Active |
| `national.captain.elected` | Captain election completes.. One candidate finishes a round with strictly more votes than every other candidate and at least one vote. | success | Optional | Active |
| `national.captain.election` | A national captain election opens.. An annual, activation or special captain election is created. | info | Required | Active |
| `national.captain.runoff` | A captain election round ends without a unique winner.. A tie, zero-vote round or empty election requires another seven-day round. | warning | Required | Active |
| `national.captain.vacancy` | Captain seat becomes vacant.. The active captain resigns or no longer has an eligible active association membership. | warning | Required | Active |
| `national.competition.launch` | A national association becomes active before the official launch season.. Association is active while the current season is earlier than the official launch season. | info | Optional | Active |
| `national.friendly.accepted` | The invited captain accepts a friendly proposal.. The window slot is still available for both associations. | success | Optional | Active |
| `national.friendly.declined` | The invited captain declines a friendly proposal.. The invitation was still pending. | info | Optional | Active |
| `national.friendly.invitation` | A captain invites another listed association for a national-window friendly.. Both associations are active and the pairing deadline has not passed. | info | Required | Active |

### player_condition — 3 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `player.fatigue.critical` | player_skills fatigue update. Fatigue crosses upward from below 90 to 90 or higher. | error | Required | Active |
| `player.fatigue.day_off_recommended` | player_skills fatigue update. Fatigue crosses upward from below 80 to 80 or higher. | warning | Optional | Active |
| `player.fatigue.tired` | player_skills fatigue update. Fatigue crosses upward from below 60 to 60 or higher. | info | Optional | Active |

### player_development — 2 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `player.skill.decreased` | A tennis skill value decreases.. NEW skill value is lower than OLD skill value on public.player_skills. | warning | Optional | Active |
| `player.skill.increased` | A tennis skill value increases.. NEW skill value is greater than OLD skill value on public.player_skills. | success | Optional | Active |

### player_health — 14 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `player.health.competition_clear` | competition return reached. A health condition reaches its tournament return date. | info | Required | Active |
| `player.health.competition_cleared` | competition return reached. A health condition reaches its tournament return date. | info | N/A | Legacy / inactive |
| `player.health.match_surrendered` | health surrender. The user withdraws from a scheduled or active match because of health risk. | warning | Required | Active |
| `player.health.medical_walkover` | match health resolution. A scheduled tournament match reaches preparation while the player is medically unavailable. | warning | Required | Active |
| `player.health.nearly_fit` | recovery progress. Recovery reaches at least 75 percent while not complete. | info | Required | Active |
| `player.health.risk` | daily health risk. Daily health risk reaches a warning level. | warning | Required | Active |
| `player.health.tournament_withdrawn` | tournament field lock. Accepted player remains medically unavailable at tournament start. | warning | Required | Active |
| `player.health.training_clear` | training return reached. A health condition reaches its training return date. | info | Required | Active |
| `player.health.training_cleared` | training return reached. A health condition reaches its training return date. | info | N/A | Legacy / inactive |
| `player.illness.detected` | illness generated. A daily illness roll succeeds. | warning | Required | Active |
| `player.illness.recovered` | illness recovered. The expected full recovery date is reached. | success | Required | Active |
| `player.illness.worsened` | illness progression. A fatigued player has an illness progression event. | error | Required | Active |
| `player.injury.detected` | injury generated. An injury roll succeeds. | error | Required | Active |
| `player.injury.recovered` | injury recovery processor. Expected full recovery date is reached. | info | Optional | Active |
| `player.injury.risk` | injury risk calculation. Risk reaches elevated, high or very high for an activity. | warning | Optional | Active |
| `player.injury.worsened` | injury aggravation. A player competes or trains while not fully recovered and the aggravation roll succeeds. | error | Required | Active |

### private_life — 1 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `player.private_life.running_costs` | Combined monthly Private Life costs are processed on the first game day of a month.. At least one owned Private Life asset has a monthly living or maintenance charge due. | info | Optional | Active |

### tournament — 21 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `doubles.draw.published` | doubles_draw_published. The tournament doubles draw is published. | info | Required | Active |
| `doubles.entry.accepted` | doubles_entry_allocated. A confirmed team is inside the doubles draw capacity. | success | Optional | Active |
| `doubles.entry.waitlisted` | doubles_entry_waitlisted. A confirmed team is ranked outside doubles draw capacity. | warning | Optional | Active |
| `doubles.invitation.accepted` | doubles_partner_invitation_accepted. The invited player accepts before the partnership deadline. | success | Optional | Active |
| `doubles.invitation.declined` | doubles_partner_invitation_declined. The invited player declines. | info | Optional | Active |
| `doubles.invitation.expired` | doubles_partner_invitation_expired. A pending invitation reaches the partnership deadline. | warning | Required | Active |
| `doubles.match.result` | doubles_match_completed. A doubles match finishes by play or walkover. | info | Optional | Active |
| `doubles.match.scheduled` | doubles_match_scheduled. A doubles match for the player is scheduled or rescheduled. | info | Required | Active |
| `doubles.partner.invitation` | doubles_partner_invitation_created. A pending tournament-specific doubles invitation is created. | info | Required | Active |
| `doubles.partnership.confirmed` | doubles_partnership_created. An invitation is accepted and a doubles team is created. | success | Optional | Active |
| `doubles.team.withdrawn` | doubles_team_withdrawn. One partner leaves before lock or withdraws the team after lock. | warning | Required | Active |
| `tournament.application.submitted` | tournament_application_created. A human player submits a normal tournament application. | info | Optional | Active |
| `tournament.application.withdrawn` | tournament_application_withdrawn. A human player withdraws an application. | info | Optional | Active |
| `tournament.canceled` | tournament_canceled. A tournament containing a human player is canceled. | warning | Required | Active |
| `tournament.draw.published` | tournament_draw_published. A draw publication is created for a competition containing the player. | info | Required | Active |
| `tournament.entry.accepted_main` | tournament_application_decided. A human application becomes accepted_main_draw. | success | Required | Active |
| `tournament.entry.accepted_qualification` | tournament_application_decided. A human application becomes accepted_qualification. | success | Required | Active |
| `tournament.entry.rejected` | tournament_application_decided. A human application becomes rejected. | warning | Required | Active |
| `tournament.match.travel_no_show` | Scheduled tournament match reached while player is not yet ready at the venue. Travel readiness is impossible at scheduled match time. | warning | Required | Active |
| `tournament.preparation.available` | tournament_entry_accepted. A human player receives a tournament place. | info | Required | Active |
| `tournament.result.completed` | player_tournament_result_finalized. A human player receives or updates their final player_tournament_results row. | info | Optional | Active |

### training — 3 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `training.camp.booked` | Training camp booking created. A player successfully books a camp for 1–4 weeks. | info | Optional | Active |
| `training.camp.cancelled` | Training camp booking cancelled. A booked training camp is cancelled before its starting day. | info | Optional | Active |
| `training.camp.completed` | Final training-camp day processed. The current game day equals the booking end day. | success | Optional | Active |

### travel — 2 active

| Notification code | Trigger / condition | Importance | Control | Status |
|---|---|---|---|---|
| `travel.arrived` | travel_leg_processed. A planned player_travel_legs row changes to completed. | info | Optional | Active |
| `travel.planned` | travel_plan_rebuilt. A future route is created or recalculated from player commitments. | info | Optional | Active |

## Implemented runtime API

- `get_my_notification_inventory_v2()`: categorized active events with metadata, required locks and effective per-user values.
- `set_my_notification_type_enabled_v1(code, enabled)`: per-event optional toggle, refuses required events.
- `set_my_notification_category_enabled_v1(category, enabled)`: optional events in category only.
- `restore_my_notification_defaults_v1()`: clears overrides for signed-in user only.
- `emit_notification_v1(...)`: checks optional overrides before insertion, bypasses overrides for required messages.

### Remaining delivery channels and future types

Email and push are not exposed until connected to actual send providers and verified end-to-end. Automated digest/frequency options, Youth race reports, transfer advisories, and financial-risk categories must wait for real producer integration. Account/payment/security alerts should remain required whenever introduced.

### Validation

SQL transaction rollback tests covered optional event suppression, required delivery, rejection of required toggles, category toggles, restore defaults, and authentication/RLS checks. The UI build and deployed mobile visual QA are separate verification steps.
