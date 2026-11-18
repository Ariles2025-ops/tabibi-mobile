// Connexion dans l'appli (sans page web) : erreurs claires, retour connecte, compte a finaliser.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/pages/connexion_page.dart';
import 'package:tabibi_mobile/services/auth_service.dart';

class _AuthFausse extends AuthService {
  _AuthFausse(this.reponse);
  final String? reponse;
  final appels = <String>[];

  @override
  Future<String?> connexionDirecte(String email, String motDePasse) async {
    appels.add('$email/$motDePasse');
    if (reponse == null) accessToken = 'jeton';
    return reponse;
  }
}

Future<bool?> _ouvrir(WidgetTester tester, AuthService auth) async {
  bool? resultat;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => resultat = await Navigator.of(context)
            .push<bool>(MaterialPageRoute(builder: (_) => ConnexionPage(auth: auth))),
        child: const Text('ouvrir'),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return resultat;
}

Future<void> _saisir(WidgetTester tester, String email, String mdp) async {
  await tester.enterText(find.byKey(const ValueKey('connexion-email')), email);
  await tester.enterText(find.byKey(const ValueKey('connexion-mot-de-passe')), mdp);
  await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('champs vides : message, aucun appel au serveur', (tester) async {
    final auth = _AuthFausse(null);
    await _ouvrir(tester, auth);
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Saisissez votre e-mail et votre mot de passe.'), findsOneWidget);
    expect(auth.appels, isEmpty);
  });

  testWidgets('identifiants refusés : message clair, on reste sur l écran', (tester) async {
    final auth = _AuthFausse('invalid_grant');
    await _ouvrir(tester, auth);
    await _saisir(tester, ' dr@exemple.dz ', 'faux');
    expect(auth.appels, ['dr@exemple.dz/faux']); // e-mail nettoyé des espaces
    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
    expect(find.byType(ConnexionPage), findsOneWidget);
    expect(find.text('Définir mon mot de passe'), findsNothing);
  });

  testWidgets('connexion réussie : l écran se ferme et renvoie vrai', (tester) async {
    final auth = _AuthFausse(null);
    await _ouvrir(tester, auth);
    await _saisir(tester, 'dr@exemple.dz', 'bon');
    expect(find.byType(ConnexionPage), findsNothing);
    expect(auth.estConnecte, isTrue);
  });

  testWidgets('compte à finaliser : propose de définir le mot de passe', (tester) async {
    await _ouvrir(tester, _AuthFausse('account_incomplete'));
    await _saisir(tester, 'dr@exemple.dz', 'provisoire');
    expect(find.textContaining('Votre compte doit être finalisé'), findsOneWidget);
    expect(find.text('Définir mon mot de passe'), findsOneWidget);
  });
}
