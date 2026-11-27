# Changelog

Notable changes, newest first. No releases yet: entries accumulate under "Unreleased" until the first tag
(`vX.Y.Z`, [semver](https://semver.org)).

## Unreleased

### Added

- Integrations: GitHub on all the operator's repositories by pull request only (`gh`, fine-grained token in
  `secrets/gh_token`, Belayline `guard-git` in the managed policy, `gh pr merge`/`repo delete`/`secret`/`auth`
  denied) and the UniFi Network local API (`bin/unifi`, key read from `secrets/unifi_api_key`, GET free, writes on
  approval). `scripts/set-secret.sh` pushes any Keychain secret to the host; `guard-bash` refuses commands that
  would print a token.

- Belayline harness 0.5.0-dev, lean profile: agent rules (`CLAUDE.md`, `AGENTS.md`), skills (no lots, no
  orchestration), the adversarial reviewer, the `guard-git` hook, issue and PR templates, repository settings as code
  ([docs/belayline-adoption.md](docs/belayline-adoption.md)).
- pre-commit: hadolint, actionlint, zizmor and markdownlint next to ShellCheck and gitleaks; CI replays the hooks and
  scans the full history; weekly hook autoupdate and Dependabot.
- `SECURITY.md`, `CONTRIBUTING.md`, MIT `LICENSE`, `FUNDING.yml`, README.
- `homeassistant/`: compose, generic config, deploy script (paused).
