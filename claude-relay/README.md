# claude-relay

Claude Code headless, disponible 24/7 sur un hôte Docker du LAN (testé sur un vieux
Synology : kernel 3.10, Docker 20.10, compose v1), piloté depuis l'app Claude mobile
(**Remote Control**) et, en option, Telegram (**Channels**). Objectif : la disponibilité,
pas la réactivité.

## Arborescence

| Chemin | Versionné | Rôle |
|---|---|---|
| `Dockerfile` | oui | `node:22-bookworm-slim` épinglé par digest, Claude Code épinglé, utilisateur `relay` non-root, tmux + tini, healthcheck |
| `docker-compose.yml` | oui | service unique, `mem_limit`, rootfs en lecture seule, `cap_drop: ALL`, pas de socket Docker, aucun port |
| `bin/` | oui | `relay-entrypoint` (PID 1 → tmux), `relay-loop` (supervision, relance, renouvellement quotidien du certificat), `relay-healthcheck`, `unifi` (API UniFi locale, clé jamais exposée), `relay-acme` (certificat Let's Encrypt du NAS : acme.sh, DNS-01 Gandi, déploiement DSM) |
| `policy/` | oui | monté en lecture seule sur `/etc/claude-code` : `managed-settings.json` (deny/ask, hooks), hooks, `CLAUDE.md` de base |
| `local/` | **non** | personnel : `CLAUDE.md` (contexte opérateur → `~/.claude/CLAUDE.md`), `managed-settings.d/*.json` (allowlists). Modèles `*.example` |
| `.env` | **non** | hôte SSH, chemins, uid, mode. Modèle : `.env.example` |
| `scripts/deploy.sh` | oui | copie (tar via ssh), `docker build` sur l'hôte, volumes, `up -d` du seul service |
| `scripts/set-token.sh` | oui | trousseau macOS → `secrets/oauth_token` (600) sans affichage |
| `scripts/set-secret.sh` | oui | trousseau macOS → `secrets/<nom>` (600) sans affichage, un secret ou `--all` d'après `local/secrets.map` ; dans le conteneur, variable `<NOM>` |

Sur l'hôte, sous `$RELAY_DATA` : `app/` (déployé), `home/` (`~/.claude`, login, sessions,
mémoire, plugins), `workspace/`, `logs/actions.jsonl` (audit, rotation 5 × 5 Mo),
`secrets/`. Rien de tout ça n'est dans le repo.

## Authentification : deux jetons, deux usages

| Moyen | Remote Control | Channels / `claude -p` | Durée |
|---|---|---|---|
| `claude auth login` dans le conteneur (login claude.ai complet, rafraîchi automatiquement) | 🟢 requis | 🟢 | jusqu'à expiration/révocation ; avertissement 3 jours avant |
| `claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN` | 🔴 refusé (« requires a full-scope login token ») | 🟢 | 1 an |

`relay-loop` n'exporte jamais le jeton setup-token quand un login complet existe (il
primerait et casserait Remote Control).

## Mise en route

```sh
cp .env.example .env && $EDITOR .env
cp local/CLAUDE.md.example local/CLAUDE.md && $EDITOR local/CLAUDE.md
scripts/deploy.sh

# Login claude.ai complet (une fois ; ouvrir l'URL affichée, coller le code)
ssh -t <hôte> 'sudo docker exec -it claude-relay claude auth login'

# Premières confirmations (une fois) : « Enable Remote Control? » et « Trust /workspace? »
ssh -t <hôte> 'sudo docker exec -it claude-relay tmux attach -t relay'   # puis Ctrl-b d
```

Puis, sur le téléphone : app Claude → **Code** → session `RELAY_NAME` (icône ordinateur,
point vert). Dans tmux, la barre d'espace affiche un QR code.

### Option Channels (Telegram)

1. `.env` : `RELAY_INSTALL_BUN=true`, `RELAY_MODE=channels`, puis `scripts/deploy.sh`.
2. Bot via @BotFather, puis dans tmux : `/plugin install telegram@claude-plugins-official`
   (portée user), `/telegram:configure <token>` (stocké dans `~/.claude/channels/telegram/.env`).
3. Redémarrer (`sudo docker restart claude-relay`), écrire au bot, puis dans tmux :
   `/telegram:access pair <code>` et `/telegram:access policy allowlist`.

