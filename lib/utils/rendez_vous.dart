// Regles d'affichage d'un rendez-vous patient, alignees sur le site (mes-rendez-vous) :
// un rendez-vous passe n'est plus annulable et s'affiche « Terminé » s'il etait confirme.

import '../i18n/langue.dart';
import 'libelles.dart';

String _brut(Object? statut) => (statut?.toString() ?? '').trim().toUpperCase();

/// Vrai pour ANNULE, ANNULEE...
bool estAnnule(Object? statut) => _brut(statut).startsWith('ANNUL');

/// Vrai pour CONFIRME ou RESERVE (meme etat pour le patient).
bool estConfirme(Object? statut) => _brut(statut) == 'CONFIRME' || _brut(statut) == 'RESERVE';

/// Date de debut (ISO 8601) ; null si absente ou illisible.
DateTime? _debut(Object? debut) => debut == null ? null : DateTime.tryParse(debut.toString());

/// Vrai si le rendez-vous est a venir : ni annule, ni honore, ni absent, et pas encore commence.
bool estAVenir(Map<String, dynamic> rdv, {DateTime? maintenant}) {
  if (!peutEtreAnnule(rdv['statut'])) return false;
  final debut = _debut(rdv['debut']);
  return debut == null || !debut.isBefore(maintenant ?? DateTime.now());
}

/// Un rendez-vous annule, honore ou marque absent ne s'annule plus.
bool peutEtreAnnule(Object? statut) {
  final s = _brut(statut);
  return !estAnnule(s) && s != 'HONORE' && s != 'ABSENT';
}

/// Annulable : encore a venir (comme sur le site, l'historique n'a pas de bouton « Annuler »).
bool estAnnulable(Map<String, dynamic> rdv, {DateTime? maintenant}) =>
    estAVenir(rdv, maintenant: maintenant);

/// Libelle du statut cote patient ; confirme passe ou honore = « Terminé », absent = « Non honoré ».
String libelleStatutRendezVous(Map<String, dynamic> rdv, {DateTime? maintenant}) {
  if (estConfirme(rdv['statut']) && !estAVenir(rdv, maintenant: maintenant)) {
    return t('Terminé', 'منتهٍ');
  }
  // Vocabulaire patient, comme l'historique du site : consultation effectuee = « Terminé »,
  // absence = « Non honoré ». Les agendas medecin / secretaire gardent « Honoré » / « Absent ».
  final s = _brut(rdv['statut']);
  if (s == 'HONORE') return t('Terminé', 'منتهٍ');
  if (s == 'ABSENT') return t('Non honoré', 'لم يتم الحضور');
  return libelleStatut(rdv['statut']);
}

/// Rendez-vous separes comme sur le site : « À venir » (du plus proche au plus lointain)
/// puis « Passés » (du plus recent au plus ancien).
class RendezVousClasses {
  const RendezVousClasses(this.aVenir, this.passes);

  final List<Map<String, dynamic>> aVenir;
  final List<Map<String, dynamic>> passes;
}

/// Partitionne [rdvs] avec [estAVenir] ; un rendez-vous sans date lisible passe en fin de
/// section.
RendezVousClasses classerRendezVous(List<Map<String, dynamic>> rdvs, {DateTime? maintenant}) {
  final aVenir = <Map<String, dynamic>>[];
  final passes = <Map<String, dynamic>>[];
  for (final rdv in rdvs) {
    (estAVenir(rdv, maintenant: maintenant) ? aVenir : passes).add(rdv);
  }
  final fin = DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true);
  DateTime debut(Map<String, dynamic> r) => _debut(r['debut']) ?? fin;
  aVenir.sort((a, b) => debut(a).compareTo(debut(b)));
  passes.sort((a, b) => debut(b).compareTo(debut(a)));
  return RendezVousClasses(aVenir, passes);
}
