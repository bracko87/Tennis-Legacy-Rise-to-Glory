# Steam technical integration — assessment and design

Existing code inspected on 2026-11-18:
- \`desktop/main.cjs\` loads \`https://www.tennislegacygame.com/\` in Electron and opens approved external HTTP(S)/mailto URLs.
- \`src/pages/manager/ProPackages.tsx\` currently creates authenticated checkout intents and sends users to Stripe Payment Links / Stripe customer portal.
- \`src/pages/auth/Login.tsx\` uses Supabase Auth email/password.
- \`src/pages/auth/Register.tsx\` creates Supabase email accounts, including email confirmation; current email redirects may require special desktop behavior.
- Steam app build does not yet initialize Steamworks; SteamID is not verified by the server.
- Desktop installer v0.1.1 is a **direct-download preview**, not a Steam build.

## Proposed architecture

Steam client launch
  -> Native Steamworks initialization with real AppID
  -> Steam user session ticket
  -> HTTPS to a dedicated authenticated server endpoint
  -> Server-side Steam ticket verification (ISteamUserAuth/AuthenticateUserTicket)
  -> Allow existing Tennis Legacy account to link ONLY after authenticated player consent
  -> Server stores unique SteamID/account binding, prevents impersonation or relinking to another account
  -> Game opens shared online multiplayer world under user's actual Tennis Legacy account

Premium purchase initiated from Steam client
  -> Steam-native wallet purchase request
  -> Trusted server receives/validates payment with Steam
  -> Server grants Premium according to validated purchase, with idempotency
  -> Reconciliation handles refunds/chargebacks/expiration
  -> Player's correct shared account receives entitlement

Direct website and direct-download desktop versions continue using their own existing authorized payment flows, while Steam installs use Steam purchasing. Product catalog/entitlement design must account for both without double charging.

## Non-negotiable security conditions

1. Never trust a SteamID, ownership flag, payment status or Premium entitlement submitted by a JavaScript client without trusted server verification.
2. Do not embed Steam publisher secrets, Steam Web API keys, Stripe secret keys or Supabase service role credentials in a game build.
3. Keep Steam accounts linked uniquely and avoid automatically merging unrelated profiles. Require account ownership and explicit confirmation.
4. Never grant Premium merely because the Steam overlay closed or a front-end redirect completed.
5. Do not use unapproved third-party checkout prompts for Steam customers; Steamworks requires use of the Steam microtransaction API for in-game purchases.
6. Do not modify multiplayer game-clock or reset data as part of packaging.
7. Reuse the owner-approved blue tennis-ball icon for Windows package.

## Development stages

1. **Staging rehearsal now:** package current Windows app *privately*, do not upload a public Steam build; verify size, files, icons and internet behavior. This still uses website login and checkout, therefore NOT ready for release.
2. **Steam auth:** obtain AppID, integrate Steamworks SDK and secure account linking.
3. **Steam payment:** implement verified Steam wallet purchases / entitlements and avoid external Stripe checkouts in the Steam app.
4. **Compatibility:** test Steam app login/logout/account switching, game loading, refunds, Premium cross-platform, server outage and updates.
5. **SteamPipe:** obtain the actual app and depot IDs from Steamworks and create release-specific VDF upload scripts locally. Do not commit publisher credentials or use fictitious IDs.
6. **Review:** send both store page and app build to Valve only after all blockers cleared.

## References
- https://partner.steamgames.com/doc/features/auth
- https://partner.steamgames.com/doc/features/microtransactions
- https://partner.steamgames.com/doc/store/review_process
- https://partner.steamgames.com/doc/gettingstarted/contentsurvey
