import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/widgets/liens_legaux.dart';
import 'package:tabibi_mobile/widgets/vue_connexion.dart';

void main() {
  tearDown(() => Langue.courante.value = Langue.francais);

  test('les liens visent les pages legales du site', () {
    expect(LiensLegaux.confidentialite.toString(), 'https://tabibi.doctor/legal/confidentialite.html');
    expect(LiensLegaux.conditions.toString(), 'https://tabibi.doctor/legal/cgu.html');
  });

  testWidgets('la politique de confidentialite est visible avant connexion (FR et AR)', (tester) async {
    for (final langue in [Langue.francais, Langue.arabe]) {
      Langue.courante.value = langue;
      await tester.pumpWidget(const SizedBox()); // reconstruit tout dans la nouvelle langue
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: Langue.direction,
          child: Scaffold(body: VueConnexion(message: 'm', onSeConnecter: () {})),
        ),
      ));
      expect(find.text(langue == Langue.arabe ? 'سياسة الخصوصية' : 'Politique de confidentialité'), findsOneWidget);
      expect(find.text(langue == Langue.arabe ? 'شروط الاستخدام' : "Conditions d'utilisation"), findsOneWidget);
    }
  });
}
