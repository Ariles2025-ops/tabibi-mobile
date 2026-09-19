// Lecture des avis (voir `Avis` et `SyntheseAvis`) : moyenne dans la langue de l'interface,
// note, libelle de statut, date et regles d'eligibilite d'un rendez-vous.

import '../i18n/traductions.dart' as i18n;
import '../models/avis.dart';
import '../models/synthese_avis.dart';
import 'dates.dart';
import 'libelles.dart';

/// Note la plus basse et la plus haute acceptees par l'API.
const int noteMinimale = 1;
const int noteMaximale = 5;

/// Vrai si la note est renseignee et comprise entre 1 et 5.
bool noteValide(int? note) => note != null && note >= noteMinimale && note <= noteMaximale;

/// « 4,5 » : une decimale et le separateur decimal de la langue
/// (`format.separateurDecimal` : virgule en francais et en arabe, point en anglais).
String formaterDecimal(String langue, double valeur) =>
    valeur.toStringAsFixed(1).replaceAll('.', i18n.traduire(langue, 'format.separateurDecimal'));

/// « 4,5 / 5 (12 avis) » ; « Aucun avis » tant que la moyenne est inconnue ou qu'aucun
/// avis n'est publie.
String formaterMoyenne(String langue, SyntheseAvis synthese) {
  final moyenne = synthese.moyenne;
  if (moyenne == null || synthese.nombre <= 0) return i18n.traduire(langue, 'avis.aucun');
  return i18n.traduire(langue, 'avis.moyenne', params: {
    'moyenne': formaterDecimal(langue, moyenne),
    'nombre': i18n.traduirePluriel(langue, 'avis.nombre', synthese.nombre),
  });
}

/// « 4 / 5 ».
String formaterNote(String langue, int note) =>
    i18n.traduire(langue, 'avis.note', params: {'note': note});

/// « PUBLIE » -> « Publié », « SIGNALE » -> « Signalé », « MASQUE » -> « Masqué » ;
/// toute autre valeur suit la mise en forme generique ([libelleStatut]).
String libelleStatutAvis(String langue, Object? statut) => libelleStatut(langue, statut);

/// Date de depot formatee (« jeu. 4 déc. 09:00 ») ; « date inconnue » si absente.
String dateAvis(String langue, Avis avis) {
  final deposeLe = avis.deposeLe;
  return deposeLe == null
      ? i18n.traduire(langue, 'commun.dateInconnue')
      : formaterDateHeure(langue, deposeLe);
}

/// Vrai si le statut brut d'un rendez-vous est HONORE : seul un rendez-vous honore
/// peut recevoir un avis.
bool estHonore(Object? statut) => (statut?.toString() ?? '').trim().toUpperCase() == 'HONORE';
