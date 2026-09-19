import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/utils/libelles.dart';
import 'package:tabibi_mobile/utils/ordonnances.dart';

import 'outils.dart';

void main() {
  setUp(preparerTests);

  test('nomFichierPdf nomme le fichier par le code de verification, sinon par l identifiant', () {
    expect(nomFichierPdf({'id': 'd4d4d4d4-0000', 'codeVerification': 'ABC123'}),
        'ordonnance-ABC123.pdf');
    // Caracteres hors lettres, chiffres, tiret et soulignement retires.
    expect(nomFichierPdf({'codeVerification': 'AB/C 1..23'}), 'ordonnance-ABC123.pdf');
    expect(
      nomFichierPdf({'id': 'd4d4d4d4-0000-4000-8000-000000000042', 'codeVerification': ''}),
      'ordonnance-d4d4d4d4.pdf',
    );
    expect(nomFichierPdf({}), 'ordonnance.pdf');
  });

  test('estPdf reconnait le type de contenu application/pdf', () {
    expect(estPdf('application/pdf'), isTrue);
    expect(estPdf('Application/PDF; charset=binary'), isTrue);
    expect(estPdf('application/json'), isFalse);
    expect(estPdf(''), isFalse);
    expect(estPdf(null), isFalse);
    expect(typePdf, 'application/pdf');
  });

  test('libelleStatut met en forme un statut brut et tolere une valeur absente', () {
    expect(libelleStatut('fr', 'EMISE'), 'Émise');
    expect(libelleStatut('fr', 'EN_ATTENTE'), 'En attente');
    expect(libelleStatut('fr', null), '');
    expect(libelleStatut('fr', ''), '');
    // Statut absent des dictionnaires : mise en forme generique.
    expect(libelleStatut('fr', 'AUTRE_STATUT'), 'Autre statut');
    expect(libelleStatut('ar', 'EMISE'), 'صادرة');
  });

  test('dateEmission formate emiseLe et signale une date absente', () {
    expect(dateEmission('fr', {'emiseLe': '2026-12-03T10:15:00'}), 'jeu. 3 déc. 10:15');
    expect(dateEmission('fr', {}), 'date inconnue');
    expect(dateEmission('fr', {'emiseLe': null}), 'date inconnue');
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
