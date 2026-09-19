// Lecture des demandes de medicament et des reponses de pharmacies (voir `BesoinMedicament`
// et `ReponsePharmacie`) : prix, statut, disponibilite, nombre de reponses, lieu, dates et tri.

import '../models/besoin_medicament.dart';
import '../models/reponse_pharmacie.dart';
import 'dates.dart';
import 'libelles.dart';

/// « 850 DA » ; null si le prix est absent ou negatif.
String? formaterPrix(int? prixDa) => prixDa == null || prixDa < 0 ? null : '$prixDa DA';

/// « OUVERT » -> « Ouverte », « CLOTURE » -> « Clôturée » (la demande) ;
/// toute autre valeur suit la mise en forme generique ([libelleStatut]).
String libelleStatutBesoin(Object? statut) {
  return switch (statut?.toString().trim().toUpperCase()) {
    'OUVERT' => 'Ouverte',
    'CLOTURE' => 'Clôturée',
    _ => libelleStatut(statut),
  };
}

/// « 0 réponse », « 1 réponse », « 3 réponses ».
String libelleReponses(int nombre) => nombre == 1 ? '1 réponse' : '$nombre réponses';

/// « Disponible » ou « Indisponible ».
String libelleDisponibilite(bool disponible) => disponible ? 'Disponible' : 'Indisponible';

/// Vrai tant que la demande est ouverte (elle peut encore etre cloturee).
bool estOuvert(BesoinMedicament besoin) => besoin.statut.trim().toUpperCase() == 'OUVERT';

/// « Wilaya 16 · Alger » ; la commune est omise si elle est absente.
String lieuBesoin(BesoinMedicament besoin) {
  final wilaya = 'Wilaya ${besoin.wilayaCode}';
  final commune = besoin.commune;
  return commune == null ? wilaya : '$wilaya · $commune';
}

/// « Publiée le jeu. 4 dec. 09:00 » ; « Clôturée le ... » une fois la demande cloturee ;
/// « Date inconnue » si aucune date n'est lisible.
String dateBesoin(BesoinMedicament besoin) {
  final clotureLe = besoin.clotureLe;
  if (clotureLe != null) return 'Clôturée le ${formaterDateHeure(clotureLe)}';
  final publieLe = besoin.publieLe;
  if (publieLe != null) return 'Publiée le ${formaterDateHeure(publieLe)}';
  return 'Date inconnue';
}

/// Date de la reponse formatee (« jeu. 4 dec. 09:00 ») ; « date inconnue » si absente.
String dateReponse(ReponsePharmacie reponse) {
  final repondueLe = reponse.repondueLe;
  return repondueLe == null ? 'date inconnue' : formaterDateHeure(repondueLe);
}

/// Copie triee de la plus recente a la plus ancienne (`publieLe`) ;
/// les dates absentes sont placees en fin de liste.
List<BesoinMedicament> trierParPublication(List<BesoinMedicament> besoins) {
  final copie = List<BesoinMedicament>.of(besoins);
  copie.sort((a, b) {
    final da = a.publieLe;
    final db = b.publieLe;
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return copie;
}
