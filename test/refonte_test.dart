// Refonte du design : coque a onglets, onglet Compte, garde des comptes pro, choix du creneau.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/main.dart';
import 'package:tabibi_mobile/pages/fiche_medecin_page.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';

import 'espace_widget_test.dart' show FakeEspaceApi, SessionTest, afficher;
import 'widget_test.dart' show FakeApiService;

class _FicheSansCompte extends FakeApiService {
  const _FicheSansCompte();

  @override
  Future<bool> reclamable(String id) async => true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Langue.courante.value = Langue.francais);

  testWidgets(
      'la barre du bas propose Accueil, Rendez-vous, Ordonnances et Compte',
      (tester) async {
    await afficher(tester, CoqueApp(api: FakeEspaceApi(), auth: SessionTest()));
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final onglet in ['Accueil', 'Rendez-vous', 'Ordonnances', 'Compte']) {
      expect(
          find.descendant(
              of: find.byType(NavigationBar), matching: find.text(onglet)),
          findsOneWidget);
    }
    expect(find.text('Nom du médecin'), findsOneWidget);

    await tester.tap(find.text('Compte'));
    await tester.pumpAndSettle();
    expect(find.text('Mon compte'), findsOneWidget);
    expect(find.text('Compte connecté'), findsOneWidget);
    expect(find.text('Mes avis'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets(
      'compte pro sans role patient : Rendez-vous et Ordonnances renvoient vers Mon espace',
      (tester) async {
    await afficher(tester,
        CoqueApp(api: FakeEspaceApi(roles: ['MEDECIN']), auth: SessionTest()));
    await tester.tap(find.text('Rendez-vous'));
    await tester.pumpAndSettle();
    expect(find.text(messagePageReservee()), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Mon espace'), findsOneWidget);

    await tester.tap(find.text('Ordonnances'));
    await tester.pumpAndSettle();
    expect(find.text(messagePageReservee()), findsOneWidget);
  });

  testWidgets(
      'compte patient : l onglet Rendez-vous affiche ses rendez-vous, sans renvoi',
      (tester) async {
    await afficher(tester, CoqueApp(api: FakeEspaceApi(), auth: SessionTest()));
    await tester.tap(find.text('Rendez-vous'));
    await tester.pumpAndSettle();
    expect(find.text(messagePageReservee()), findsNothing);
  });

  testWidgets(
      'fiche : jour, heure puis un seul bouton Réserver avec le creneau choisi',
      (tester) async {
    await afficher(
        tester,
        const FicheMedecinPage(
            medecinId: FakeApiService.medecinDemo, api: FakeApiService()));
    expect(find.widgetWithText(ChoiceChip, '09:00'), findsOneWidget);
    expect(find.text('jeu. 3 déc. 09:00'),
        findsOneWidget); // recapitulatif du creneau choisi
    expect(find.text('30 min'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Réserver'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '09:30'),
        findsNothing); // creneau deja pris
  });

  testWidgets(
      'fiche sans compte : encart « pas encore sur Ndawik », sans conversation ni liste d attente',
      (tester) async {
    await afficher(
        tester,
        const FicheMedecinPage(
            medecinId: FakeApiService.medecinDemo, api: _FicheSansCompte()));
    expect(find.text(titreFicheSansCompte), findsOneWidget);
    expect(find.text(texteFicheSansCompte), findsOneWidget);
    expect(find.text('Ouvrir une conversation'), findsNothing);
    expect(find.text("Liste d'attente"), findsNothing);
    expect(find.text('Créneaux disponibles'), findsNothing);
  });

  testWidgets('fiche avec compte : conversation et liste d attente restent',
      (tester) async {
    await afficher(
        tester,
        const FicheMedecinPage(
            medecinId: FakeApiService.medecinDemo, api: FakeApiService()));
    expect(find.text(titreFicheSansCompte), findsNothing);
    expect(find.text('Ouvrir une conversation'), findsOneWidget);
  });
}
