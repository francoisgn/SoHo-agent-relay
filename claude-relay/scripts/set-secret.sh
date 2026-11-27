#!/usr/bin/env bash
# Pousse un secret du trousseau macOS vers l'hôte, dans $RELAY_DATA/secrets/<nom> (600, uid
# du conteneur), sans jamais l'afficher : trousseau -> pipe -> ssh (stdin) -> conteneur jetable.
#
# Usage : scripts/set-secret.sh <nom> <service du trousseau> [compte]
#   scripts/set-secret.sh gh_token claude-relay-gh        # jeton GitHub fine-grained (GH_TOKEN)
#   scripts/set-secret.sh unifi_api_key claude-relay-unifi # clé API locale UniFi (wrapper unifi)
# Compte par défaut : $RELAY_KEYCHAIN_ACCOUNT.
#
# Préalable (une fois, sur le Mac ; -w en dernier = saisie masquée, rien dans l'historique) :
#   security add-generic-password -U -a claude-relay -s <service> -w
# Le conteneur lit le fichier à chaque (re)démarrage de claude (relay-loop) ou à chaque appel (unifi).
set -euo pipefail

# shellcheck source=/dev/null  # common.sh, à côté de ce script
. "$(dirname "$0")/common.sh"
load_env

[ $# -ge 2 ] && [ $# -le 3 ] || die "usage: $0 <name> <keychain-service> [account]"
name=$1 service=$2 account=${3:-$RELAY_KEYCHAIN_ACCOUNT}
[[ $name =~ ^[a-z0-9_]+$ ]] || die "name must match [a-z0-9_]+ (got '$name')"

command -v security >/dev/null || die "macOS 'security' not found (run this on the Mac)"
security find-generic-password -a "$account" -s "$service" >/dev/null 2>&1 ||
  die "no keychain item '$service': security add-generic-password -U -a $account -s $service -w"

push_secret() {
  # Le secret ne transite que par des pipes (jamais en argument ni à l'écran).
  # La commande distante est construite côté client (voulu) ; le secret reste sur stdin.
  # shellcheck disable=SC2029
  security find-generic-password -a "$account" -s "$service" -w | tr -d '\r\n' |
    ssh "$RELAY_SSH_HOST" "$RELAY_DOCKER run --rm -i --network none --user 0 --entrypoint sh \
      -v '$RELAY_DATA/secrets:/s' claude-relay:local -c \
      'umask 077; cat > /s/$name.new && test -s /s/$name.new \
       && chown $RELAY_UID:$RELAY_GID /s/$name.new && chmod 600 /s/$name.new \
       && mv -f /s/$name.new /s/$name || { rm -f /s/$name.new; exit 1; }'"
}
spin "Pushing $service to $RELAY_SSH_HOST:$RELAY_DATA/secrets/$name" push_secret
ok "secret $name in place (never printed)"
