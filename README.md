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
- Recherche de medecins, fiche, reservation.
- Notifications push, stockage securise du jeton.
