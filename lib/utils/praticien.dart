import '../i18n/langue.dart';

/// Ligne « spécialité · ville (wilaya) » d'un praticien, sans « null » quand une donnée manque.
/// En arabe, la specialite et la wilaya viennent du referentiel (slug, code), avec repli sur
/// les libelles francais renvoyes par l'API.
String sousTitrePraticien(Map<String, dynamic> m) {
  var specialite = (m['specialiteFr'] as String?) ?? '';
  var wilaya = (m['wilayaFr'] as String?) ?? '';
  if (Langue.estArabe) {
    final sp = specialiteParSlug(m['specialiteSlug'] as String?);
    if (sp != null) {
      specialite = sp.nomAr;
    } else if (m['specialiteSlug'] == 'autre') {
      specialite = 'أخرى';
    }
    final w = wilayaParCode(m['wilayaCode']?.toString());
    if (w != null) wilaya = w.nomAr;
  }
  final ville = m['ville'] as String?;
  // « Alger (Alger) » : la ville n'est pas repetee quand elle porte le nom de la wilaya.
  final villeUtile =
      ville != null && ville.isNotEmpty && ville != (m['wilayaFr'] as String?);
  final lieu = villeUtile ? '$ville ($wilaya)' : wilaya;
  return [specialite, lieu].where((x) => x.isNotEmpty).join(' · ');
}
