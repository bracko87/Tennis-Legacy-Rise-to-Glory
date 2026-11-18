# Steam release checklist — Tennis Legacy
Updated 2026-11-18
Status: IN PREPARATION, NOT STEAM-READY.

## Steamworks account — requires publisher action

- [ ] Open https://partner.steamgames.com/ and sign in with your own Steam account.
- [ ] Complete the partner onboarding agreements, legal business information, tax and banking setup.
- [ ] Pay the $100 Steam Direct app fee, then retrieve your **real** Steam App ID.
- [ ] Confirm required wait/review dates in your own Steamworks dashboard. Steam docs currently disagree between 21/30 days, so plan conservatively for at least 30 days.
- [ ] Select **Free to Play**, Windows, online multiplayer and correct supported languages.
- [ ] Complete Steam's content survey, including candid AI-content, mature-content, data/privacy and regional ratings disclosures.
- [ ] Add the Steam App ID to local development configuration (not a fake ID).

## Store page assets — must use real media, not invented gameplay

- [ ] Header Capsule: 920 x 430 PNG/JPG, title clearly readable.
- [ ] Small Capsule: 462 x 174 PNG/JPG, title clearly readable.
- [ ] Main Capsule: 1232 x 706 PNG/JPG, title clearly readable.
- [ ] Vertical Capsule: 748 x 896 PNG/JPG, title clearly readable.
- [ ] Steam library assets and community assets using the templates in Steamworks.
- [ ] At least several genuine gameplay screenshots at 1920 x 1080 or larger, 16:9. Good candidates: player creation, dashboard, rankings, calendar, tournament draws, staff/sponsors, private life.
- [ ] Source trailer MP4 exported and reviewed for the Steam upload (YouTube URL alone is not the Steam video upload).
- [ ] Check rights/licences for any people, logos, music, AI-created artwork, text or sound in the game and marketing.
- [ ] Enter reviewed store copy from STORE_COPY.md.

## Technical blockers — do not submit build until closed

- [ ] **STEAM-01** Native Steamworks initialization and identity/session ticket in packaged Windows app.
- [ ] **STEAM-02** Backend verification of Steam identity/ownership using official API, with user-account linking that protects existing Tennis Legacy users.
- [ ] **STEAM-03** Steam purchase route: Steam Wallet microtransactions or an approved Steam purchasing solution, and server-side receipts, refunds, entitlements. Existing Stripe links must not be the purchase route shown to Steam customers in the app.
- [ ] **STEAM-04** Review the entire purchase interface, Premium, coins, subscriptions, referrals and offers for Steam compliance; ensure Steam purchasers are not directed to Stripe.
- [ ] **STEAM-05** Login, signup, recovery and account linking end-to-end, including email confirmation/deep links launched from an installed Steam build.
- [ ] **STEAM-06** Package and run actual Steamworks SDK-enabled Windows build, Steam overlay, Steam-client launch and application exit.
- [ ] **STEAM-07** Ensure an outage/restart/error screen is useful even when the online game server is unavailable.
- [ ] **STEAM-08** Confirm Valve is satisfied that this installed online game is sufficiently functional as a Steam product, not merely a shortcut to a website.
- [ ] **STEAM-09** Stage private Steam build and complete release checklist review on a test account.
- [ ] **STEAM-10** Multiplayer and Premium security/regression tests, no account crossovers, no duplicate charges or trials.
- [ ] **STEAM-11** Decide whether Steam support will be Windows-only initially; Linux is already available as a separate direct download but is not validated for Steam distribution.
- [ ] **STEAM-12** Verify Steam age rating & Germany compliance if game is distributed there.

## Release steps — only once above items are cleared

- [ ] Submit page for Valve review, make public Coming Soon.
- [ ] Leave Coming Soon visible for the required minimum period (at least 2 weeks).
- [ ] Publish Steam link on tennislegacygame.com only when there is a real approved store URL. Keep the current disabled Steam button until then.
- [ ] Submit packaged game build for Valve review.
- [ ] Publish release through Steamworks when approved.
- [ ] Monitor wishlists, impressions, installs, account linking, completed registrations, active players, retention and refund/checkout failures.

## Do not change during Steam preparation

No live multiplayer state reset, game-clock modification, Netlify deploy, Stripe settings change or Supabase production migration is authorized by this checklist.
