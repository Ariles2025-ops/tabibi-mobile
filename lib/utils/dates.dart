// Mise en forme des dates en francais ou en arabe (langue courante), sans dependance a `intl`.
// Les chiffres restent occidentaux (usage algerien).

import '../i18n/langue.dart';

/// Copie triee de la plus recente a la plus ancienne selon [date] (comme le site) ; les dates
/// absentes vont en fin de liste.
List<T> trierParDateRecente<T>(Iterable<T> elements, DateTime? Function(T) date) {
  final copie = List<T>.of(elements);
  copie.sort((a, b) {
    final da = date(a);
    final db = date(b);
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return copie;
}

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
/// mois et heure ; l'annee est ajoutee si [avecAnnee] (« jeu. 4 déc. 2025 09:00 »).
///
/// Un instant avec fuseau (« ...+01:00 », « ...Z » : [DateTime.isUtc]) est toujours affiche a
/// l'heure d'Algerie (UTC+1), comme sur le site, quel que soit le fuseau du telephone. Une
/// date sans fuseau est deja l'heure murale algerienne et n'est pas decalee.
String formaterDateHeure(DateTime date, {bool avecAnnee = false}) {
  final d = date.isUtc ? date.add(const Duration(hours: 1)) : date;
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final annee = avecAnnee ? ' ${d.year}' : '';
  return '${_jour(d.weekday)} ${d.day} ${_nomMois(d.month)}$annee $hh:$mm';
}

/// Idem a partir d'une chaine ISO 8601 ; la chaine brute est renvoyee si elle est invalide.
String formaterDateIso(String iso, {bool avecAnnee = false}) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : formaterDateHeure(d, avecAnnee: avecAnnee);
}

/// « 14 mai 1990 » : jour, mois et annee sans heure (date de naissance, par exemple).
String formaterJour(DateTime date) => '${date.day} ${_nomMois(date.month)} ${date.year}';

/// « 20 min » (« 20 دقيقة » en arabe) : duree d'un creneau ; [minutes] absent -> chaine vide.
String formaterDuree(Object? minutes) {
  if (minutes == null) return '';
  return t('$minutes min', '$minutes دقيقة');
}
