#!/usr/bin/env bash
# Prepare le projet Android, qui n'est pas versionne (voir README, « Note plateforme ») :
# 1. le genere avec `flutter create` s'il est absent (dossier android/) ;
# 2. y applique la configuration Tabibi : identifiant d'application dz.tabibi.app, schema de
#    redirection OAuth exige par flutter_appauth (appAuthRedirectScheme, sans lequel la
#    compilation Android echoue) et declaration <queries> recommandee par url_launcher pour
#    l'ouverture des liens https.
# Idempotent : relancable sans effet de bord. Utilise par la CI (.github/workflows/ci.yml)
# et en local avant `flutter build apk` / `flutter build appbundle`. Portable (perl, present
# avec Git sur toutes les plateformes ; aucune option sed propre a GNU ou BSD).
set -euo pipefail
cd "$(dirname "$0")/.."

ID_APPLICATION="dz.tabibi.app"

if [ ! -d android ]; then
  flutter create . --platforms=android --org dz.tabibi --project-name tabibi_mobile
fi

# --- build.gradle : Kotlin DSL (Flutter >= 3.29) ou Groovy (versions anterieures) ---
GRADLE="android/app/build.gradle.kts"
if [ -f "$GRADLE" ]; then
  PLACEHOLDER='manifestPlaceholders["appAuthRedirectScheme"] = "'"$ID_APPLICATION"'"'
else
  GRADLE="android/app/build.gradle"
  PLACEHOLDER='manifestPlaceholders += [appAuthRedirectScheme: "'"$ID_APPLICATION"'"]'
fi
if [ ! -f "$GRADLE" ]; then
  echo "Fichier $GRADLE introuvable : le projet Android n'a pas ete genere." >&2
  exit 1
fi

# applicationId "..." (Groovy ancien) ou applicationId = "..." (Groovy recent, Kotlin DSL).
perl -pi -e 's/(applicationId\s*=?\s*)"[^"]*"/$1"'"$ID_APPLICATION"'"/' "$GRADLE"
if ! grep -q appAuthRedirectScheme "$GRADLE"; then
  perl -pi -e 's/^(\s*)(applicationId\b.*)$/$1$2\n$1'"$PLACEHOLDER"'/' "$GRADLE"
fi

# --- AndroidManifest.xml : requete des applications ouvrant les liens https ---
MANIFEST="android/app/src/main/AndroidManifest.xml"
INTENT='        <intent>\n'
INTENT+='            <action android:name="android.intent.action.VIEW" />\n'
INTENT+='            <data android:scheme="https" />\n'
INTENT+='        </intent>'
if ! grep -q 'android:scheme="https"' "$MANIFEST"; then
  if grep -q '<queries>' "$MANIFEST"; then
    perl -0pi -e 's#<queries>#<queries>\n'"$INTENT"'#' "$MANIFEST"
  else
    BLOC='    <queries>\n'"$INTENT"'\n    </queries>\n</manifest>'
    perl -0pi -e 's#</manifest>#'"$BLOC"'#' "$MANIFEST"
  fi
fi

echo "Projet Android pret : $GRADLE (applicationId $ID_APPLICATION, appAuthRedirectScheme)"
echo "et $MANIFEST (requete https)."
