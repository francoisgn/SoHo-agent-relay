#!/usr/bin/env bash
# Déploie claude-relay sur l'hôte Docker (RELAY_SSH_HOST) sans registry :
#   1. copie Dockerfile, compose, bin/, policy/, local/ et .env dans $RELAY_DATA/app
#      (tar via ssh : pas de scp/SFTP sur DSM) ;
#   2. build de l'image sur l'hôte ;
#   3. prépare les volumes (home, workspace, logs, secrets) avec l'uid du conteneur ;
#   4. `up -d` ciblé sur le seul service claude-relay (aucun autre conteneur touché).
# Usage : scripts/deploy.sh [--no-up]
set -euo pipefail

# shellcheck source=/dev/null  # common.sh, à côté de ce script
. "$(dirname "$0")/common.sh"
load_env

do_up=1
[ "${1:-}" = "--no-up" ] && do_up=0

cd "$RELAY_DIR"

# Fichiers personnels : à défaut, partir des exemples (avec avertissement).
if [ ! -f local/CLAUDE.md ]; then
  cp local/CLAUDE.md.example local/CLAUDE.md
  warn "local/CLAUDE.md missing: created from the example, edit it"
fi
mkdir -p local/managed-settings.d
if ! compgen -G 'local/managed-settings.d/*.json' >/dev/null; then
  cp local/managed-settings.d/50-local.json.example local/managed-settings.d/50-local.json
  warn "local/managed-settings.d is empty: created 50-local.json from the example"
fi
for f in policy/managed-settings.json local/managed-settings.d/*.json; do
  jq empty "$f" 2>/dev/null || die "invalid JSON: $f"
done
ok "local config present and valid"

# 1. Copie : archive tar poussée via ssh (COPYFILE_DISABLE : pas de fichiers ._* macOS),
#    extraite dans app.new puis basculée, pour ne jamais laisser de fichiers obsolètes.
copy_files() {
  local q
  q=$(printf %q "$RELAY_DATA")
  # shellcheck disable=SC2029  # expansion côté client voulue (chemin quoté)
  ssh "$RELAY_SSH_HOST" "mkdir -p $q && cat > $q/.app.tar" < <(
    COPYFILE_DISABLE=1 tar -c --exclude '*.example' \
      Dockerfile docker-compose.yml .env bin policy local
  )
  remote "$RELAY_DATA" <<'EOF'
set -euo pipefail
data=$1
rm -rf "$data/app.new"
mkdir -p "$data/app.new"
tar -x -C "$data/app.new" -f "$data/.app.tar"
rm -f "$data/.app.tar"
chmod 600 "$data/app.new/.env"
# Point de montage des réglages locaux dans policy/ (monté en lecture seule)
mkdir -p "$data/app.new/policy/managed-settings.d"
# L'ancien app/ reste monté par le conteneur en cours : on le garde de côté (horodaté)
# et on le supprime après le redémarrage (étape 4).
if [ -d "$data/app" ]; then mv "$data/app" "$data/app.old.$(date +%s)"; fi
mv "$data/app.new" "$data/app"
echo "files in $data/app"
EOF
}
spin "Copying files to $RELAY_SSH_HOST:$RELAY_DATA/app" copy_files

# 2. Build sur l'hôte avec `docker build` (docker-compose v1 sous sudo délègue le build à
#    un `docker` absent du PATH sécurisé de sudo sur DSM). CPU modeste : plusieurs minutes.
build() {
  remote "$RELAY_DATA" "$RELAY_DOCKER" "${RELAY_INSTALL_BUN:-false}" "$RELAY_UID" "$RELAY_GID" <<'EOF'
set -euo pipefail
cd "$1/app"
# shellcheck disable=SC2086
$2 build -t claude-relay:local \
  --build-arg INSTALL_BUN="$3" --build-arg RELAY_UID="$4" --build-arg RELAY_GID="$5" .
EOF
}
spin "Building image claude-relay:local on $RELAY_SSH_HOST" build

# 3. Volumes : créés puis attribués à l'uid du conteneur via un conteneur jetable
#    (pas de sudo chown hors docker sur DSM). ~/.claude pré-créé, sinon Docker le créerait
#    en root pour y monter CLAUDE.md.
prepare_volumes() {
  remote "$RELAY_DATA" "$RELAY_DOCKER" "$RELAY_UID" "$RELAY_GID" <<'EOF'
set -euo pipefail
data=$1 docker=$2 uid=$3 gid=$4
mkdir -p "$data/home" "$data/workspace" "$data/logs" "$data/secrets"
# shellcheck disable=SC2086
$docker run --rm --network none --user 0 --entrypoint sh \
  -v "$data:/d" claude-relay:local -c "
    set -e
    mkdir -p /d/home/.claude
    chown $uid:$gid /d/home /d/home/.claude /d/workspace /d/logs /d/secrets
    # chmod retire aussi les ACL Synology héritées (sinon lisibles par tous)
    chmod 700 /d/home /d/home/.claude /d/workspace /d/logs /d/secrets
    for f in /d/secrets/*; do [ -f \"\$f\" ] || continue; chown $uid:$gid \"\$f\"; chmod 600 \"\$f\"; done
  "
echo "owner $uid:$gid"
EOF
}
spin "Preparing volumes" prepare_volumes

# 4. Démarrage ciblé
if [ "$do_up" -eq 1 ]; then
  up() {
    remote "$RELAY_DATA" "$RELAY_COMPOSE" <<'EOF'
set -euo pipefail
cd "$1/app"
# --force-recreate : app/ est remplacé à chaque déploiement, les montages policy/ et local/
# doivent pointer sur le nouveau dossier (Claude reprend ses sessions au redémarrage).
# shellcheck disable=SC2086
$2 -p claude-relay up -d --no-deps --force-recreate claude-relay
# Anciennes versions de app/ (plus montées) : ménage, sans échouer si l'une résiste.
rm -rf "$1"/app.old* 2>/dev/null || echo "warn: some $1/app.old* could not be removed" >&2
EOF
  }
  spin "Starting container claude-relay (this service only)" up
  info "status: ssh $RELAY_SSH_HOST '$RELAY_DOCKER ps --filter name=claude-relay'"
  info "first run: ssh -t $RELAY_SSH_HOST '$RELAY_DOCKER exec -it claude-relay claude auth login'"
else
  warn "--no-up: container not (re)started"
fi
