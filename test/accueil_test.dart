import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/main.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/services/auth_service.dart';

/// API factice : un seul praticien, aucune requete reseau.
class _ApiAccueil extends ApiService {
  const _ApiAccueil();

  @override
  Future<List<Map<String, dynamic>>> rechercherMedecins({
    String? specialite,
    String? wilaya,
    String? q,
  }) async =>
      [
        {
          'id': '00000000-0000-0000-0000-000000000001',
          'nomComplet': 'Dr Amina Benali',
          'specialiteSlug': 'cardiologue',
          'specialiteFr': 'Cardiologue',
          'wilayaCode': '16',
          'wilayaFr': 'Alger',
          'ville': 'Alger',
        },
      ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Langue.courante.value = Langue.francais);

  Future<void> afficher(WidgetTester tester) async {
    await tester.pumpWidget(TabibiApp(api: const _ApiAccueil(), auth: AuthService()));
    await tester.pumpAndSettle();
  }

  testWidgets("l'accueil affiche le titre, la recherche et la liste en francais", (tester) async {
    await afficher(tester);
    expect(find.text('Votre santé ne devrait jamais attendre'), findsOneWidget);
    expect(find.text('Nom du médecin'), findsOneWidget);
    expect(find.text('Spécialité'), findsOneWidget);
    expect(find.text('Wilaya'), findsOneWidget);
    expect(find.text('Lancement prochainement'), findsOneWidget);
    // Comme le site : « plateforme », jamais « annuaire » dans un texte visible.
    expect(find.textContaining('Trouvez déjà un médecin sur la plateforme.'), findsOneWidget);
    expect(find.textContaining('annuaire'), findsNothing);
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(find.text('AB'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Nom du médecin'))), TextDirection.ltr);
  });

  testWidgets("l'accueil affiche le titre, la recherche et la liste en arabe (RTL)",
      (tester) async {
    Langue.courante.value = Langue.arabe;
    await afficher(tester);
    expect(find.text('صحتك لا تحتمل الانتظار'), findsOneWidget);
    expect(find.text('اسم الطبيب'), findsOneWidget);
    expect(find.text('التخصص'), findsOneWidget);
    expect(find.text('الولاية'), findsOneWidget);
    expect(find.text('الإطلاق قريبًا'), findsOneWidget);
    expect(find.textContaining('منصة طبية: ابحث عن طبيب من الآن.'), findsOneWidget);
    expect(find.textContaining('دليل'), findsNothing);
    expect(find.text('Votre santé ne devrait jamais attendre'), findsNothing);
    expect(Directionality.of(tester.element(find.text('اسم الطبيب'))), TextDirection.rtl);
  });
}
