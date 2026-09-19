// Lecture des teleconsultations (voir `Teleconsultation`) : libelle de statut, date affichee
// et regles d'acces a la salle video.

import '../i18n/traductions.dart' as i18n;
import '../models/teleconsultation.dart';
import 'dates.dart';
import 'libelles.dart';

/// « PLANIFIEE » -> « Planifiée », « EN_COURS » -> « En cours »,
/// « TERMINEE » -> « Terminée », « ANNULEE » -> « Annulée » ;
/// toute autre valeur suit la mise en forme generique ([libelleStatut]).
String libelleStatutTeleconsultation(String langue, Object? statut) {
  return statut == null ? '' : libelleStatut(langue, statut);
}

/// Vrai si la session peut encore avoir lieu : planifiee ou en cours.
bool estActive(Teleconsultation t) => t.statut == 'PLANIFIEE' || t.statut == 'EN_COURS';

/// Vrai si le patient peut rejoindre la salle : lien remis (donc consentement donne)
/// et session planifiee ou en cours.
bool peutRejoindre(Teleconsultation t) => t.lienSalle != null && estActive(t);

/// Date a afficher selon l'avancement : « Terminée le ... », « Démarrée le ... » ou
/// « Proposée le ... » (date de planification, format « jeu. 4 déc. 09:00 ») ;
/// « Date inconnue » si aucune date n'est lisible.
String dateTeleconsultation(String langue, Teleconsultation t) {
  final termineeLe = t.termineeLe;
  if (termineeLe != null) {
    return i18n.traduire(langue, 'tele.termineeLe',
        params: {'date': formaterDateHeure(langue, termineeLe)});
  }
  final demarreeLe = t.demarreeLe;
  if (demarreeLe != null) {
    return i18n.traduire(langue, 'tele.demarreeLe',
        params: {'date': formaterDateHeure(langue, demarreeLe)});
  }
  final creeLe = t.creeLe;
  if (creeLe != null) {
    return i18n.traduire(langue, 'tele.proposeeLe',
        params: {'date': formaterDateHeure(langue, creeLe)});
  }
  return i18n.traduire(langue, 'commun.dateInconnueMaj');
}
