# Tennis Legacy — final mobile-phone audit

Tracking issue: https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/issues/11

## Truthful status — 2026-10-23
The source-level audit has begun. The route inventory in `docs/mobile-route-audit.json` was extracted from the actual `src/App.tsx`, including anonymous and admin-only routes. **No route is considered passed simply because it exists or builds.** Device/interactive testing remains pending; do not close Issue #11 or call this production-mobile-ready without it.

Run `npm run check:mobile-routes` to detect drift whenever routes are added/removed. CI also checks inventory parity. Each route/workflow in the JSON uses `pending_device_validation`, `blocked`, `passed` or `not_applicable`. Mark `passed` only after actual mobile testing, with evidence linked to Issue #11.

## Test procedure
For every applicable route and nested tab, test widths 320, 360, 375, 390, 414, 430px in portrait; use landscape for draw, charts, calendar, payment and forms. Validate iPhone Safari and Android Chrome with real or emulated touch/keyboard. Repeat representative long-label screens with German, Serbian, French and Russian.

1. Inspect actual `document.documentElement.scrollWidth` against `window.innerWidth`; overflow belonging to a table/draw must stay in its own scroller.
2. Use touch, not hover, to open tabs, tooltips, drawers, selects and chart controls. Confirm buttons/close targets are reachable and labels don't overlap.
3. Traverse every action through confirmation, failed/error state and return navigation. Check under keyboard-open viewport and slow network.
4. For singles/doubles tournament draws verify visible round selection, highlighted own matches, readable scores and later-round access.
5. For all custom dialogs verify scroll lock, backdrop/Escape dismissal where safe, sticky confirmation actions and iPhone safe areas.
6. Confirm photos lazy-load and large sets of notifications, ranking rows and assets remain responsive on mid-range devices.

## Known-source audit findings
- A persisted collapsed desktop sidebar could make an opened mobile drawer icon-only. The first mobile foundations change separates these states.
- The generic header mobile CSS hides direct child spans, potentially hiding the unread badge. Scoped badge display was added.
- The shared Radix dialog previously had no viewport-height scroll cap. The first change adds one.
- GameConfirmDialog has mobile layout rules, but its actions and close area required stronger touch sizing and safe-area treatment.
- Tournament draws have specialized custom CSS; all match-round UX and real device touch behavior still require page-specific testing. Do not mark these verified on source inspection alone.

## Gate
Keep Netlify builds stopped. Follow current `main` AGENTS.md and `docs/RELEASE_PROCESS.md`; no deployment or backend/payment changes as part of source testing.
