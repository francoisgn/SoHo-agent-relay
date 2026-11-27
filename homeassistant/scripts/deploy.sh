#!/usr/bin/env bash
# Deploie Home Assistant sur le NAS : copie compose + configuration.yaml,
# puis `up -d` cible sur le seul service homeassistant (aucun autre conteneur touche).
# Usage : scripts/deploy.sh [--pull]   (--pull : tire l'image pinnee avant)
# Dependances : ssh ; pas de scp (flux via `ssh host cat >`, marche sans SFTP).
# shellcheck disable=SC2029  # expansion cote client voulue (variables fixes)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Reglages propres a la machine : .env (gitignore), modele .env.example
if [ -f "$HERE/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$HERE/.env"
  set +a
fi
: "${HA_HOST:?set HA_HOST in .env (see .env.example)}"
: "${HA_REMOTE_DIR:?set HA_REMOTE_DIR in .env}"
HOST="$HA_HOST"
REMOTE_DIR="$HA_REMOTE_DIR"
DOCKER="${HA_DOCKER:-docker}"
COMPOSE="${HA_COMPOSE:-docker-compose}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else
  G=""; Y=""; R=""; N=""
fi
ok()   { printf '%sok%s   %s\n' "$G" "$N" "$*"; }
warn() { printf '%swarn%s %s\n' "$Y" "$N" "$*"; }
ko()   { printf '%sko%s   %s\n' "$R" "$N" "$*" >&2; }

put() { # put <local> <remote>
  ssh "$HOST" "cat > '$2'" < "$1"
}

pull=0
[ "${1:-}" = "--pull" ] && pull=1

ssh "$HOST" "mkdir -p '$REMOTE_DIR/config'" && ok "remote dir $REMOTE_DIR"
put "$HERE/docker-compose.yml" "$REMOTE_DIR/docker-compose.yml" && ok "docker-compose.yml copied"
put "$HERE/.env" "$REMOTE_DIR/.env" && ok ".env copied"
put "$HERE/config/configuration.yaml" "$REMOTE_DIR/config/configuration.yaml" && ok "configuration.yaml copied"

# secrets.yaml : cree vide s'il n'existe pas (jamais ecrase, jamais versionne)
ssh "$HOST" "[ -e '$REMOTE_DIR/config/secrets.yaml' ] || { : > '$REMOTE_DIR/config/secrets.yaml'; chmod 600 '$REMOTE_DIR/config/secrets.yaml'; }"
ok "secrets.yaml present (600)"

if [ "$pull" -eq 1 ]; then
  ssh "$HOST" "cd '$REMOTE_DIR' && $COMPOSE pull homeassistant" && ok "image pulled"
fi
ssh "$HOST" "cd '$REMOTE_DIR' && $COMPOSE up -d homeassistant" && ok "homeassistant up -d"

state="$(ssh "$HOST" "$DOCKER inspect -f '{{.State.Status}}' homeassistant")"
if [ "$state" = "running" ]; then ok "container $state"; else ko "container $state"; exit 1; fi
warn "UI: http://$HOST:8123 (first start can take a few minutes on this CPU)"
