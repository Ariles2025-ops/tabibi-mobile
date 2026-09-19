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

## v0.11.0 — Mon profil
- Ecran « Mon profil » (`lib/pages/mon_profil_page.dart`, utilisateur connecte, invitation « Se connecter »
  sans jeton) : `GET /api/moi/profil` preremplit le formulaire, un 404 (profil jamais renseigne) laisse
  le formulaire vide sans erreur ; nom complet obligatoire (120 caracteres au plus), telephone (clavier
  telephone, numero algerien de 9 a 10 chiffres commencant par 0 verifie localement, espaces retires),
  date de naissance facultative (`showDatePicker`, de 1901 a hier, icone « Effacer la date »), wilaya
  (code, deux chiffres), langue (`DropdownButton` Français / العربية / Taqbaylit / English -> fr, ar,
  kab, en) ; « Enregistrer » -> refus local (« Indiquez votre nom complet. », telephone invalide) puis
  `PUT /api/moi/profil` avec `Profil.toJson()`, « Profil enregistré. » et formulaire realigne sur la vue
  renvoyee (« Mis à jour le ... ») ; 400 affiche tel quel, jeton expire (401) -> deconnexion.
- Accueil : entree « Mon profil ».
- Modele `Profil` (`lib/models/profil.dart`, `fromJson` tolerant : date ramenee au jour, langue par defaut
  fr ; `toJson` = {nomComplet, telephone, dateNaissance yyyy-MM-dd ou null, wilayaCode, langue}, sans
  identifiant ni date de mise a jour ; constantes `langues`, `langueParDefaut`) ; utilitaires
  `lib/utils/profil.dart` (`libellesLangues`, `libelleLangue`, `messageTelephoneInvalide`,
  `normaliserTelephone`, `telephoneValide`, `libelleDateNaissance`, `libelleMiseAJour`) et
  `formaterJour` dans `lib/utils/dates.dart` ; `ApiService.monProfil` (404 en `ApiException`),
  `enregistrerProfil(Map, token)` (PUT, corps JSON UTF-8).
- Tests : `test/profil_test.dart` (fromJson complet et valeurs nulles, toJson avec date, sans date et
  date horodatee, langues, telephone valide / invalide, normalisation, libelles), `test/dates_test.dart`
  (`formaterJour`) ; `test/widget_test.dart` (`FakeApiService` etendu : `monProfil`, `enregistrerProfil` ;
  variantes `FakeApiServiceProfil` (enregistrements conserves), `FakeApiServiceSansProfil` (404),
  `FakeApiServiceProfilInvalide` (400) ; formulaire prerempli puis enregistrement avec date effacee et
  langue anglaise, 404 -> formulaire vide, nom obligatoire, telephone invalide, date choisie dans le
  selecteur puis enregistrement, refus 400 affiche, sans jeton, entree d'accueil).

## v0.12.0 — Liste d'attente par medecin
- Fiche medecin (`lib/pages/fiche_medecin_page.dart`) : section « Liste d'attente » entre les creneaux et
  les avis, texte « Vous serez notifié dès qu'un créneau se libère. » (`texteListeAttente`) et bouton
  « M'inscrire sur la liste d'attente » (`POST /api/medecins/{id}/liste-attente`, 201, connexion a la
  volee) ; succes -> « Inscription enregistrée. ... » et texte d'etat `texteInscrit` a la place du bouton ;
  409 -> « Vous êtes déjà inscrit sur cette liste. » (`messageDejaInscrit`) et meme etat ; jeton expire
  (401) -> deconnexion. Pas d'appel authentifie a l'ouverture de la fiche (ecran public) : l'etat
  « inscrit » n'est connu qu'apres une inscription ou un 409.
- Ecran « Mes listes d'attente » (`lib/pages/mes_listes_attente_page.dart`, `GET /api/liste-attente/mes`,
  jeton PATIENT, invitation « Se connecter » sans jeton) : cartes praticien (nom via `GET /api/medecins/{id}`,
  repli `libelleMedecin`) + « Inscription le ... », tri par date d'inscription (plus anciennes d'abord, ordre
  de la file) ; « Me retirer » -> boite de confirmation (« Non » / « Oui, me retirer »),
  `POST /api/liste-attente/{id}/retirer` (204 sans corps, `_verifier` seulement), « Retrait de la liste
  d'attente effectué. » et carte retiree localement (404 : retiree aussi, message de l'API) ; erreurs
  `VueErreur`, jeton expire (401) -> deconnexion ; etat vide explicatif.
