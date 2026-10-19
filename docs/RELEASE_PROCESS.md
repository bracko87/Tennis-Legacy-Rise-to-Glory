# Controlled GitHub release workflow — Tennis Legacy

## Objective

Reduce paid GitHub Actions usage while retaining production validation and deployment from GitHub.

## Everyday development

- **Default branch for new code changes: `staging`, not `main`.** This applies to teammates and coding assistants.
- Changes can be pushed to `staging` as often as needed; ordinary staging pushes do not trigger the production GitHub Actions jobs.
- Verify changes locally as needed: `npm ci`, `npm run check:pt`, `npm run check:preferences`, `npm run build`. This is not a substitute for CI.
- Do **not** enable Netlify production deployment from `staging`. Production stays on `main`.

## Controlled releases

- **Two preferred release windows each day: morning and evening, Europe/Berlin.** These are review windows, not scheduled automatic merges.
- At a release window, open a pull request **`staging` → `main`**, check the diff and run the single consolidated PR validation job.
- Merge only after checks pass and the intended release is ready. A merge creates one production push to `main`, triggering one consolidated GitHub Actions validation job. Netlify can continue deploying from `main`.
- Keep the pull request closed between release windows where practical: an open staging PR will automatically validate new staging commits and use Actions minutes.
- Urgent critical bugfixes can follow the same PR process outside a window. Do not silently bypass review if a check fails.
- **Never automatically merge, schedule deployments, or auto-push code to main.**

## How minutes are saved

- One consolidated CI workflow validates Portuguese coverage, Preferences localization, production build, and the CPX Earn Free Coins output.
- The three specialized validation workflows are retained, but are **manual (`workflow_dispatch`) only**. Run them for isolated troubleshooting when needed.
- Concurrency cancels superseded runs for the same ref. Production build has a maximum 15-minute timeout.
- Changes only to Markdown/docs skip the main-branch push validation; PR validation always runs.
- Frequent direct pushes to `main` from other tools or assistants **are still possible**. This workflow does not technically block those pushes. If you need enforcement, enable a `main` branch ruleset/branch protection in GitHub settings (availability depends on the plan), restricting direct pushes and requiring PR checks.

## Budget and safety

- This policy limits CI executions, not GitHub API commits directly.
- GitHub Actions allowances apply to billable runners in private repositories. A 2,000-minute allowance is monthly, not daily.
- GitHub's actual billing budget is separate. Set a suitable spending cap at https://github.com/settings/billing/budgets.
- If free Actions minutes are exhausted, PR checks can be blocked; do not merge an unvalidated release just to bypass usage limits.
- Before any code task, explicitly tell the coding assistant to use `staging` and batch release changes.
