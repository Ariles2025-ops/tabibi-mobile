// Lecture des ordonnances renvoyees par l'API (cartes JSON), sans modele dedie :
// {id, medecinId, patientId, rendezVousId, lignes: [{medicament, posologie, duree}],
//  emiseLe (ISO 8601), codeVerification, statut}.

import '../i18n/langue.dart';
import 'dates.dart';

/// Date d'emission formatee (« jeu. 4 dec. 09:00 ») ; « date inconnue » si absente.
String dateEmission(Map<String, dynamic> ordonnance) {
  final Object? iso = ordonnance['emiseLe'];
  return iso is String && iso.isNotEmpty
      ? formaterDateIso(iso)
      : t('date inconnue', 'تاريخ غير معروف');
}

/// Lignes de l'ordonnance : {medicament, posologie, duree} ; liste vide si absentes.
List<Map<String, dynamic>> lignesOrdonnance(Map<String, dynamic> ordonnance) {
  final Object? lignes = ordonnance['lignes'];
  if (lignes is! List) return const [];
  return [
    for (final Object? ligne in lignes)
      if (ligne is Map) ligne.cast<String, dynamic>(),
  ];
}

/// Copie triee de la plus recente a la plus ancienne (`emiseLe`) ;
/// les dates absentes ou illisibles sont placees en fin de liste.
List<Map<String, dynamic>> trierParEmission(List<Map<String, dynamic>> ordonnances) {
  DateTime? date(Map<String, dynamic> o) {
    final Object? iso = o['emiseLe'];
    return iso is String ? DateTime.tryParse(iso) : null;
  }

  final copie = List<Map<String, dynamic>>.of(ordonnances);
  copie.sort((a, b) {
    final da = date(a);
    final db = date(b);
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return copie;
}

/// Avertissement a afficher a la verification d'un code dont l'ordonnance ne doit plus etre
/// delivree (comme le site) : « Déjà délivrée le ... » ou « Annulée : ... » ; null sinon.
String? avertissementVerification(Map<String, dynamic> resultat) {
  switch ('${resultat['statut'] ?? ''}'.trim().toUpperCase()) {
    case 'DELIVREE':
      final Object? iso = resultat['delivreeLe'];
      final date = iso is String && DateTime.tryParse(iso) != null ? formaterDateIso(iso) : null;
      return t(
          'Déjà délivrée${date == null ? '' : ' le $date'} : cette ordonnance ne peut pas être délivrée une nouvelle fois.',
          'سبق صرفها${date == null ? '' : ' في $date'}: لا يمكن صرف هذه الوصفة مرة أخرى.');
    case 'ANNULEE':
      return t('Annulée : cette ordonnance a été annulée par le médecin et ne doit pas être délivrée.',
          'ملغاة: ألغى الطبيب هذه الوصفة ولا يجوز صرفها.');
  }
  return null;
}
