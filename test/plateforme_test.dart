import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/config/lancement.dart';
import 'package:tabibi_mobile/config/referentiel.dart';
import 'package:tabibi_mobile/utils/praticien.dart';

void main() {
  test('memes drapeaux que le site : pre-lancement actif, visio fermee', () {
    expect(prelancement, isTrue);
    expect(visioActive, isFalse);
  });

  test('referentiel identique au site : 69 wilayas et slugs de l API', () {
    expect(wilayas.length, 69);
    expect(wilayas.last.code, '69');
    final slugs = specialites.map((s) => s.slug).toSet();
    expect(slugs, contains('medecin-generaliste'));
    expect(slugs, isNot(contains('generaliste')));
  });

  test('sous-titre praticien sans « null » quand la ville manque', () {
    expect(
        sousTitrePraticien({
          'specialiteFr': 'Cardiologue',
          'ville': null,
          'wilayaFr': 'Sétif'
        }),
        'Cardiologue · Sétif');
    expect(
        sousTitrePraticien({
          'specialiteFr': 'Dentiste',
          'ville': 'Kouba',
          'wilayaFr': 'Alger'
        }),
        'Dentiste · Kouba (Alger)');
  });

  test('sous-titre sans « Alger (Alger) » quand la ville est la wilaya', () {
    expect(
        sousTitrePraticien({
          'specialiteFr': 'Médecin généraliste',
          'ville': 'Alger',
          'wilayaFr': 'Alger'
        }),
        'Médecin généraliste · Alger');
  });
}
