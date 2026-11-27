#!/usr/bin/env bash
# Pousse un secret du trousseau macOS vers l'hôte, dans $RELAY_DATA/secrets/<nom> (600, uid
# du conteneur), sans jamais l'afficher : trousseau -> pipe -> ssh (stdin) -> conteneur jetable.
# Dans le conteneur, chaque secret devient une variable d'environnement en majuscules
# (qbt_password -> QBT_PASSWORD) au démarrage du conteneur ; gh_token devient GH_TOKEN.
#
# Usage :
#   scripts/set-secret.sh <nom> <service du trousseau> [compte|-]
#   scripts/set-secret.sh <nom> 'cmd:<commande qui écrit le secret sur stdout>'
#   scripts/set-secret.sh --all [table]     # chaque ligne de la table (défaut : local/secrets.map)
# Compte par défaut : $RELAY_KEYCHAIN_ACCOUNT ; « - » = n'importe quel compte (-s seul).
# Exemples :
#   scripts/set-secret.sh unifi_api_key claude-relay-unifi
#   scripts/set-secret.sh qbt_password seedbox-qbt -
#   scripts/set-secret.sh gh_token 'cmd:gh auth token'
# Table : « <nom> <service> [compte|-] » ou « <nom> cmd:<commande> » par ligne, # = commentaire
# (local/secrets.map.example).
#
# Préalable pour un nouveau secret (une fois, sur le Mac ; -w en dernier = saisie masquée) :
#   security add-generic-password -U -a claude-relay -s <service> -w
# Les variables sont relues au redémarrage du conteneur (déploiement) ;
# le wrapper unifi relit son fichier à chaque appel.
set -euo pipefail

# shellcheck source=/dev/null  # common.sh, à côté de ce script
. "$(dirname "$0")/common.sh"
load_env

command -v security >/dev/null || die "macOS 'security' not found (run this on the Mac)"

# Écrit le secret lu sur stdin dans $RELAY_DATA/secrets/<nom> sur l'hôte.
push_stdin() {
  local name=$1
  # Côté hôte, la valeur passe par une variable du shell (mémoire, jamais disque ni argument : printf est
  # un builtin) : Docker 20.10 reste bloqué si `run -i` lit directement le stdin de la session ssh.
  # La commande distante est construite côté client (voulu) ; le secret reste sur stdin.
  # shellcheck disable=SC2029
  tr -d '\r\n' |
    ssh "$RELAY_SSH_HOST" "v=\$(cat); printf %s \"\$v\" | $RELAY_DOCKER run --rm -i --network none --user 0 --entrypoint sh \
      -v '$RELAY_DATA/secrets:/s' claude-relay:local -c \
      'umask 077; cat > /s/$name.new && test -s /s/$name.new \
       && chown $RELAY_UID:$RELAY_GID /s/$name.new && chmod 600 /s/$name.new \
       && mv -f /s/$name.new /s/$name || { rm -f /s/$name.new; exit 1; }'"
}

# Écrit la valeur de la source (trousseau ou commande) sur stdout, vers un pipe seulement.
read_source() {
  local source=$1 account=$2
  case "$source" in
    cmd:*) bash -c "${source#cmd:}" ;;
    *)
      if [ "$account" = "-" ]; then
        security find-generic-password -s "$source" -w
      else
        security find-generic-password -a "$account" -s "$source" -w
      fi
      ;;
  esac
}

# Vérifie la source, puis pousse. Retour 1 (sans arrêter --all) si elle manque.
set_one() {
  local name=$1 source=$2 account=${3:-$RELAY_KEYCHAIN_ACCOUNT}
  [[ $name =~ ^[a-z0-9_]+$ ]] || {
    ko "name must match [a-z0-9_]+ (got '$name')"
    return 1
  }
  if [[ $source != cmd:* ]]; then
    local args=(-s "$source")
    [ "$account" = "-" ] || args=(-a "$account" "${args[@]}")
    if ! security find-generic-password "${args[@]}" >/dev/null 2>&1; then
      warn "skipped $name: no keychain item '$source' (security add-generic-password -U -a $account -s $source -w)"
      return 1
    fi
  fi
  SRC=$source ACC=$account NAME=$name
  spin "Pushing $name to $RELAY_SSH_HOST:$RELAY_DATA/secrets/$name" push_current
  ok "secret $name in place (never printed)"
}
# shellcheck disable=SC2329  # appelée par spin
push_current() { read_source "$SRC" "$ACC" | push_stdin "$NAME"; }

if [ "${1:-}" = "--all" ]; then
  map=${2:-$(dirname "$0")/../local/secrets.map}
  [ -r "$map" ] || die "no secrets table at $map (see local/secrets.map.example)"
  failed=0
  while read -r name rest; do
    case "$name" in '' | '#'*) continue ;; esac
    if [[ $rest == cmd:* ]]; then
      set_one "$name" "$rest" || failed=$((failed + 1))
    else
      read -r source account _ <<<"$rest"
      set_one "$name" "$source" "${account:-}" || failed=$((failed + 1))
    fi
  done <"$map"
  [ "$failed" -eq 0 ] || warn "$failed secret(s) not pushed"
  exit 0
fi

[ $# -ge 2 ] && [ $# -le 3 ] || die "usage: $0 <name> <keychain-service|cmd:...> [account|-] | --all [table]"
set_one "$@" || exit 1
