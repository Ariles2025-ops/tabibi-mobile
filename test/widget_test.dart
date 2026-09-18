import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/main.dart';
import 'package:tabibi_mobile/pages/fiche_medecin_page.dart';
import 'package:tabibi_mobile/services/api_service.dart';

/// API factice : aucune requete reseau, donnees fixes.
class FakeApiService extends ApiService {
  const FakeApiService();

  @override
  Future<Map<String, dynamic>> medecin(int id) async => {
        'id': id,
        'nomComplet': 'Dr Amina Benali',
        'specialiteSlug': 'cardiologue',
        'specialiteFr': 'Cardiologue',
        'wilayaCode': '16',
        'wilayaFr': 'Alger',
        'ville': 'Alger',
      };

  @override
  Future<List<Map<String, dynamic>>> creneaux(int medecinId) async => [
        {
          'id': 10,
          'medecinId': medecinId,
          'debut': '2026-12-03T09:00:00',
          'dureeMinutes': 30,
          'disponible': true,
        },
        {
          'id': 11,
          'medecinId': medecinId,
          'debut': '2026-12-03T09:30:00',
          'dureeMinutes': 30,
          'disponible': false,
        },
      ];
}

void main() {
  testWidgets('affiche le champ de recherche au demarrage', (tester) async {
    await tester.pumpWidget(const TabibiApp());
    expect(find.text('Nom du medecin'), findsOneWidget);
  });

  testWidgets('la fiche medecin affiche le titre, le praticien et ses creneaux disponibles',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FicheMedecinPage(medecinId: 1, api: FakeApiService()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Fiche medecin'), findsOneWidget);
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(find.text('Cardiologue · Alger (Alger)'), findsOneWidget);
    // Seul le creneau disponible est propose a la reservation.
    expect(find.text('jeu. 3 dec. 09:00'), findsOneWidget);
    expect(find.text('jeu. 3 dec. 09:30'), findsNothing);
    expect(find.text('Reserver'), findsOneWidget);
  });
}
