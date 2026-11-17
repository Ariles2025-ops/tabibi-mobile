// Libelles lisibles a partir des valeurs brutes renvoyees par l'API.

import '../i18n/langue.dart';

/// « CONFIRME » -> « Confirmé », « EN_ATTENTE » -> « En attente » (ou leur traduction arabe) ;
/// chaine vide si absent. RESERVE est affiche comme CONFIRME (meme etat pour le patient).
String libelleStatut(Object? statut) {
  final brut = (statut?.toString() ?? '').trim().toUpperCase();
  if (brut.isEmpty) return '';
  final connu = _statuts[brut];
  if (connu != null) return t(connu.$1, connu.$2);
  final s = brut.replaceAll('_', ' ').toLowerCase();
  return s[0].toUpperCase() + s.substring(1);
}

/// Statuts de l'API (sans accents) : libelle francais accentue et libelle arabe.
const Map<String, (String, String)> _statuts = {
  'CONFIRME': ('Confirmé', 'مؤكد'),
  'RESERVE': ('Confirmé', 'مؤكد'),
  'ANNULE': ('Annulé', 'ملغى'),
  'ANNULEE': ('Annulée', 'ملغاة'),
  'HONORE': ('Honoré', 'تم الحضور'),
  'ABSENT': ('Absent', 'غائب'),
  'EN_ATTENTE': ('En attente', 'قيد الانتظار'),
  'EN_COURS': ('En cours', 'جارية'),
  'CLOTURE': ('Clôturé', 'مغلق'),
  'OUVERT': ('Ouvert', 'مفتوح'),
  'EXPIREE': ('Expirée', 'منتهية الصلاحية'),
  'DELIVREE': ('Délivrée', 'مصروفة'),
  'TERMINEE': ('Terminée', 'منتهية'),
  'PLANIFIEE': ('Planifiée', 'مبرمجة'),
  'DEMARREE': ('Démarrée', 'بدأت'),
  'VALIDEE': ('Validée', 'مُعتمدة'),
  'REFUSEE': ('Refusée', 'مرفوضة'),
  'MASQUE': ('Masqué', 'مخفي'),
  'PUBLIE': ('Publié', 'منشور'),
  'SIGNALE': ('Signalé', 'مُبلّغ عنه'),
  'EMISE': ('Émise', 'صادرة'),
};
