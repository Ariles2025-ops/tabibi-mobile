import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/utils/dates.dart';

import 'outils.dart';

void main() {
  setUp(preparerTests);

  test('formate une date en francais court', () {
    expect(formaterDateHeure('fr', DateTime(2026, 12, 3, 9, 5)), 'jeu. 3 déc. 09:05');
    expect(formaterDateHeure('fr', DateTime(2026, 8, 30, 14, 0)), 'dim. 30 août 14:00');
  });

  test('accepte une chaine ISO 8601 et tolere une valeur invalide', () {
    expect(formaterDateIso('fr', '2026-12-03T09:00:00'), 'jeu. 3 déc. 09:00');
    expect(formaterDateIso('fr', 'n/a'), 'n/a');
  });

  test('formate un jour sans heure (date de naissance)', () {
    expect(formaterJour('fr', DateTime(1990, 5, 14)), '14 mai 1990');
    expect(formaterJour('fr', DateTime(1985, 12, 3)), '3 déc. 1985');
  });

  test('suit la langue demandee : anglais et arabe donnent un autre libelle', () {
    final anglais = formaterDateHeure('en', DateTime(2026, 12, 3, 9, 5));
    expect(anglais, contains('Dec'));
    expect(anglais, contains('09:05'));
    // Arabe d'Algerie : mois maghrebins, chiffres arabes occidentaux.
    final arabe = formaterDateHeure('ar', DateTime(2026, 12, 3, 9, 5));
    expect(arabe, contains('3'));
    expect(arabe, contains('09:05'));
    expect(arabe, isNot(anglais));
    expect(arabe, isNot(formaterDateHeure('fr', DateTime(2026, 12, 3, 9, 5))));
  });

  test('localeDates replie sur une locale connue de intl', () {
    expect(localeDates('fr'), 'fr');
    expect(localeDates('en'), 'en');
    expect(localeDates('ar'), anyOf('ar_DZ', 'ar'));
  });
}
