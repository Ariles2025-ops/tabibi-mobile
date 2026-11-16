import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';

void main() {
  test('rolesDe lit les roles de GET /api/moi en majuscules', () {
    expect(
        rolesDe({
          'roles': ['medecin', 'PATIENT']
        }),
        {'MEDECIN', 'PATIENT'});
    expect(rolesDe({}), isEmpty);
  });

  test('espacesPour et aUnEspacePro suivent les roles', () {
    expect(espacesPour({'PATIENT'}), isEmpty);
    expect(aUnEspacePro({'PATIENT'}), isFalse);
    expect(espacesPour({'PHARMACIE', 'MEDECIN', 'SECRETAIRE'}),
        [Espace.medecin, Espace.secretaire, Espace.pharmacie]);
    expect(aUnEspacePro({'SECRETAIRE'}), isTrue);
  });

  test('statutAgenda traite RESERVE comme CONFIRME ; actions seulement si confirme', () {
    expect(statutAgenda('RESERVE'), 'CONFIRME');
    expect(statutAgenda('honore'), 'HONORE');
    expect(actionsCabinetPossibles('RESERVE'), isTrue);
    expect(actionsCabinetPossibles('CONFIRME'), isTrue);
    expect(actionsCabinetPossibles('ANNULE'), isFalse);
    expect(actionsCabinetPossibles('HONORE'), isFalse);
  });

  test('trierParDebut range du plus proche au plus lointain, dates absentes a la fin', () {
    final tries = trierParDebut([
      {'id': 'b', 'debut': '2026-12-04T09:00:00Z'},
      {'id': 'x'},
      {'id': 'a', 'debut': '2026-12-03T09:00:00Z'},
    ]);
    expect(tries.map((e) => e['id']), ['a', 'b', 'x']);
  });

  test('creneauxSerie : jours retenus, plage horaire, duree, sans les debuts passes', () {
    // Lundi 7 decembre 2026 ; serie de 7 jours, lundi et mercredi, 9 h a 10 h, 30 min.
    final serie = creneauxSerie(
      premierJour: DateTime(2026, 12, 7),
      jours: {DateTime.monday, DateTime.wednesday},
      debutMinutes: 9 * 60,
      finMinutes: 10 * 60,
      dureeMinutes: 30,
      maintenant: DateTime(2026, 12, 7, 9, 10),
    );
    expect(serie, [
      DateTime(2026, 12, 7, 9, 30),
      DateTime(2026, 12, 9, 9, 0),
      DateTime(2026, 12, 9, 9, 30),
    ]);
    expect(
      creneauxSerie(
        premierJour: DateTime(2026, 12, 7),
        jours: {1},
        debutMinutes: 600,
        finMinutes: 600,
        dureeMinutes: 30,
        maintenant: DateTime(2026),
      ),
      isEmpty,
    );
  });
}
