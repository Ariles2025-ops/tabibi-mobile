# Activation Push/FCM — Tabibi mobile

Tout le code est pret. Tant que `android/app/google-services.json` n'est pas
depose, rien n'est actif et le build reste intact.

## 1. Cote Firebase (toi, ~5 min)
1. console.firebase.google.com -> Ajouter un projet (« Tabibi »).
2. Ajouter une app **Android**, package **`dz.tabibi.app`**.
3. Telecharger **`google-services.json`** -> le mettre dans **`android/app/`**.
4. (iOS plus tard : app iOS bundle `dz.tabibi.app` -> `GoogleService-Info.plist` dans `ios/Runner/`.)

## 2. Cote code (moi, 1 passage)
- `pubspec.yaml` : decommenter `firebase_core`, `firebase_messaging`, `flutter_local_notifications`.
- `android/app/build.gradle.kts` : decommenter `id("com.google.gms.google-services")`.
- `android/settings.gradle.kts` : decommenter la ligne `com.google.gms.google-services ... apply false`.
- Deplacer `fcm/notifications_push.dart` -> `lib/services/`.
- Dans `main()`, apres l'init Supabase : `await NotificationsPush.initialiser();`
- `flutter pub get` puis build.

## 3. Cote serveur (envoi)
- Copier `fcm/send-push/` -> `supabase/functions/send-push/` (repo web) puis `supabase functions deploy send-push`.
- Secrets : `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
  (depuis un service account : Firebase -> Parametres -> Comptes de service -> Generer une cle privee).
- Declencher l'appel la ou les notifs in-app sont deja creees (meme trigger) :
  POST send-push `{ user_id, title, body }` avec la cle service_role.

## Table
`public.device_tokens` est prete : unique (user_id, token), RLS par proprietaire,
GRANT insert/select/update pour `authenticated`. Le service fait un upsert.
