# tabibi_mobile

Application mobile Tabibi — **Flutter** (iOS + Android), un seul code.

## Ce que fait cette premiere version
- Connexion **Keycloak** (OIDC natif via `flutter_appauth`, realm `tabibi`).
- Appel `GET /api/moi` avec le JWT, affichage utilisateur + roles.
- Theme aux couleurs Tabibi (vert #0F7560), Material 3.

## Lancer
```bash
flutter pub get
flutter run          # iOS (localhost) ou Android (emulateur : 10.0.2.2)
# necessite l'API + Keycloak (docker compose up) en marche
```

## Note plateforme
Les projets natifs `ios/` et `android/` se generent avec `flutter create .`
(non versionnes ici pour rester leger). L'essentiel — code, auth, API, test — est present.

## Prochaines etapes
- Notifications push, stockage securise du jeton, rafraichissement du jeton.

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
