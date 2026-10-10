# Italian localization rollout — in progress

Source language: English (`en`). Target language: Italian, `it-IT`.

## Current audited status (10 October 2026)

- English source entries: **5126**
- Italian entries translated: **2275** (**44.4%**)
- English entries not yet translated into Italian: **2851**
- Italian keys not found in English: **0**
- Dynamic `{{placeholder}}` mismatches in translated entries: **0**
- Italian resources registered in `src/i18n/index.ts`: **yes**
- Italian enabled for players: **no — intentionally held behind the QA gate**
- Browser and production-build QA: **not yet run on the complete Italian locale**.

## Translated sections

- `common`
- `nav`
- `header`
- `footer`
- `settings`
- `marketing`
- `home`
- `terminology`
- `createPlayer`
- `authPages`
- `auth`
- `notifications`
- `skillsPage`
- `overviewPage`
- `statisticsPage`
- `rankingsPage`
- `inbox`
- `manual`
- `tutorial`
- `publicReview`
- `referralLanding`
- `commercePage`
- `referrals`
- `calendarPage`
- `healthPage`
- `financePage`
- `financeSponsorPage`
- `supportPages`
- `tennisClubPage`
- `playerAccountPage`

## Sections still requiring Italian strings

- `tournamentDoublesPage`
- `schedulePage`
- `playerProfilePage`
- `equipmentPage`
- `tournamentPage`
- `privateLifePage`
- `nationalTeamPage`
- `trainingPage`
- `staffPage`
- `tacticEducation`

## Production acceptance criteria

1. Reach 100% source-key parity. Do not fill untranslated Italian keys with unchanged English just to pass count checks.
2. Preserve every interpolation variable and arrays of localized content.
3. Translate all tutorial/manual **content**, not only their page labels; check server-generated descriptions and notifications as well.
4. Check Italian grammar, singular/plural, number/date/currency formats, and tennis terminology (classifica, tabellone, qualificazioni, servizio, diritto, rovescio, infortunio, montepremi).
5. Review navigation, modals and dense tables on mobile for clipping and overflow; keep the established homepage font scale consistent with Serbian.
6. Run production build and desktop/mobile end-to-end review.
7. Only then add `it` to `ENABLED_LOCALES` and make it selectable for all players.

Existing English, Serbian, German and Spanish packs must remain unchanged.
