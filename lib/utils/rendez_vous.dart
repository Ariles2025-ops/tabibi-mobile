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

/// Libelle du statut ; un rendez-vous confirme dont l'heure est passee est « Terminé ».
String libelleStatutRendezVous(Map<String, dynamic> rdv, {DateTime? maintenant}) {
  if (estConfirme(rdv['statut']) && !estAVenir(rdv, maintenant: maintenant)) {
    return t('Terminé', 'منتهٍ');
  }
  return libelleStatut(rdv['statut']);
}
