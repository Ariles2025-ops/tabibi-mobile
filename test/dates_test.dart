import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/utils/dates.dart';

void main() {
  test('formate une date en francais court', () {
    expect(formaterDateHeure(DateTime(2026, 12, 3, 9, 5)), 'jeu. 3 dec. 09:05');
    expect(formaterDateHeure(DateTime(2026, 8, 30, 14, 0)), 'dim. 30 aout 14:00');
  });

  test('accepte une chaine ISO 8601 et tolere une valeur invalide', () {
    expect(formaterDateIso('2026-12-03T09:00:00'), 'jeu. 3 dec. 09:00');
    expect(formaterDateIso('n/a'), 'n/a');
  });
}
