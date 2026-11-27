# Home Assistant

**Statut : EN PAUSE (2026-11-16).** Rien ne tourne : le conteneur n'a jamais été créé (le `docker load`
de l'image a été interrompu), seuls `docker-compose.yml` et `config/` (`configuration.yaml`, `secrets.yaml` vide)
sont posés sur le serveur et y restent. La PS5 se pilote via le Remote Play officiel de Sony, HA n'y sert plus.
HA ne resterait que comme relais HomeKit depuis le LAN : voir « HomeKit depuis le LAN : options ».

Home Assistant (HA) en conteneur : relais HomeKit, puis PlayStation, pour un agent Claude
qui le pilote via le serveur MCP officiel de HA avec un jeton limité.

## Contenu

| Fichier | Rôle |
|---|---|
| `docker-compose.yml` | Service `homeassistant`, image pinnée, `network_mode: host`, `mem_limit`, pas de privileged |
| `config/configuration.yaml` | Config générique versionnée (aucune coordonnée, zone ni pays) |
| `scripts/deploy.sh` | Copie compose + config + `.env`, puis `up -d homeassistant` (seul ce service) |
| `.env.example` | Modèle des réglages propres à la machine ; copier en `.env` (gitignoré) |

Hors repo, sur le serveur : `config/secrets.yaml`, `config/.storage/` (comptes, jetons, appairages, zones), base SQLite.

## Déploiement

```sh
cp .env.example .env     # adapter HA_HOST, HA_REMOTE_DIR, commandes docker
scripts/deploy.sh        # --pull pour tirer l'image (voir limite ci-dessous)
```

UI : `http://<hôte>:8123`. Premier démarrage : plusieurs minutes sur un petit CPU.

### Limite Docker 20.10 : couches zstd

Les images HA récentes ont des couches `tar+zstd` ; Docker < 23 (ex. Synology DSM 7.1, Docker 20.10)
échoue avec `failed to register layer: archive/tar: invalid tar header`. Contournement : sur un poste
récent, télécharger les couches, les décompresser (`zstd -d`), vérifier les `diff_ids`, assembler une
archive `docker save` et la charger avec `ssh <hôte> 'docker load' < ha-image.tar`. Refaire à chaque
changement de version d'image. Alternative : mettre Docker à jour (Container Manager).

## Procédure pour l'utilisateur, dans l'ordre

### 1. Onboarding

1. Ouvrir `http://<hôte>:8123`, **Créer mon espace**.
2. Créer le compte propriétaire (administrateur ; mot de passe fort, stocké dans un gestionnaire).
3. Nom du domicile, position, fuseau, unités, pays : saisis ici, ils restent dans `.storage/` sur le serveur.
4. Laisser décocher le partage de statistiques si souhaité, **Terminer**.

### 2. HomeKit : deux sens différents

| Intégration | Sens | Usage |
|---|---|---|
| **HomeKit Bridge** (`homekit`) | HA vers Apple Maison | Expose des entités HA (lumières, prises, sondes...) à l'app Maison et Siri |
| **HomeKit Device** (`homekit_controller`) | Apple/accessoire vers HA | Importe dans HA des accessoires « Compatible Apple Home » |

**HomeKit Bridge** : *Réglages > Appareils et services > Ajouter une intégration > HomeKit Bridge*,
choisir les domaines/entités à exposer, puis scanner le QR code (notification HA) depuis l'app Maison
(**+ > Ajouter un accessoire**). Ports : 21063 (bridge), 21064+ (mode accessoire : caméras, TV, serrures).
Seul l'iPhone (ou Apple TV/HomePod) sur le **même réseau local** peut appairer ; multicast mDNS requis.

**HomeKit Device** : un accessoire HomeKit IP ne s'appaire qu'à **un seul** contrôleur à la fois.
- Retirer l'accessoire de l'app Maison (il reste sur le Wi-Fi), puis dans HA accepter la découverte
  et saisir son code à 8 chiffres (sur l'appareil ou l'emballage, introuvable sinon).
- Il disparaît alors de l'app Maison : le ré-exposer via HomeKit Bridge.
- Si la marque a une intégration native (Hue, Netatmo, Shelly, etc.), la préférer : plus complète, sans conflit de contrôleur.
- Bluetooth/Thread : nécessitent adaptateur ou proxy (ESPHome) / routeur Thread, non fournis ici.

### 3. Accès pour l'agent Claude (MCP + jeton)

Doc HA (intégration `mcp_server`, vérifiée 2026-11) :

- Activer : *Réglages > Système > IA* (ou *Appareils et services > Ajouter > Model Context Protocol*), bouton **Enable**.
- URL principale `/api/mcp` : tous les outils, **compte administrateur obligatoire** (option activée par défaut). Elle peut être limitée avec les options (« Expose all AI tools » désactivé, « Read-only »).
- URL individuelle `/api/mcp/assist` (**Device control**) : ne voit que les entités **exposées à Assist** (*Réglages > Assistants vocaux > Exposer*), n'exige **pas** d'admin. Les URL individuelles ignorent « Read-only ».
- Le jeu d'outils « Home Assistant » (tout lire/agir, logs, historique) exige un admin : à éviter pour l'agent.

