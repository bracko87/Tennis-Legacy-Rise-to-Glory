# Premium rollout proposals — Tennis Legacy

**Branch:** staging. **Status:** User review required after each small feature; do not treat this as approval of the overall Free/Premium business model.

## Step 0: Homepage Next Match layout (2026-10-19)

- Put the latest match's Tournament details link at the bottom of its card.
- Split the Next Match card: left side shows the next tournament logo, existing prize/points/draw/status data; right side mirrors Latest Match with the next opponent's flag, profile link and photo plus round/day.
- No fabricated score is shown before the match begins. If the next opponent is not scheduled, keep a waiting state.
- **Status:** committed on staging; browser build and layout review pending.

## Step 1: Statistics Intelligence (2026-10-19)

- A clearly marked *Premium preview* on the Statistics page compares completed-match win rate, aces per match and winners per match against the **currently selected world and period's displayed leaderboard sample**.
- The comparison excludes the current player from the peer aggregate. Denominators are total completed matches; no artificial average-of-averages.
- If a player isn't in the leaderboard sample, display the peer aggregate without inventing personal period-specific statistics. Explain that the sample is *not* the full population.
- Trial and paid Premium members can view this UI; Free members see a description and link to Pro Packages.
- **Important:** This is an experimental presentation-only split. `get_world_statistics_v1` still returns the existing information to all players, and all previously visible statistics and career data remain Free. **This is not an enforced backend paywall or final Premium business-model decision.**
- No gameplay effects, access to hidden player skills, ranking bonuses, or match calculation changes.
- English, Serbian, German strings added; other locale fallbacks follow the existing localization system.
- **Status:** committed on staging, awaiting user review and validation of the build, visual presentation, Free/Premium eligibility, and real sample results.

## After the first review

Do not build or restrict further premium features until user accepts or requests changes. If approved, decide exactly which *new* analytics require server-side entitlement checks while keeping official ranking and match statistics and core gameplay Free. Update all locales, manual, Premium page and marketing only after the complete access contract is approved.

## Development and release guardrails

- Never edit production `main` without a reviewed staging→main release.
- Run `npm run check:pt`, `npm run check:preferences`, `npm run build` before production release.
- Source-level checks are not a substitute for browser or CI validation.
