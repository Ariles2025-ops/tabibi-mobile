import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/widgets/liens_legaux.dart';
import 'package:tabibi_mobile/widgets/vue_connexion.dart';

void main() {
  tearDown(() => Langue.courante.value = Langue.francais);

  test('les liens visent les pages legales du site', () {
    expect(LiensLegaux.confidentialite.toString(), 'https://ndawik.com/legal/confidentialite.html');
    expect(LiensLegaux.conditions.toString(), 'https://ndawik.com/legal/cgu.html');
    expect(LiensLegaux.mentions.toString(), 'https://ndawik.com/legal/mentions-legales.html');
  });

  test("le centre d'aide suit la langue de l'interface", () {
    expect(LiensLegaux.aide().toString(), 'https://ndawik.com/aide');
    Langue.courante.value = Langue.arabe;
    expect(LiensLegaux.aide().toString(), 'https://ndawik.com/ar/aide');
  });

  test('« À propos » et « Nous contacter » comme le pied de page du site', () {
    expect(LiensLegaux.aPropos().toString(), 'https://ndawik.com/a-propos');
    expect(LiensLegaux.contact.toString(), 'mailto:contact@ndawik.com');
    Langue.courante.value = Langue.arabe;
    expect(LiensLegaux.aPropos().toString(), 'https://ndawik.com/ar/a-propos');
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
      expect(find.text(langue == Langue.arabe ? 'الإشعارات القانونية' : 'Mentions légales'), findsOneWidget);
      expect(find.text(langue == Langue.arabe ? 'مركز المساعدة' : "Centre d'aide"), findsOneWidget);
      expect(find.text(langue == Langue.arabe ? 'عن نداويك' : 'À propos'), findsOneWidget);
      expect(find.text(langue == Langue.arabe ? 'اتصل بنا' : 'Nous contacter'), findsOneWidget);
    }
  });
}
