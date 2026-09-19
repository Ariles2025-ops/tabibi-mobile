// Outils partages par les tests (ce fichier n'est pas un test : pas de suffixe _test).

import 'dart:convert';

import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/i18n/traductions.dart';
import 'package:tabibi_mobile/utils/dates.dart';

/// Langue imposee aux tests : les libelles et les dates attendus sont en francais.
const String langueDesTests = langueParDefaut;

/// A appeler dans `setUp` de chaque fichier de test : charge les donnees de date de `intl`
/// (sans quoi `DateFormat` ne connait que l'anglais) et remet l'interface en francais, quel
/// que soit l'ordre des tests (le controleur [langues] est partage).
Future<void> preparerTests() async {
  await preparerDates();
  langues.reinitialiser(langueDesTests);
}

/// Libelle francais de [cle] tel que l'interface l'affiche pendant les tests.
String libelle(String cle, {Map<String, Object?> params = const {}}) =>
    traduire(langueDesTests, cle, params: params);

/// Libelle arabe de [cle] (ecran bascule en arabe).
String libelleArabe(String cle, {Map<String, Object?> params = const {}}) =>
    traduire('ar', cle, params: params);

/// Jeton JWT factice (entete.charge.signature) dont la charge utile, en base64url sans
/// remplissage comme dans un vrai JWT, porte le sujet [sujet]. Aucune signature valide :
/// seul le sujet est lu par l'application.
String jetonAvecSujet(String sujet) {
  final charge = base64Url
      .encode(utf8.encode(jsonEncode({'sub': sujet, 'exp': 1})))
      .replaceAll('=', '');
  return 'entete.$charge.signature';
}
