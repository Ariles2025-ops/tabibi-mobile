#!/usr/bin/env bash
# Prepare le projet Android, qui n'est pas versionne (voir README, « Note plateforme ») :
# 1. le genere avec `flutter create` s'il est absent (dossier android/) ;
# 2. y applique la configuration Tabibi : identifiant d'application dz.tabibi.app, schema de
#    redirection OAuth exige par flutter_appauth (appAuthRedirectScheme, sans lequel la
#    compilation Android echoue) et declarations <queries> recommandees par url_launcher pour
#    l'ouverture des liens https et par open_filex pour l'ouverture des PDF (ordonnances).
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

# --- compileSdk : au moins 36 (exige par les plugins Flutter groupes (shared_preferences, url_launcher, androidx.core 1.17...)) ---
# Le gabarit Flutter fixe compileSdk = flutter.compileSdkVersion, parfois trop bas (31) : la
# compilation des plugins echoue alors (CheckAarMetadata). On force 36, valeur qui satisfait
# fragment/activity/core 1.13+. Idempotent.
if [ "${GRADLE##*.}" = "kts" ]; then
  perl -pi -e 's/^(\s*)compileSdk\s*=.*$/${1}compileSdk = 36/' "$GRADLE"
else
  perl -pi -e 's/^(\s*)compileSdk(Version)?\b.*$/${1}compileSdk 36/' "$GRADLE"
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

# --- AndroidManifest.xml : requete des applications ouvrant les PDF (open_filex, Android 11+) ---
INTENT_PDF='        <intent>\n'
INTENT_PDF+='            <action android:name="android.intent.action.VIEW" />\n'
INTENT_PDF+='            <data android:mimeType="application/pdf" />\n'
INTENT_PDF+='        </intent>'
if ! grep -q 'android:mimeType="application/pdf"' "$MANIFEST"; then
  perl -0pi -e 's#<queries>#<queries>\n'"$INTENT_PDF"'#' "$MANIFEST"
fi

# --- Force compileSdk 36 sur TOUS les sous-projets (plugins) ---
# flutter_appauth fixe compileSdk 31 dans son propre build.gradle et n'herite pas du module app :
# CheckAarMetadata echoue (ses dependances androidx exigent 34+). On force 36 sur chaque plugin
# depuis le build.gradle racine, en afterEvaluate (par reflexion : aucun import AGP, donc pas de
# risque de compilation KTS). Idempotent (marqueur tabibi-compilesdk-override).
ROOT_KTS="android/build.gradle.kts"
ROOT_GROOVY="android/build.gradle"
if [ -f "$ROOT_KTS" ] && ! grep -q "tabibi-compilesdk-override" "$ROOT_KTS"; then
  cat >> "$ROOT_KTS" <<'KTS'

// tabibi-compilesdk-override : force compileSdk 36 sur tous les plugins (flutter_appauth fixe 31).
subprojects {
    // Le build.gradle racine de Flutter evalue deja :app (evaluationDependsOn) : on ne
    // (re)planifie afterEvaluate que sur les sous-projets pas encore evalues (les plugins).
    if (!state.executed) {
        afterEvaluate {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                try {
                    androidExt.javaClass
                        .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        .invoke(androidExt, 36)
                } catch (e: Exception) {
                }
            }
        }
    }
}
KTS
elif [ -f "$ROOT_GROOVY" ] && ! grep -q "tabibi-compilesdk-override" "$ROOT_GROOVY"; then
  cat >> "$ROOT_GROOVY" <<'GROOVY'

// tabibi-compilesdk-override : force compileSdk 36 sur tous les plugins (flutter_appauth fixe 31).
subprojects {
    if (!project.state.executed) {
        afterEvaluate { project ->
            if (project.hasProperty('android')) {
                project.android {
                    compileSdkVersion 36
                }
            }
        }
    }
}
GROOVY
fi

echo "Projet Android pret : $GRADLE (applicationId $ID_APPLICATION, appAuthRedirectScheme)"
echo "et $MANIFEST (requetes https et PDF)."
