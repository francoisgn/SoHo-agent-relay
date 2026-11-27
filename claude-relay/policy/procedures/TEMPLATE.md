# Procédure : <titre court>

<!--
Modèle obligatoire pour toute action qui scie la branche du relais (redémarrage de l'hôte,
du démon Docker ou du conteneur claude-relay, changement réseau, SSH, stockage, mise à jour
DSM ou paquet Container Manager…). Le relais N'EXÉCUTE PAS ces procédures : il les écrit
dans /workspace/handoff/<AAAA-MM-JJ>-<sujet>.md (statut PROPOSED), et l'agent du poste
de l'opérateur, hors de l'hôte, les relit, les fait valider, les exécute et en rend compte.
Chaque commande doit être copiable telle quelle, idempotente si possible, sans secret.
-->

- **Statut** : PROPOSED | APPROVED | RUNNING | DONE | ROLLED-BACK | ABANDONED
- **Rédigée par** : claude-relay, <date ISO>
- **Exécutant** : agent du poste opérateur (hors de l'hôte), après « oui » de l'opérateur
- **Cible** : <hôte / service / conteneur>
- **Pourquoi** : <symptôme constaté, preuves (commandes et sorties utiles), lien éventuel>
- **Impact attendu** : <ce qui s'arrête, combien de temps ; le relais sera-t-il coupé ?>
- **Fenêtre conseillée** : <quand, et ce qu'il ne faut pas interrompre (téléchargements, scans…)>

## 0. Pré-requis et points de non-retour

- [ ] Accès hors relais vérifié : `ssh <hôte> true` depuis le poste opérateur
- [ ] Sauvegarde ou export de l'état actuel : <commandes ; où est stocké l'état>
- [ ] Aucune tâche longue en cours : <commande de contrôle>
- Point de non-retour : <étape au-delà de laquelle le rollback devient différent, ou « aucun »>

## 1. État initial (capture)

```sh
# commandes de lecture seule, sorties à conserver pour comparaison
```

## 2. Arrêt

```sh
```

## 3. Changement / relance

```sh
```

## 4. Tests de validation

| Test | Commande | Résultat attendu |
|---|---|---|
| Hôte joignable | `ssh <hôte> uptime` | répond |
| Services ciblés | | |
| Relais revenu | `ssh <hôte> 'sudo docker ps --filter name=claude-relay'` | `healthy` |
| Session Remote Control | app Claude → Code → session du relais | point vert |

## 5. Rollback

Déclencheur : un test de l'étape 4 échoue, ou <condition>.

```sh
# retour exact à l'état capturé en 1
```

## 6. Compte rendu (rempli par l'exécutant)

- Exécutée le : / par :
- Résultat des tests :
- Écarts, incidents :
- Statut final :
