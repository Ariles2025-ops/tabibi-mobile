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
/// delivree (comme le site) : « Déjà délivrée le ... », « Annulée : ... » ou « Expirée : ... » ; null sinon.
String? avertissementVerification(Map<String, dynamic> resultat) {
  switch ('${resultat['statut'] ?? ''}'.trim().toUpperCase()) {
    case 'DELIVREE':
      final Object? iso = resultat['delivreeLe'];
      final date = iso is String && DateTime.tryParse(iso) != null ? formaterDateIso(iso) : null;
      return t(
          'Déjà délivrée${date == null ? '' : ' le $date'} : cette ordonnance ne peut pas être délivrée une nouvelle fois.',
          'سُلّمت من قبل${date == null ? '' : ' بتاريخ $date'}: لا يمكن تسليم هذه الوصفة مرة أخرى.');
    case 'ANNULEE':
      return t('Annulée : cette ordonnance a été annulée par le médecin et ne doit pas être délivrée.',
          'ملغاة: ألغى الطبيب هذه الوصفة ولا يجب تسليمها.');
    case 'EXPIREE':
      return t('Expirée : cette ordonnance n\'est plus valable et ne doit pas être délivrée.',
          'منتهية الصلاحية: لم تعد هذه الوصفة صالحة ولا يجب تسليمها.');
  }
  return null;
}

/// Precision sous le statut (comme le site) : « Annulée par le médecin : motif » ou
/// « Délivrée en pharmacie le ... » ; null pour les autres statuts.
String? infoStatutOrdonnance(Map<String, dynamic> ordonnance) {
  switch ('${ordonnance['statut'] ?? ''}'.trim().toUpperCase()) {
    case 'ANNULEE':
      final Object? brut = ordonnance['motifAnnulation'];
      final motif = brut is String ? brut.trim() : '';
      return motif.isEmpty
          ? t('Annulée par le médecin', 'ألغاها الطبيب')
          : t('Annulée par le médecin : $motif', 'ألغاها الطبيب: $motif');
    case 'DELIVREE':
      final Object? iso = ordonnance['delivreeLe'];
      final date = iso is String && DateTime.tryParse(iso) != null ? formaterDateIso(iso) : null;
      return t('Délivrée en pharmacie${date == null ? '' : ' le $date'}',
          'صُرفت في الصيدلية${date == null ? '' : ' في $date'}');
  }
  return null;
}

/// Corps de POST /api/ordonnances, comme le site : patient, lignes {medicament, posologie, duree}
/// (champs facultatifs vides mais presents) et rendez-vous lie facultatif. Null si le patient
/// manque, s'il n'y a aucune ligne ou si un medicament est vide.
Map<String, dynamic>? corpsOrdonnance(
    String patientId, String rendezVousId, List<Map<String, String>> lignes) {
  final patient = patientId.trim();
  if (patient.isEmpty || lignes.isEmpty) return null;
  final propres = [
    for (final l in lignes)
      {
        'medicament': (l['medicament'] ?? '').trim(),
        'posologie': (l['posologie'] ?? '').trim(),
        'duree': (l['duree'] ?? '').trim(),
      },
  ];
  if (propres.any((l) => l['medicament']!.isEmpty)) return null;
  final rdv = rendezVousId.trim();
  return {'patientId': patient, 'lignes': propres, if (rdv.isNotEmpty) 'rendezVousId': rdv};
}

/// Rendez-vous d'un patient auxquels une ordonnance peut etre liee (seuls acceptes par l'API :
/// confirmes ou honores, comme sur le site), les plus recents d'abord.
List<Map<String, dynamic>> rendezVousLiables(List<Map<String, dynamic>> rendezVous, String patientId) {
  final liste = [
    for (final r in rendezVous)
      if ('${r['patientId']}' == patientId &&
          const {'CONFIRME', 'HONORE'}.contains('${r['statut']}'.trim().toUpperCase()))
        r,
  ];
  liste.sort((a, b) =>
      (DateTime.tryParse('${b['debut']}')?.millisecondsSinceEpoch ?? 0)
          .compareTo(DateTime.tryParse('${a['debut']}')?.millisecondsSinceEpoch ?? 0));
  return liste;
}
