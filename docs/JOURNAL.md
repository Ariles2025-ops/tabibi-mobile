# Journal des fonctionnalites (mobile)

## v0.1.0 — Socle
- Flutter (iOS + Android), connexion Keycloak (OIDC natif via `flutter_appauth`, realm `tabibi`),
  appel `GET /api/moi` avec le JWT, theme Tabibi (Material 3).

## v0.2.0 — Annuaire
- Ecran d'accueil : recherche de praticiens (nom, specialite) via `GET /api/medecins`.

## v0.3.0 — Reservation
- Fiche medecin et creneaux disponibles, reservation d'un creneau (connexion a la volee, 409 gere),
  ecran « Mes rendez-vous » avec annulation ; session partagee (`lib/services/session.dart`) ;
  `ApiException(statusCode, message)` ; `FakeApiService` injectable dans les tests.

## v0.4.0 — Ordonnances
- Ecrans « Mes ordonnances », detail (code de verification, medicaments) et verification publique
  d'un code ; `lib/utils/libelles.dart`, `lib/utils/ordonnances.dart`, `lib/widgets/vue_connexion.dart`.

## v0.5.0 — Notifications
- Ecran « Mes notifications » (`GET /api/notifications/mes`) : sujet en gras tant que non lue, message,
  date, tri de la plus recente a la plus ancienne, tirer pour rafraichir ; toucher ou icone
  « Marquer comme lue » (`POST /api/notifications/{id}/lue`), icone « Tout marquer comme lu » dans
  l'AppBar (`POST /api/notifications/toutes-lues`) ; etat vide « Aucune notification pour le moment. »,
  erreurs `VueErreur`, invitation « Se connecter » sans jeton ; jeton expire (401) -> deconnexion.
- Accueil : entree « Notifications (n) » (nombre de non lues via `GET /api/notifications/non-lues/nombre`)
  chargee a l'ouverture, apres connexion et au retour de chaque ecran ; « Notifications » sans compteur
  hors connexion ou si le compteur est indisponible.
- Modele `NotificationUtilisateur` (`lib/models/notification.dart`, `fromJson` tolerant, copie `marquerLue`),
  utilitaires `lib/utils/notifications.dart` (`dateNotification`, `trierParCreation`, `compterNonLues`,
  `libelleNotifications`) ; `ApiService.mesNotifications`, `nombreNonLues`, `marquerLue`, `toutMarquerLu`
  (identifiants UUID en texte, corps `{ "nombre": n }` lu par `_nombre`).
- Tests : `test/notifications_test.dart` (fromJson complet et valeurs nulles, copie lue, date, tri, compteur,
  libelle) ; `test/widget_test.dart` (liste et marquage lu, tout marquer lu, etat vide, sans jeton,
  entree d'accueil avec et sans compteur).
