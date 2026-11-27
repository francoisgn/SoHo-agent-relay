# claude-relay : Claude Code headless 24/7 (NAS ou tout hôte Docker), piloté depuis le téléphone
# (Remote Control, et Channels Telegram en option). Paramétrage : .env (voir .env.example).
# Validé sur un Synology x86_64 ancien (kernel 3.10, Docker 20.10, compose v1) : Node 22,
# Claude Code et Bun y tournent.
# Monter une version : changer l'ARG / le digest, puis scripts/deploy.sh.

# node:22.23.5-bookworm-slim, épinglé par digest (index multi-arch)
FROM node:22.23.5-bookworm-slim@sha256:e9f565d32859f0cbfb52125eafe8be39390f24dac302dc3cdf566e8ba3ab21ee

ARG CLAUDE_CODE_VERSION=2.1.325
# Bun n'est utile que pour les plugins Channels (Telegram) : désactivé par défaut.
ARG INSTALL_BUN=false
ARG BUN_VERSION=1.4.4
ARG RELAY_UID=1500
ARG RELAY_GID=1500
# acme.sh (certificat du NAS, bin/relay-acme) : archive de la release officielle, SHA-256 vérifié.
ARG ACME_SH_VERSION=3.1.7
ARG ACME_SH_SHA256=1b674f31aab8844e0ed770d4a5907a777d259f58b476c5f9334cc846832081e7

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Outils minimaux. Versions apt non épinglées (DL3008) : Debian retire les anciennes
# versions du miroir, l'épinglage casserait le build ; le digest de l'image fixe la base.
# force-unsafe-io : dpkg sans fsync par fichier (sinon des dizaines de minutes sur un NAS
# dont le disque est chargé) ; sans risque pour un build d'image, retiré ensuite.
# python3 : hook guard-git et scripts d'analyse ; gh : GitHub par PR (dépôt apt officiel, clé
# vérifiée par signed-by) ; openssl : clés et CSR d'acme.sh ; sqlite3, dig, nc, file, less, tree, archives : diagnostic et inspection.
# Ni pip, ni compilateurs, ni ping (CAP_NET_RAW) : image légère pour un petit NAS.
# hadolint ignore=DL3008
RUN echo force-unsafe-io >/etc/dpkg/dpkg.cfg.d/99-relay-unsafe-io \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq openssh-client procps tmux tini util-linux \
      python3-minimal python3 openssl sqlite3 dnsutils netcat-openbsd file less tree unzip xz-utils zstd \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod 0644 /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      >/etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/* /etc/dpkg/dpkg.cfg.d/99-relay-unsafe-io

# acme.sh en lecture seule dans /opt/acme.sh : le script et ses hooks dnsapi/ et deploy/ ;
# son état (compte, certificats) va dans le home persistant (bin/relay-acme --config-home).
RUN curl -fsSL -o /tmp/acme.tar.gz \
      "https://github.com/acmesh-official/acme.sh/archive/refs/tags/${ACME_SH_VERSION}.tar.gz" \
 && echo "${ACME_SH_SHA256}  /tmp/acme.tar.gz" | sha256sum -c - \
 && mkdir -p /opt/acme.sh \
 && tar -xzf /tmp/acme.tar.gz -C /opt/acme.sh --strip-components=1 \
      "acme.sh-${ACME_SH_VERSION}/acme.sh" "acme.sh-${ACME_SH_VERSION}/dnsapi" \
      "acme.sh-${ACME_SH_VERSION}/deploy" "acme.sh-${ACME_SH_VERSION}/LICENSE.md" \
 && chmod 0755 /opt/acme.sh/acme.sh \
 && rm -f /tmp/acme.tar.gz

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
