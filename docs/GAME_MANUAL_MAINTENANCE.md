# Tennis Legacy — Full Game Manual Maintenance

Status: **Production reference**
Source language: **English**
Current version: **1.0**
Current chapter count: **33**

## Principle

The Full Game Manual documents only currently implemented Tennis Legacy behavior.
Planned or proposed systems must not be described as active gameplay.

When a production rule changes, the related manual chapter is part of the same
feature change rather than a separate documentation backlog item.

## Source files

The manual uses structured content rather than one monolithic page:

- `src/content/manual/types.ts`
- `src/content/manual/index.ts`
- `src/content/manual/manual.en.core.ts`
- `src/content/manual/manual.en.competition.ts`
- `src/content/manual/manual.en.career.ts`

The in-game reader is:

- `src/pages/manager/GameManual.tsx`
- `src/styles/game-manual.css`

The downloadable PDF is generated in the browser from the same manual document:

- `src/lib/manualPdf.ts`

This keeps the PDF and in-game manual on one content source and avoids a stale
static PDF drifting behind the game.

## Adding or changing a chapter

1. Update the relevant English source file.
2. Keep a stable chapter `id` whenever possible so direct manual links remain valid.
3. Add direct game-page links where a relevant page exists.
4. Update the runtime chapter count only when the number of chapters changes.
5. Verify manual search finds important page/rule terminology.
6. Verify Previous / Next chapter navigation.
7. Verify mobile layout for the changed content, especially wide tables.
8. Download the PDF from the manual and confirm the changed section appears.
9. Run the Game Manual System Health check.
10. Confirm the manual processes remain visible in Control Center.

## Localization

English is the source edition.

A future locale should mirror the same `GameManualDocument` structure and stable
chapter IDs, for example:

- `manual.de.core.ts`
- `manual.sr.core.ts`

Then register the locale in `src/content/manual/index.ts`.

Do not fork gameplay rules between translations. Update English first, then
translate the same approved behavior.

## System Health

Registered processes:

- `check:game_manual_publishing`
- `cron:tennis-game-manual-health-v1`

The database publication contract verifies:

- manual active state
- source locale
- manual version
- expected chapter count
- in-game manual route
- Help Center route
- PDF download route

A documentation publishing issue is a **Warning**, not a gameplay-critical alert.
Build/deployment health remains responsible for whether a static front-end bundle
itself is reachable.
