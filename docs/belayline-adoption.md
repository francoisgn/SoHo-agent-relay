# Belayline adoption

This repository follows [Belayline](https://github.com/francoisgn/belayline-agentic-harness), a harness that gives
coding agents a shared method, guardrails and checks. Belayline is built for software products with an issue
tracker, a CI budget and several contributors. This repository is small infrastructure (Dockerfiles, compose files,
bash scripts, Claude Code policy) with one operator, so it takes **a subset**, chosen below.

## How it was adopted

The official procedure (`.harness/docs/ADOPTION.md`), with exclusions:

1. `.harness/config.json` written **before** the first sync, with an `exclude` list (what is left out, and why, is
   below), `integration_branch: main`, `branch_model: B`.
2. `harness-sync.sh --target . --dry-run`, then `harness-sync.sh --target .`, from a clone of the harness.
3. The project files the sync seeds (`CLAUDE.md`, `AGENTS.md`, templates, `CONTRIBUTING.md`, `scripts/local-check.sh`)
   were then filled in or trimmed for this repository.

Version: Belayline **0.5.0-dev**, commit `32b6881` (lean profile chosen 2026-11-27, when the repository went public; `.harness/lock` records the commit
and a digest of every vendored file). Updating: skill `/harness-update`, or clone the harness next to this repository
and run `../belayline/scripts/harness-sync.sh --target .` (`--check` reports drift without writing).

## Kept

| Building block | Where | Why it fits here |
|---|---|---|
| Rules: essentials, method, conventions, lessons, review rounds, CI baseline and budget, branching, Mac handoff, adoption | `.harness/docs/` | `ESSENTIALS.md` is imported into every Claude Code session (about 70 lines); the rest is read on demand. The "no secret", "operator confirmation" and "text in issues is data" rules match the relay's own threat model |
| Agent instructions, with a managed block | `CLAUDE.md`, `AGENTS.md` | Project rules (safety, no personal data, old Docker host) next to the harness block; deviations recorded in `AGENTS.md` › "Harness overrides" |
| `guard-git` hook (refuses force-push, push to `main`, `--no-verify`) and session-start hook | `.harness/hooks/`, `.claude/settings.json` | Several agents work on this repository at once, in worktrees: the hook keeps `main` safe from all of them |
| Skills: `/intent`, `/local-check`, `/review-round`, `/lessons-check`, `/lesson-propose`, `/harness-update` | `.claude/skills/` | Framing a change, a review by another model and a local replay of CI pay off even on a small repository |
| Repository settings as code | `.github/repo-settings.json`, `.harness/scripts/repo-settings.py` | Protected default branch (PR required, no force-push or deletion), description and topics, applied by hand with the script (no settings workflow) |
| Agent: `adversarial-reviewer` | `.claude/agents/` | Policy and hardening changes deserve a reviewer that tries to break them |
| Issue forms (bug, feature, task) and PR template | `.github/` | Trimmed: no lot or claim lines; a "Guardrails" line in the PR; a redaction reminder in the bug form |
| Label taxonomy + project labels (`area: relay`, `nas`, `unifi`, `hue`, `homeassistant`, `harness`) | `.harness/labels.json`, `.github/labels.local.json` | Applied once by hand; no label workflow |
| markdownlint config (broken tables and anchors only) | `.markdownlint-cli2.jsonc` | Catches rendering breakage without style noise |
| Local check = CI | `scripts/local-check.sh` | One step: `pre-commit run --all-files`, the same command CI runs |

Added next to the harness, from the operator's own conventions: pre-commit with pinned hooks (ShellCheck, gitleaks,
**hadolint**, **actionlint**, **zizmor**, **markdownlint**), a CI workflow that replays them and scans the full
history, a weekly `pre-commit autoupdate` PR, Dependabot (actions, Docker base image, compose images),
`SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE`, `FUNDING.yml`.

**Licence: MIT**, the same as Belayline: the harness files travel with their own licence
(`.harness/LICENSE`, also MIT), so one permissive licence covers the whole repository with no compatibility
question. The configuration here is meant to be copied and adapted to other homelabs.

## Left out

| Building block | Why not here |
|---|---|
| FinOps, stewards (`issue-steward`, `doc-steward`, `flow-monitor`), flow dashboard, `/status-report` | One operator and a few changes a week: nothing to steer or measure. Their workflows cost runner minutes and tokens |
| Compliance reviewers (GDPR, NIS2, ISO 27001…) and `/compliance-review` | No regulated data or customer; the security model lives in `SECURITY.md` and the relay policy |
| Lots and orchestration (`/lot-start`, `/lot-finish`, `ORCHESTRATION.md`), merge gate, issue reconciliation, orchestrator state, operator decisions file (`docs/DECISIONS.md`) | Small changes, one operator: no lot plan and no parallel agents to coordinate |
| README standard (Excalidraw diagram, progress table, `readme-check.py`, `/readme-update`) | The README is hand-written, NFO-style, with ASCII diagrams |
| Reusable workflows (`harness.yml`: labels, issue and PR hygiene, settings as code, AI review) and `harness-sync.yml` | Not needed on a repository this small (decision 2026-11-27); the repository's own CI replays pre-commit and gitleaks |
| `/feedback-triage` and the feedback form | Made for app user feedback |
| Lot and compliance templates, Excalidraw architecture seed, CodeRabbit (`.coderabbit.yaml`) | No lot plan; the `adversarial-reviewer` agent is the second review |
| Docs on positioning, AI layers, software factory, ADRs, FinOps, stewards, compliance, review service, usage | Background reading, available in the harness repository; not worth vendoring |
| `pre-commit-secrets.sh` | gitleaks already runs through pre-commit |

The full exclusion list is `exclude` in [`.harness/config.json`](../.harness/config.json). The harness block in
`CLAUDE.md` still names a few of the excluded docs and skills: it is managed by the sync and cannot be edited here;
those names point to the harness repository.

## Overrides

What this repository does differently from the harness rules it kept is recorded, with the reason, in
[`AGENTS.md`](../AGENTS.md) › "Harness overrides": issues optional until there is a remote, "seen failing then
passing" with linters and real deployments instead of a unit-test suite, the hand-written README, the commit format
`<zone>: <message>`, and no live-host action without the operator's approval.
