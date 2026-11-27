# Security policy

## Reporting a vulnerability

Please **do not open a public issue, PR or discussion** for a security problem.

Report it privately from the repository's **Security** tab: **Report a vulnerability**
(GitHub [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)).
The report is only visible to you and the maintainer.

Include what you found, the commit, how to reproduce it and the impact you expect. Never paste a real token,
hostname or IP address. You should get an answer within a week; the project is maintained in spare time, so there is
no guaranteed delay for the fix. Please disclose nothing before the fix is published.

## Supported versions

Only the `main` branch.

## Scope

This repository runs a coding agent on a home server, so its guardrails are the attack surface.

| In scope | Examples |
|---|---|
| Relay policy | a command the agent can run without approval although `claude-relay/policy/` should ask or deny it; a way for the agent to edit its own policy, hooks or audit log |
| Container hardening | an escape to the host, a privilege the container should not have, a path that gives it the Docker socket or host data |
| Secrets | a token printed, logged unmasked in the audit log, passed as a command argument, or written outside its `600` file |
| Prompt injection | text from a web page, an API answer, a log or a chat message that makes the relay act without approval |
| Scripts and CI | a deploy script writing outside its target directory; a workflow injection or an over-broad token |

Out of scope: Claude Code, Docker, DSM, UniFi or Home Assistant themselves (report those to their vendor), and
findings from automated tools without an exploitation scenario.
