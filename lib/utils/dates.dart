// Mise en forme des dates en francais ou en arabe (langue courante), sans dependance a `intl`.
// Les chiffres restent occidentaux (usage algerien).

import '../i18n/langue.dart';

const List<String> _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

const List<String> _mois = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// Jours en arabe, du lundi au dimanche.
const List<String> _joursAr = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// Mois en arabe tels qu'on les nomme en Algerie.
const List<String> _moisAr = [
  'جانفي',
  'فيفري',
  'مارس',
  'أفريل',
  'ماي',
  'جوان',
  'جويلية',
  'أوت',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String _jour(int weekday) => (Langue.estArabe ? _joursAr : _jours)[weekday - 1];

String _nomMois(int mois) => (Langue.estArabe ? _moisAr : _mois)[mois - 1];

/// « jeu. 4 déc. 09:00 » (« الخميس 4 ديسمبر 09:00 » en arabe) : jour de la semaine, jour,
/// mois et heure locale.
String formaterDateHeure(DateTime date) {
  final d = date.toLocal();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${_jour(d.weekday)} ${d.day} ${_nomMois(d.month)} $hh:$mm';
}

/// Idem a partir d'une chaine ISO 8601 ; la chaine brute est renvoyee si elle est invalide.
String formaterDateIso(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : formaterDateHeure(d);
}

/// « 14 mai 1990 » : jour, mois et annee sans heure (date de naissance, par exemple).
String formaterJour(DateTime date) => '${date.day} ${_nomMois(date.month)} ${date.year}';
