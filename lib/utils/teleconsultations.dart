// Lecture des teleconsultations (voir `Teleconsultation`) : libelle de statut, date affichee
// et regles d'acces a la salle video.

import '../models/teleconsultation.dart';
import 'dates.dart';
import 'libelles.dart';

/// « PLANIFIEE » -> « Planifiee », « EN_COURS » -> « En cours »,
/// « TERMINEE » -> « Terminee », « ANNULEE » -> « Annulee » ;
/// toute autre valeur suit la mise en forme generique ([libelleStatut]).
String libelleStatutTeleconsultation(Object? statut) {
  return switch (statut?.toString().trim().toUpperCase()) {
    'PLANIFIEE' => 'Planifiee',
    'EN_COURS' => 'En cours',
    'TERMINEE' => 'Terminee',
    'ANNULEE' => 'Annulee',
    _ => libelleStatut(statut),
  };
}

/// Vrai si la session peut encore avoir lieu : planifiee ou en cours.
bool estActive(Teleconsultation t) => t.statut == 'PLANIFIEE' || t.statut == 'EN_COURS';

/// Vrai si le patient peut rejoindre la salle : lien remis (donc consentement donne)
/// et session planifiee ou en cours.
bool peutRejoindre(Teleconsultation t) => t.lienSalle != null && estActive(t);

/// Date a afficher selon l'avancement : « Terminee le ... », « Demarree le ... » ou
/// « Proposee le ... » (date de planification, format « jeu. 4 dec. 09:00 ») ;
/// « Date inconnue » si aucune date n'est lisible.
String dateTeleconsultation(Teleconsultation t) {
  final termineeLe = t.termineeLe;
  if (termineeLe != null) return 'Terminee le ${formaterDateHeure(termineeLe)}';
  final demarreeLe = t.demarreeLe;
  if (demarreeLe != null) return 'Demarree le ${formaterDateHeure(demarreeLe)}';
  final creeLe = t.creeLe;
  if (creeLe != null) return 'Proposee le ${formaterDateHeure(creeLe)}';
  return 'Date inconnue';
}
