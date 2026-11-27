# shellcheck shell=bash
# Commun à deploy.sh et set-token.sh : chargement de .env et helpers d'affichage.
# Sourcé, pas exécuté.

RELAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Helpers ok/warn/ko/info/spin : lib/ui.sh des dotfiles si présente, sinon repli minimal
# (le repo doit rester utilisable sans les dotfiles).
UI_LIB="${DOTFILES:-$HOME/Git/dotfiles}/lib/ui.sh"
if [ -r "$UI_LIB" ]; then
  # shellcheck source=/dev/null
  . "$UI_LIB"
else
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_BLUE=$'\033[34m' C_RESET=$'\033[0m'
  else
    C_GREEN='' C_YELLOW='' C_RED='' C_BLUE='' C_RESET=''
  fi
  say()  { printf '%s%-7s%s %s\n' "$1" "$2" "$C_RESET" "$3"; }
  ok()   { say "$C_GREEN" ok "$*"; }
  warn() { say "$C_YELLOW" warn "$*"; }
  ko()   { say "$C_RED" ko "$*" >&2; }
  info() { say "$C_BLUE" info "$*"; }
  spin() {
    local msg="$1"; shift
    info "$msg..."
    if "$@"; then ok "$msg"; else ko "$msg"; return 1; fi
  }
fi

die() { ko "$*"; exit 1; }

# Charge .env (obligatoire) et vérifie les variables utilisées par les scripts.
load_env() {
  local f="$RELAY_DIR/.env"
  [ -r "$f" ] || die "missing $f (copy .env.example and adapt it)"
  set -a
  # shellcheck source=/dev/null
  . "$f"
  set +a
  : "${RELAY_SSH_HOST:?RELAY_SSH_HOST not set in .env}"
  : "${RELAY_DATA:?RELAY_DATA not set in .env}"
  RELAY_DOCKER=${RELAY_DOCKER:-docker}
  RELAY_COMPOSE=${RELAY_COMPOSE:-docker-compose}
  RELAY_UID=${RELAY_UID:-1500}
  RELAY_GID=${RELAY_GID:-1500}
  RELAY_KEYCHAIN_SERVICE=${RELAY_KEYCHAIN_SERVICE:-claude-relay-oauth}
  RELAY_KEYCHAIN_ACCOUNT=${RELAY_KEYCHAIN_ACCOUNT:-claude-relay}
}

# remote <args…> <<'EOF' : exécute un script bash (stdin) sur l'hôte. ssh recolle ses
# arguments en une seule ligne de commande : on les quote pour le shell distant.
remote() {
  local q=""
  [ "$#" -gt 0 ] && q=$(printf ' %q' "$@")
  # shellcheck disable=SC2029  # expansion côté client voulue (arguments déjà quotés)
  ssh "$RELAY_SSH_HOST" "bash -s --$q"
}
