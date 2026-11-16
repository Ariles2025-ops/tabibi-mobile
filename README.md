# tabibi_mobile

Application mobile Tabibi — **Flutter** (iOS + Android), un seul code.

## Ce que fait cette premiere version
- Connexion **Keycloak** (OIDC natif via `flutter_appauth`, realm `tabibi`).
- Appel `GET /api/moi` avec le JWT, affichage utilisateur + roles.
- Theme aux couleurs Tabibi (vert #0F7560), Material 3.

## Lancer
```bash
flutter pub get
flutter run          # emulateur Android : valeurs par defaut (10.0.2.2), voir « Configuration »
# necessite l'API + Keycloak (docker compose up) en marche
```

## Configuration
Aucune adresse n'est codee en dur : `lib/config/configuration.dart` (classe `Configuration`) lit
quatre variables fixees a la compilation avec `--dart-define` (`String.fromEnvironment`), et
`ApiService` comme `AuthService` s'y referent.

| Variable | Role | Valeur par defaut (emulateur Android) |
|---|---|---|
| `TABIBI_API_URL` | adresse de base de l'API (sans barre oblique finale) | `http://10.0.2.2:8080` |
| `TABIBI_ISSUER` | emetteur OIDC (realm Keycloak) | `http://10.0.2.2:8081/realms/tabibi` |
| `TABIBI_CLIENT_ID` | client public Keycloak (PKCE, aucun secret) | `tabibi-mobile` |
| `TABIBI_REDIRECT` | URI de redirection apres connexion | `dz.tabibi.app:/oauthredirect` |

```bash
# Emulateur Android : 10.0.2.2 designe la machine hote, rien a preciser.
flutter run

# Simulateur iOS : la machine hote est localhost.
flutter run --dart-define=TABIBI_API_URL=http://localhost:8080 \
            --dart-define=TABIBI_ISSUER=http://localhost:8081/realms/tabibi

# Appareil physique : adresse IP de la machine sur le reseau local (API et Keycloak).
flutter run --dart-define=TABIBI_API_URL=http://192.168.1.10:8080 \
            --dart-define=TABIBI_ISSUER=http://192.168.1.10:8081/realms/tabibi

# Production : API et Keycloak publics en HTTPS (memes options pour `flutter build`).
flutter build apk --release \
  --dart-define=TABIBI_API_URL=https://api.tabibi.dz \
  --dart-define=TABIBI_ISSUER=https://auth.tabibi.dz/realms/tabibi \
  --dart-define=TABIBI_CLIENT_ID=tabibi-mobile \
  --dart-define=TABIBI_REDIRECT=dz.tabibi.app:/oauthredirect
```
Les valeurs par defaut (`http://`) ne conviennent qu'au developpement local ; en production,
l'API et Keycloak sont servis en HTTPS. Le schema de l'URI de redirection (`dz.tabibi.app`)
doit etre declare dans les projets natifs (`appAuthRedirectScheme` sur Android, `CFBundleURLSchemes`
sur iOS), voir la documentation de `flutter_appauth`. Les tests (`flutter test`) s'executent sans
`--dart-define` et verifient les valeurs par defaut (`test/configuration_test.dart`).

## Note plateforme
Les projets natifs `ios/` et `android/` se generent avec `flutter create .`
(non versionnes ici pour rester leger). L'essentiel — code, auth, API, test — est present.
Pour Android, `tool/preparer_android.sh` genere le projet s'il manque et y applique la
configuration Tabibi (identifiant `dz.tabibi.app`, schema de redirection OAuth exige par
`flutter_appauth`, requete `<queries>` https pour `url_launcher`) ; il est relancable sans effet
de bord et sert aussi a la CI. Pour iOS, voir « Publication ».

## Integration continue
`.github/workflows/ci.yml` (GitHub Actions) s'execute a chaque `push` et `pull_request` :
`subosito/flutter-action@v2` (canal `stable`, cache), `flutter pub get`, `flutter analyze`
(`analysis_options.yaml` inclut `package:flutter_lints/flutter.yaml`), `flutter test`, puis
`tool/preparer_android.sh` et `flutter build apk --debug` ; l'APK de debogage est conserve sept
jours en artefact. Seul Android est construit en CI (JDK 17, `ubuntu-latest`) : la construction
iOS exige macOS, Xcode et les certificats Apple, elle reste manuelle (voir « Publication »).
Une execution en cours est annulee par un nouvel envoi sur la meme branche.

## Publication
Identifiant d'application sur les deux stores : `dz.tabibi.app` (aussi schema de l'URI de
redirection OAuth). Avant toute publication :
- `pubspec.yaml` : `version: 0.13.0+1` donne `versionName` / `CFBundleShortVersionString`
  (`0.13.0`) et `versionCode` / `CFBundleVersion` (`1`) ; incrementer le numero apres `+` a
  chaque envoi sur un store (et la version a chaque livraison fonctionnelle).
