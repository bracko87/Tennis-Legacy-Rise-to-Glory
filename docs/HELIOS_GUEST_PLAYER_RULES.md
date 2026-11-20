# Project Helios — Guest/Test Player Product Rules

**Scope:** Tennis Legacy: Rise to Glory only. ProPeloton Manager guest work remains Project Saturn.

**Status:** User-approved product direction recorded 20 November 2026. **Specification only — NOT implemented or enabled.**

## 1. Guest entry and player creation

- Homepage and registration entry point offer **Try as Test Player** alongside regular registration and sign-in.
- No email, Google account, password, home city, or real-person birth date is required to start testing.
- Before gameplay, each guest **must create their own fictional tennis player**, using the existing player-creation experience in a streamlined test-player mode.
- Required: **player name** (the same first/last-name data needed by existing player model), **country**, and **player appearance/avatar** (select/customize from existing supported options).
- Do not request **home city** for guests. Where the underlying table requires a home-city value, investigate schema/logic and allow an actual NULL/optional value safely; do **not** invent a city or silently select one.
- Starting abilities and attributes must follow the normal new-player balance where possible. Do not create extra competitive advantage.

## 2. Guest ranking and fairness

- New guests enter at **0 ranking points**, shown at the bottom of the ranking behind all existing players, not artificially seeded near the top.
- Enforce rank ordering **server-side** and consistently in ranking list, player card and header.
- Official competition/tournament eligibility must be analyzed and gated until fairness rules are verified. Avoid fabricated rank points and accidental tournament awards.
- Decide how guest-ranked entries are visually marked (e.g. **Test Player**) and how official ranking/tournament logic differentiates guest from permanent accounts.

## 3. Test account lifetime

- A guest may **play for a maximum of 14 calendar days** measured from a server-stored creation timestamp; do not use client clock or browser-only countdown.
- Show **Test Player** and **days remaining** in the logged-in game interface.
- Before expiry, guests may convert at any time.
- On expiry, stop guest gameplay **server-side**. If no successful permanent conversion has occurred, the automatic retirement worker withdraws future participation and grants opponent walkovers in unstarted scheduled matches; the interface explains that registration must happen before auto-retirement.
- **Updated decision Nov 20:** An unconverted guest is retired automatically at the 14-day deadline (worker checks every minute); already-started/completed matches and historical results are not rewritten. Once `retired_at` is set, the same guest can no longer convert. The user can create a new permanent account instead. A physical Auth/player deletion requires a separate archival and foreign-key preservation solution, because direct Auth deletion cascades the player and nulls historical match participants/winners.
- Do not allow recurring guest signup/reset to extend the same identity's guest trial.

## 4. Permanent conversion and navigation

- Keep a persistent, clearly visible **Register / Save My Progress** CTA in the **game header action area**, near notifications/settings, on desktop **and** mobile. It should be absent for normal registered users and present for test players during their 14-day window.
- Guest conversion can use a password/email account, **Google** once H03 is verified/activated, or another supported provider later.
- The account link must happen against the **same authenticated guest user identity**, keeping the original user/player identifiers and data relations whenever possible. Never move progress by trusting email, a URL/user-supplied player ID, or a manually rewritten ownership field.
- Preserve **player appearance, country, name, ranking points/position, training, tournaments/results, finance, equipment, staff, sponsor contracts, notifications and Premium entitlement history** that are legitimately allowed during guest testing.
- If social sign-in is configured with an email already attached to another game account, **do not automatically merge** two accounts. Provide an explicit conflict/recovery path to avoid progress loss, duplicates or reward abuse.
- Conversion is available throughout the 14-day trial and only until automated retirement. After the worker marks the unconverted guest retired, the old player's future commitments are withdrawn and cannot be recovered via same-identity registration.

## 5. Premium trial and economy protection

