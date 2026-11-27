# Changelog

Notable changes, newest first. No releases yet: entries accumulate under "Unreleased" until the first tag
(`vX.Y.Z`, [semver](https://semver.org)).

## Unreleased

### Added

- NAS certificate: `bin/relay-acme` issues a Let's Encrypt certificate by DNS-01 (Gandi LiveDNS, no open port) with
  acme.sh 3.1.7 pinned in the image (SHA-256 checked), deploys it to DSM (`synology_dsm` hook, DSM reached by name
  through `RELAY_ACME_HOSTS_ENTRY`) and `relay-loop` checks the renewal daily. acme.sh always saves the token and
  password it is given: `relay-acme` purges them on every exit. `openssl` added to the image.
- Image: `python3`, `gh` (official apt repository), `sqlite3`, `dig`, `nc`, `file`, `less`, `tree` and archive
  tools.
- Secrets as environment variables: every file pushed by `scripts/set-secret.sh` becomes `<NAME>` for the agent
  (`RELAY_SECRET_NAMES` lists them, `guard-bash` refuses to print them); `set-secret.sh --all` pushes a whole
  name → Keychain table (`local/secrets.map`), including `cmd:` sources such as `gh auth token`.

### Changed

- Auto mode: Claude Code's classifier reviews every action; `ask` only for UniFi writes, `gh api` writes and package
  installs; the base `CLAUDE.md` keeps the announced-yes rule for destructive or irreversible actions.
- In-container SSH alias of the host renamed `docker-host` (rerun `scripts/grant-host-ssh.sh` after deploying).

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
