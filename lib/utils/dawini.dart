// Lecture des demandes de medicament et des reponses de pharmacies (voir `BesoinMedicament`
// et `ReponsePharmacie`) : prix, statut, disponibilite, nombre de reponses, lieu, dates et tri.

import '../i18n/traductions.dart' as i18n;
import '../models/besoin_medicament.dart';
import '../models/reponse_pharmacie.dart';
import 'dates.dart';
import 'libelles.dart';

/// « 850 DA » ; null si le prix est absent ou negatif.
String? formaterPrix(String langue, int? prixDa) => prixDa == null || prixDa < 0
    ? null
    : i18n.traduire(langue, 'dawini.prix', params: {'prix': prixDa});

/// « OUVERT » -> « Ouverte », « CLOTURE » -> « Clôturée » (la demande) ;
/// toute autre valeur suit la mise en forme generique ([libelleStatut]).
String libelleStatutBesoin(String langue, Object? statut) => libelleStatut(langue, statut);

/// « 0 réponse », « 1 réponse », « 3 réponses ».
String libelleReponses(String langue, int nombre) =>
    i18n.traduirePluriel(langue, 'dawini.reponses', nombre);

/// « Disponible » ou « Indisponible ».
String libelleDisponibilite(String langue, bool disponible) =>
    i18n.traduire(langue, disponible ? 'dawini.disponible' : 'dawini.indisponible');

/// Vrai tant que la demande est ouverte (elle peut encore etre cloturee).
bool estOuvert(BesoinMedicament besoin) => besoin.statut.trim().toUpperCase() == 'OUVERT';

/// « Wilaya 16 · Alger » ; la commune est omise si elle est absente.
String lieuBesoin(String langue, BesoinMedicament besoin) {
  final wilaya = i18n.traduire(langue, 'dawini.wilayaLieu', params: {'code': besoin.wilayaCode});
  final commune = besoin.commune;
  if (commune == null) return wilaya;
  return i18n.traduire(langue, 'dawini.lieuCommune',
      params: {'wilaya': wilaya, 'commune': commune});
}

/// « Publiée le jeu. 4 déc. 09:00 » ; « Clôturée le ... » une fois la demande cloturee ;
/// « Date inconnue » si aucune date n'est lisible.
String dateBesoin(String langue, BesoinMedicament besoin) {
  final clotureLe = besoin.clotureLe;
  if (clotureLe != null) {
    return i18n.traduire(langue, 'dawini.clotureeLe',
        params: {'date': formaterDateHeure(langue, clotureLe)});
  }
  final publieLe = besoin.publieLe;
  if (publieLe != null) {
    return i18n.traduire(langue, 'dawini.publieeLe',
        params: {'date': formaterDateHeure(langue, publieLe)});
  }
  return i18n.traduire(langue, 'commun.dateInconnueMaj');
}

/// Date de la reponse formatee (« jeu. 4 déc. 09:00 ») ; « date inconnue » si absente.
String dateReponse(String langue, ReponsePharmacie reponse) {
  final repondueLe = reponse.repondueLe;
  return repondueLe == null
      ? i18n.traduire(langue, 'commun.dateInconnue')
      : formaterDateHeure(langue, repondueLe);
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
