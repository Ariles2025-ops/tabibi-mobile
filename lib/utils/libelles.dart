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

/// Sous-titre d'un medecin : « Specialite · Ville, Wilaya », en omettant proprement
/// les valeurs absentes (jamais de « null », jamais de parentheses vides).
String medecinSousTitre(Map<String, dynamic> m) {
  String? net(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty || s.toLowerCase() == 'null') ? null : s;
  }
  final spe = net(m['specialiteFr']);
  final ville = net(m['ville']);
  final wilaya = net(m['wilayaFr']);
  final lieu = <String>[
    if (ville != null) ville,
    if (wilaya != null && wilaya != ville) wilaya,
  ].join(', ');
  return <String>[
    if (spe != null) spe,
    if (lieu.isNotEmpty) lieu,
  ].join(' · ');
}
