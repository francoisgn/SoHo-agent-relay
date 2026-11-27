# SoHo-agent-relay

![Claude Code](https://img.shields.io/badge/Claude_Code-relay-D97757?logo=claude&logoColor=white)
![Docker 20.10](https://img.shields.io/badge/Docker-20.10_compose_v1-2496ED?logo=docker&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-ShellCheck-4EAA25?logo=gnubash&logoColor=white)
![pre-commit](https://img.shields.io/badge/pre--commit-hadolint_·_actionlint_·_gitleaks-FAB040?logo=precommit&logoColor=white)
![Belayline](https://img.shields.io/badge/harness-Belayline-111111)
![License: MIT](https://img.shields.io/badge/License-MIT-blue)

```text
 ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
 █                                                                          █
 █  ╔═╗╔═╗╦ ╦╔═╗   ╔═╗╔═╗╔═╗╔╗╔╔╦╗   ╦═╗╔═╗╦  ╔═╗╦ ╦                        █
 █  ╚═╗║ ║╠═╣║ ║───╠═╣║ ╦║╣ ║║║ ║ ───╠╦╝║╣ ║  ╠═╣╚╦╝                        █
 █  ╚═╝╚═╝╩ ╩╚═╝   ╩ ╩╚═╝╚═╝╝╚╝ ╩    ╩╚═╚═╝╩═╝╩ ╩ ╩                         █
 █                                                                          █
 █  the night shift that never clocks out, on a tired NAS                   █
 █                                                                          █
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
      *         .            .-.          *
           .          *     (   )   .
   .              ╷          '-'               *            ┌──────────┐
         .     (( │ ))  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  │ relay    │
                  │       ▐▛███▜▌     .                     │──────────│
      *           │      ▝▜█████▛▘[o]                       │ rm logs? │
                  │        ▘▘ ▝▝          *                 │ [y]  [n] │
       ┌──────────┴──────────────────────┐                  │    ()    │
       │ [====] [====] [====] [====]   ● │                  └──────────┘
       │ DS416play  ·  kernel 3.10     ● │
       └─────────────────────────────────┘
       night watch: lantern lit, antenna up, risky moves ask first
 ░▒▓█▓▒░ RELEASE INFO ░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░
   Name ......... SoHo-agent-relay         Agent ...... Claude Code
   Type ......... always-on relay          Remote ..... your phone
   Host ......... Synology DS416play       Guards ..... audit, auto, deny
   Shift ........ 24/7, outbound only      Status ..... on duty
```

**An always-on Claude Code relay on an old home NAS, driven from your phone: it gets on with routine work and asks before anything risky.**

> **Intended use.** A personal homelab experiment, shared as is. It runs Claude Code with the operator's own
> account, for the operator's own machines. Read and respect
> [Anthropic's terms](https://www.anthropic.com/legal/consumer-terms) and
> [usage policy](https://www.anthropic.com/legal/aup) (one account per person, no shared or resold access, no
> automated use the terms do not allow), and the terms of every device or service you connect to it. Nothing here
> is affiliated with or endorsed by Anthropic, Synology or Ubiquiti. You are responsible for what the agent does on
> your network.

## Why

**Available, not just reactive.** A coding agent on a laptop exists while the laptop is open. Questions about the
homelab ("why is the NAS slow?", "what ate the bandwidth last night?", "clean up the old snapshots") come up from the
couch or on the go. A relay that is always running on the box that is always on can answer them from the phone,
with the context it already has: its memory, its workspace, its logs.

**Why Claude Code rather than a third-party agent.** Facts, not a ranking:

| Need | What Claude Code brings, first-party |
|---|---|
| Reach it from a phone without opening a port | Remote Control: the session shows up in the Claude app; the container only makes outbound HTTPS. Channels (Telegram) as an option |
| Decide what it may do, and lock that decision | Managed settings in a read-only mount: `deny` / `ask` / `allow` rules, auto mode (Claude Code's action classifier) on, bypass mode disabled, managed hooks only |
| See what it did | `PreToolUse` / `PostToolUse` hooks: refuse a command before it runs, log every action |
| Plug in the NAS and the router | MCP servers or plain API calls with scoped tokens |
| One login, one bill | The operator's own Claude account, no extra API key to keep on the box (an OAuth token from `claude setup-token` for Channels only) |

No agent framework, gateway or bot server to host and keep patched next to it.

## Architecture

```text
   YOU (phone)                                ANTHROPIC
  ┌───────────────────┐                     ┌───────────────────────┐
  │ Claude app        │◀── Remote Control ─▶│ claude.ai session     │
  │ Telegram (option) │◀── Channels ───────▶│ relay                 │
  └───────────────────┘                     └───────────▲───────────┘
                                                        │ outbound HTTPS only
  NAS (DSM, Docker 20.10, compose v1)                   │ no published port
  ┌─────────────────────────────────────────────────────┼─────────────────┐
  │  claude-relay container                             │                 │
  │  ┌──────────────────────────────────────────────────┴──────────────┐  │
  │  │ Claude Code (pinned)    uid 1500, cap_drop ALL, read-only root  │  │
  │  │   │                                                             │  │
  │  │   ├─ managed policy (ro) ── auto + deny / ask, no bypass mode   │  │
  │  │   ├─ PreToolUse hook ────── guard-bash: refuse before it runs   │  │
  │  │   └─ PostToolUse hook ───── log-action ──▶ logs/actions.jsonl   │  │
  │  │                                                                 │  │
  │  │ volumes: home (login, memory) · workspace (rw) · logs · secrets │  │
  │  └───────────────┬─────────────────────────────────┬───────────────┘  │
  │                  │ scoped token (planned)          │ scoped token     │
  │                  ▼                                 ▼ (planned)        │
  │        NAS: load, bandwidth,             UniFi: clients, traffic,     │
  │        housekeeping (ask first)          (read-only first)            │
  └───────────────────────────────────────────────────────────────────────┘
       not mounted: Docker socket, host data shares, SSH keys
```

| Path | What |
|---|---|
| [`claude-relay/`](claude-relay/) | The relay: `Dockerfile` (base image pinned by digest, Claude Code pinned), compose, `bin/` (entrypoint in tmux, loop, healthcheck), `policy/` (managed settings, hooks, base `CLAUDE.md`), `scripts/deploy.sh`, `scripts/set-token.sh` |
| [`homeassistant/`](homeassistant/) | Home Assistant container. **Paused**, optional |
| [`docs/`](docs/) | Notes, including [why and how the Belayline harness was adopted](docs/belayline-adoption.md) |
| `.harness/`, `.claude/`, `CLAUDE.md`, `AGENTS.md` | Rules and tools for the coding agents that work **on** this repository ([Belayline](https://github.com/francoisgn/belayline-agentic-harness)) |

## Security model

The relay is a capable agent on a machine that also holds family photos. The design assumes the model can be wrong
or manipulated (a web page, a log line or a chat message that reads like an order), and puts the limits **outside**
the model.

| Layer | Guardrail |
|---|---|
| Container | Non-root (`uid 1500`), `cap_drop: ALL`, `no-new-privileges`, read-only root filesystem, `/tmp` in tmpfs, memory and CPU caps |
| Host | **No Docker socket**, no privileged mode, no published port, no NAS share mounted. Only its own volumes: home, workspace, logs, secrets |
| Policy | Managed settings mounted read-only, above anything Claude can write: `deny` for `docker`, `sudo`, `rm -r`, `dd`, reading credentials or `/proc/*/environ`, editing its own settings, hooks or logs |
| Human approval | Auto mode: Claude Code's classifier reviews every action and lets routine work through (clone, branch and PR, reading the host over SSH, scripts in the workspace). `ask` remains for UniFi writes, `gh api` writes and package installs; the base `CLAUDE.md` requires an announced yes for anything destructive or irreversible (deletions outside the workspace, restarts, host or network changes). Prompts land on the phone |
| Second net | `PreToolUse` hook `guard-bash` refuses destructive patterns even when wrapped (`bash -c '…'`, `/bin/rm`) |
| Audit | `PostToolUse` hook appends every action to `actions.jsonl`, secrets masked (Anthropic, GitHub, Telegram, JWT, bearer, private keys, `password=`…), rotated by size, on the host only |
| Tokens | Scoped to the minimum (read-only first), one per integration; stored in the Mac's Keychain, pushed through pipes to `600` files outside the repository (`scripts/set-secret.sh --all` from a name → Keychain table), exported to the agent as environment variables (`QBT_PASSWORD`…) that `guard-bash` refuses to print |
| Repository | No IP, hostname or email in git: values in `.env` (gitignored, `.env.example` versioned), personal context in `local/`; gitleaks at commit time and over the full history in CI |

Known limits, stated plainly: an agent-side hook can be bypassed by a creative enough command, which is why the
container boundary, not the hook, is the real perimeter. Remote Control depends on Anthropic's service: if it is
down, the relay is unreachable (it keeps running). Report a flaw privately: [SECURITY.md](SECURITY.md).

## Tested hardware

| | |
|---|---|
| NAS | Synology **DS416play**, Intel Celeron N3060 (2 cores, no AVX2) |
| OS | DSM with **kernel 3.10** |
| Containers | **Docker 20.10**, `docker-compose` v1, classic builder |
| Relay footprint | ~200-300 MB idle, capped at 1 GB and 1.5 CPU by default |

What that old stack means in practice:

- **Compose v1, file format 2.4**: `mem_limit` and `cpus` without swarm; no newer compose features.
- **No BuildKit**: no `COPY --chmod`, no cache mounts; scripts are executable in the repository instead.
- **No AVX2**: Bun (for Channels plugins) uses its baseline build.
- **No zstd layers**: Docker before 23 cannot pull images with `zstd` layers (recent Home Assistant images); see
  the workaround in [`homeassistant/README.md`](homeassistant/README.md).
- **Slow first build**: minutes, not seconds, on a Celeron. Builds happen on the NAS itself (no registry).

Any x86_64 Docker host should do; newer ones need none of the workarounds.

## Quickstart

Full details, including the first login, live in [`claude-relay/`](claude-relay/). In short, from a Mac or Linux
machine with an SSH alias for the NAS:

```sh
cd claude-relay
cp .env.example .env     # SSH alias of the host, data directory, uid/gid, mode (remote-control | channels)
scripts/deploy.sh        # copies the files over SSH, builds on the host, starts only this service
```

Then:

1. **Log in once** inside the container, as described in `claude-relay/`: Remote Control needs a full
   `claude.ai` login, kept in the persistent home volume.
2. **Token (Channels only)**: create it with `claude setup-token`, store it in the macOS Keychain, then
   `scripts/set-token.sh` pushes it to a `600` file on the host, through pipes only.
3. **Personal context**: `local/CLAUDE.md` and `local/managed-settings.d/*.json` (created from the `*.example`
   files on the first deploy): your inventory, your language, extra `allow` rules. Gitignored.

## Driving it from the phone

- **Remote Control** (default): the relay session appears in the Claude app under its name (`RELAY_NAME`). Type
  as you would in a terminal; when the relay needs an approval, it waits for you there.
- **Telegram** (optional, `RELAY_MODE=channels`): the official Channels plugin forwards messages to the running
  session. Handy for short questions; approvals stay on the policy's terms.
- **From a terminal**: `docker exec -it claude-relay tmux attach -t relay` on the host (detach with `Ctrl-b d`).

Answers are kept short on purpose: they are read on a phone.

## Integrations

| Target | Status | How | Scope |
|---|---|---|---|
| NAS (Synology) | 🟠 planned | DSM API or MCP, scoped account and token | Load, bandwidth, storage, housekeeping (every deletion asked first) |
| GitHub (all the operator's repositories) | 🔵 wired: `gh` in the image, needs a token | `gh` + `git` over HTTPS, fine-grained token (contents, PRs, issues; no admin, no workflows) in `secrets/gh_token` | Branches and pull requests only: Belayline `guard-git` in the managed policy refuses pushes to protected branches, force-push and `--no-verify`; merge, repo deletion and settings denied |
| UniFi network | 🔵 wired, needs an API key | UniFi Network local integration API through `bin/unifi` (`X-API-KEY`, key read from `secrets/unifi_api_key`, never exposed). Agent guide: [ai-gettingstarted.md](https://developer.ui.com/network/v11.0.97/ai-gettingstarted.md), [llms.txt](https://developer.ui.com/network/v11.0.97/llms.txt), [OpenAPI](https://developer.ui.com/network/v11.0.97/openapi.json) | Devices, clients, networks, firewall, Wi-Fi: `GET` free, every write asked first. Details in [`claude-relay/README.md`](claude-relay/README.md#intégrations) |
| Philips Hue (and the Zigbee devices paired to the bridge) | 🟠 planned | Hue bridge local API (CLIP v2), application key valid on the LAN only; no Home Assistant | Lights, scenes, sensors |
| Native HomeKit accessories | ⛔ out of scope | No local API for a container. The only routes: unpair them and re-pair to Home Assistant's HomeKit Controller, or an Apple Shortcut run on a Mac that stays on | Not driven by the relay |
| Home Assistant | ⏸️ paused, optional | Home Assistant's MCP server, limited token | Only if a later need justifies it, see [`homeassistant/`](homeassistant/) |
| PlayStation 5 | ⛔ out of scope | Sony's own Remote Play app | Not driven by the relay |

## Roadmap

- [x] Relay container: hardened, non-root, pinned, outbound only
- [x] Policy: managed settings, guard hook, JSONL audit log with masking
- [x] Repository: Belayline harness, pre-commit, CI, security policy
- [ ] NAS integration with a scoped, mostly read-only account
- [ ] UniFi integration, read-only first (wired: `bin/unifi`; key to create)
- [ ] GitHub on all the operator's repositories, by pull request only (wired: policy and `guard-git`; `gh` in the image)
- [ ] Hue integration through the bridge's local API (CLIP v2), LAN-only application key
- [ ] Daily digest to the phone (disk, load, unusual traffic), on demand rather than noisy
- [ ] Audit log review: a weekly summary of what the relay did and what was refused
- [ ] Publish: history scan, English comments everywhere, GitHub security features on

## Development

```sh
pre-commit install            # once per clone (hooks are pinned; no linter to install by hand)
pre-commit run --all-files    # ShellCheck, hadolint, actionlint, zizmor, markdownlint, JSON/YAML, gitleaks
scripts/local-check.sh        # the same as CI, with a summary
```

Coding agents working on this repository follow [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) and the
[Belayline](https://github.com/francoisgn/belayline-agentic-harness) harness. See also
[CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE). The vendored harness files in `.harness/` carry Belayline's own MIT licence
([`.harness/LICENSE`](.harness/LICENSE)).

## Support

If the night watch saves you a trip to the NAS, you can buy me a coffee:

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-francoisgn-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/francoisgn)
