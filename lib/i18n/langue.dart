// Langue de l'interface : francais ou arabe (sens RTL), choisie dans l'appli et memorisee sur le
// telephone. Chaque texte visible est ecrit dans les deux langues au meme endroit :
// `t('Mes rendez-vous', 'مواعيدي')`, si bien qu'aucun texte ne peut manquer dans une langue.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/referentiel.dart';

/// Langue courante de l'appli.
class Langue {
  const Langue._();

  static const String francais = 'fr';
  static const String arabe = 'ar';

  /// Langues proposees, dans l'ordre du selecteur.
  static const List<String> codes = [francais, arabe];

  /// Cle de la preference enregistree sur le telephone.
  static const String cle = 'tabibi.langue';

  /// Langue affichee ; l'appli se reconstruit a chaque changement.
  static final ValueNotifier<String> courante = ValueNotifier(francais);

  static bool get estArabe => courante.value == arabe;

  static Locale get locale => Locale(courante.value);

  static TextDirection get direction => estArabe ? TextDirection.rtl : TextDirection.ltr;

  /// Langue par defaut : l'arabe si le telephone est en arabe, sinon le francais.
  static String parDefaut(String? langueTelephone) => langueTelephone == arabe ? arabe : francais;

  /// Langue au demarrage : celle memorisee, sinon celle du telephone ([parDefaut]).
  static Future<void> initialiser({String? langueTelephone}) async {
    String? memorisee;
    try {
      memorisee = (await SharedPreferences.getInstance()).getString(cle);
    } on Exception {
      // Stockage indisponible : langue du telephone.
    }
    courante.value = codes.contains(memorisee)
        ? memorisee!
        : parDefaut(langueTelephone ?? PlatformDispatcher.instance.locale.languageCode);
  }

  /// Change la langue et la memorise (ignore un code inconnu).
  static Future<void> choisir(String code) async {
    if (!codes.contains(code)) return;
    courante.value = code;
    try {
      await (await SharedPreferences.getInstance()).setString(cle, code);
    } on Exception {
      // Non memorisee : la langue reste choisie pour cette session.
    }
  }

  /// Nom de la langue dans sa propre ecriture (selecteur).
  static String nom(String code) => code == arabe ? 'العربية' : 'Français';
}

/// Texte dans la langue courante : [fr] en francais, [ar] en arabe.
String t(String fr, String ar) => Langue.estArabe ? ar : fr;

/// Nom d'une specialite dans la langue courante.
String nomSpecialite(Specialite s) => t(s.nom, s.nomAr);

/// Nom d'une wilaya dans la langue courante.
String nomWilaya(Wilaya w) => t(w.nom, w.nomAr);

/// Wilaya du referentiel par code (« 16 », « 016 » ou « 01 » acceptes) ; null si inconnue.
Wilaya? wilayaParCode(String? code) {
  final n = int.tryParse((code ?? '').trim());
  if (n == null) return null;
  for (final w in wilayas) {
    if (w.code == '$n') return w;
  }
  return null;
}

/// Specialite du referentiel par slug ; null si inconnue.
Specialite? specialiteParSlug(String? slug) {
  for (final s in specialites) {
    if (s.slug == slug) return s;
  }
  return null;
}

/// « 16 - Alger » (ou « 16 - الجزائر ») ; le code seul si la wilaya est inconnue.
String libelleWilaya(String? code) {
  final w = wilayaParCode(code);
  if (w == null) return code ?? '';
  return '${w.code} - ${nomWilaya(w)}';
}