- Accueil : entree « Liste d'attente ».
- Modele `InscriptionAttente` (`lib/models/inscription_attente.dart`, `fromJson` tolerant : id, patientId,
  medecinId, inscritLe) ; utilitaires `lib/utils/liste_attente.dart` (`dateInscription`,
  `trierParInscription`) ; `ApiService.inscrireListeAttente`, `mesInscriptionsAttente`,
  `retirerListeAttente` (identifiants UUID en texte, chemins encodes).
- Tests : `test/liste_attente_test.dart` (fromJson complet et valeurs nulles, date, tri) ;
  `test/widget_test.dart` (`FakeApiService` etendu : `mesInscriptionsAttente`, `inscrireListeAttente`,
  `retirerListeAttente`, fixture `inscriptionDemo` ; variantes `FakeApiServiceListeAttente`
  (inscriptions et retraits conserves, inscription retiree absente de la liste) et
  `FakeApiServiceDejaInscrit` (409) ; inscription depuis la fiche puis texte d'etat, refus 409, liste avec
  praticien et date puis refus dans la confirmation et retrait, repli « Médecin 00000000 »
  (`FakeApiServiceSansFiche`), sans jeton, entree d'accueil ; `surfaceHaute` sur la fiche sans avis).

## v0.13.0 — Integration continue et preparation des stores
- `.github/workflows/ci.yml` (GitHub Actions, `push` et `pull_request`, `permissions: contents:
  read`, `concurrency` par branche, `timeout-minutes: 30`) : `actions/checkout@v4`,
  `actions/setup-java@v4` (Temurin 17 pour Gradle), `subosito/flutter-action@v2`
  (`channel: stable`, `cache: true`), `flutter --version`, `flutter pub get`, `flutter analyze`,
  `flutter test`, `tool/preparer_android.sh`, `flutter build apk --debug`,
  `actions/upload-artifact@v4` (`app-debug.apk`, sept jours). Android uniquement : iOS (macOS,
  Xcode, certificats Apple) reste manuel et documente.
- `tool/preparer_android.sh` (bash + perl, executable) : `android/` n'etant pas versionne, le
  genere avec `flutter create . --platforms=android --org dz.tabibi --project-name tabibi_mobile`
  s'il manque, puis remplace `applicationId` par `dz.tabibi.app`, ajoute `manifestPlaceholders`
  `appAuthRedirectScheme` (obligatoire pour compiler avec `flutter_appauth` ; syntaxe Kotlin DSL
  `build.gradle.kts` ou Groovy `build.gradle`) et l'intent VIEW https dans `<queries>`
  (`url_launcher`) ; idempotent. Verifie hors SDK sur des extraits de templates Groovy ancien /
  recent et Kotlin DSL, avec et sans `<queries>`.
- `analysis_options.yaml` deja en place (`package:flutter_lints/flutter.yaml`,
  `flutter_lints: ^5.0.0` en devDependency) ; `.gitignore` : `android/key.properties`,
  `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.mobileprovision` ; `pubspec.yaml` :
  `version: 0.13.0+1` (versionName 0.13.0, versionCode 1 ; le numero apres `+` s'incremente a
  chaque envoi sur un store).
- README : « Note plateforme » (script), « Integration continue », « Publication » (version,
  valeurs de production par `--dart-define`, icone et ecran de lancement a fournir via
  `flutter_launcher_icons` / `flutter_native_splash` sans fichier binaire dans le depot,
  exigences des stores pour des donnees de sante ; Android : script, `keytool -genkey`,
  `android/key.properties`, `signingConfigs` en Kotlin DSL, `flutter build appbundle --release`,
  Play Console ; iOS : `flutter create . --platforms=ios`, bundle id `dz.tabibi.app` et signature
  automatique dans Xcode, `CFBundleURLTypes` / `LSApplicationQueriesSchemes` dans `Info.plist`,
  `flutter build ipa`, Transporter / Organizer, TestFlight, revue) ; « Prochaines etapes » :
  signature release en CI par secrets, iOS sur macOS.

## v0.14.0 — Ordonnance imprimable (PDF)
- Detail d'une ordonnance (`lib/pages/detail_ordonnance_page.dart`) : bouton « Ouvrir le PDF »
  (icone PDF, indicateur pendant le telechargement) sous la carte du code de verification ;
  `GET /api/ordonnances/{id}/pdf` (jeton, `Accept: application/pdf`), fichier
  `ordonnance-<code>.pdf` ecrit dans `getTemporaryDirectory()` (`path_provider`) puis
  `OpenFilex.open(chemin, type: application/pdf)` (`open_filex`) ; echec d'ecriture ou
  d'ouverture (`ResultType` autre que `done`, exception) -> SnackBar `messagePdfImpossible` ;
  erreur de l'API affichee telle quelle, jeton expire (401) -> deconnexion.
- `ApiService.ordonnancePdf(String id, String token)` -> `Future<Uint8List>` : `_verifier`
  (erreurs `{ "erreur": ... }` comme ailleurs) puis controle du `Content-Type` (`estPdf`, casse
  et parametres toleres ; sinon `ApiException(statut, messagePasUnPdf)`) ; `typePdf` partage.
- `lib/utils/ordonnances.dart` : `nomFichierPdf(ordonnance)` (code de verification reduit a
  `[A-Za-z0-9_-]`, repli sur l'identifiant abrege, puis `ordonnance.pdf`).
- Injection : `typedef EnregistrerEtOuvrir = Future<bool> Function(String, Uint8List)`,
  parametre `enregistrerEtOuvrir` de `DetailOrdonnancePage` (defaut `enregistrerEtOuvrirFichier`,
  implementation reelle, comme `ouvrirLien` pour la teleconsultation) : les tests de widget ne
  chargent aucun greffon.
- `pubspec.yaml` : `path_provider: ^2.1.4`, `open_filex: ^4.5.0`, `version: 0.14.0+1` ;
  `tool/preparer_android.sh` : intent VIEW `application/pdf` dans `<queries>` (idempotent,
  verifie hors SDK sur un manifeste factice).
- README : section v0.14.0, note plateforme et publication mises a jour.
- Tests : `FakeApiService.ordonnancePdf` (`pdfDemo`, octets `%PDF-1.4`) et
  `FakeApiServiceSansPdf` (404) ; `test/widget_test.dart` (bouton, appel avec
  `ordonnance-ABC123.pdf` et octets `%PDF`, bouton reactive ; ouverture refusee -> message ; 404
  -> message de l'API sans ecriture) ; `test/ordonnances_test.dart` (`nomFichierPdf`, `estPdf`).

## v0.15.0 — Interface en francais, arabe et anglais (RTL)
- Dictionnaires `lib/i18n/traductions.dart` : `Map<String, Map<String, String>>` pour `fr`,
  `ar` et `en`, memes cles dans les trois langues (250 cles, un test le verifie), parametres
  `{nom}` remplaces par `traduire(langue, cle, params: ...)` et formes plurielles
  `<cle>.zero|un|deux|peu|beaucoup` (`traduirePluriel`, `formePlurielle`) : le duel et le
  pluriel restreint de l'arabe sont distingues (« رد واحد », « ردان », « 3 ردود »). Aucune
  generation de code, aucun `flutter gen-l10n`, aucun fichier ARB.
- `lib/i18n/langue.dart` : `ControleurLangue` (`ChangeNotifier`) partage par l'application
  (`langues`, comme `session`), expose `langue`, `locale`, `direction` (RTL en arabe) et
  `localesPrisesEnCharge` ; `initialiser` prend la langue memorisee
  (`shared_preferences: ^2.3.0`, cle `tabibi.langue`) sinon la locale du telephone
  (`langueDeLocale` : ar -> ar, en -> en, sinon fr) ; `choisir` (choix explicite, memorise) et
  `suivreLeProfil` (langue du profil serveur, ignoree des qu'un choix a ete fait, et ignoree
  pour « kab », acceptee par l'API mais pas encore traduite). `LangueScope`
  (`InheritedNotifier`) porte le controleur, `t(context, cle, {params})` et
  `tp(context, cleBase, n)` lisent la portee la plus proche (repli sur `langues` dans les
  tests d'un ecran isole), `messageApi(context, erreur)` traduit les erreurs de l'API.
- `MaterialApp` (`lib/main.dart`) : `locale`, `supportedLocales` (fr, ar, en) et
  `localizationsDelegates` (`flutter_localizations: sdk: flutter`, delegues Material, Widgets
  et Cupertino) ; la direction d'ecriture vient de la locale (le `Localizations` de Flutter
  pose lui-meme la `Directionality`), donc les widgets Material suivent. `ListenableBuilder`
  sur le controleur : changer de langue rebatit l'application. `TabibiApp` accepte desormais
  un controleur, une API et une session (tests).
- Ecran « Langue » (`lib/pages/langue_page.dart`) et entree « Langue » sur l'accueil :
  Français / العربية / English, choix applique et memorise, confirmation dans la langue
  choisie.
- Migration de tous les libelles : les 15 ecrans, `lib/widgets/` et `lib/utils/` passent par
  les dictionnaires ; les utilitaires prennent la langue en premier parametre
  (`dateAvis(langue, avis)`, `libelleStatut(langue, statut)`, `libelleMedecin(langue, id)`...)
  et les constantes de libelles des pages (`messageDejaInscrit`, `texteConsentement`,
  `messageTelephoneInvalide`...) disparaissent au profit de cles. Les statuts bruts de l'API
  (CONFIRME, EMISE, OUVERT, PLANIFIEE...) sont traduits par les cles `statut.<BRUT>`, un
  statut inconnu gardant la mise en forme generique.
- Dates : `intl: ^0.19.0`, `preparerDates()` (`initializeDateFormatting`) appele au demarrage
  et dans les tests ; `formaterDateHeure`, `formaterDateIso` et `formaterJour` utilisent
  `DateFormat` avec le motif et la locale de la langue (`dates.dateHeure`, `dates.jour`,
  `dates.locale` : `fr`, `en`, `ar_DZ` pour l'arabe algerien), avec repli si la locale n'est
  pas chargee (`localeDates`). Les libelles francais portent donc leurs accents
  (« jeu. 3 déc. 10:15 »).
- Droite a gauche : alignements directionnels (`AlignmentDirectional.centerStart` / `centerEnd`)
  pour les bulles de la messagerie (`alignementMessage`), l'accueil, la fiche et le detail
  d'une ordonnance.
- Erreurs de l'API : `ApiException(statut, message, {cle, params})` ; le message du serveur
  (`{"erreur": ...}`) reste affiche tel quel, les libelles par defaut (401, 403, 404, 409,
  echec generique, PDF invalide) portent une cle traduite a l'affichage.
- `pubspec.yaml` : `flutter_localizations` (SDK), `intl: ^0.19.0`,
  `shared_preferences: ^2.3.0`, `version: 0.15.0+1`.
- `tool/verifier_libelles.py` : relit les chaines litterales des ecrans (hors commentaires) et
  echoue si l'une porte un caractere accentue francais, c'est-a-dire un libelle non traduit.
- Tests : `test/i18n_test.dart` (memes cles dans les trois dictionnaires, aucune valeur vide,
  termes de sante arabes, parametres, replis, pluriels, langue initiale selon la locale,
  direction, choix de l'utilisateur contre langue du profil, `t` suivant la portee) ;
  `test/widget_test.dart` bascule l'application en arabe depuis l'ecran « Langue » et verifie
  les libelles arabes, la memorisation du choix et
  `Directionality.of(context) == TextDirection.rtl` ; `test/outils.dart` expose
  `preparerTests` (dates chargees, interface forcee en francais) et `libelle` / `libelleArabe`,
  utilises par tous les fichiers de test.
