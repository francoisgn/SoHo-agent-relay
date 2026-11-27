#!/usr/bin/env bash
# Pousse le jeton `claude setup-token` du trousseau macOS vers l'hôte, dans
# $RELAY_DATA/secrets/oauth_token (600, uid du conteneur), sans jamais l'afficher :
# trousseau -> pipe -> ssh (stdin) -> conteneur jetable qui écrit le fichier.
#
# Ce jeton ne sert qu'au mode Channels sans login complet (ou à `claude -p`) :
# Remote Control exige `claude auth login` dans le conteneur (voir README).
#
# Préalable (une fois, sur le Mac ; -w en dernier = saisie masquée, rien dans l'historique) :
#   security add-generic-password -U -a claude-relay -s claude-relay-oauth -w
set -euo pipefail

# shellcheck source=/dev/null  # common.sh, à côté de ce script
. "$(dirname "$0")/common.sh"
load_env

command -v security >/dev/null || die "macOS 'security' not found (run this on the Mac)"
security find-generic-password -a "$RELAY_KEYCHAIN_ACCOUNT" -s "$RELAY_KEYCHAIN_SERVICE" >/dev/null 2>&1 ||
  die "no keychain item '$RELAY_KEYCHAIN_SERVICE': security add-generic-password -U -a $RELAY_KEYCHAIN_ACCOUNT -s $RELAY_KEYCHAIN_SERVICE -w"

push_token() {
  # Le jeton ne transite que par des pipes (jamais en argument ni à l'écran).
  # Côté hôte, la valeur passe par une variable du shell (mémoire, jamais disque ni argument : printf est
  # un builtin) : Docker 20.10 reste bloqué si `run -i` lit directement le stdin de la session ssh.
  # La commande distante est construite côté client (voulu) ; le jeton reste sur stdin.
  # shellcheck disable=SC2029
  security find-generic-password -a "$RELAY_KEYCHAIN_ACCOUNT" -s "$RELAY_KEYCHAIN_SERVICE" -w | tr -d '\r\n' |
    ssh "$RELAY_SSH_HOST" "v=\$(cat); printf %s \"\$v\" | $RELAY_DOCKER run --rm -i --network none --user 0 --entrypoint sh \
      -v '$RELAY_DATA/secrets:/s' claude-relay:local -c \
      'umask 077; cat > /s/oauth_token.new && test -s /s/oauth_token.new \
       && chown $RELAY_UID:$RELAY_GID /s/oauth_token.new && chmod 600 /s/oauth_token.new \
       && mv -f /s/oauth_token.new /s/oauth_token || { rm -f /s/oauth_token.new; exit 1; }'"
}
spin "Pushing token to $RELAY_SSH_HOST:$RELAY_DATA/secrets/oauth_token" push_token
info "used by RELAY_MODE=channels when no full claude.ai login exists (read at each (re)start of claude)"
