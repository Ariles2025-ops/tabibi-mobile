// Lecture des avis (voir `Avis` et `SyntheseAvis`) : moyenne au format francais, note,
// libelle de statut, date et regles d'eligibilite d'un rendez-vous.

import '../models/avis.dart';
import '../models/synthese_avis.dart';
import 'dates.dart';
import 'libelles.dart';

/// Note la plus basse et la plus haute acceptees par l'API.
const int noteMinimale = 1;
const int noteMaximale = 5;

/// Vrai si la note est renseignee et comprise entre 1 et 5.
bool noteValide(int? note) => note != null && note >= noteMinimale && note <= noteMaximale;

/// « 4,5 » : une decimale, virgule francaise.
String formaterDecimal(double valeur) => valeur.toStringAsFixed(1).replaceAll('.', ',');

/// « 4,5 / 5 (12 avis) » ; « Aucun avis » tant que la moyenne est inconnue ou qu'aucun
/// avis n'est publie (« avis » est invariable).
String formaterMoyenne(SyntheseAvis synthese) {
  final moyenne = synthese.moyenne;
  if (moyenne == null || synthese.nombre <= 0) return 'Aucun avis';
  return '${formaterDecimal(moyenne)} / 5 (${synthese.nombre} avis)';
}

/// « 4 / 5 ».
String formaterNote(int note) => '$note / 5';

/// « PUBLIE » -> « Publié », « SIGNALE » -> « Signalé », « MASQUE » -> « Masqué » ;
/// toute autre valeur suit la mise en forme generique ([libelleStatut]).
String libelleStatutAvis(Object? statut) {
  return switch (statut?.toString().trim().toUpperCase()) {
    'PUBLIE' => 'Publié',
    'SIGNALE' => 'Signalé',
    'MASQUE' => 'Masqué',
    _ => libelleStatut(statut),
  };
}

/// Date de depot formatee (« jeu. 4 dec. 09:00 ») ; « date inconnue » si absente.
String dateAvis(Avis avis) {
  final deposeLe = avis.deposeLe;
  return deposeLe == null ? 'date inconnue' : formaterDateHeure(deposeLe);
}

/// Vrai si le statut brut d'un rendez-vous est HONORE : seul un rendez-vous honore
/// peut recevoir un avis.
bool estHonore(Object? statut) => (statut?.toString() ?? '').trim().toUpperCase() == 'HONORE';
