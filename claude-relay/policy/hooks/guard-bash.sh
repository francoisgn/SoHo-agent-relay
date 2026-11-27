#!/usr/bin/env bash
# Hook PreToolUse (Bash) : filet derrière les règles de managed-settings.json, qui ne voient
# pas `bash -c '…'`, `/bin/rm`, ni les commandes passées dans `ssh docker-host '…'`.
#
# Règle d'or : le relais tourne SUR l'hôte qu'il administre. Il ne scie jamais sa propre
# branche : alimentation, réseau, démon Docker, SSH, son propre conteneur, sa politique.
# Ces actions sont refusées ici, où qu'elles apparaissent (local ou via SSH), et passent
# par une procédure écrite pour l'agent du poste opérateur (/etc/claude-code/procedures/).
# Ce n'est pas une frontière de sécurité (sudo docker = root sur l'hôte) : un garde-fou.
set -uo pipefail

cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0

deny() {
  jq -cn --arg r "Blocked by claude-relay guard: $1." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}
self_saw() {
  deny "$1 would cut the branch the relay sits on. Write a procedure (stop / restart / test / rollback) from /etc/claude-code/procedures/TEMPLATE.md into /workspace/handoff/ for the operator's workstation agent"
}

# Position de commande : début, séparateur, sous-shell, guillemet (bash -c "…", ssh h '…'),
# chemin absolu (/sbin/reboot) ou wrapper (sudo, xargs, env…), suivis d'espaces éventuels.
B='(^|[;&|(`"'"'"'{]|\$\(|/|(sudo|xargs|exec|env|nohup|nice|time|timeout|command|builtin|watch)[[:space:]]+(-[^[:space:]]+[[:space:]]+)*)[[:space:]]*'
E='([[:space:]"'"'"';&|)]|$)'
# Commande Docker ou Compose, avec ou sans chemin/sudo.
D="${B}(docker([[:space:]]+compose)?|docker-compose)[[:space:]]"

# --- 1. Alimentation et services de l'hôte -------------------------------------------
if grep -Eq "${B}(reboot|shutdown|poweroff|halt|telinit|synopoweroff|synoshutdown)${E}" <<<"$cmd" \
  || grep -Eq "${B}init[[:space:]]+[06]${E}" <<<"$cmd"; then
  self_saw "Power action on the host"
fi
if grep -Eq "${B}(systemctl|synosystemctl|synoservice|synoservicectl|service)[[:space:]]" <<<"$cmd" \
  || grep -Eq "${B}synopkg[[:space:]]+(stop|restart|start|uninstall|disable|install)" <<<"$cmd"; then
  self_saw "Host service or package control"
fi

# --- 2. Démon Docker, son propre conteneur, réseaux ------------------------------------
if grep -Eq "${B}(dockerd|containerd)${E}" <<<"$cmd" \
  || grep -Eq "(kill|pkill|killall)[^;&|]*(dockerd|containerd|sshd|synoscgi|nginx|[[:space:]]-1([[:space:]]|$)|[[:space:]]1([[:space:]]|$))" <<<"$cmd"; then
  self_saw "Touching the Docker daemon, sshd or PID 1"
fi
if grep -Eq "${D}[^;&|]*claude-relay" <<<"$cmd"; then
  # Lecture de son propre état tolérée ; tout le reste sur lui-même est refusé.
  if ! grep -Eq "${D}[[:space:]]*(ps|logs|stats|inspect|images|top|port)([[:space:]]|$)" <<<"$cmd"; then
    self_saw "Acting on the claude-relay container, image or project"
  fi
fi
if grep -Eq "${D}[[:space:]]*(system|network|volume|builder|image|container)[[:space:]]+(prune|rm|disconnect)" <<<"$cmd" \
  || grep -Eq "${D}[[:space:]]*(stop|kill|restart|rm|pause|update)[^;&|]*(\\\$\(|\`|[[:space:]]-a([[:space:]]|$)|--all)" <<<"$cmd" \
  || grep -Eq "${D}[[:space:]]*([^;&|]*[[:space:]])?(down|--remove-orphans)([[:space:]\"';&|)]|$)" <<<"$cmd"; then
  self_saw "Bulk Docker action (prune, mass stop/rm, network change, compose down)"
