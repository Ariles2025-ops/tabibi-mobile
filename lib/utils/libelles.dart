// Libelles lisibles a partir des valeurs brutes renvoyees par l'API, dans la langue de
// l'interface.

import '../i18n/traductions.dart' as i18n;

/// « CONFIRME » -> « Confirmé », « EN_ATTENTE » -> « En attente » (cles `statut.<BRUT>` des
/// dictionnaires) ; un statut absent des dictionnaires est seulement mis en forme
/// (soulignements remplaces, premiere lettre en capitale) ; chaine vide sans statut.
String libelleStatut(String langue, Object? statut) {
  final brut = (statut?.toString() ?? '').trim().toUpperCase();
  if (brut.isEmpty) return '';
  final cle = 'statut.$brut';
  if (i18n.cleConnue(cle)) return i18n.traduire(langue, cle);
  final s = brut.replaceAll('_', ' ').toLowerCase();
  return s[0].toUpperCase() + s.substring(1);
}
