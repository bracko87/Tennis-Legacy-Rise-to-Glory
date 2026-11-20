# Project Helios H03 — Google Sign-In activation checklist (Tennis Legacy only)

**Current status: disabled.** The application code and database identity support are prepared, but the provider has **not** been verified configured or tested. Keep `registration_control.google_oauth_enabled = false` until this checklist passes.

## Provider setup — credentials must stay private

1. In Google Cloud Console, create/configure an OAuth 2.0 web application for Tennis Legacy. Review the consent screen, authorized domains, test/published status and project ownership.
2. For Supabase Tennis project `cwfznmroiqcyhfkfcrow`, authorize the Supabase OAuth callback URL with Google: `https://cwfznmroiqcyhfkfcrow.supabase.co/auth/v1/callback`. Verify it against the project Dashboard before saving.
3. In **Supabase Dashboard → Authentication → Providers → Google**, enter the Google OAuth Client ID and **secret**. Do not put the secret in a GitHub file, public client, URL, or chat.
4. In **Supabase Dashboard → Authentication → URL Configuration**, allow exactly the official redirect `https://tennislegacygame.com/create-player` (plus a separately controlled staging callback if used), and check the Site URL. Confirm any `www` host redirect behavior.
5. Do not turn on the game's Google option yet. Ensure the underlying provider is configured and complete the tests below.

## Acceptance tests (required before launch)

- Existing password account with a **verified matching Google email** signs in using the **same `auth.users.id`**, with one profile, one existing human tennis player and intact career, finances, Premium, staff and equipment. Account identity linking follows Supabase's provider-side logic; do not merge records based only on browser-supplied email.
- New Google user gets one `auth.users` account, a unique generated `google_<16 hex>` login handle, a profile with null birth date and no birthday reward, then is directed to Create Player exactly once.
- Repeating Google login doesn't award multiple signup coins/trials, duplicate players or referrals.
- Signing in while public registration is closed must continue to work for **existing** accounts; a new account must be blocked by the existing server-side signup gate.
- Password login, referrals/invitations, email verification, mobile Safari/Chrome, popup restrictions, logout and expired sessions still behave correctly.
- Verify `/create-player` redirects an existing player to their existing overview without a create-player prompt; newly registered users arrive at player creation.
- Ensure only `https://tennislegacygame.com` (and any explicitly trusted official variant) is used for `redirectTo`, and authorized URLs aren't wildcarded broadly.
- Test with a dedicated staging Google identity, not a real customer's account. Check OAuth errors never reveal credentials.

## Enablement

Only after provider configuration and these checks pass, an authorized operator may set `public.registration_control.google_oauth_enabled=true` for the singleton row using the secured database administration channel. The public read-only `get_public_google_oauth_status_v1()` function controls whether the login and register buttons appear. To roll back visibility, return the flag to `false`.

This switch **hides UI only**. It is not a substitute for disabling the OAuth provider in Supabase when emergency shutdown is necessary. Audit source-table access, provider-side policies and existing onboarding credits before activation.

## Limitations

H03 does not yet implement explicit authenticated `linkIdentity()` or unlinking management. Supabase's automatic linking for verified matching email addresses must be tested in the live configuration. Invitation and referral registrations retain the current email/password path until their rewards/attribution are implemented securely for OAuth. The Google provider is not verified enabled, and the end-to-end flow has not been executed.
