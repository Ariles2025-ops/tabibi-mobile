// Libelles lisibles a partir des valeurs brutes renvoyees par l'API.

/// « CONFIRME » -> « Confirme », « EN_ATTENTE » -> « En attente » ; chaine vide si absent.
String libelleStatut(Object? statut) {
  final s = (statut?.toString() ?? '').replaceAll('_', ' ').trim().toLowerCase();
  if (s.isEmpty) return s;
  final lisible = s[0].toUpperCase() + s.substring(1);
  return _accents[lisible] ?? lisible;
}

/// Statuts de l'API (sans accents) affichés avec leurs accents.
const Map<String, String> _accents = {
  'Confirme': 'Confirmé',
  'Annule': 'Annulé',
  'Annulee': 'Annulée',
  'Honore': 'Honoré',
  'Reserve': 'Réservé',
  'Cloture': 'Clôturé',
  'Expiree': 'Expirée',
  'Delivree': 'Délivrée',
  'Terminee': 'Terminée',
  'Planifiee': 'Planifiée',
  'Demarree': 'Démarrée',
  'Validee': 'Validée',
  'Refusee': 'Refusée',
  'Masque': 'Masqué',
  'Emise': 'Émise',
};
