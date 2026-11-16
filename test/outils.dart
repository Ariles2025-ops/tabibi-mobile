// Outils partages par les tests (ce fichier n'est pas un test : pas de suffixe _test).

import 'dart:convert';

/// Jeton JWT factice (entete.charge.signature) dont la charge utile, en base64url sans
/// remplissage comme dans un vrai JWT, porte le sujet [sujet]. Aucune signature valide :
/// seul le sujet est lu par l'application.
String jetonAvecSujet(String sujet) {
  final charge = base64Url
      .encode(utf8.encode(jsonEncode({'sub': sujet, 'exp': 1})))
      .replaceAll('=', '');
  return 'entete.$charge.signature';
}