- Every **eligible first-time guest identity** starts with the same **7-day Premium trial** as a regular new player, beginning at guest creation.
- Guest Premium ends at day 7 regardless of whether the guest continues as a test player for 14 days.
- **Do not start a second 7-day Premium trial on conversion.** Trial history and one-time eligibility must follow the same linked identity.
- Review the existing 20-coin signup welcome grant, referral rewards and payment flows. Do not give repeat grants through guest creation or conversion. Define the exact one-time welcome-coin policy separately before enabling Guest Mode.
- Premium trial issuance, expiry and guest eligibility must be enforced by the database/backend rather than UI hiding alone.

## 6. Technical gates before enabling

- Supabase anonymous-account identities are not a separate PostgreSQL `guest` role. Ensure every privileged gameplay RPC/RLS policy distinguishes an anonymous guest from a permanently linked account using server-trusted Auth state. Do not treat `TO authenticated` alone as permanent-user authorization.
- Separate guest creation/player-profile flow from regular email registration. Ensure no accidental official tournament entries or duplicate profile creation.
- Add abuse defenses: prevent limitless coin/Premium trial farming, reserve appropriate rate limits and identity controls, protect admin functions, and test new-identity creation on different browsers/devices. Avoid claims that browser fingerprinting can guarantee uniqueness.
- Do not activate Guest Mode until server-side expiry, conversion, reward fairness, ranking and tournament gates pass tests.
- Test time boundaries: just before day 7, at day 7; just before day 14, at day 14; conversion while active, at expiry before retirement, and blocked after retirement; repeated login/refresh/session recovery; Google and password identity linking; mobile header CTA.
- Validate what happens when the user clears their browser or switches devices before registration — anonymous test progress may be unrecoverable until linked. Explain this risk plainly within the game.

## 7. Proposed entry experience

**Homepage:** `Try as Test Player` (no email) beside `Create Account`.

**Test setup:** `Player Name` → `Country` → `Appearance` → `Start Testing`.

**Game header:** `Test Player · N days left` + persistent `Register · Save Progress` CTA.

**7-day Premium:** existing Premium UI shows trial end date. After day 7, Premium ends without affecting 14-day test access.

**Day 14 expiry:** gameplay ends and the backend automatically retires an unconverted guest, withdrawing tournament applications/entries and resolving not-started scheduled matches by walkover for an eligible opponent. If the worker has not yet retired the account, the registration page may still offer conversion; afterward it instead offers a new permanent account. Registration before day 14 is the reliable way to preserve progress.

**After account linking:** guest marker and register CTA disappear. Same tennis career continues, no duplicated player or repeated Premium trial.

## Existing code to reuse or inspect

- `src/components/layout/GameHeader.tsx` already contains the player identity, ranking/flag, notification, Premium and settings action area. Put the Register CTA there without displacing necessary controls.
- `src/components/layout/GameSidebar.tsx` provides mobile navigation; show conversion CTA on narrow screens even if header action area collapses.
- Regular new-player creation currently lives behind `/create-player` and `RequireNoPlayer`; create an appropriately authorized guest setup route or gated variant of the existing flow.
- `player_current_rank_position_v1` supplies rank for the header: adapt relevant ranking queries consistently for zero-point guest placement, not the display alone.
- Existing Helios H06 optional birth date and H03 OAuth provider readiness work should remain compatible.
- Do not change the launch clock or current registration gate as part of this specification.

## Development checklist

- [ ] H01A Guest identity and securely gated entry
- [ ] H01B Required player name/country/appearance; city omitted
- [ ] H01C Start last with zero points and correct label
- [ ] H01D Server-enforced 14-day gameplay window and expiry modal
- [ ] H02A Permanent visible header/mobile Register CTA
- [ ] H02B Conversion to email/password, Google (when enabled), other providers later
- [ ] H02C Retain identity/player/progress and safely handle account conflicts
- [ ] H08A 7-day Premium at guest start, never repeated at conversion
- [ ] H08B Welcome coin, reward and abuse safeguards
- [ ] H08C Official tournament participation, role/RLS and expiry test coverage
- [ ] Production and authenticated browser verification before enablement

**Open policy decisions:** physical erasure of retired Auth/player data while retaining historical tournament result consistency; detailed access to official ranked tournaments during guest trial; one-time welcome-coin eligibility for guests vs on conversion. These are implementation safeguards, not permission to invent policy.
