// Lecture des inscriptions en liste d'attente (voir `InscriptionAttente`) : date affichee et
// tri dans l'ordre de la file.

import '../i18n/traductions.dart' as i18n;
import '../models/inscription_attente.dart';
import 'dates.dart';

/// « Inscription le jeu. 4 déc. 09:00 » ; « Date d'inscription inconnue » si absente.
String dateInscription(String langue, InscriptionAttente inscription) {
  final inscritLe = inscription.inscritLe;
  if (inscritLe == null) return i18n.traduire(langue, 'attente.dateInconnue');
  return i18n.traduire(langue, 'attente.inscriptionLe',
      params: {'date': formaterDateHeure(langue, inscritLe)});
}

/// Copie triee de la plus ancienne a la plus recente (`inscritLe`), c'est-a-dire dans l'ordre
/// de la file d'attente (les premiers inscrits sont prevenus en premier) ; les dates absentes
/// sont placees en fin de liste.
List<InscriptionAttente> trierParInscription(List<InscriptionAttente> inscriptions) {
  final copie = List<InscriptionAttente>.of(inscriptions);
  copie.sort((a, b) {
    final da = a.inscritLe;
    final db = b.inscritLe;
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return copie;
}
