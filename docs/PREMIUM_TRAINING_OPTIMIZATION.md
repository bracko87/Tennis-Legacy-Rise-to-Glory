# Premium Training Optimization — extension completion (2026-10-20)

## Scope
- Embedded below the existing Training Effectiveness history inside its collapsed-by-default Premium panel on Skills.
- No new Premium card on Skills, no changes to Free training, no gameplay writes and no new Supabase endpoint.
- Uses the pre-existing owned-player Premium `get_premium_training_effectiveness_v1` report plus current `player_skills` already loaded by Skills.
- No real-world dates: report grouping/trends use recorded in-game seasons and weeks.
- Works with zero historical sessions by offering an advisory focus rotation and an honest empty-evidence state.

## Functionality
- Interactive target attribute (13 trainable skills), current rating, a one-to-four-session advisory rotation and priority/balanced alternatives. The secondary skill is the lowest observed attribute in the opposite technical/physical group.
- Comparison of recorded **regular** development sessions by their actual user-selected focus, with selected-skill progress/session, all fractional progress/session and mean engine efficiency. Camp days and rest are intentionally excluded from like-for-like choice comparison. Each cohort shows its real sample size.
- At least three real regular sessions per focus are required before showing a supported cross-focus comparison. Small groups are labelled.
- Two equal-sized groups of six recorded sessions and at least three distinct **game weeks** are required for recent/previous comparison. This is descriptive, not a prediction, and does not equate correlation to causation.
- Warnings for high current fatigue, near-cap target skills and the 120-session API history limit. All eight site languages included (EN, DE, SR, ES, FR, IT, RU, PT).
- Opens the Free regular Training planner at `/game/training?view=regular`; never auto-saves or overrides it.

## Regression coverage
`tests/trainingOptimizationModel.test.mjs` covers:
1. Excluding camps/invalid focuses and preserving cohort averages.
2. Requiring repeated evidence for cross-focus comparisons.
3. In-game-week-only, 12-regular-session trend threshold.
4. Weakness selection, focused/balanced rotations, short-week complement and four-session cap.

Run with Node 22+: `node --experimental-strip-types --test tests/trainingOptimizationModel.test.mjs`.

## Release validation still required
- Run `npm ci`, `npm run check:pt`, `npm run check:preferences` and `npm run build` on a complete checkout; review desktop/mobile Skills layouts in each locale.
- Test Free, trial and paid access; test careers with 0, 1–2, 3+ and 12+ regular sessions and mixed camps; confirm player switching refreshes data.
- Review `staging` in localhost, then include in a manually validated batched `staging` → `main` release. No production release is authorized by this feature PR.
