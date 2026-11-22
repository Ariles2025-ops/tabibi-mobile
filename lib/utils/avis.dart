// Lecture des avis (voir `Avis` et `SyntheseAvis`) : moyenne au format francais, note,
// libelle de statut, date et regles d'eligibilite d'un rendez-vous.

import '../models/avis.dart';
import '../models/synthese_avis.dart';
import '../i18n/langue.dart';
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
  if (moyenne == null || synthese.nombre <= 0) return t('Aucun avis', 'لا توجد آراء');
  return t('${formaterDecimal(moyenne)} / 5 (${synthese.nombre} avis)',
      '${formaterDecimal(moyenne)} / 5 (${synthese.nombre} رأي)');
}

/// « 4 / 5 ».
String formaterNote(int note) => '$note / 5';

/// « PUBLIE » -> « Publié », « SIGNALE » -> « Signalé », « MASQUE » -> « Masqué » ;
/// toute autre valeur suit la mise en forme generique ([libelleStatut]).
String libelleStatutAvis(Object? statut) {
  return switch (statut?.toString().trim().toUpperCase()) {
    'PUBLIE' => t('Publié', 'منشور'),
    'SIGNALE' => t('Signalé', 'مُبلَّغ عنه'),
    'MASQUE' => t('Masqué', 'مخفي'),
    _ => libelleStatut(statut),
  };
}

/// Libelle cote patient (page « Mes avis »), comme sur le site : un avis signale est « En cours
/// de verification », un avis masque l'a ete « par la moderation » ; sinon [libelleStatutAvis].
String libelleStatutAvisPatient(Object? statut) {
  return switch (statut?.toString().trim().toUpperCase()) {
    'SIGNALE' => t('En cours de vérification', 'قيد التحقق'),
    'MASQUE' => t('Masqué par la modération', 'أخفته الإدارة'),
    _ => libelleStatutAvis(statut),
  };
}

/// Date de depot formatee (« jeu. 4 dec. 09:00 ») ; « date inconnue » si absente.
String dateAvis(Avis avis) {
  final deposeLe = avis.deposeLe;
  return deposeLe == null ? t('date inconnue', 'تاريخ غير معروف') : formaterDateHeure(deposeLe);
}

/// Vrai si le statut brut d'un rendez-vous est HONORE : seul un rendez-vous honore
/// peut recevoir un avis.
bool estHonore(Object? statut) => (statut?.toString() ?? '').trim().toUpperCase() == 'HONORE';

/// Refus du dépôt d'un avis, mêmes phrases que le site : 403 (rendez-vous d'un autre patient)
/// et 404 (rendez-vous inconnu) ; null pour les autres statuts.
String? messageRefusDepotAvis(int statut) => switch (statut) {
      403 => t('Seul le patient du rendez-vous peut donner son avis.',
          'يمكن لمريض هذا الموعد فقط إبداء رأيه.'),
      404 => t('Rendez-vous introuvable.', 'الموعد غير موجود.'),
      _ => null,
    };

/// Refus du signalement d'un avis par le médecin, mêmes phrases que le site : 403 (avis d'un autre
/// médecin), 409 (déjà signalé) et 404 (l'avis n'existe plus : la liste est alors rechargée) ;
/// null pour les autres statuts.
String? messageRefusSignalementAvis(int statut) => switch (statut) {
      403 => t('Cet avis ne vous concerne pas.', 'هذا الرأي لا يخصّك.'),
      409 => t('Cet avis a déjà été signalé.', 'تم الإبلاغ عن هذا الرأي من قبل.'),
      404 => t("Cet avis n'existe plus.", 'هذا الرأي لم يعد موجودًا.'),
      _ => null,
    };
