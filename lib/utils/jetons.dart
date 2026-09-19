// Lecture du jeton d'acces (JWT Keycloak) cote application : sujet de l'utilisateur.
// La signature n'est pas verifiee ici (c'est le role du backend) : le sujet ne sert
// qu'a l'affichage, par exemple pour reconnaitre ses propres messages.

import 'dart:convert';

/// Sujet (`sub`) d'un jeton JWT, c'est-a-dire l'identifiant Keycloak de l'utilisateur
/// connecte ; null si le jeton est absent, opaque, mal forme ou sans sujet.
String? sujetDuJeton(String? jeton) {
  if (jeton == null) return null;
  final parties = jeton.split('.');
  if (parties.length < 2) return null;
  try {
    final Object? corps = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parties[1]))),
    );
    if (corps is Map) {
      final Object? sujet = corps['sub'];
      if (sujet is String && sujet.isNotEmpty) return sujet;
    }
  } on FormatException {
    // Charge utile illisible (jeton opaque, base64 ou JSON invalide) : sujet inconnu.
  }
  return null;
}
