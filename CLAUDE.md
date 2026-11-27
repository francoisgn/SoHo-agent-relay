# CLAUDE.md

Instructions for coding agents (Claude Code reads this file; other agents read `AGENTS.md`). Product details: [README.md](README.md).

<!-- harness:begin harness -->
## Shared harness: Belayline 0.5.0-dev

This block is managed by `scripts/harness-sync.sh`, which lives in the [Belayline](https://github.com/francoisgn/belayline-agentic-harness) harness repository, not in this repository: do not edit it here (propose changes in the harness). To update: skill `/harness-update`, or, from the root of this repository, clone the harness at the wanted tag next to it (`git clone --depth 1 --branch vX.Y.Z https://github.com/francoisgn/belayline-agentic-harness.git ../belayline`) then run `../belayline/scripts/harness-sync.sh --target .` (`.harness/docs/ADOPTION.md` §Updates).

**Precedence**: the project rules win over the harness. The project records each deviation from the harness, with its reason, in the "Harness overrides" section of its `AGENTS.md`; its settings go in `.harness/config.json`; everything outside this block belongs to the project. Order on a conflict: "Harness overrides" section, then the rest of the project rules (`AGENTS.md`, `CLAUDE.md`), then `.harness/config.json`, then `.harness/docs/`. Report an unresolved conflict in an issue of the project.

@.harness/docs/ESSENTIALS.md

Read as the task requires (not loaded by default): method `.harness/docs/METHODOLOGY.md`, conventions `.harness/docs/CONVENTIONS.md`, lessons `.harness/docs/LESSONS.md` (self-review before every PR), reviews `.harness/docs/REVIEW-ROUNDS.md`, orchestration and model choice `.harness/docs/ORCHESTRATION.md`, branches and releases `.harness/docs/BRANCHING-RELEASE.md`, CI budget and security `.harness/docs/CI-BUDGET.md`, project README `.harness/docs/README-STANDARD.md`, Mac handoff `.harness/docs/MAC-HANDOFF.md`.
Skills: `/intent`, `/lot-start`, `/lot-finish`, `/local-check`, `/review-round`, `/feedback-triage`, `/lessons-check`, `/readme-update`, `/status-report`, `/compliance-review`, `/lesson-propose`, `/harness-update`.
<!-- harness:end harness -->

## The project

An always-on Claude Code relay running in a container on a small home NAS, driven from a phone
(Remote Control; Telegram via Channels as an option), plus the integrations it is allowed to use.
It is infrastructure, not a software product: Dockerfiles, compose files, bash scripts, Claude Code
policy (managed settings, hooks, `CLAUDE.md`).

| Path | Role |
|---|---|
| `claude-relay/` | The relay container: `Dockerfile`, compose, `bin/` (entrypoint, loop, healthcheck), `policy/` (managed settings, hooks, base `CLAUDE.md`), `scripts/deploy.sh`, `scripts/set-token.sh` |
| `homeassistant/` | Home Assistant container. **Paused**, optional: nothing runs |
| `docs/` | Project docs, including [`docs/belayline-adoption.md`](docs/belayline-adoption.md) |
| `.harness/` | Vendored Belayline harness (do not edit, see the block above) |

## Build and tests

There is no unit-test suite: the checks are the linters and a deployment you can observe.

```sh
pre-commit run --all-files      # ShellCheck, hadolint, actionlint, zizmor, markdownlint, JSON/YAML, gitleaks
scripts/local-check.sh          # the same as CI, with a summary (OK / FAILED / INCOMPLETE)
```

- A change to a container: build it on the target (`<module>/scripts/deploy.sh --no-up` when the script offers it),
  then check the healthcheck and the audit log. Never claim "works" without having seen it run.
- The target host is old (kernel 3.10, Docker 20.10, compose v1, no BuildKit, no AVX2): see the README's
  "Tested hardware" before using a newer Docker or compose feature.

## Project conventions

- **Safety first.** Least privilege: non-root containers, `cap_drop: ALL`, `no-new-privileges`, read-only rootfs
  where possible, **never the Docker socket**, no published ports unless needed. Tokens are scoped to the minimum
  (read-only when it is enough).
- **Human approval** before any destructive or network action taken by the relay (delete, move, kill, any
  `curl`/`ssh`/`git push`…): enforced by `claude-relay/policy/` (`ask`/`deny` rules and hooks), never relaxed
  in a commit without saying why.
- **Audit**: every relay action is logged as JSONL with secrets masked; logs stay on the host, never in git.
- **No personal data**: no IP, hostname, domain, email, username or serial number in the repository. Machine values
  go in `.env` (gitignored) with a generic `.env.example`; personal context in `local/` (gitignored, only
  `*.example` are versioned). SSH targets are aliases from `~/.ssh/config`.
- **Secrets**: macOS Keychain on the operator's Mac, or `600` files on the host outside the repository; piped, never
  passed as an argument or printed.
- **Scripts**: bash with `set -euo pipefail`, ShellCheck clean; output in English; colours `ok` green, `warn`
  yellow, `ko` red (off without a TTY or with `NO_COLOR`); a spinner for long tasks. Flag any GNU/BSD difference
  (scripts run on macOS, containers on Debian).
- **Pin everything**: base images by digest, tool versions as build args, pre-commit hooks by tag, actions by tag.
- **Language**: English for docs, commits, script output and new comments (the repository is meant to go public).

## Branches and CI

- Model B (`.harness/docs/BRANCHING-RELEASE.md`): one integration branch, `main`, protected by the `guard-git` hook.
  Work on `<type>/<short-name>` branches; several agents may work at once, each in its own `git worktree`.
- Commits: `<zone>: <message>` in English (`relay:`, `homeassistant:`, `harness:`, `ci:`, `docs:`, `repo:`).
- CI (`.github/workflows/ci.yml`) replays `pre-commit run --all-files` and scans the full history with gitleaks.
  No remote yet: CI runs once the repository is on GitHub.

## Project-specific labels

`area: relay`, `area: nas`, `area: unifi`, `area: hue`, `area: homeassistant`, `area: harness` (`.github/labels.local.json`):
one per issue, for the module it touches.
