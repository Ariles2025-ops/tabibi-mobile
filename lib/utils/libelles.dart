// Libelles lisibles a partir des valeurs brutes renvoyees par l'API.

/// « CONFIRME » -> « Confirme », « EN_ATTENTE » -> « En attente » ; chaine vide si absent.
String libelleStatut(Object? statut) {
  final s = (statut?.toString() ?? '').replaceAll('_', ' ').trim().toLowerCase();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
