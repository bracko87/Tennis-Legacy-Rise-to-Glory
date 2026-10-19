# Agent instructions — Tennis Legacy: Rise to Glory

These repository instructions are the **source of truth for every coding assistant**, including ChatGPT conversations, Codex, and other connected agents. Read these before creating commits, editing workflow files, or proposing a release.

## Branch policy (effective 2026-10-19)

- **Development branch: `staging`.** Create all normal bug fixes, features, translations, and UI edits on `staging`, not `main`.
- **Production branch: `main`.** Netlify production stays on `main`.
- **Never push application changes directly to `main`** unless the user explicitly authorizes a break-glass emergency exception. Do not silently fall back to `main` if your tool defaults to the default branch: specify `branch: staging` or the equivalent for every write.
- Before editing, fetch and verify the remote branch state. If `staging` is behind `main`, synchronize safely without overwriting unmerged development. Do not force-push or reset away another assistant's changes.
- If your tool cannot target a nondefault branch, explain the limitation and do not make an unauthorized `main` write.

## Releases and tests

- Group completed changes into **two manual release windows per day** (morning/evening, Europe/Berlin), not automated time-based pushes. Emergency releases can happen outside those windows when validated.
- For a release, review a `staging` → `main` pull request, run the consolidated release validation, and merge **only after passing checks**. Never enable automatic merges or bypass a failed build to save minutes.
- Keep all critical tests: `npm run check:pt`, `npm run check:preferences`, `npm run build`, and the CPX integration assertion in the release workflow. Run local tests while staging changes; local builds do not consume GitHub Actions minutes.
- Do not open a persistent staging → main PR during frequent staging commits unless you intend each PR update to trigger billed CI.
- CI configuration is in `.github/workflows/`; the consolidated Tennis Legacy release workflow runs on main pushes and PRs targeting main. Specialist workflows are manual.
- Keep GitHub Actions use low: avoid unnecessary reruns, redundant workflows, and repeated small pushes to `main`. **Never drop validation to achieve savings.**

## Cross-chat rule

This policy applies to **every conversation or coding agent** working on this repository. Do not rely on an agent remembering an earlier chat: read this file and `docs/RELEASE_PROCESS.md` at the start of each task. ProPeloton Manager and Game Control Center have separate processes; do not apply this rule to them automatically.

The file is guidance, **not technical branch protection**. Repository admins should add GitHub branch rules/protection when available if direct pushes must be prevented.
