# CLAUDE.md — dépôt tabibi-mobile de Ndawik (anciennement Tabibi)

Règles communes de tout le projet : https://github.com/Ariles2025-ops/tabibi-infra-docs/blob/main/CLAUDE.md

## Marque : la plateforme s'appelle **Ndawik** (depuis le 17/11/2026)

> À lire par tout agent (développeur, relecteur, chef d'équipe, réparateur, brigade de revue, cohérence, chasse aux erreurs) et tout humain.

- **Nom** : **Ndawik** — en arabe **نداويك** (« je te soigne »). Ancien nom : **Tabibi** (à ne plus utiliser dans les textes visibles, sauf la mention discrète « anciennement Tabibi » pendant la transition).
- **Éditeur** : HADEV Studio (inchangé).
- **Nature** : une **plateforme médicale** algérienne (rendez-vous, médecins, secrétaires, ordonnances, messagerie, visio, médicaments). Jamais « annuaire » dans un texte visible.
- **Adresse publique du site** : **https://ndawik.com** (https://tabibi.doctor y redirige).
- **Restent sur tabibi.doctor pour l'instant** (ne pas changer sans ticket dédié) : l'API `https://api.tabibi.doctor`, la connexion Keycloak `https://auth.tabibi.doctor` (realm `tabibi`), les adresses e-mail `@tabibi.doctor`.
- **Ne jamais renommer les identifiants techniques** : dépôts `tabibi-*`, packages Java `dz.tabibi…`, applicationId Android `dz.tabibi.app`, redirection `dz.tabibi.app:/oauthredirect`, noms de tables, de classes, de variables d'environnement (`DOMAINE` = domaine API/auth ; `SITE_DOMAINE` = domaine public du site).
- **Tout nouveau texte visible** (FR, AR, EN si présent), titre, e-mail, SMS, notification, page légale, donnée structurée : utiliser **Ndawik / نداويك**.
- Charte graphique inchangée (vert #0F7560, or #D4A437, Plus Jakarta Sans ; IBM Plex Sans Arabic en arabe).
- Choix voulus inchangés : pré-lancement (connexion → /bientot, bandeau), le chiffre « 75 000 », visio « Bientôt », gratuité, aucun message envoyé aux médecins/patients par les agents.
