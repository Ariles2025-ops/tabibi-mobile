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

## v0.7.0 — Messagerie
- Ecran « Messagerie » (`GET /api/conversations`, jeton PATIENT) : praticien (nom via `GET /api/medecins/{id}`
  quand l'identifiant est numerique, sinon « Médecin n° ... »), en gras s'il reste des non lus, « Dernier
  message le ... » (ou « Ouverte le ... »), pastille « n non lus » ; tirer pour rafraichir, invitation
  « Se connecter » sans jeton, erreurs `VueErreur`, jeton expire (401) -> deconnexion ; rechargement au retour
  du fil.
- Fil (`GET /api/conversations/{id}/messages`, marque lus les messages recus) : bulles a droite pour mes
  messages, a gauche pour ceux du praticien, date sous chaque bulle, liste inversee (dernier message en bas) ;
  saisie limitee a 2000 caracteres, bouton « Envoyer » desactive a vide, `POST /api/conversations/{id}/messages`
  puis rechargement ; 400 (vide ou trop long) affiche tel quel.
- Fiche medecin : « Ouvrir une conversation » (`POST /api/conversations`, 201 ou 200, connexion a la volee)
  puis ouverture du fil ; 403 -> « Vous devez avoir un rendez-vous avec ce médecin pour lui écrire. ».
- Accueil : entree « Messagerie ».
- Identite : `AuthService.sujet` (sujet `sub` du jeton, `lib/utils/jetons.dart`, sans verification de
  signature) pour reconnaitre mes messages (`auteurId == moi`) ; repli sur le `patientId` de la conversation.
- Modeles `Conversation` (`lib/models/conversation.dart`, `fromJson` tolerant, `derniereActivite`) et `Message`
  (`lib/models/message.dart`, `fromJson` tolerant, `estLu`) ; utilitaires `lib/utils/messagerie.dart`
  (`estDeMoi`, `alignementMessage`, `dateMessage`, `libelleActivite`, `libelleNonLus`, `trierParActivite`) ;
  `ApiService.mesConversations`, `ouvrirConversation`, `messages`, `envoyerMessage` (corps JSON UTF-8,
  identifiants en texte).
- Tests : `test/messagerie_test.dart` (fromJson complets et valeurs nulles, alignement selon l'auteur, dates,
  libelles, tri, sujet du jeton) ; `test/widget_test.dart` (liste puis ouverture du fil, bulles alignees,
  « Envoyer » inactif a vide puis envoi et rafraichissement, fiche : ouverture et refus 403, entree d'accueil) ;
  `test/outils.dart` (jeton JWT factice porteur du sujet).

## v0.8.0 — Avis
- « Mes rendez-vous » : bouton « Donner mon avis » sur les rendez-vous HONORE (desormais non annulables), ou
  « Avis donné » si un avis existe deja (`GET /api/avis/mes`, echec tolere) ; rechargement apres le depot.
- Ecran « Mon avis » (`lib/pages/deposer_avis_page.dart`) : praticien et date en rappel, note obligatoire de 1
  a 5 (cinq `ChoiceChip`), commentaire facultatif (500 caracteres), « Envoyer mon avis » inactif sans note ;
  `POST /api/avis` puis « Merci pour votre avis. » et fermeture (`pop(true)`) ; 409 -> « Vous avez déjà donné
  votre avis pour ce rendez-vous. », autres erreurs affichees, jeton expire (401) -> deconnexion.
- Ecran « Mes avis » (`GET /api/avis/mes`) : praticien (nom via l'annuaire, repli « Médecin n° ... »),
  « 4 / 5 · Publié », commentaire, « Déposé le ... » ; entree « Mes avis » sur l'accueil.
- Fiche medecin : moyenne « 4,5 / 5 (12 avis) » (virgule francaise, « Aucun avis ») et section « Avis des
  patients » (derniers avis anonymes : note, commentaire, date, cinq au plus) via `GET /api/medecins/{id}/avis`
  (public) ; « Avis indisponibles pour le moment. » si l'appel echoue.
- Modeles `Avis` (`lib/models/avis.dart`, `fromJson` tolerant, `aCommentaire`) et `SyntheseAvis`
  (`lib/models/synthese_avis.dart`, `fromJson` tolerant, `aDesAvis`) ; utilitaires `lib/utils/avis.dart`
  (`noteValide`, `formaterDecimal`, `formaterMoyenne`, `formaterNote`, `libelleStatutAvis`, `dateAvis`,
  `estHonore`) ; `ApiService.deposerAvis` (corps JSON, commentaire omis s'il est vide), `mesAvis`,
  `avisDuMedecin`.
- Tests : `test/avis_test.dart` (fromJson complets et valeurs nulles, synthese, moyenne avec virgule et
  « Aucun avis », note, statuts, date, `noteValide`, `estHonore`) ; `test/widget_test.dart` (fiche avec
  synthese et derniers avis, fiche sans avis, parcours « Donner mon avis » avec note obligatoire puis
  « Avis donné », refus 409, « Mes avis », entree d'accueil).

## v0.9.0 — Dawini (pharmacies)
- Ecran « Dawini » (`lib/pages/dawini_page.dart`, jeton PATIENT, invitation « Se connecter » sans jeton) :
  formulaire (medicament et code de wilaya obligatoires, commune et precision facultatives ; champ texte
  pour la wilaya faute de selecteur dans l'annuaire mobile), refus local sans medicament (« Indiquez le
  médicament recherché. ») ou sans wilaya, `POST /api/dawini/besoins` (400 affiche), « Demande publiée. »,
  formulaire vide et liste rechargee ; « Mes demandes » (`GET /api/dawini/besoins/mes`, tri par publication) :
  medicament, lieu et statut (Ouverte, Clôturée), date, « n réponses ».
- Ecran « Réponses des pharmacies » (`lib/pages/reponses_besoin_page.dart`,
  `GET /api/dawini/besoins/{id}/reponses`) : rappel de la demande, cartes pharmacie / « Disponible » ou
  « Indisponible » / prix « 850 DA » / commentaire / date ; « Clôturer la demande » (confirmation,
  `POST /api/dawini/besoins/{id}/cloturer`) tant qu'elle est ouverte ; 409 -> « Cette demande est déjà
  clôturée. » et statut cloture localement ; jeton expire (401) -> deconnexion ; liste rechargee au retour.
- Accueil : entree « Dawini (pharmacies) ».
- Modeles `BesoinMedicament` (`lib/models/besoin_medicament.dart`, `fromJson` tolerant, copie `cloturer`) et
  `ReponsePharmacie` (`lib/models/reponse_pharmacie.dart`, `fromJson` tolerant) ; utilitaires
  `lib/utils/dawini.dart` (`formaterPrix`, `libelleStatutBesoin`, `libelleReponses`, `libelleDisponibilite`,
  `estOuvert`, `lieuBesoin`, `dateBesoin`, `dateReponse`, `trierParPublication`) ; `ApiService.publierBesoin`
  (corps JSON), `mesBesoins`, `cloturerBesoin` (sans lecture du corps de reponse), `reponsesBesoin`.
- Tests : `test/dawini_test.dart` (fromJson complets et valeurs nulles, copie cloturee, prix, statuts, accords,
  lieu, dates, tri) ; `test/widget_test.dart` (formulaire refuse sans medicament puis sans wilaya, publication
  et liste, reponses puis cloture, refus 409, sans jeton, entree d'accueil ; aides `surfaceHaute` pour les
  ecrans longs, appliquee aussi a la fiche avec avis, et `laisserPasserLeMessage` entre deux SnackBar).

## v0.9.1 — Correctif identifiants
- Bug bloquant a l'execution : le backend identifie tout par des UUID serialises en texte
  (`"00000000-0000-0000-0000-000000000001"` pour le premier praticien de demonstration ; `id`,
  `medecinId`, `creneauId`, `rendezVousId`, `conversationId`, `besoinId`... dans toutes les vues),
  alors que l'application lisait plusieurs identifiants comme des entiers (`m['id'] as int`,
  `rdv['medecinId'] as int`, `creneau['id'] as int`, `int.tryParse(medecinId)`, `is! int`) et
  typait `int` les parametres de `ApiService.medecin`, `creneaux`, `reserverCreneau`, `annuler`,
  `ordonnance`, `ouvrirConversation`, `deposerAvis`, `avisDuMedecin` ainsi que `FicheMedecinPage`,
  `DetailOrdonnancePage` et `DeposerAvisPage` : `as int` plantait sur un vrai UUID, la fiche et
  les creneaux ne s'ouvraient pas, et les noms de praticiens n'etaient jamais resolus dans la
  messagerie et « Mes avis » (fiche demandee « uniquement si l'identifiant est numerique »).
- Tous les identifiants sont desormais des `String` de bout en bout : parametres des huit
  methodes ci-dessus (chemins construits avec `Uri.encodeComponent`), champs `medecinId`,
  `ordonnanceId`, `rendezVousId` des pages, creneau en cours de reservation, cache des noms de
  praticiens (`Map<String, String>`), corps JSON `{"medecinId": "<uuid>"}` et
  `{"rendezVousId": "<uuid>", ...}` en texte. Les compteurs (`nonLues`, `nombre`, `note`,
  `prixDa`, `dureeMinutes`) restent des `int`.
- Nouvel utilitaire `lib/utils/identifiants.dart` : `identifiant(Object?)` (valeur en texte,
  tolere un nombre, chaine vide si absente ; remplace tous les `as int` sur des identifiants),
  `abreger(String)` (8 premiers caracteres, premier groupe de l'UUID) et `libelleMedecin(String)`
  (« Médecin 00000000 », « Médecin inconnu » sans identifiant). Comparaisons en texte
  (`identifiant(c['id']) == creneauId`), aucun tri ne depend d'un type numerique.
- Messagerie, « Mes avis », « Mes rendez-vous », detail d'ordonnance : le nom du praticien est
  toujours resolu via `GET /api/medecins/{id}` ; en cas d'echec, repli « Médecin » suivi de
  l'identifiant abrege (plus jamais « Médecin n° ... » ni un UUID entier a l'ecran).
- Tests : `FakeApiService` et ses variantes signent `String` comme `ApiService` (verifie par
  script, hors SDK) ; fixtures en UUID (`FakeApiService.medecinDemo` =
  `00000000-0000-0000-0000-000000000001`, `sujetPatient`, `rdvHonore`, `ordonnanceDemo`,
  `conversationDemo`...) ; variante `FakeApiServiceSansFiche` (404 sur la fiche) pour le repli
  « Médecin 00000000 » dans la messagerie, « Mes rendez-vous » et le detail d'ordonnance ;
  `test/identifiants_test.dart` ; `test/ordonnances_test.dart` avec des identifiants en texte.

## v0.10.0 — Configuration par environnement
- `lib/config/configuration.dart` : `Configuration.apiUrl`, `issuer`, `clientId`, `redirect`, constantes
  `String.fromEnvironment` (`TABIBI_API_URL`, `TABIBI_ISSUER`, `TABIBI_CLIENT_ID`, `TABIBI_REDIRECT`)
  fixees par `--dart-define` a la compilation ; valeurs par defaut de l'emulateur Android
  (`http://10.0.2.2:8080`, `http://10.0.2.2:8081/realms/tabibi`, `tabibi-mobile`,
  `dz.tabibi.app:/oauthredirect`, aussi exposees en `apiUrlParDefaut`...) ; simulateur iOS :
  `--dart-define=TABIBI_API_URL=http://localhost:8080` (et `TABIBI_ISSUER` sur localhost).
- `ApiService` : plus de constante `_base` ; `const ApiService({this.base = Configuration.apiUrl})`
  (parametre nomme optionnel pour les tests), chemins construits sur `base`. `AuthService` : plus de
  constantes `_issuer`, `_clientId`, `_redirect`, lecture de `Configuration`.
- README : section « Configuration » (tableau des variables, commandes `flutter run --dart-define=...`
  pour l'emulateur Android, le simulateur iOS, un appareil physique et la production en HTTPS ;
  rappel du schema de redirection a declarer dans les projets natifs).
- Tests : `test/configuration_test.dart` (configuration par defaut = emulateur Android, constantes
  `...ParDefaut`, adresses sans barre oblique finale, `ApiService().base` par defaut ou fournie).
