import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/utils/libelles.dart';
import 'package:tabibi_mobile/utils/ordonnances.dart';

void main() {
  test('libelleStatut met en forme un statut brut et tolere une valeur absente', () {
    expect(libelleStatut('EMISE'), 'Emise');
    expect(libelleStatut('EN_ATTENTE'), 'En attente');
    expect(libelleStatut(null), '');
    expect(libelleStatut(''), '');
  });

  test('dateEmission formate emiseLe et signale une date absente', () {
    expect(dateEmission({'emiseLe': '2026-12-03T10:15:00'}), 'jeu. 3 dec. 10:15');
    expect(dateEmission({}), 'date inconnue');
    expect(dateEmission({'emiseLe': null}), 'date inconnue');
  });

  test('lignesOrdonnance renvoie les lignes et ignore un champ absent ou mal forme', () {
    final lignes = lignesOrdonnance({
      'lignes': [
        {'medicament': 'Paracetamol 1 g', 'posologie': '1 le matin', 'duree': '5 jours'},
        'pas une ligne',
      ],
    });
    expect(lignes.length, 1);
    expect(lignes.single['medicament'], 'Paracetamol 1 g');
    expect(lignesOrdonnance({}), isEmpty);
    expect(lignesOrdonnance({'lignes': 'n/a'}), isEmpty);
  });

  test('trierParEmission place la plus recente en tete et les dates illisibles en fin', () {
    final triees = trierParEmission([
      {'id': '1', 'emiseLe': '2026-01-10T09:00:00'},
      {'id': '2'},
      {'id': '3', 'emiseLe': '2026-03-05T09:00:00'},
    ]);
    expect(triees.map((o) => o['id']).toList(), ['3', '1', '2']);

    final illisible = trierParEmission([
      {'id': '4', 'emiseLe': 'n/a'},
      {'id': '5', 'emiseLe': '2026-03-05T09:00:00'},
    ]);
    expect(illisible.map((o) => o['id']).toList(), ['5', '4']);
  });
}
