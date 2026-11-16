import '../i18n/langue.dart';

/// Ligne « spécialité · ville (wilaya) » d'un praticien, sans « null » quand une donnée manque.
/// En arabe, la specialite et la wilaya viennent du referentiel (slug, code), avec repli sur
/// les libelles francais renvoyes par l'API.
String sousTitrePraticien(Map<String, dynamic> m) {
  var specialite = (m['specialiteFr'] as String?) ?? '';
  var wilaya = (m['wilayaFr'] as String?) ?? '';
  if (Langue.estArabe) {
    final sp = specialiteParSlug(m['specialiteSlug'] as String?);
    if (sp != null) specialite = sp.nomAr;
    final w = wilayaParCode(m['wilayaCode']?.toString());
    if (w != null) wilaya = w.nomAr;
  }
  final ville = m['ville'] as String?;
  final lieu = (ville == null || ville.isEmpty) ? wilaya : '$ville ($wilaya)';
  return [specialite, lieu].where((x) => x.isNotEmpty).join(' · ');
}
