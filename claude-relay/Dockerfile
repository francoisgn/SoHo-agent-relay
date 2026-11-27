# claude-relay : Claude Code headless 24/7 (NAS ou tout hôte Docker), piloté depuis le téléphone
# (Remote Control, et Channels Telegram en option). Paramétrage : .env (voir .env.example).
# Validé sur un Synology x86_64 ancien (kernel 3.10, Docker 20.10, compose v1) : Node 22,
# Claude Code et Bun y tournent.
# Monter une version : changer l'ARG / le digest, puis scripts/deploy.sh.

# node:22.23.5-bookworm-slim, épinglé par digest (index multi-arch)
FROM node:26.13.0-bookworm-slim@sha256:add5c17c14752c54d2f3d519ec46a3815684d41c33f198bcb09fb998f7dcbf68

ARG CLAUDE_CODE_VERSION=2.1.325
# Bun n'est utile que pour les plugins Channels (Telegram) : désactivé par défaut.
ARG INSTALL_BUN=false
ARG BUN_VERSION=1.4.4
ARG RELAY_UID=1500
ARG RELAY_GID=1500

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Outils minimaux. Versions apt non épinglées (DL3008) : Debian retire les anciennes
# versions du miroir, l'épinglage casserait le build ; le digest de l'image fixe la base.
# force-unsafe-io : dpkg sans fsync par fichier (sinon des dizaines de minutes sur un NAS
# dont le disque est chargé) ; sans risque pour un build d'image, retiré ensuite.
# hadolint ignore=DL3008
RUN echo force-unsafe-io >/etc/dpkg/dpkg.cfg.d/99-relay-unsafe-io \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq openssh-client procps tmux tini util-linux \
 && rm -rf /var/lib/apt/lists/* /etc/dpkg/dpkg.cfg.d/99-relay-unsafe-io

# Claude Code (npm, version épinglée) ; Bun optionnel (le paquet npm choisit le binaire
# « baseline » sans AVX2, nécessaire sur les vieux Celeron/Atom).
RUN npm install -g --no-fund --no-audit "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && if [ "${INSTALL_BUN}" = "true" ]; then npm install -g --no-fund --no-audit "bun@${BUN_VERSION}"; fi \
 && npm cache clean --force

# Utilisateur non-root dédié (uid fixe : propriétaire des volumes sur le NAS).
RUN groupadd -g "${RELAY_GID}" relay \
 && useradd -l -m -u "${RELAY_UID}" -g relay -s /bin/bash relay \
 && mkdir -p /workspace /var/log/claude-relay /etc/claude-code \
 && chown relay:relay /workspace /var/log/claude-relay

# Les scripts sont exécutables dans le repo (pas de COPY --chmod : builder classique, sans BuildKit).
COPY bin/ /usr/local/bin/

# DISABLE_AUTOUPDATER : la version vient de l'image (rootfs en lecture seule de toute façon).
# Ne PAS mettre CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC : il désactive Remote Control.
ENV DISABLE_AUTOUPDATER=1 \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    RELAY_MODE=remote-control \
    RELAY_NAME=claude-relay

USER ${RELAY_UID}:${RELAY_GID}
WORKDIR /workspace

HEALTHCHECK --interval=60s --timeout=10s --start-period=60s --retries=3 \
  CMD ["/usr/local/bin/relay-healthcheck"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/relay-entrypoint"]
