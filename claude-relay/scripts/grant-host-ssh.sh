#!/usr/bin/env bash
# Donne au relais un accès SSH à son propre hôte, comme un administrateur tiers :
#   1. clé ed25519 dédiée générée DANS le conteneur (~/.ssh/id_ed25519_host, volume home),
#      la clé privée ne quitte jamais le conteneur ;
#   2. clé publique ajoutée à ~/.ssh/authorized_keys de l'utilisateur hôte, restreinte au
#      réseau Docker (from=) et sans forwarding, commentée « claude-relay » (traçable) ;
#   3. ~/.ssh/config (alias « docker-host ») et known_hosts épinglé avec la clé d'hôte lue par le
#      canal SSH de l'opérateur (pas de trust-on-first-use depuis le conteneur) ;
#   4. test de connexion depuis le conteneur.
# Idempotent. Révocation : scripts/grant-host-ssh.sh --revoke.
# À lancer depuis le poste de l'opérateur (Mac), pas depuis le relais.
# shellcheck disable=SC2029  # commandes distantes construites côté client : voulu
set -euo pipefail

# shellcheck source=/dev/null  # common.sh, à côté de ce script
. "$(dirname "$0")/common.sh"
load_env

RELAY_CONTAINER=${RELAY_CONTAINER:-claude-relay}
# Adresse de l'hôte vue depuis le conteneur (IP LAN de l'hôte, ou passerelle du réseau
# Docker si vide) et utilisateur SSH sur l'hôte.
RELAY_HOST_ADDR=${RELAY_HOST_ADDR:-}
RELAY_HOST_USER=${RELAY_HOST_USER:-$(ssh "$RELAY_SSH_HOST" 'id -un')}
# Réseaux autorisés à présenter la clé (plages Docker par défaut).
RELAY_HOST_FROM=${RELAY_HOST_FROM:-172.16.0.0/12}
KEY=.ssh/id_ed25519_host
COMMENT=claude-relay

dexec() { ssh "$RELAY_SSH_HOST" "$RELAY_DOCKER exec $RELAY_CONTAINER $*"; }

if [ "${1:-}" = "--revoke" ]; then
  # shellcheck disable=SC2329  # appelée via spin
  revoke() {
    # Sauvegarde horodatée, puis réécriture en place (garde propriétaire, droits, ACL).
    # shellcheck disable=SC2016  # variables du shell distant
    ssh "$RELAY_SSH_HOST" 'f=$HOME/.ssh/authorized_keys
      cp -p "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
      grep -v " '"$COMMENT"'\$" "$f" > "$f.tmp" || true
      cat "$f.tmp" > "$f"; rm -f "$f.tmp"'
  }
  spin "Removing '$COMMENT' keys from the host user's authorized_keys" revoke
  ok "revoked (the container key stays in its home volume but no longer opens anything)"
  exit 0
fi

ssh "$RELAY_SSH_HOST" "$RELAY_DOCKER ps --filter name=^$RELAY_CONTAINER\$ -q" | grep -q . ||
  die "container $RELAY_CONTAINER is not running on $RELAY_SSH_HOST"

if [ -z "$RELAY_HOST_ADDR" ]; then
  RELAY_HOST_ADDR=$(ssh "$RELAY_SSH_HOST" "$RELAY_DOCKER inspect $RELAY_CONTAINER --format '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}'")
  warn "RELAY_HOST_ADDR not set: using Docker network gateway $RELAY_HOST_ADDR (changes if the network is recreated)"
fi

gen_key() {
  # shellcheck disable=SC2016  # $HOME est développé dans le conteneur
  dexec sh -c "'umask 077; mkdir -p \$HOME/.ssh; [ -f \$HOME/$KEY ] || ssh-keygen -q -t ed25519 -N \"\" -C $COMMENT -f \$HOME/$KEY'"
}
spin "Container key ~/$KEY" gen_key

pub=$(dexec cat "/home/relay/$KEY.pub")
case "$pub" in ssh-ed25519\ *) ;; *) die "unexpected public key format" ;; esac
line="from=\"$RELAY_HOST_FROM\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding $pub"

authorize() {
  # La ligne transite par stdin ; ajout seulement si la clé n'y est pas déjà.
  # shellcheck disable=SC2016  # variables du shell distant
  printf '%s\n' "$line" | ssh "$RELAY_SSH_HOST" '
    umask 077; mkdir -p "$HOME/.ssh"; f="$HOME/.ssh/authorized_keys"; touch "$f"
    IFS= read -r l; k=$(printf "%s" "$l" | awk "{print \$(NF-1)}")
    grep -qF "$k" "$f" && exit 0
    cp -p "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"; printf "%s\n" "$l" >> "$f"'
}
spin "Authorizing key for $RELAY_HOST_USER (from=$RELAY_HOST_FROM, no forwarding)" authorize

hostkey=$(ssh "$RELAY_SSH_HOST" 'cat /etc/ssh/ssh_host_ed25519_key.pub' | awk '{print $1" "$2}')
[ -n "$hostkey" ] || die "cannot read host ed25519 key"

write_config() {
  {
    printf 'Host docker-host\n  HostName %s\n  User %s\n  IdentityFile ~/%s\n  IdentitiesOnly yes\n' \
      "$RELAY_HOST_ADDR" "$RELAY_HOST_USER" "$KEY"
    printf '  StrictHostKeyChecking yes\n  UserKnownHostsFile ~/.ssh/known_hosts_host\n'
    printf '  HostKeyAlias docker-host\n  ConnectTimeout 10\n  ServerAliveInterval 30\n  ServerAliveCountMax 4\n'
  } | ssh "$RELAY_SSH_HOST" "$RELAY_DOCKER exec -i $RELAY_CONTAINER sh -c 'umask 077; cat > \$HOME/.ssh/config'"
  printf 'docker-host %s\n' "$hostkey" |
    ssh "$RELAY_SSH_HOST" "$RELAY_DOCKER exec -i $RELAY_CONTAINER sh -c 'umask 077; cat > \$HOME/.ssh/known_hosts_host'"
}
spin "Writing ssh config (alias 'docker-host' -> $RELAY_HOST_ADDR) and pinned host key" write_config

test_ssh() {
  dexec ssh -o BatchMode=yes docker-host "'echo connected as \$(id -un) on \$(hostname); sudo -n /usr/local/bin/docker ps -q | wc -l | sed \"s/^/containers visible: /\"'"
}
spin "Testing 'ssh docker-host' from the container" test_ssh
ok "relay can administer its host via 'ssh docker-host' (guard-bash still blocks self-sawing actions)"
