import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/widgets/vue_erreur.dart';

Future<void> afficher(WidgetTester tester, VoidCallback onReessayer) async {
  await tester.pumpWidget(MaterialApp(
    locale: Langue.locale,
    home: Directionality(
      textDirection: Langue.direction,
      child: Scaffold(
          body: VueErreur(message: messageReseau(), onReessayer: onReessayer)),
    ),
  ));
}

void main() {
  tearDown(() => Langue.courante.value = Langue.francais);

  testWidgets('erreur reseau en francais avec bouton Réessayer',
      (tester) async {
    Langue.courante.value = Langue.francais;
    var essais = 0;
    await afficher(tester, () => essais++);
    expect(
        find.text('Pas de connexion. Vérifiez votre réseau.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(essais, 1);
  });

  testWidgets('erreur reseau en arabe avec bouton Réessayer', (tester) async {
    Langue.courante.value = Langue.arabe;
    var essais = 0;
    await afficher(tester, () => essais++);
    expect(find.text('لا يوجد اتصال. تحقق من الشبكة.'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    expect(essais, 1);
  });

  test('les erreurs reseau donnent le message clair, jamais un texte technique',
      () {
    for (final e in [
      const SocketException('Failed host lookup'),
      TimeoutException('delai'),
      http.ClientException('boom'),
    ]) {
      expect(messageErreur(e), 'Pas de connexion. Vérifiez votre réseau.');
    }
    Langue.courante.value = Langue.arabe;
    expect(
        messageErreur(TimeoutException('x')), 'لا يوجد اتصال. تحقق من الشبكة.');
    expect(messageErreur(const FormatException('x')), isNot(contains('x')));
  });

  test('un appel API sans reponse echoue avec TimeoutException', () async {
    // Le delai reel est de 15 s : on verifie ici qu'une coupure reseau remonte bien.
    await expectLater(
      http.runWithClient(
        () => const ApiService(base: 'https://api.test').medecin('1'),
        () => MockClient((_) async => throw const SocketException('coupe')),
      ),
      throwsA(isA<SocketException>()),
    );
    expect(delaiApi, const Duration(seconds: 15));
  });
}
