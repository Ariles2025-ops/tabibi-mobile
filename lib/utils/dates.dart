// Mise en forme des dates dans la langue de l'interface, via `intl` (`DateFormat`) : la
// locale et les motifs sont des cles de traduction (`dates.locale`, `dates.dateHeure`,
// `dates.jour`), l'arabe utilisant la locale algerienne `ar_DZ` (mois « جانفي »...).
//
// [preparerDates] charge les donnees de locale une fois pour toutes, au demarrage (`main`)
// comme dans les tests : sans cet appel, `DateFormat` ne connait que l'anglais.

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../i18n/traductions.dart' as i18n;

/// Charge les donnees de date de toutes les locales (a appeler avant tout formatage).
Future<void> preparerDates() => initializeDateFormatting();

/// Locale `intl` de [langue], repliee sur la langue seule (« ar_DZ » -> « ar ») puis sur
/// l'anglais si ses donnees n'ont pas ete chargees.
String localeDates(String langue) {
  final demandee = i18n.traduire(langue, 'dates.locale');
  if (DateFormat.localeExists(demandee)) return demandee;
  final court = demandee.split('_').first;
  return DateFormat.localeExists(court) ? court : 'en';
}

/// « jeu. 4 déc. 09:00 » : jour de la semaine, jour, mois et heure locale.
String formaterDateHeure(String langue, DateTime date) {
  final motif = i18n.traduire(langue, 'dates.dateHeure');
  return DateFormat(motif, localeDates(langue)).format(date.toLocal());
}

/// Idem a partir d'une chaine ISO 8601 ; la chaine brute est renvoyee si elle est invalide.
String formaterDateIso(String langue, String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : formaterDateHeure(langue, d);
}

/// « 14 mai 1990 » : jour, mois et annee sans heure (date de naissance, par exemple).
String formaterJour(String langue, DateTime date) =>
    DateFormat(i18n.traduire(langue, 'dates.jour'), localeDates(langue)).format(date);