Jeton setup-token (seulement sans login complet) :
`claude setup-token` sur le Mac → `security add-generic-password -U -a claude-relay -s claude-relay-oauth -w`
(coller à l'invite) → `scripts/set-token.sh`.

## Intégrations

| Intégration | Accès | Secret (`$RELAY_DATA/secrets/`) | Garde-fous |
|---|---|---|---|
| GitHub (tous les repos de l'opérateur) | `gh` + `git` en HTTPS ; jeton fine-grained « All repositories » : Contents, Pull requests, Issues en écriture, Metadata en lecture, **ni** Administration **ni** Workflows | `gh_token` → `GH_TOKEN`, git passe par `gh auth git-credential` | `guard-git` (Belayline) dans la politique managée : pas de push sur `main`/`master`/`develop`/`beta`, pas de force-push, pas de `--no-verify`, quel que soit le repo. `gh pr merge`, `gh repo delete/edit`, `gh secret`, `gh auth` refusés ; lectures `gh … list/view` libres ; push, PR, issues et `gh api` sur approbation |
| Certificat du NAS (Let's Encrypt) | `relay-acme` : acme.sh 3.1.7 figé dans l'image (SHA-256 vérifié), DNS-01 par l'API Gandi LiveDNS (aucun port ouvert), hook `synology_dsm` vers DSM joint par son nom (`RELAY_ACME_HOSTS_ENTRY`) | `gandi_livedns_token` → `GANDI_LIVEDNS_TOKEN` (PAT limité au domaine) ou `gandi_livedns_key` → `GANDI_LIVEDNS_KEY` (clé legacy, tout le compte), `syno_acme_password` → `SYNO_ACME_PASSWORD` (administrateur DSM dédié) | acme.sh enregistre jeton et mot de passe dans sa conf : `relay-acme` les purge à chaque sortie. Écritures de zone hors ACME sur approbation |
| UniFi Network (API d'intégration locale de la console) | wrapper `unifi get\|post\|put\|patch\|delete /v1/…` sur `$UNIFI_URL/proxy/network/integration`, en-tête `X-API-KEY` | `unifi_api_key`, lue par le wrapper (jamais en argument ni en variable) | `unifi get` libre ; toute écriture sur approbation. La clé locale n'a pas de scope : la politique est la seule limite |

Doc UniFi pour agents IA (point d'entrée, à donner au relais) :
<https://developer.ui.com/network/v11.0.97/ai-gettingstarted.md> ; endpoints :
<https://developer.ui.com/network/v11.0.97/llms.txt> ; contrat :
<https://developer.ui.com/network/v11.0.97/openapi.json>. Le contexte propre à l'opérateur (connaissance, recettes
vérifiées, inventaire) vit dans un repo privé séparé, cloné dans `/workspace`, jamais ici.

Mise en service (sur le Mac ; `-w` en dernier = saisie masquée) :

```sh
security add-generic-password -U -a claude-relay -s claude-relay-unifi -w   # clé API locale UniFi
cp local/secrets.map.example local/secrets.map   # nom -> service du trousseau (ou cmd:), jamais de valeur
scripts/set-secret.sh --all                      # pousse chaque secret ; un absent est signalé et sauté
# .env : UNIFI_URL, RELAY_GIT_NAME, RELAY_GIT_EMAIL ; puis scripts/deploy.sh (relance du relais)
```

Chaque secret devient une variable d'environnement de l'agent au démarrage du conteneur (`qbt_password` →
`QBT_PASSWORD`, `gh_token` → `GH_TOKEN`) : utilisable en argument d'une commande, jamais affichable (`guard-bash`).

## Garde-fous

- Conteneur = vraie frontière : non-root, rootfs en lecture seule, `no-new-privileges`,
  aucune capability, pas de socket Docker, aucun partage de données monté, aucun port.
- `managed-settings.json` (priorité maximale, non modifiable par Claude) : mode auto (le
  classifieur de Claude Code juge chaque action), bypass désactivé, écriture hors workspace bloquée,
  deny (`rm -r`, docker, sudo, secrets, config), ask (écritures UniFi, `gh api` en écriture,
  installations npm/pip), allow sans confirmation pour le travail courant (`ssh docker-host`, lecture
  `jq`/`grep`/`ls`, `/workspace`, mémoire du relais). Les hooks PreToolUse passent avant les allow :
  `ssh docker-host '…'` reste filtré par `guard-bash.sh`.
- Les règles Bash ne sont pas une frontière (`bash -c`, `/bin/rm`…) : `guard-bash.sh`
  (PreToolUse) refuse ces motifs où qu'ils apparaissent.
- `guard-git.py` (PreToolUse, Belayline) : pas de push sur une branche protégée, pas de force-push, pas de
  `--no-verify`, dans tous les repos ; `guard-bash.sh` refuse aussi ce qui afficherait un jeton (`$GH_TOKEN`,
  `printenv`, `gh auth token`…).
- `log-action.sh` (PostToolUse) : chaque action en JSONL, secrets masqués.
- Demandes d'approbation sur le téléphone (Remote Control les relaie).

## Limites

- Login complet : s'il expire ou est révoqué, la session n'avance plus jusqu'à un nouveau
  `claude auth login`. Les jetons et le transcript passent par les serveurs Anthropic
  (Remote Control stocke la conversation).
- Mode serveur : sans réseau ~10 min, `claude remote-control` sort ; `relay-loop` le
  relance et reprend les sessions arrêtées depuis moins de ~4 h.
- Channels : research preview ; messages reçus seulement quand la session tourne.
- Le journal est écrit par l'utilisateur du conteneur : Claude ne peut pas le modifier
  via ses outils (deny), mais un shell détourné le pourrait. Pour un audit inviolable,
  l'exporter hors de l'hôte.
- Quota : partagé avec l'usage interactif du même compte.
