/// Ligne « spécialité · ville (wilaya) » d'un praticien, sans « null » quand une donnée manque.
String sousTitrePraticien(Map<String, dynamic> m) {
  final specialite = (m['specialiteFr'] as String?) ?? '';
  final ville = m['ville'] as String?;
  final wilaya = (m['wilayaFr'] as String?) ?? '';
  final lieu = (ville == null || ville.isEmpty) ? wilaya : '$ville ($wilaya)';
  return [specialite, lieu].where((x) => x.isNotEmpty).join(' · ');
}
