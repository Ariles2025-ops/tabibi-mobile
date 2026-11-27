// Regles d'affichage d'un rendez-vous patient, alignees sur le site (mes-rendez-vous) :
// un rendez-vous passe n'est plus annulable et s'affiche « Terminé » s'il etait confirme.

import '../i18n/langue.dart';
import 'dates.dart';
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

/// Confirmation d'un déplacement, comme le site : « Rendez-vous déplacé au {date}. » (la date du
/// nouveau créneau) ; sans date lisible, le texte seul, jamais « null ».
String messageRendezVousDeplace(Object? debut) {
  final date = debut is String && debut.isNotEmpty ? formaterDateIso(debut) : '';
  if (date.isEmpty) return t('Rendez-vous déplacé.', 'تم نقل الموعد.');
  return t('Rendez-vous déplacé au $date.', 'تم نقل الموعد إلى $date.');
}

/// Message d'un déplacement refusé (409) : le texte « créneau pris » seul quand l'API dit que le
/// créneau n'est plus disponible ; sinon (chevauchement avec un autre rendez-vous...) le vrai
/// motif de l'API, déjà traduit par traduireErreurServeur.
String messageDeplacementRefuse(String messageApi) {
  final m = messageApi.toLowerCase();
  if (m.contains('plus disponible') || m.contains('pris') || m.contains('لم يعد متاحًا') || m.contains('حُجز')) {
    return t("Ce créneau vient d'être pris. Votre rendez-vous n'a pas changé : choisissez un autre créneau.",
        'هذا الموعد حُجز للتوّ. لم يتغيّر موعدك: اختر موعدًا آخر.');
  }
  return messageApi;
}

/// Confirmation d'un déplacement côté médecin/secrétaire, comme le site : « Rendez-vous déplacé au
/// {date} : le patient est prévenu. » ; pour un rendez-vous pris par téléphone (le patient n'a pas de
/// compte, personne ne le prévient) : « Rendez-vous déplacé au {date}. » sans promesse trompeuse.
String messageRendezVousDeplaceCabinet(Object? debut, {required bool patientPrevenu}) {
  final date = debut is String && debut.isNotEmpty ? formaterDateIso(debut) : '';
  if (date.isEmpty) {
    return patientPrevenu
        ? t('Rendez-vous déplacé : le patient est prévenu.', 'تم نقل الموعد: تم إعلام المريض.')
        : t('Rendez-vous déplacé.', 'تم نقل الموعد.');
  }
  return patientPrevenu
      ? t('Rendez-vous déplacé au $date : le patient est prévenu.', 'تم نقل الموعد إلى $date: تم إعلام المريض.')
      : t('Rendez-vous déplacé au $date.', 'تم نقل الموعد إلى $date.');
}

/// Confirmation d'une annulation côté médecin/secrétaire, comme le site : « Rendez-vous du {date}
/// annulé : le créneau est de nouveau proposé et le patient est prévenu. » ; pour un rendez-vous pris
/// par téléphone, sans « le patient est prévenu » (il n'a pas de compte, personne ne le prévient).
String messageRendezVousAnnuleCabinet(Object? debut, {required bool patientPrevenu}) {
  final date = debut is String && debut.isNotEmpty ? formaterDateIso(debut) : '';
  final fr = date.isEmpty ? 'Rendez-vous annulé' : 'Rendez-vous du $date annulé';
  final ar = date.isEmpty ? 'تم إلغاء الموعد' : 'تم إلغاء الموعد في $date';
  return t(
    '$fr : le créneau est de nouveau proposé${patientPrevenu ? ' et le patient est prévenu' : ''}.',
    '$ar: الموعد متاح من جديد${patientPrevenu ? ' وتم إعلام المريض' : ''}.',
  );
}
