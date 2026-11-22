import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/utils/dates.dart';

void main() {
  test('formate une date en francais court', () {
    expect(formaterDateHeure(DateTime(2026, 12, 3, 9, 5)), 'jeu. 3 déc. 09:05');
    expect(formaterDateHeure(DateTime(2026, 8, 30, 14, 0)), 'dim. 30 août 14:00');
  });

  test('accepte une chaine ISO 8601 et tolere une valeur invalide', () {
    expect(formaterDateIso('2026-12-03T09:00:00'), 'jeu. 3 déc. 09:00');
    expect(formaterDateIso('n/a'), 'n/a');
  });

  test("affiche l'annee a la demande", () {
    expect(formaterDateHeure(DateTime(2025, 12, 4, 9, 0), avecAnnee: true), 'jeu. 4 déc. 2025 09:00');
    expect(formaterDateIso('2025-12-04T09:00:00', avecAnnee: true), 'jeu. 4 déc. 2025 09:00');
  });

  test("affiche toujours l'heure d'Algerie (UTC+1) pour un instant avec fuseau", () {
    expect(formaterDateIso('2026-12-03T08:00:00Z'), 'jeu. 3 déc. 09:00');
    expect(formaterDateIso('2026-12-03T09:00:00+01:00'), 'jeu. 3 déc. 09:00');
    expect(formaterDateIso('2026-12-03T23:30:00Z'), 'ven. 4 déc. 00:30');
    expect(formaterDateIso('2026-12-03T09:00:00'), 'jeu. 3 déc. 09:00');
  });

  test('formate un jour sans heure (date de naissance)', () {
    expect(formaterJour(DateTime(1990, 5, 14)), '14 mai 1990');
    expect(formaterJour(DateTime(1985, 12, 3)), '3 déc. 1985');
  });

  test('formate la duree d\'un creneau en francais et en arabe', () {
    expect(formaterDuree(20), '20 min');
    expect(formaterDuree(null), '');
    Langue.courante.value = Langue.arabe;
    addTearDown(() => Langue.courante.value = Langue.francais);
    expect(formaterDuree(20), '20 دقيقة');
  });

  test('trierParDateRecente : du plus recent au plus ancien, dates absentes en fin', () {
    final tries = trierParDateRecente<({String id, DateTime? date})>([
      (id: 'sans1', date: null),
      (id: 'ancien', date: DateTime(2026, 1, 1)),
      (id: 'recent', date: DateTime(2026, 11, 20)),
      (id: 'milieu', date: DateTime(2026, 6, 1)),
    ], (e) => e.date);
    expect(tries.map((e) => e.id), ['recent', 'milieu', 'ancien', 'sans1']);
  });

  test('trierParDateRecente ne modifie pas la liste d\'origine', () {
    final origine = [DateTime(2026, 1, 1), DateTime(2026, 2, 1)];
    trierParDateRecente<DateTime>(origine, (d) => d);
    expect(origine.first, DateTime(2026, 1, 1));
  });
}
