# Contributing

This is a personal homelab repository, shared in case it helps someone. Issues and small PRs are welcome; large
changes are best discussed in an issue first. Humans and coding agents follow the same path; the agents' rules are
in [`AGENTS.md`](AGENTS.md) and [`CLAUDE.md`](CLAUDE.md).

## In short

1. **An issue first** for anything beyond a small fix: what you want, why, how we will know it works.
2. **A branch** `<type>/<short-name>` (`fix`, `feat`, `chore`, `docs`) from an up-to-date `main`.
3. **Commits** `<zone>: <message>` in English (`relay: drop curl from the allowlist`).
4. **Checks before pushing**, the same as CI:

   ```sh
   pre-commit install            # once per clone
   pre-commit run --all-files    # or scripts/local-check.sh
   ```

5. **A draft PR**: what changed, why, what you verified on a real host and what you did not.

## What a PR must keep true

- **No personal data**: no IP, hostname, domain, email, username or serial number. Machine values go in `.env`
  (see `.env.example`), personal context in `local/`; both are gitignored.
- **No secret**, anywhere: code, logs, screenshots, PR text. gitleaks runs at commit time and in CI.
- **Guardrails are not relaxed silently**: a change to `claude-relay/policy/` (permissions, hooks) or to the
  container hardening says what it allows and why.
- Pinned versions stay pinned (image digests, tool versions, hook revisions, action SHAs).

## Reporting a flaw

Never in a public issue: see [SECURITY.md](SECURITY.md) (Security tab › Report a vulnerability).
