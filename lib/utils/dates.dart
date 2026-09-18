// Mise en forme des dates en francais, sans dependance a `intl`.

const List<String> _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

const List<String> _mois = [
  'janv.',
  'fevr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'aout',
  'sept.',
  'oct.',
  'nov.',
  'dec.',
];

/// « jeu. 4 dec. 09:00 » : jour de la semaine, jour, mois et heure locale.
String formaterDateHeure(DateTime date) {
  final d = date.toLocal();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]} $hh:$mm';
}

/// Idem a partir d'une chaine ISO 8601 ; la chaine brute est renvoyee si elle est invalide.
String formaterDateIso(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : formaterDateHeure(d);
}