Mise en place du moindre privilège :

1. *Réglages > Personnes > Utilisateurs* (mode avancé activé dans le profil) : créer l'utilisateur `claude-agent`, **non administrateur**, « Peut se connecter en local uniquement » coché.
2. Exposer à Assist uniquement les entités que l'agent peut piloter (liste blanche).
3. Se connecter en tant que `claude-agent`, *Profil > Sécurité > Jetons d'accès longue durée > Créer*. **Copier le jeton immédiatement** (affiché une fois).
4. Stockage, jamais dans le repo :
   ```sh
   security add-generic-password -a "$USER" -s ha-agent-token -w   # trousseau macOS (saisie masquée)
   # sur le serveur, fichier 600 lisible par l'agent seulement :
   ( umask 077; ssh <hôte> 'cat > /chemin/ha-agent.token' )   # coller le jeton puis Ctrl-D
   ```
5. Côté claude-relay : `claude mcp add --transport http --header "Authorization: Bearer $(cat /chemin/ha-agent.token)" home-assistant http://<hôte>:8123/api/mcp/assist`.
   ⚠️ La doc HA décrit OAuth (PKCE) et un client Claude Code en HTTPS ; l'usage d'un jeton longue durée en en-tête Bearer est le fonctionnement standard de l'API HA mais **n'est pas documenté pour MCP : à valider** au premier branchement. Si Claude Code refuse le HTTP clair, mettre un reverse proxy TLS **local** (jamais d'exposition Internet).
6. Révocation : supprimer le jeton dans le profil de `claude-agent`, ou désactiver l'utilisateur. Rotation conseillée tous les 90 jours.

### 4. PlayStation 5

| Option | Apporte | Limites |
|---|---|---|
| Intégration officielle **PlayStation Network** (`playstation_network`) | Statut en ligne, jeu en cours, pochette, troppées, entité media_player | Via le compte PSN (jeton NPSSO, valable ~2 mois, ne pas se déconnecter de playstation.com). **Pas** d'allumage/extinction |
| **ps5-mqtt** (add-on communautaire) + broker MQTT (Mosquitto) | Allumer/mettre en veille la console | Le conteneur HA « Container » n'a pas le Supervisor/add-ons : ps5-mqtt se lance comme conteneur séparé ; nécessite un broker ; console en mode repos et réseau local ; projet non officiel |

Mosquitto n'est **pas** déployé : à ajouter ensuite (conteneur séparé, authentification, port 1883 en LAN seulement) si l'allumage est voulu.

## HomeKit depuis le LAN : options

| Option | Principe | Faisabilité | Source |
|---|---|---|---|
| **HomeKit Controller** (HA) | HA devient le contrôleur HomeKit de l'accessoire | 🟠 L'accessoire HomeKit IP n'a qu'un contrôleur : il faut le retirer de l'app Maison (donc perdre Siri/automations Apple pour lui) ; ré-exposable ensuite via HomeKit Bridge | doc HA `homekit_controller` |
| **Matter multi-admin** | Un accessoire **Matter** est partagé entre fabrics (Apple Home + HA) sans désappairage ; 5 fabrics minimum par la spec | 🟢 si l'accessoire est Matter, ⚪ sinon (non applicable aux accessoires HomeKit-only). Demande un serveur Matter en plus de HA (conteneur `matterjs-server`, IPv6/mDNS, host network ; Thread = border router type HomePod/Apple TV). Partage : « Share » depuis l'app Maison, code saisi dans HA | doc HA `matter` (Multi Fabric, partage depuis Apple/Google) |
| **Intégration native de la marque** | Hue, Netatmo, Shelly etc. parlent à HA par leur API/bridge, indépendamment d'Apple | 🟢 quand elle existe : pas de conflit de contrôleur, souvent plus complète | doc HA de chaque intégration |
| **Raccourci Apple via `shortcuts run`** | Un Mac du LAN lance un raccourci de l'app Raccourcis (action Maison) : `shortcuts run "Nom"` | 🟠 Pas de HA nécessaire ni de désappairage ; exige un Mac allumé et connecté à la session iCloud, raccourcis à créer à la main, pas de retour d'état fiable. À valider sur la version macOS en place (non testé ici) | `shortcuts` CLI Apple (macOS 12+, `man shortcuts`) : connaissance générale, non revérifié en ligne |

Sans HA, les options 3 et 4 suffisent pour des commandes ponctuelles ; HA n'apporte de valeur que pour l'agrégation d'état et les automatisations (Matter multi-admin ou intégrations natives).

## Pour une publication du repo

Conçu pour : réglages machine dans `.env` (gitignoré), config générique, aucune coordonnée ni IP en dur.
Reste à faire : scan de tout l'historique (secrets, données perso), `.github/FUNDING.yml`, `SECURITY.md`,
section Support du README, `.github/dependabot.yml` (github-actions), activation des protections GitHub
(private vulnerability reporting, Dependabot, secret scanning, CodeQL), CI `pre-commit run --all-files`,
licence, et relecture des mentions « Synology / DSM » éventuelles du README racine.
