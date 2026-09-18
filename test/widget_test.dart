import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/main.dart';
import 'package:tabibi_mobile/pages/detail_ordonnance_page.dart';
import 'package:tabibi_mobile/pages/fiche_medecin_page.dart';
import 'package:tabibi_mobile/pages/mes_ordonnances_page.dart';
import 'package:tabibi_mobile/pages/verifier_ordonnance_page.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/services/auth_service.dart';

/// API factice : aucune requete reseau, donnees fixes.
class FakeApiService extends ApiService {
  const FakeApiService();

  /// Code de verification de l'ordonnance factice (seul code reconnu par [verifierOrdonnance]).
  static const String codeValide = 'ABC123';

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

  @override
  Future<List<Map<String, dynamic>>> mesOrdonnances(String token) async => [_ordonnance(42)];

  @override
  Future<Map<String, dynamic>> ordonnance(int id, String token) async => _ordonnance(id);

  @override
  Future<Map<String, dynamic>> verifierOrdonnance(String code) async => code == codeValide
      ? {'valide': true, 'emiseLe': '2026-12-03T10:15:00', 'statut': 'EMISE'}
      : {'valide': false};

  static Map<String, dynamic> _ordonnance(int id) => {
        'id': id,
        'medecinId': 1,
        'patientId': 7,
        'rendezVousId': 3,
        'lignes': [
          {
            'medicament': 'Paracetamol 1 g',
            'posologie': '1 comprime matin et soir',
            'duree': '5 jours',
          },
          {
            'medicament': 'Amoxicilline 500 mg',
            'posologie': '1 gelule 3 fois par jour',
            'duree': '7 jours',
          },
        ],
        'emiseLe': '2026-12-03T10:15:00',
        'codeVerification': codeValide,
        'statut': 'EMISE',
      };
}

/// Session de test deja munie d'un jeton (aucun appel a Keycloak).
AuthService sessionConnectee() => AuthService()..accessToken = 'jeton-test';

void main() {
  testWidgets('affiche le champ de recherche et les acces aux ordonnances au demarrage',
      (tester) async {
    await tester.pumpWidget(const TabibiApp());
    expect(find.text('Nom du medecin'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
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

  testWidgets('mes ordonnances sans jeton propose de se connecter', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesOrdonnancesPage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.textContaining('ABC123'), findsNothing);
  });

  testWidgets('mes ordonnances liste date, code et statut, puis ouvre le detail',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesOrdonnancesPage(api: const FakeApiService(), auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mes ordonnances'), findsOneWidget);
    expect(find.text('Emise le jeu. 3 dec. 10:15'), findsOneWidget);
    expect(find.text('Code ABC123 · Emise'), findsOneWidget);

    await tester.tap(find.text('Code ABC123 · Emise'));
    await tester.pumpAndSettle();
    expect(find.text('Ordonnance'), findsOneWidget);
    expect(find.text('Paracetamol 1 g'), findsOneWidget);
  });

  testWidgets("le detail d'une ordonnance affiche le praticien, le code et les medicaments",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DetailOrdonnancePage(
        ordonnanceId: 42,
        api: const FakeApiService(),
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ordonnance'), findsOneWidget);
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(find.text('Emise le jeu. 3 dec. 10:15 · Emise'), findsOneWidget);
    // Code de verification bien visible (SelectableText).
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    // Une carte par ligne : medicament, posologie, duree.
    expect(find.text('Paracetamol 1 g'), findsOneWidget);
    expect(find.text('Posologie : 1 comprime matin et soir'), findsOneWidget);
    expect(find.text('Duree : 5 jours'), findsOneWidget);
    expect(find.text('Amoxicilline 500 mg'), findsOneWidget);
  });

  testWidgets("la verification publique distingue un code authentique d'un code inconnu",
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: VerifierOrdonnancePage(api: FakeApiService()),
    ));

    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.tap(find.text('Verifier'));
    await tester.pumpAndSettle();
    expect(find.text('Ordonnance authentique, emise le jeu. 3 dec. 10:15'), findsOneWidget);
    expect(find.text('Statut : Emise'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ZZZ999');
    await tester.tap(find.text('Verifier'));
    await tester.pumpAndSettle();
    expect(find.text('Code inconnu'), findsOneWidget);
    expect(find.textContaining('Ordonnance authentique'), findsNothing);
  });
}
