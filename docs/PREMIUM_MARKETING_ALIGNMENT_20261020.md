# Free vs Premium website copy alignment — 2026-10-20

## Implemented surfaces in source on main
1. **Public homepage:** prominent, indexed `#premium-features` Free/Premium section immediately after core gameplay features. The marketing header includes a Premium anchor link.
2. **Public footer pricing dialog:** the same module descriptions beneath the existing monthly, 3-month and annual plan cards; dialog is scrollable on small screens.
3. **Signed-in Pro Packages:** the same full benefits guide above the existing Free-versus-Premium checkmark table. The leading offer summary is shortened rather than listing the modules twice, and the checkmark table additionally includes Development Outlook, Training Optimization, Ranking Protection and Private Life.

All three consumers use `PremiumBenefitsGuide` and one source of eight-language descriptions (`premiumFeatureGuideI18n`, EN/SR/DE/ES/FR/IT/RU/PT), so package descriptions cannot silently diverge. The catalogue includes exactly 11 delivered intelligence modules. Development Outlook is explained with Player Development; Training Optimization is explained with Training Effectiveness. Ranking Protection and Private Life are listed as additional Premium features.

**Not advertised:** Premium Convenience Tools (saved comparisons/custom dashboard reports/advanced alerts) is unimplemented. No claim of guaranteed sporting outcomes. Free training, official tournaments, rankings, match results, equipment, staff and finance remain visibly Free. Premium membership, trial access and optional coin payments are clearly separated.

The existing checkout, subscription costs, purchase flows and entitlement checks are untouched. Copy and UI only. Changes target `staging`, not production.

## Validation
- Verified every delivered ID has a title mapping and substantive description in all eight game languages.
- Added regression `tests/premiumFeatureGuide.test.mjs` for module count, translation completeness and locale fallback.
- Final QA still needs: `npm ci`, `npm run check:pt`, `npm run check:preferences`, `npm run build`, and browser review of homepage, public pricing dialog, signed-in paid/trial/Free packages page on desktop/mobile in all eight languages. GitHub source commits do not authorize Netlify deployment.
- `main` release must follow approved manual batched staging→main validation; do not merge solely on these copy checks.