fi
if grep -Eq "${D}[[:space:]]*(run|create)[^;&|]*(--privileged|--pid[= ]host|--net(work)?[= ]host|--userns[= ]host|--cap-add|(-v|--volume|--mount)[= ]+[^[:space:]]*(/:|source=/[,[:space:]]|docker\.sock))" <<<"$cmd"; then
  self_saw "Privileged or host-root container (escape route)"
fi

# --- 3. Réseau et accès -----------------------------------------------------------------
if grep -Eq "${B}(ifdown|iptables|ip6tables|nft|brctl|synonet|synofirewall|nmcli)${E}" <<<"$cmd" \
  || grep -Eq "${B}ifconfig[^;&|]*[[:space:]]down" <<<"$cmd" \
  || grep -Eq "${B}ip[[:space:]]+(-[^[:space:]]+[[:space:]]+)*(link|addr|address|route|rule)[[:space:]]+(set|del|delete|flush|add|change|replace)" <<<"$cmd" \
  || grep -Eq "${B}route[[:space:]]+(del|add)" <<<"$cmd"; then
  self_saw "Network change on the host"
fi
if grep -Eq "sshd_config|/etc/ssh/|authorized_keys" <<<"$cmd"; then
  self_saw "Changing SSH access"
fi

# --- 4. Stockage ------------------------------------------------------------------------
if grep -Eq "${B}(mkfs(\.[[:alnum:]]+)?|dd|mdadm|lvremove|vgremove|pvremove|lvreduce|umount|swapoff|wipefs|fdisk|parted|sgdisk)${E}" <<<"$cmd" \
  || grep -Eq "/volume[0-9]+/@(docker|appstore|database|syno)" <<<"$cmd"; then
  self_saw "Disk, volume or system storage operation"
fi
# rm récursif : refusé sur une racine (/, volume, dossier partagé, home), toléré ailleurs
# (ménage) — la règle « ask » de la politique fait valider chaque commande sur le téléphone.
if grep -Eq "${B}rm[[:space:]]+([^;&|]*[[:space:]])?(-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)" <<<"$cmd" \
  && grep -Eq "[[:space:]](/|/\*|/volume[0-9]+/?(\*)?|/volume[0-9]+/[^/[:space:]\"']+/?(\*)?|~/?|\\\$HOME/?|\*|\.|\.\.)([[:space:]\"';&|)]|$)" <<<"$cmd"; then
  deny "recursive rm on a root, volume, shared folder or home. Target a precise subfolder"
fi

# --- 5. Divers --------------------------------------------------------------------------
if grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh' <<<"$cmd"; then
  deny "piping a download into a shell"
fi
if grep -Eq ':\(\)[[:space:]]*\{' <<<"$cmd"; then
  deny "fork bomb"
fi
# Jetons des intégrations : GH_TOKEN est dans l'environnement de claude (gh en a besoin) ;
# on refuse ce qui l'afficherait ou l'exfiltrerait (le wrapper unifi lit sa clé lui-même).
if grep -Eq '\$\{?(GH_TOKEN|GITHUB_TOKEN|CLAUDE_CODE_OAUTH_TOKEN)\b' <<<"$cmd" \
  || grep -Eq "${B}(printenv|export[[:space:]]+-p|declare[[:space:]]+-[a-zA-Z]*x)${E}" <<<"$cmd" \
  || grep -Eq "${B}(env|set|export)[[:space:]]*([;&|)\"']|$)" <<<"$cmd" \
  || grep -Eq "${B}gh[[:space:]]+auth[[:space:]]+(token|status)" <<<"$cmd" \
  || grep -Eq "credential[[:space:]]+fill|git-credential|/proc/[^[:space:]]*/environ" <<<"$cmd"; then
  deny "this would print or leak an integration token (GH_TOKEN, credentials). Use gh/git/unifi directly"
fi
if grep -Eq '/var/run/docker\.sock|/run/relay-secrets|\.credentials\.json|claude-relay/(app|logs|secrets)|/etc/claude-code/(hooks|managed)' <<<"$cmd"; then
  deny "access to the relay's own credentials, policy, audit log or deployed files"
fi

exit 0
