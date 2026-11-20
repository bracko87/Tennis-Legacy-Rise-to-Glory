# Project Helios H02 — Guest Registration and Progress Preservation

Status: implemented in code with the guest rollout switch OFF.

**Updated guest-removal rule (Nov 20):** conversion must finish before the unconverted guest's automatic retirement at the 14-day boundary. After retirement, the player leaves future competitions, pending matches are handled by walkover, the original guest identity cannot be converted and the player is hidden from active rankings. Until a safe historical archive exists, the original Auth/player records remain in the database rather than being physically hard-deleted. The email/Google conversion pathways require end-to-end testing and verified Supabase Auth configuration before Guest Mode can be enabled.

## Same-identity conversion

Supabase anonymous accounts are real `auth.users` rows. Preserve the same row and UUID when upgrading the user's authentication method. Player ownership, ranking records, money, equipment, staff, sponsor contracts and canonical Premium trials all continue using that same UUID or the same player record. Do **not** call `signUp()`, `signInWithOAuth()`, generate a second player, or manually copy owner IDs during conversion.

**Email/password:** With the original anonymous session still signed in, call `supabase.auth.updateUser({email}, {emailRedirectTo: '<origin>/guest/register'})`. The user must verify the email link and return in the original browser. Then, **only after email verification**, call `supabase.auth.updateUser({password})`. The conversion is recorded when Supabase switches that original `auth.users.is_anonymous` flag to false. Do not store passwords, reveal emails via the status RPC, or issue signup coins or new Premium trials.

**Google:** With the original guest session signed in, call `supabase.auth.linkIdentity({provider:'google',options:{redirectTo:'<origin>/guest/register'}})`. Do not use the standalone Google login method. Provider manual identity linking must be enabled, its OAuth callback and app redirect allowlists must be configured, and existing-email account conflicts must be tested. Google linking remains UI-gated by H03 Google readiness (currently disabled).

**Existing account conflict:** If the email/Google identity belongs to another account, no two-player merge is attempted. Keep the guest session and present the original provider error. Recover manually through a documented support process; do not overwrite user IDs or email identity ownership.

## User experience

- During the 14-day trial, show `Register · Save Progress` in the game header and mobile sidebar. Show remaining days when current server-trial data is available.
- `/guest/register` is an authenticated page, not the ordinary anonymous-only `/register` wizard.
- At 14 days, game pages display an unclosable expiry overlay. The server retires an unconverted guest automatically (checked minutely), withdrawing future tournament entries and awarding opponent walkovers in unstarted scheduled matches. The registration page shows whether retirement has occurred; registration is no longer possible once it has.
- Guests can register before retirement; once the automatic worker has marked the guest retired, that same player cannot be converted. Earlier Premium timestamps never change during legitimate conversion. Once Supabase reports a nonanonymous user, the guest CTA disappears.
- Account deletion/recovery and support actions should remain available despite guest expiry.
- Avoid logging out, clearing browser data, or switching devices before verified conversion; doing so can make unlinked guest progress unrecoverable.

## Pre-activation checks

- [ ] Verify Supabase **Allow anonymous sign-ins** enabled in Auth dashboard and H01 launch gate still OFF until remaining tests pass.
- [ ] Add the exact `https://tennislegacygame.com/guest/register` email/OAuth redirect to Supabase URL allowlist and verify official Site URL.
- [ ] For Google linking, configure/verify Google OAuth provider and manual identity linking in Supabase Authentication settings; verify Google authorized callback and same-user identity.
- [ ] Validate old and new `auth.users.id` unchanged after email verify, password added, and after Google link. Ensure player ID unchanged and no duplicate players.
- [ ] Confirm existing rank, money, equipment, staff, sponsor offers, Premium grant date/expiry, taxes and ongoing tournament commitments are unchanged.
- [ ] Confirm no extra 20-coin signup reward, referral/invite reward, birthday gift, seven-day Premium or second guest period after conversion.
- [ ] Test active day 1, day 7 Premium expiry, just before day 14 and worker retirement at day 14. Verify conversion is blocked after retirement while a fresh account can be created, with no repeated Premium or signup grant.
- [ ] Verify expired guest can't bypass the UI by calling uncovered database RPCs, storage and edge functions.
- [ ] Test page reload, verification from mobile browser, email not received, email already used, Google account already linked, provider error, and browser data loss warning.
- [ ] Test persistent CTA visibility on small screens, collapsed sidebar and large desktop header.
- [ ] Decide one-time welcome-coin timing and unfinished guest retention policy before enabling.
- [ ] Verify no scheduled/not-started singles or doubles match remains playable for a retired guest, eligible opponent receives walkover, and prior completed match results persist.
- [ ] Design archival-preserving physical deletion for retired accounts; cascade deletion of auth.users would otherwise destroy player references and completed match history.
- [ ] Test server-side ranking bottom placement and tournament fairness (currently pending).

The new server conversion status function is current-user-only and returns no email, password, identifiers or auth secrets. Database flags are authoritative; front-end countdown and expiry modal are for guidance only.

**References:** Supabase documentation for [anonymous sign-ins](https://supabase.com/docs/guides/auth/auth-anonymous) and [identity linking](https://supabase.com/docs/guides/auth/auth-identity-linking).
