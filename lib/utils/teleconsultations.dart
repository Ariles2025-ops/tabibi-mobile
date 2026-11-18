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

/// Fenetre d'acces a la salle, comme sur le site : de 15 min avant le rendez-vous a 2 h apres.
const Duration avanceAcces = Duration(minutes: 15);
const Duration dureeAcces = Duration(hours: 2);

/// Vrai si [maintenant] est dans la fenetre d'acces du rendez-vous ; vrai aussi si la date du
/// rendez-vous est inconnue (on ne bloque pas sans information).
bool dansFenetreAcces(Teleconsultation tc, {DateTime? maintenant}) {
  final debut = tc.debutRendezVous;
  if (debut == null) return true;
  final now = maintenant ?? DateTime.now();
  return !now.isBefore(debut.subtract(avanceAcces)) && !now.isAfter(debut.add(dureeAcces));
}

/// Vrai si le patient peut rejoindre la salle : lien remis (donc consentement donne),
/// session planifiee ou en cours et fenetre d'acces ouverte.
bool peutRejoindre(Teleconsultation tc, {DateTime? maintenant}) =>
    tc.lienSalle != null && estActive(tc) && dansFenetreAcces(tc, maintenant: maintenant);

/// Texte affiche a la place du bouton « Rejoindre » hors fenetre ; null si la fenetre est ouverte.
String? texteHorsFenetre(Teleconsultation tc, {DateTime? maintenant}) {
  if (dansFenetreAcces(tc, maintenant: maintenant)) return null;
  final debut = tc.debutRendezVous!;
  if ((maintenant ?? DateTime.now()).isBefore(debut)) {
    return t('Disponible 15 min avant le rendez-vous', 'متاحة قبل 15 دقيقة من الموعد');
  }
  return t('Le créneau de ce rendez-vous est passé', 'انتهى وقت هذا الموعد');
}

/// Date a afficher selon l'avancement : « Terminee le ... », « Demarree le ... » ou
/// « Proposee le ... » (date de planification, format « jeu. 4 dec. 09:00 ») ;
/// « Date inconnue » si aucune date n'est lisible.
String dateTeleconsultation(Teleconsultation tc) {
  final rdv = tc.debutRendezVous;
  if (rdv != null && tc.termineeLe == null && tc.demarreeLe == null) {
    return '${t('Rendez-vous le', 'الموعد في')} ${formaterDateHeure(rdv)}';
  }
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
