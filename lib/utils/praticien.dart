import '../i18n/langue.dart';
import 'dates.dart';

/// Vrai si l'API marque le praticien comme réservable en ligne (`reservable == true`).
bool estReservable(Map<String, dynamic> m) => m['reservable'] == true;

/// Texte du badge du site, dans la langue courante.
String libelleReservable() =>
    t('Réservable en ligne', 'الحجز متاح عبر الإنترنت');

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

/// « Prochaine disponibilité : jeu. 4 déc. 09:00 », comme sur la fiche du site : le premier
/// créneau de la liste (déjà triée par l'API) ; null si aucun créneau n'a de date lisible.
String? texteProchaineDisponibilite(List<Map<String, dynamic>> creneaux) {
  if (creneaux.isEmpty) return null;
  final debut = creneaux.first['debut']?.toString();
  if (debut == null || DateTime.tryParse(debut) == null) return null;
  return '${t('Prochaine disponibilité :', 'أقرب موعد متاح:')} ${formaterDateIso(debut)}';
}