- Construire avec les valeurs de production (`--dart-define`, voir « Configuration ») : API et
  Keycloak en HTTPS, jamais les adresses de developpement.
- Icone et ecran de lancement : aucun fichier graphique n'est fourni dans ce depot. Prevoir une
  icone 1024 x 1024 (PNG, sans transparence pour iOS) et un visuel de lancement, puis les
  appliquer aux projets natifs, par exemple avec les paquets `flutter_launcher_icons` et
  `flutter_native_splash` (configuration dans `pubspec.yaml`, images dans `assets/`).
- Donnees de patients : fiche store avec politique de confidentialite (obligatoire sur Google
  Play et l'App Store pour une application de sante), declarations de collecte de donnees
  (Play « Securite des donnees », App Store « Confidentialite de l'app ») limitees au strict
  necessaire (identite, contact, rendez-vous), aucun suivi publicitaire.

### Android (Google Play)
1. Projet natif : `tool/preparer_android.sh` (genere `android/` et applique l'identifiant, le
   schema de redirection et la requete https). Une fois configure, le dossier `android/` peut
   etre versionne ; `key.properties` et le keystore ne le sont jamais (`.gitignore`).
2. Cle de signature (une seule fois, a conserver hors du depot et sauvegarder) :
   ```bash
   keytool -genkey -v -keystore ~/tabibi-release.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias tabibi
   ```
3. `android/key.properties` (non versionne) :
   ```properties
   storePassword=<mot de passe du keystore>
   keyPassword=<mot de passe de la cle>
   keyAlias=tabibi
   storeFile=/chemin/vers/tabibi-release.jks
   ```
4. Signature de la version release dans `android/app/build.gradle.kts` (Kotlin DSL ; meme
   principe en Groovy dans `build.gradle`) :
   ```kotlin
   import java.util.Properties
   import java.io.FileInputStream

   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }

   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
               storeFile = keystoreProperties["storeFile"]?.let { file(it) }
               storePassword = keystoreProperties["storePassword"] as String
           }
       }
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")
           }
       }
   }
   ```
5. Bundle signe (format exige par Google Play) :
   ```bash
   flutter build appbundle --release \
     --dart-define=TABIBI_API_URL=https://api.tabibi.dz \
     --dart-define=TABIBI_ISSUER=https://auth.tabibi.dz/realms/tabibi \
     --dart-define=TABIBI_CLIENT_ID=tabibi-mobile \
     --dart-define=TABIBI_REDIRECT=dz.tabibi.app:/oauthredirect
   # -> build/app/outputs/bundle/release/app-release.aab
   ```
6. Play Console : creer l'application (`dz.tabibi.app`, ne peut plus changer ensuite), activer
   la signature par Google Play (la cle ci-dessus devient la cle d'envoi), remplir la fiche
   (textes, captures, politique de confidentialite, securite des donnees), publier d'abord
   en test interne, puis en production progressive.

### iOS (App Store)
1. Sur macOS avec Xcode et un compte Apple Developer : `flutter create . --platforms=ios
   --org dz.tabibi --project-name tabibi_mobile` genere `ios/`.
2. Dans Xcode (`open ios/Runner.xcworkspace`), cible `Runner` : Bundle Identifier
   `dz.tabibi.app`, equipe de developpement et signature automatique (Xcode cree et renouvelle
   les certificats et profils de provisionnement ; rien a versionner).
3. `ios/Runner/Info.plist` : schema de redirection OAuth (`flutter_appauth`) et requete https
   (`url_launcher`) :
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key><string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array><string>dz.tabibi.app</string></array>
     </dict>
   </array>
   <key>LSApplicationQueriesSchemes</key>
   <array><string>https</string></array>
   ```
4. Archive signee et IPA :
   ```bash
   flutter build ipa --release \
     --dart-define=TABIBI_API_URL=https://api.tabibi.dz \
     --dart-define=TABIBI_ISSUER=https://auth.tabibi.dz/realms/tabibi \
     --dart-define=TABIBI_CLIENT_ID=tabibi-mobile \
     --dart-define=TABIBI_REDIRECT=dz.tabibi.app:/oauthredirect
   # -> build/ios/ipa/tabibi_mobile.ipa (et l'archive build/ios/archive/Runner.xcarchive)
   ```
5. Envoi vers App Store Connect avec l'application Transporter ou l'Organizer de Xcode
   (archive -> Distribute App), puis TestFlight (testeurs internes, puis externes apres la
   revue TestFlight) et enfin soumission a la revue de l'App Store avec la fiche complete
   (captures, confidentialite, categorie Medecine).

Simulateur iOS en developpement : `flutter run --dart-define=TABIBI_API_URL=http://localhost:8080`
(et `TABIBI_ISSUER` sur `localhost`), voir « Configuration ».

## Prochaines etapes
- Notifications push, stockage securise du jeton, rafraichissement du jeton.
- CI : signature release Android a partir de secrets GitHub (keystore encode en base64) et
  execution iOS sur `macos-latest` si un compte Apple Developer est rattache au depot.

## v0.2.0 — Annuaire (mobile)
- Ecran d'accueil : recherche de praticiens (nom, specialite) via `GET /api/medecins`.

## v0.3.0 — Reservation (mobile)
- Fiche medecin (`GET /api/medecins/{id}`) avec ses creneaux disponibles
  (`GET /api/medecins/{id}/creneaux`), dates en heure locale au format « jeu. 4 dec. 09:00 »
  (`lib/utils/dates.dart`, sans `intl`).
- Bouton « Reserver » par creneau (`POST /api/creneaux/{id}/reserver`, jeton PATIENT) :
  connexion Keycloak a la volee si necessaire ; « Rendez-vous confirme » et retrait du creneau
  en cas de succes, « Ce creneau vient d'etre pris » en cas de 409.
- Ecran « Mes rendez-vous » (`GET /api/rendezvous/mes`) : date, praticien, statut, et bouton
  « Annuler » avec confirmation (`POST /api/rendezvous/{id}/annuler`) ; bouton « Se connecter »
  si aucun jeton.
- Navigation : un praticien de la liste ouvre sa fiche ; dans l'AppBar, l'icone calendrier ouvre
  « Mes rendez-vous » et l'icone personne connecte l'utilisateur (ou confirme « Connecte »).
- Session partagee (`lib/services/session.dart`) : une seule instance d'`AuthService`, le jeton
  est conserve d'un ecran a l'autre.
- `ApiService` : `medecin`, `creneaux`, `reserverCreneau`, `mesRendezVous`, `annuler` ;
  erreurs HTTP (401, 403, 404, 409...) remontees en `ApiException(statusCode, message)`,
  corps decode en UTF-8.
- Tests : `ApiService` injectable dans les pages (`FakeApiService` dans `test/widget_test.dart`),
  test de la fiche medecin et du formatage des dates.

## v0.4.0 — Ordonnances (mobile)
- Ecran « Mes ordonnances » (`GET /api/ordonnances/mes`, jeton PATIENT) : date d'emission, code de
  verification et statut, de la plus recente a la plus ancienne ; bouton « Se connecter » sans jeton.
- Detail d'une ordonnance (`GET /api/ordonnances/{id}`) : praticien (nom resolu via
  `GET /api/medecins/{id}`, repli « Medecin n° ... »), date et statut, code de verification bien
  visible (`SelectableText` + bouton copier) et une carte par ligne (medicament, posologie, duree).
- Ecran public « Verifier une ordonnance » (`GET /api/ordonnances/verifier/{code}`, sans compte,
  par exemple en pharmacie) : saisie du code puis « Ordonnance authentique, emise le ... » (et statut)
  ou « Code inconnu » (`valide: false` ou 404).
- AppBar de la recherche : icone coche (verification publique) et icone document (mes ordonnances),
  a cote du calendrier et de la connexion.
- `ApiService` : `mesOrdonnances`, `ordonnance`, `verifierOrdonnance`.
- Partage : `lib/utils/libelles.dart` (`libelleStatut`, aussi utilise par les rendez-vous),
  `lib/utils/ordonnances.dart` (date d'emission, lignes, tri) et `lib/widgets/vue_connexion.dart`
  (invitation « Se connecter »).
- Tests : `FakeApiService` etendu (ordonnances, verification) ; liste, detail (code + medicaments),
  verification publique et utilitaires (`test/ordonnances_test.dart`).

## v0.5.0 — Notifications (mobile)
- Ecran « Mes notifications » (`GET /api/notifications/mes`, utilisateur connecte) : sujet en gras tant
  que la notification n'est pas lue, message et date (« jeu. 4 dec. 09:00 »), de la plus recente a la
  plus ancienne ; tirer pour rafraichir ; un toucher (ou l'icone « Marquer comme lue ») marque
  l'element lu (`POST /api/notifications/{id}/lue`) et l'icone « Tout marquer comme lu » de l'AppBar
  passe tout a lu (`POST /api/notifications/toutes-lues`) ; etat vide « Aucune notification pour le
  moment. », erreurs via `VueErreur`, bouton « Se connecter » sans jeton.
- Accueil : entree « Notifications (n) » sous la recherche, avec le nombre de non lues
  (`GET /api/notifications/non-lues/nombre`) charge a l'ouverture et actualise apres connexion et au
  retour de chaque ecran ; « Notifications » sans compteur hors connexion.
- Modele `lib/models/notification.dart` (`NotificationUtilisateur.fromJson`, tolerant aux champs
  absents ; nomme ainsi pour ne pas masquer `Notification` de Flutter) et `lib/utils/notifications.dart`
  (date, tri, compteur, libelle de l'entree). Les identifiants de ce module sont des UUID (texte).
- `ApiService` : `mesNotifications`, `nombreNonLues`, `marquerLue`, `toutMarquerLu`.
- Tests : modele et utilitaires (`test/notifications_test.dart`) ; `FakeApiService` etendu
  (notifications, variante sans notification) ; liste + marquage lu, tout marquer lu, etat vide,
  entree d'accueil avec et sans compteur.

## v0.6.0 — Teleconsultation (mobile)
- Ecran « Mes teleconsultations » (`GET /api/teleconsultations/mes`, jeton PATIENT) : une carte par
  session avec sa date (« Proposee le ... », « Demarree le ... » ou « Terminee le ... ») et son statut
  (Planifiee, En cours, Terminee, Annulee) ; bouton « Se connecter » sans jeton, erreurs via `VueErreur`.
- Consentement explicite : tant que `consentementPatientLe` est nul (session planifiee ou en cours),
  une carte rappelle que la seance se deroule en video via un service tiers (Jitsi Meet) sans
  enregistrement par Tabibi, avec le bouton « Je donne mon consentement »
  (`POST /api/teleconsultations/{id}/consentir`) ; la vue renvoyee, qui porte le lien de salle,
  remplace l'element.
- « Rejoindre la teleconsultation » des que le lien est remis et que la session est planifiee ou en
  cours : ouverture dans le navigateur externe (`url_launcher`, `LaunchMode.externalApplication`,
  liens http(s) seulement) ; sinon texte d'etat (terminee, annulee).
- Accueil : entree « Teleconsultations » a cote de « Notifications (n) ».
- Modele `lib/models/teleconsultation.dart` (`Teleconsultation.fromJson`, `aConsenti`) et
  `lib/utils/teleconsultations.dart` (`libelleStatutTeleconsultation`, `estActive`, `peutRejoindre`,
  `dateTeleconsultation`) ; `ApiService` : `mesTeleconsultations`, `teleconsultation`, `consentir`
  (identifiants UUID en texte).
- Dependance `url_launcher: ^6.3.0` (`flutter pub get`). Sur Android 11+, ajouter dans
  `android/app/src/main/AndroidManifest.xml` (projet genere par `flutter create .`) la declaration
  `<queries><intent><action android:name="android.intent.action.VIEW" /><data android:scheme="https" /></intent></queries>`
  recommandee par `url_launcher` pour l'ouverture des liens https.
- Tests : modele et utilitaires (`test/teleconsultations_test.dart`) ; page avec service factice
  (carte de consentement quand le consentement est nul, bouton « Rejoindre » apres consentement et
  lien ouvert via `ouvrirLien` injecte, texte d'etat d'une session terminee), entree d'accueil.

## v0.7.0 — Messagerie (mobile)
- Ecran « Messagerie » (`GET /api/conversations`, jeton PATIENT) : une ligne par conversation avec
  le praticien (nom resolu via `GET /api/medecins/{id}` quand l'identifiant est numerique, sinon
  « Médecin n° ... »), en gras s'il reste des non lus, « Dernier message le jeu. 4 dec. 09:00 »
  (ou « Ouverte le ... » sans message) et pastille textuelle « n non lus » ; tirer pour rafraichir,
  bouton « Se connecter » sans jeton, erreurs via `VueErreur` ; la liste est rechargee au retour du
  fil (la lecture marque les messages lus).
- Fil d'une conversation (`GET /api/conversations/{id}/messages`, du plus ancien au plus recent,
  liste inversee pour garder le dernier message en bas) : bulles alignees a droite pour mes messages,
  a gauche pour ceux du praticien, contenu puis date ; champ de saisie (2000 caracteres au plus) et
  bouton « Envoyer » desactive tant que le texte est vide ; `POST /api/conversations/{id}/messages`
  puis rechargement du fil, un 400 (contenu vide ou trop long) est affiche tel quel.
- Fiche medecin : bouton « Ouvrir une conversation » (`POST /api/conversations`, connexion Keycloak a
  la volee si necessaire) qui ouvre le fil ; en cas de 403, « Vous devez avoir un rendez-vous avec ce
  médecin pour lui écrire. ».
- Accueil : entree « Messagerie » a cote de « Notifications (n) » et « Teleconsultations ».
- Mes propres messages sont reconnus par l'identifiant de la session : `AuthService.sujet` lit le
  sujet (`sub`) du jeton (`lib/utils/jetons.dart`, sans verification de signature, affichage
  seulement) ; a defaut, le `patientId` de la conversation.
- Modeles `lib/models/conversation.dart` (`Conversation.fromJson`, `derniereActivite`) et
  `lib/models/message.dart` (`Message.fromJson`, `estLu`), utilitaires `lib/utils/messagerie.dart`
  (`estDeMoi`, `alignementMessage`, `dateMessage`, `libelleActivite`, `libelleNonLus`,
  `trierParActivite`) ; `ApiService` : `mesConversations`, `ouvrirConversation`, `messages`,
  `envoyerMessage` (corps JSON UTF-8). Identifiants conserves en texte.
- Tests : `test/messagerie_test.dart` (modeles, alignement selon l'auteur, dates, libelles, tri,
  sujet du jeton) ; `test/widget_test.dart` (liste et ouverture du fil, alignement des bulles,
  bouton « Envoyer » inactif a vide puis envoi et rafraichissement, fiche medecin : ouverture et
  refus 403, entree d'accueil) ; `test/outils.dart` (jeton JWT factice).

## v0.8.0 — Avis (mobile)
- « Mes rendez-vous » : sur un rendez-vous HONORE, bouton « Donner mon avis » (un rendez-vous honore
  n'est plus annulable) ou mention « Avis donné » si un avis existe deja (`GET /api/avis/mes`,
  tolerant en cas d'echec) ; la liste est rechargee apres le depot.
- Ecran « Mon avis » (`deposer_avis_page.dart`) : rappel du praticien et de la date, note obligatoire
  de 1 a 5 (cinq boutons « 1 » a « 5 », sans emoji), commentaire facultatif (500 caracteres au plus),
  bouton « Envoyer mon avis » inactif tant qu'aucune note n'est choisie ; `POST /api/avis` puis
  « Merci pour votre avis. » et fermeture ; 409 -> « Vous avez déjà donné votre avis pour ce
  rendez-vous. », 400 (note hors bornes) affiche tel quel, bouton « Se connecter » sans jeton.
- Ecran « Mes avis » (`GET /api/avis/mes`) : praticien (nom via `GET /api/medecins/{id}`, repli
  « Médecin n° ... »), « 4 / 5 · Publié » (statuts Publié, Signalé, Masqué), commentaire et
  « Déposé le ... » ; entree « Mes avis » sur l'accueil.
- Fiche medecin : moyenne « 4,5 / 5 (12 avis) » (format francais, virgule ; « Aucun avis » sans avis)
  sous la specialite et section « Avis des patients » avec les derniers avis anonymes (note « 4 / 5 »,
  commentaire, date) via `GET /api/medecins/{id}/avis` (public) ; « Avis indisponibles pour le
  moment. » si l'appel echoue, sans bloquer la fiche.
- Modeles `lib/models/avis.dart` (`Avis.fromJson`, `aCommentaire`) et `lib/models/synthese_avis.dart`
  (`SyntheseAvis.fromJson`, `aDesAvis`), utilitaires `lib/utils/avis.dart` (`noteValide`,
  `formaterDecimal`, `formaterMoyenne`, `formaterNote`, `libelleStatutAvis`, `dateAvis`, `estHonore`) ;
  `ApiService` : `deposerAvis`, `mesAvis`, `avisDuMedecin`.
- Tests : `test/avis_test.dart` (modeles, moyenne avec virgule et « Aucun avis », note, statuts,
  date, eligibilite) ; `test/widget_test.dart` (fiche avec synthese et derniers avis, fiche sans
  avis, parcours « Donner mon avis » -> note obligatoire -> envoi -> « Avis donné », refus 409,
  « Mes avis », entree d'accueil).

## v0.9.0 — Dawini, demander un medicament aux pharmacies (mobile)
- Ecran « Dawini » (`dawini_page.dart`, jeton PATIENT ; bouton « Se connecter » sans jeton) :
  formulaire « Demander un médicament » avec le medicament (obligatoire), le code de wilaya
  (obligatoire, champ texte a deux chiffres : l'annuaire mobile n'a pas encore de selecteur de wilayas),
  la commune et une precision facultatives ; « Publier la demande » refuse localement une demande sans
  medicament (« Indiquez le médicament recherché. ») ou sans wilaya (« Indiquez le code de votre
  wilaya. »), puis `POST /api/dawini/besoins` (400 affiche tel quel), « Demande publiée. », formulaire
  vide (la wilaya est conservee) et liste rechargee.
- Sous le formulaire, « Mes demandes » (`GET /api/dawini/besoins/mes`, les plus recentes d'abord) :
  medicament, « Wilaya 16 · Alger-Centre · Ouverte » (statuts Ouverte, Clôturée), « Publiée le ... »
  ou « Clôturée le ... », et « n réponses » (accord au singulier) ; un toucher ouvre les reponses.
- Ecran « Réponses des pharmacies » (`reponses_besoin_page.dart`, `GET /api/dawini/besoins/{id}/reponses`) :
  rappel de la demande, puis une carte par reponse avec le nom de la pharmacie, « Disponible » /
  « Indisponible », le prix « 850 DA » s'il est indique, le commentaire et la date ; bouton
  « Clôturer la demande » tant qu'elle est ouverte, avec confirmation
  (`POST /api/dawini/besoins/{id}/cloturer`) ; 409 -> « Cette demande est déjà clôturée. » et la demande
  passe cloturee localement ; la liste des demandes est rechargee au retour.
- Accueil : entree « Dawini (pharmacies) ».
- Modeles `lib/models/besoin_medicament.dart` (`BesoinMedicament.fromJson`, copie `cloturer`) et
  `lib/models/reponse_pharmacie.dart` (`ReponsePharmacie.fromJson`), utilitaires `lib/utils/dawini.dart`
  (`formaterPrix`, `libelleStatutBesoin`, `libelleReponses`, `libelleDisponibilite`, `estOuvert`,
  `lieuBesoin`, `dateBesoin`, `dateReponse`, `trierParPublication`) ; `ApiService` : `publierBesoin`,
  `mesBesoins`, `cloturerBesoin`, `reponsesBesoin`.
- Tests : `test/dawini_test.dart` (modeles, copie cloturee, prix, statuts, accords, lieu, dates, tri) ;
  `test/widget_test.dart` (formulaire refuse sans medicament puis sans wilaya, publication et liste,
  reponses avec disponibilite, prix et date puis cloture, refus 409, sans jeton, entree d'accueil ;
  surface de test haute pour les ecrans longs et attente entre deux messages).

## v0.9.1 — Correctif identifiants (mobile)
- Le backend identifie tout (praticien, creneau, rendez-vous, ordonnance, conversation, avis,
  besoin...) par un **UUID serialise en texte**, par exemple `00000000-0000-0000-0000-000000000001`
  pour le premier praticien de demonstration. L'application traitait plusieurs identifiants comme
  des entiers (`as int`, parametres `int` d'`ApiService`, resolution du nom du praticien
  « uniquement si l'identifiant est numerique ») : plantage a l'ouverture d'une fiche, creneaux
  non reservables, noms de praticiens jamais resolus.
- Tous les identifiants sont desormais des chaines de bout en bout : `ApiService.medecin`,
  `creneaux`, `reserverCreneau`, `annuler`, `ordonnance`, `ouvrirConversation`, `deposerAvis`,
  `avisDuMedecin` prennent un `String` (chemins encodes avec `Uri.encodeComponent`, corps JSON
  `{"medecinId": "<uuid>"}` et `{"rendezVousId": "<uuid>", ...}`), de meme que
  `FicheMedecinPage.medecinId`, `DetailOrdonnancePage.ordonnanceId` et
  `DeposerAvisPage.rendezVousId`. Les compteurs (`nonLues`, `nombre`, `note`, `prixDa`,
  `dureeMinutes`) restent des entiers.
- `lib/utils/identifiants.dart` : `identifiant(Object?)` (identifiant en texte, quel que soit le
  type recu), `abreger(String)` (8 premiers caracteres) et `libelleMedecin(String)`
  (« Médecin 00000000 »). Le nom d'un praticien est toujours demande a `GET /api/medecins/{id}` ;
  a defaut, l'ecran affiche « Médecin » suivi de l'identifiant abrege. Cette regle remplace les
  replis « Medecin n° ... » / « Médecin n° ... » et la condition « quand l'identifiant est
  numerique » decrits dans les sections v0.4.0, v0.7.0 et v0.8.0.
- Tests : fakes signes `String` comme `ApiService`, fixtures en UUID (`FakeApiService.medecinDemo`,
  `sujetPatient`, `rdvHonore`...), variante `FakeApiServiceSansFiche` pour le repli
  « Médecin 00000000 », `test/identifiants_test.dart`.

## v0.10.0 — Configuration par environnement (mobile)
- `lib/config/configuration.dart` : classe `Configuration` (`apiUrl`, `issuer`, `clientId`,
  `redirect`) lue a la compilation via `String.fromEnvironment` (`TABIBI_API_URL`, `TABIBI_ISSUER`,
  `TABIBI_CLIENT_ID`, `TABIBI_REDIRECT`) ; valeurs par defaut de l'emulateur Android
  (`http://10.0.2.2:8080`, `http://10.0.2.2:8081/realms/tabibi`, `tabibi-mobile`,
  `dz.tabibi.app:/oauthredirect`) exposees en `...ParDefaut`. Sur le simulateur iOS :
  `--dart-define=TABIBI_API_URL=http://localhost:8080`.
- `ApiService` n'a plus d'adresse codee en dur : `const ApiService({base = Configuration.apiUrl})`,
  la base pouvant etre fournie (tests) ; `AuthService` lit l'emetteur, le client et la redirection
  dans `Configuration`.
- README : section « Configuration » (variables, commandes `flutter run --dart-define=...` pour
  Android, iOS, appareil physique et production).
- Tests : `test/configuration_test.dart` (valeurs par defaut = emulateur Android, adresses sans
  barre oblique finale, base d'`ApiService` par defaut ou fournie).

## v0.11.0 — Mon profil (mobile)
- Ecran « Mon profil » (`mon_profil_page.dart`, utilisateur connecte ; bouton « Se connecter » sans
  jeton) : formulaire prerempli si un profil existe (`GET /api/moi/profil`), vide si l'API repond
  404 (profil jamais renseigne) ; champs nom complet (obligatoire, 120 caracteres au plus),
  telephone (clavier telephone, verification locale d'un numero algerien de 9 a 10 chiffres
  commencant par 0, espaces toleres), date de naissance (facultative, `showDatePicker` borne au
  passe et apres 1900, icone pour l'effacer), wilaya (code a deux chiffres) et langue
  (`DropdownButton` : Français, العربية, Taqbaylit, English -> fr, ar, kab, en).
- « Enregistrer » : refus local sans nom (« Indiquez votre nom complet. ») ou avec un telephone
  invalide, puis `PUT /api/moi/profil` ; « Profil enregistré. » et formulaire realigne sur la vue
  renvoyee (« Mis à jour le ... ») ; 400 (regle de l'API) affiche tel quel, 401 -> deconnexion.
- Accueil : entree « Mon profil ».
- Modele `lib/models/profil.dart` (`Profil.fromJson` tolerant, `toJson` = corps du PUT avec la
  date au format `yyyy-MM-dd` ou `null`, `langues`, `langueParDefaut`), utilitaires
  `lib/utils/profil.dart` (`libellesLangues`, `libelleLangue`, `normaliserTelephone`,
  `telephoneValide`, `libelleDateNaissance`, `libelleMiseAJour`) et `formaterJour` (« 14 mai 1990 »)
  dans `lib/utils/dates.dart` ; `ApiService` : `monProfil`, `enregistrerProfil`.
- Tests : `test/profil_test.dart` (modele : lecture complete, tolerance, `toJson` avec et sans date,
  jour seul ; langues ; telephone ; libelles), `test/dates_test.dart` (`formaterJour`) ;
  `test/widget_test.dart` (formulaire prerempli puis enregistrement avec date effacee et langue
  changee, 404 -> formulaire vide puis nom obligatoire, telephone invalide, date choisie et
  enregistrement, refus 400 affiche, sans jeton, entree d'accueil).

## v0.12.0 — Liste d'attente par medecin (mobile)
- Fiche medecin : section « Liste d'attente » sous les creneaux (surtout utile quand aucun creneau
  n'est disponible) avec le rappel « Vous serez notifié dès qu'un créneau se libère. » et le bouton
  « M'inscrire sur la liste d'attente » (`POST /api/medecins/{id}/liste-attente`, connexion Keycloak
  a la volee si necessaire) ; « Inscription enregistrée. ... » puis texte d'etat « Vous êtes inscrit
  sur la liste d'attente de ce médecin. » ; 409 -> « Vous êtes déjà inscrit sur cette liste. » (meme
  etat) ; 401 -> deconnexion.
- Ecran « Mes listes d'attente » (`mes_listes_attente_page.dart`, `GET /api/liste-attente/mes`,
  jeton PATIENT ; bouton « Se connecter » sans jeton) : une carte par inscription avec le praticien
  (nom via `GET /api/medecins/{id}`, repli « Médecin » et identifiant abrege) et « Inscription le ... »,
  dans l'ordre de la file (plus anciennes d'abord) ; bouton « Me retirer » avec confirmation
  (`POST /api/liste-attente/{id}/retirer`, 204 sans corps) puis « Retrait de la liste d'attente
  effectué. » et retrait de la carte (une inscription deja disparue, 404, est retiree aussi) ;
  etat vide explicatif.
- Accueil : entree « Liste d'attente ».
- Modele `lib/models/inscription_attente.dart` (`InscriptionAttente.fromJson` tolerant), utilitaires
  `lib/utils/liste_attente.dart` (`dateInscription`, `trierParInscription`) ; `ApiService` :
  `inscrireListeAttente`, `mesInscriptionsAttente`, `retirerListeAttente` (identifiants en texte).
- Tests : `test/liste_attente_test.dart` (modele complet et tolerant, date, tri) ;
  `test/widget_test.dart` (inscription depuis la fiche, refus 409, liste puis refus dans la
  confirmation et retrait, repli « Médecin 00000000 », sans jeton, entree d'accueil).

## v0.13.0 — Integration continue et preparation des stores (mobile)
- `.github/workflows/ci.yml` : a chaque `push` et `pull_request`, `subosito/flutter-action@v2`
  (canal `stable`, cache), `flutter pub get`, `flutter analyze`, `flutter test`, generation du
  projet Android puis `flutter build apk --debug` (artefact sept jours) ; JDK 17 ; une execution
  par branche. Android seulement en CI, iOS documente.
- `tool/preparer_android.sh` : `flutter create . --platforms=android --org dz.tabibi
  --project-name tabibi_mobile` si `android/` manque, puis `applicationId` `dz.tabibi.app`,
  `manifestPlaceholders` `appAuthRedirectScheme` (Kotlin DSL ou Groovy) et `<queries>` https
  dans le manifeste ; idempotent, portable (perl).
- `analysis_options.yaml` inchange (`package:flutter_lints/flutter.yaml`, `flutter_lints` deja en
  devDependency) ; `.gitignore` exclut `key.properties`, `*.jks`, `*.keystore`, `*.p12`,
  `*.mobileprovision` ; `pubspec.yaml` en `version: 0.13.0+1`.
- README : sections « Integration continue » et « Publication » pas a pas (Android : keystore
  `keytool -genkey`, `android/key.properties` non versionne, `signingConfigs` release,
  `flutter build appbundle --release --dart-define=...`, Play Console ; iOS : projet genere sur
  macOS, bundle id `dz.tabibi.app`, certificats via Xcode, `Info.plist`, `flutter build ipa`,
  TestFlight) ; icone et ecran de lancement a fournir (aucun fichier binaire dans le depot).
