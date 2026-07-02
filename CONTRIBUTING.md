# Contributing

Thanks for contributing to Bloccpay. This file covers conventions that apply across all our repositories.

## Getting help

- **Quick questions:** Slack.
- **Discussion that needs a durable record:** open a `Question / Discussion` issue.
- **Security issues:** see [SECURITY.md](./SECURITY.md).

## Filing issues

Every repository has issue templates. When you open a new issue:

- Pick the type that matches the work (Bug, Task, Feature, Chore, Design, Spike, Question, etc.)
- Fill in the required fields — they exist because the team keeps hitting the same gaps.
- Check one or more workstream boxes (`eng`, `devops`, `product`, `design`, `marketing`, `ops`) so the issue routes correctly.
- Link related issues and PRs using `#N` for same-repo refs and `org/repo#N` for cross-repo.

Templates live in `.github/ISSUE_TEMPLATE/` of each repo — the org falls back to defaults in this repo when a repo doesn't override.

## Branch and commit conventions

- Branch names: `<type>/<short-slug>` — e.g. `fix/payroll-approval-email-broken-link`, `feat/dojah-liveness`, `chore/rename-labels`.
- Commit messages: conventional-style prefix — `fix:`, `feat:`, `chore:`, `refactor:`, `docs:`, `test:`, `wip:`. Keep the subject under ~70 chars.
- One logical change per PR. If a change touches multiple concerns, split it.

## Pull requests

- **Base branch:** most repos have `dev` as the default working branch and `main` as the deployable one. Confirm per-repo (see repo README or `.github/workflows`).
- **Body:** short summary + link back to the parent issue with `Fixes #N` or `Fixes org/repo#N`.
- **Test plan:** what you did to verify. Screenshots for UI, curl commands for API, log excerpts for backend.
- **Reviewer:** at least one. For infra/security changes, more.

## Cross-repo work

Some work spans multiple repos (frontend + backend, or backend + cms). Convention:

- Open the parent bug/task/feature in the repo where the work originates or where the customer sees it.
- Task-list child PRs in the parent body: `- [ ] #<pr>` for same-repo, `- [ ] org/repo#<pr>` for cross-repo.
- Each child PR references the parent with `Fixes org/repo#<parent>`.
- Parent closes only after all children merge.

Example: parent bug in `BloccPay-Backend-V1#759`, backend PR `#760`, frontend PR `bloccpay-web-app#391`.

## Labels

- **Type labels** are applied by issue templates: `bug`, `task`, `feature`, `chore`, `design`, `spike`, `question`, `compliance`, `hiring`, `partnerships`.
- **Workstream labels** are applied by the `apply-workstream-labels` workflow based on your template checkbox selection: `eng`, `devops`, `product`, `design`, `marketing`, `ops`.
- **Priority** is a project-board field, not a label — set it on [Bloccpay Development](https://github.com/orgs/BloccPay-org/projects/2) directly.

## Project board

All issues go on [project #2 "Bloccpay Development"](https://github.com/orgs/BloccPay-org/projects/2). Status, Sprint, and Priority live there.

