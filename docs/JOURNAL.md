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

## v0.6.0 — Teleconsultation
- Ecran « Mes teleconsultations » (`GET /api/teleconsultations/mes`, jeton PATIENT) : une carte par session,
  date selon l'avancement (« Proposee le ... » a la planification, « Demarree le ... », « Terminee le ... »)
  et statut (Planifiee, En cours, Terminee, Annulee) ; invitation « Se connecter » sans jeton, erreurs
  `VueErreur`, jeton expire (401) -> deconnexion ; etat vide « Aucune teleconsultation pour le moment. ».
- Consentement explicite : tant que `consentementPatientLe` est nul et que la session est planifiee ou en
  cours, carte d'information (video via un service tiers Jitsi Meet, aucun enregistrement par Tabibi) et
  bouton « Je donne mon consentement » (`POST /api/teleconsultations/{id}/consentir`) ; la vue renvoyee
  (avec `lienSalle`) remplace l'element ; erreurs 409 (terminee / annulee) affichees telles quelles.
- « Rejoindre la teleconsultation » quand `lienSalle` est present et la session planifiee ou en cours
  (`peutRejoindre`) : ouverture dans le navigateur externe via `url_launcher`
  (`LaunchMode.externalApplication`), liens http(s) seulement ; sinon texte d'etat (terminee, annulee,
  lien a venir). Ouverture injectable (`ouvrirLien`) pour les tests.
- Accueil : entree « Teleconsultations » a cote de « Notifications (n) ».
- Modele `Teleconsultation` (`lib/models/teleconsultation.dart`, `fromJson` tolerant, `aConsenti`),
  utilitaires `lib/utils/teleconsultations.dart` (`libelleStatutTeleconsultation`, `estActive`,
  `peutRejoindre`, `dateTeleconsultation`) ; `ApiService.mesTeleconsultations`, `teleconsultation`,
  `consentir` (identifiants UUID en texte).
- Dependance `url_launcher: ^6.3.0` ; declaration `<queries>` (intent VIEW https) a ajouter au manifeste
  Android genere par `flutter create .` (voir README).
- Tests : `test/teleconsultations_test.dart` (fromJson complet et valeurs nulles, libelles, `peutRejoindre`
  et `estActive`, date selon l'avancement) ; `test/widget_test.dart` (carte de consentement quand le
  consentement est nul, bouton « Rejoindre » apres consentement et lien ouvert, texte d'etat d'une session
  terminee, sans jeton, entree d'accueil).
