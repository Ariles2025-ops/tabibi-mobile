// Lecture des teleconsultations (voir `Teleconsultation`) : libelle de statut, date affichee
// et regles d'acces a la salle video.

import '../i18n/langue.dart';
import '../models/teleconsultation.dart';
import 'dates.dart';
import 'libelles.dart';

/// « PLANIFIEE » -> « Planifiee », « EN_COURS » -> « En cours »,
/// « TERMINEE » -> « Terminee », « ANNULEE » -> « Annulee » ;
/// toute autre valeur suit la mise en forme generique ([libelleStatut]).
String libelleStatutTeleconsultation(Object? statut) {
  return switch (statut?.toString().trim().toUpperCase()) {
    'PLANIFIEE' => t('Planifiée', 'مبرمجة'),
    'EN_COURS' => t('En cours', 'جارية'),
    'TERMINEE' => t('Terminée', 'منتهية'),
    'ANNULEE' => t('Annulée', 'ملغاة'),
    _ => libelleStatut(statut),
  };
}

/// Vrai si la session peut encore avoir lieu : planifiee ou en cours.
bool estActive(Teleconsultation tc) => tc.statut == 'PLANIFIEE' || tc.statut == 'EN_COURS';

/// Vrai si le patient peut rejoindre la salle : lien remis (donc consentement donne)
/// et session planifiee ou en cours.
bool peutRejoindre(Teleconsultation tc) => tc.lienSalle != null && estActive(tc);

/// Date a afficher selon l'avancement : « Terminee le ... », « Demarree le ... » ou
/// « Proposee le ... » (date de planification, format « jeu. 4 dec. 09:00 ») ;
/// « Date inconnue » si aucune date n'est lisible.
String dateTeleconsultation(Teleconsultation tc) {
  final termineeLe = tc.termineeLe;
  if (termineeLe != null) {
    return '${t('Terminée le', 'انتهت في')} ${formaterDateHeure(termineeLe)}';
  }
  final demarreeLe = tc.demarreeLe;
  if (demarreeLe != null) {
    return '${t('Démarrée le', 'بدأت في')} ${formaterDateHeure(demarreeLe)}';
  }
  final creeLe = tc.creeLe;
  if (creeLe != null) return '${t('Proposée le', 'اقتُرحت في')} ${formaterDateHeure(creeLe)}';
  return t('Date inconnue', 'تاريخ غير معروف');
}
