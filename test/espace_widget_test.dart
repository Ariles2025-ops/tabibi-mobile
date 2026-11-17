import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/main.dart';
import 'package:tabibi_mobile/pages/dawini_page.dart';
import 'package:tabibi_mobile/pages/espace/agenda_page.dart';
import 'package:tabibi_mobile/pages/espace/cabinet.dart';
import 'package:tabibi_mobile/pages/espace/cabinet_pages.dart';
import 'package:tabibi_mobile/pages/espace/creneaux_page.dart';
import 'package:tabibi_mobile/pages/espace/fiche_semaine_pages.dart';
import 'package:tabibi_mobile/pages/espace/mon_espace_page.dart';
import 'package:tabibi_mobile/pages/espace/pharmacie_pages.dart';
import 'package:tabibi_mobile/pages/mon_profil_page.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/services/auth_service.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';

const medecinId = '00000000-0000-0000-0000-000000000001';
const patientId = 'a1a1a1a1-0000-4000-8000-000000000007';

/// API factice des espaces professionnels : donnees fixes, appels notes dans [appels].
class FakeEspaceApi extends ApiService {
  FakeEspaceApi({this.roles = const ['PATIENT'], this.wilayaProfil = '16'});

  final List<String> roles;
  final String? wilayaProfil;
  final appels = <String>[];

  /// Quand vrai, les routes semaine type / fiche / RDV telephone repondent 404.
  bool routesAbsentes = false;

  @override
  Future<Map<String, dynamic>> ficheMedecin(String token) async {
    if (routesAbsentes) throw const ApiException(404, 'absent');
    return {'adresse': 'Rue 1', 'telephoneCabinet': '023 45 67 89', 'langues': ['fr', 'ar']};
  }

  @override
  Future<Map<String, dynamic>> modifierFicheMedecin(
      Map<String, dynamic> corps, String token) async {
    appels.add('fiche ${corps['adresse']} ${corps['langues']}');
    return corps;
  }

  @override
  Future<Map<String, dynamic>> semaineTypeMedecin(Map<String, dynamic> corps, String token) async {
    if (routesAbsentes) throw const ApiException(404, 'absent');
    appels.add('semaine ${corps['jours']} ${corps['nombreSemaines']}');
    return {'crees': 12, 'ignores': 2};
  }

  @override
  Future<Map<String, dynamic>> rdvTelephoneSecretaire(
      String medecinId, Map<String, dynamic> corps, String token) async {
    if (routesAbsentes) throw const ApiException(404, 'absent');
    appels.add('tel ${corps['creneauId']} ${corps['nomPatient']}');
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> creneauxSecretaire(String medecinId, String token) =>
      creneauxMedecin(token);

  @override
  Future<List<Map<String, dynamic>>> rechercherMedecins(
          {String? specialite, String? wilaya, String? q}) async =>
      [await medecin(medecinId)];

  @override
  Future<Map<String, dynamic>> medecin(String id) async => {
        'id': id,
        'nomComplet': 'Dr Amina Benali',
        'specialiteSlug': 'cardiologue',
        'wilayaCode': '16'
      };

  @override
  Future<int> nombreNonLues(String token) async => 0;

  @override
  Future<Map<String, dynamic>> moi(String token) async =>
      {'sujet': patientId, 'nom': 'karim', 'roles': roles};

  @override
  Future<Map<String, dynamic>> monProfil(String token) async {
    if (wilayaProfil == null) throw const ApiException(404, 'Profil non renseigné.');
    return {'nomComplet': 'Karim Haddad', 'wilayaCode': wilayaProfil, 'langue': 'fr'};
  }

  @override
  Future<void> supprimerMonCompte(String token) async => appels.add('supprimer');

  Map<String, dynamic> _rdv(String id, String statut) => {
        'id': id,
        'patientId': patientId,
        'medecinId': medecinId,
        'debut': '2026-12-03T08:00:00Z',
        'statut': statut,
      };

  @override
  Future<List<Map<String, dynamic>>> agendaMedecin(String token) async =>
      [_rdv('r1', 'RESERVE'), _rdv('r2', 'HONORE')];

  @override
  Future<List<Map<String, dynamic>>> agendaSecretaire(String medecinId, String token) async =>
      [_rdv('r3', 'CONFIRME')];

  @override
  Future<List<Map<String, dynamic>>> patientsMedecin(String token) async => [
        {'patientId': patientId, 'nomComplet': 'Karim Haddad', 'telephone': '0550123456'}
      ];

  @override
  Future<List<Map<String, dynamic>>> patientsCabinet(String medecinId, String token) async =>
      patientsMedecin(token);

  @override
  Future<void> honorerRendezVous(String rdvId, String token) async => appels.add('honorer $rdvId');

  @override
  Future<void> marquerAbsentMedecin(String rdvId, String token) async =>
      appels.add('absent $rdvId');

  @override
  Future<void> annulerParMedecin(String rdvId, String token) async => appels.add('annuler $rdvId');

  @override
  Future<void> annulerParSecretaire(String rdvId, String token) async =>
      appels.add('annuler secretaire $rdvId');

  @override
  Future<List<Map<String, dynamic>>> creneauxMedecin(String token) async => [
        {'id': 'c1', 'debut': '2026-12-03T08:00:00Z', 'dureeMinutes': 30, 'disponible': true},
        {'id': 'c2', 'debut': '2026-12-03T09:00:00Z', 'dureeMinutes': 30, 'disponible': false},
      ];

  @override
  Future<Map<String, dynamic>> ouvrirCreneauMedecin(
      DateTime debut, int dureeMinutes, String token) async {
    // Heure murale d'Alger de l'instant envoye, quel que soit le fuseau du telephone / du runner.
    final alger = muraleAlger(debut);
    appels.add('ouvrir ${alger.hour}:${alger.minute} $dureeMinutes');
    return {};
  }

  @override
  Future<void> supprimerCreneauMedecin(String creneauId, String token) async =>
      appels.add('supprimer $creneauId');

  @override
  Future<List<Map<String, dynamic>>> listeAttenteMedecin(String token) async => [
        {
          'id': 'l1',
          'patientId': patientId,
          'medecinId': medecinId,
          'inscritLe': '2026-11-20T09:00:00Z'
        }
      ];

  @override
  Future<List<Map<String, dynamic>>> cabinetsSecretaire(String token) async => [
        {'id': 'k1', 'medecinId': medecinId, 'accepte': true}
      ];

  @override
  Future<List<Map<String, dynamic>>> invitationsCabinet(String token) async =>
      appels.contains('accepter i1')
          ? []
          : [
              {'id': 'i1', 'medecinId': medecinId}
            ];

  @override
  Future<void> accepterInvitation(String invitationId, String token) async =>
      appels.add('accepter $invitationId');

  @override
  Future<List<Map<String, dynamic>>> besoinsWilaya(String wilayaCode, String token) async {
    appels.add('besoins $wilayaCode');
    return [
      {'id': 'b1', 'medicament': 'Ventoline', 'wilayaCode': wilayaCode, 'dejaRepondu': false},
    ];
  }

  @override
  Future<Map<String, dynamic>> repondreBesoin(String besoinId, bool disponible, String token,
      {int? prixDa, String? commentaire}) async {
    appels.add('repondre $besoinId $disponible $prixDa');
    return {};
  }

  @override
  Future<Map<String, dynamic>> verifierOrdonnance(String code) async =>
      {'valide': true, 'emiseLe': '2026-12-03T10:15:00Z', 'statut': 'EMISE'};

  @override
  Future<Map<String, dynamic>> delivrerOrdonnance(String code, String token) async {
    appels.add('delivrer $code');
    return {'valide': true, 'statut': 'DELIVREE', 'delivreeLe': '2026-12-04T10:00:00Z'};
  }

  @override
  Future<List<Map<String, dynamic>>> mesBesoins(String token) async => [];
}

/// Session connectee qui note les deconnexions completes (pas d'appel a Keycloak).
class SessionTest extends AuthService {
  SessionTest() {
    accessToken = 'jeton';
    idToken = 'identite';
  }
  final finsDeSession = <String>[];

  @override
  Future<void> finDeSession(String jeton) async => finsDeSession.add(jeton);
}

Future<void> afficher(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Langue.courante.value = Langue.francais);

  testWidgets(
      "l'accueil affiche « Mon espace » seulement pour un role professionnel, en rangee "
      'defilante, et la teleconsultation desactivee', (tester) async {
    await afficher(tester, RecherchePage(api: FakeEspaceApi(), auth: SessionTest()));
    expect(find.text('Mon espace'), findsNothing);
    expect(find.byKey(const ValueKey('entrees-accueil')), findsOneWidget);
    final visio = tester.widget<ActionChip>(find.ancestor(
        of: find.text('Téléconsultation · Bientôt'), matching: find.byType(ActionChip)));
    expect(visio.onPressed, isNull);

    await afficher(
        tester,
        RecherchePage(
            key: UniqueKey(), api: FakeEspaceApi(roles: ['MEDECIN']), auth: SessionTest()));
    expect(find.text('Mon espace'), findsOneWidget);
  });

  testWidgets('mon espace propose les entrees selon les roles', (tester) async {
    await afficher(tester,
        MonEspacePage(api: FakeEspaceApi(roles: ['MEDECIN', 'PHARMACIE']), auth: SessionTest()));
    expect(find.text('Mon agenda'), findsOneWidget);
    expect(find.text('Mes créneaux'), findsOneWidget);
    expect(find.text("Ma liste d'attente"), findsOneWidget);
    expect(find.text('Besoins Dawini'), findsOneWidget);
    expect(find.text('Cabinets'), findsNothing);
    expect(find.text('Invitations de cabinet'), findsOneWidget);
  });

  testWidgets("l'agenda du medecin nomme le patient, traite RESERVE comme confirme et honore",
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, AgendaPage(api: api, auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 3, 9)));
    expect(find.text('Karim Haddad · Confirmé'), findsOneWidget);
    expect(find.text('Karim Haddad · Honoré'), findsOneWidget);
    expect(find.byTooltip('Actions'), findsOneWidget); // seulement sur le rendez-vous confirme

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patient venu'));
    await tester.pumpAndSettle();
    expect(api.appels, ['honorer r1']);
    expect(find.text('Rendez-vous honoré'), findsOneWidget);
  });

  testWidgets("la secretaire annule un rendez-vous de l'agenda du medecin apres confirmation",
      (tester) async {
    final api = FakeEspaceApi(roles: ['SECRETAIRE']);
    await afficher(
        tester,
        AgendaPage(
            cabinet: const Cabinet.pourSecretaire(medecinId, nomMedecin: 'Dr Amina Benali'),
            api: api,
            auth: SessionTest()));
    expect(find.text('Agenda · Dr Amina Benali'), findsOneWidget);
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, annuler'));
    await tester.pumpAndSettle();
    expect(api.appels, ['annuler secretaire r3']);
  });

  testWidgets('mes creneaux supprime un creneau libre et en ajoute un', (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, CreneauxPage(api: api, auth: SessionTest()));
    expect(find.text('30 min · Libre'), findsOneWidget);
    expect(find.text('30 min · Réservé'), findsOneWidget);
    expect(find.byTooltip('Supprimer'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(api.appels, ['supprimer c1']);
    await tester.pump(const Duration(seconds: 5)); // laisse passer le message
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter un créneau'));
    await tester.pumpAndSettle();
    expect(find.text('1 créneau(x) seront créés.'), findsOneWidget);
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(api.appels.last, 'ouvrir 9:0 30'); // demain 9 h, 30 min par defaut
    expect(find.text('1 créneau(x) ajouté(s)'), findsOneWidget);
  });

  testWidgets('une serie sur une semaine cree un creneau par pas de duree', (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(
        tester,
        NouveauCreneauPage(
          cabinet: const Cabinet.duMedecin(),
          serie: true,
          api: api,
          auth: SessionTest(),
          // Samedi : la semaine suivante compte dimanche a jeudi (5 jours), 9 h-12 h, 30 min.
          maintenant: () => DateTime(2026, 12, 5, 8),
        ));
    expect(find.text('30 créneau(x) seront créés.'), findsOneWidget);
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(api.appels.where((a) => a.startsWith('ouvrir')), hasLength(30));
  });

  testWidgets('semaine type : envoie le contrat et affiche crees / ignores', (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, CreneauxPage(api: api, auth: SessionTest()));
    await tester.tap(find.text('Semaine type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer les créneaux'));
    await tester.pumpAndSettle();
    expect(api.appels.last, 'semaine [LUNDI, MARDI, MERCREDI, JEUDI, DIMANCHE] 4');
    expect(find.text('12 créneaux créés, 2 ignorés'), findsOneWidget);
  });

  testWidgets('semaine type : un 404 affiche le message du serveur et garde le bouton',
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN'])..routesAbsentes = true;
    await afficher(tester, CreneauxPage(api: api, auth: SessionTest()));
    await tester.tap(find.text('Semaine type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer les créneaux'));
    await tester.pumpAndSettle();
    expect(find.text('Semaine type'), findsOneWidget);
    expect(find.text('absent'), findsOneWidget);
  });

  testWidgets('RDV pris au telephone : seulement pour la secretaire, sur un creneau libre',
      (tester) async {
    final api = FakeEspaceApi(roles: ['SECRETAIRE']);
    await afficher(
        tester,
        CreneauxPage(
            cabinet: const Cabinet.pourSecretaire(medecinId, nomMedecin: 'Dr Amina Benali'),
            api: api,
            auth: SessionTest()));
    await tester.tap(find.byTooltip('RDV pris au téléphone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Karim');
    await tester.enterText(find.byType(TextField).at(1), '0555 12 34 56');
    await tester.tap(find.text('Réserver'));
    await tester.pumpAndSettle();
    expect(api.appels.last, 'tel c1 Karim');
    expect(find.text('Rendez-vous enregistré'), findsOneWidget);
  });

  testWidgets('RDV pris au telephone : absent pour le medecin et cache sur 404', (tester) async {
    await afficher(tester, CreneauxPage(api: FakeEspaceApi(roles: ['MEDECIN']), auth: SessionTest()));
    expect(find.byTooltip('RDV pris au téléphone'), findsNothing);
  });

  testWidgets('ma fiche : enregistre ; un 404 cache l\'entree de Mon espace', (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, MaFichePage(api: api, auth: SessionTest()));
    expect(find.text('Rue 1'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(api.appels.last, 'fiche Rue 1 [fr, ar]');

    final absent = FakeEspaceApi(roles: ['MEDECIN'])..routesAbsentes = true;
    await afficher(tester, MonEspacePage(api: absent, auth: SessionTest()));
    expect(find.text('Mes créneaux'), findsOneWidget);
    expect(find.text('Ma fiche'), findsNothing);
  });

  testWidgets("ma liste d'attente affiche les patients inscrits", (tester) async {
    await afficher(tester, ListeAttenteMedecinPage(api: FakeEspaceApi(), auth: SessionTest()));
    expect(find.text('Karim Haddad'), findsOneWidget);
    expect(find.textContaining('0550123456'), findsOneWidget);
  });

  testWidgets('la secretaire voit ses cabinets avec le nom du medecin', (tester) async {
    await afficher(tester, CabinetsPage(api: FakeEspaceApi(), auth: SessionTest()));
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Créneaux'), findsOneWidget);
  });

  testWidgets('une invitation de cabinet peut etre acceptee', (tester) async {
    final api = FakeEspaceApi();
    await afficher(tester, InvitationsCabinetPage(api: api, auth: SessionTest()));
    expect(find.text('Dr Amina Benali vous invite à gérer son cabinet.'), findsOneWidget);
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(api.appels, ['accepter i1']);
    expect(find.text('Aucune invitation en attente.'), findsOneWidget);
  });

  testWidgets('la pharmacie voit les besoins de sa wilaya et y repond', (tester) async {
    final api = FakeEspaceApi(roles: ['PHARMACIE']);
    await afficher(tester, BesoinsPharmaciePage(api: api, auth: SessionTest()));
    expect(api.appels, ['besoins 16']);
    expect(find.text('16 - Alger'), findsOneWidget);
    expect(find.text('Ventoline'), findsOneWidget);
    await tester.tap(find.text('Répondre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Prix (DA)'), '850');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(api.appels, contains('repondre b1 true 850'));
  });

  testWidgets('la pharmacie verifie un code puis marque l\'ordonnance delivree', (tester) async {
    final api = FakeEspaceApi(roles: ['PHARMACIE']);
    await afficher(tester, DelivrerOrdonnancePage(api: api, auth: SessionTest()));
    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Ordonnance valide · Émise'), findsOneWidget);
    await tester.tap(find.text('Marquer délivrée'));
    await tester.pumpAndSettle();
    expect(api.appels, ['delivrer ABC123']);
    expect(find.text('Ordonnance valide · Délivrée'), findsOneWidget);
    expect(find.text('Marquer délivrée'), findsNothing);
  });

  testWidgets('dawini sans wilaya au profil exige le choix de la wilaya', (tester) async {
    await afficher(tester, DawiniPage(api: FakeEspaceApi(wilayaProfil: null), auth: SessionTest()));
    await tester.enterText(find.widgetWithText(TextField, 'Médicament recherché *'), 'Insuline');
    await tester.tap(find.text('Publier la demande'));
    await tester.pumpAndSettle();
    expect(find.text(messageWilayaRequise), findsOneWidget);
  });

  testWidgets('mon profil : se deconnecter efface le jeton, ferme Keycloak et revient a l\'accueil',
      (tester) async {
    final auth = SessionTest();
    await afficher(tester, MonProfilPage(api: FakeEspaceApi(), auth: auth));
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(auth.estConnecte, isFalse);
    expect(auth.finsDeSession, ['identite']);
  });

  testWidgets(
      'mon profil : supprimer mon compte demande confirmation, appelle DELETE /api/moi '
      'puis deconnecte', (tester) async {
    final api = FakeEspaceApi();
    final auth = SessionTest();
    await afficher(tester, MonProfilPage(api: api, auth: auth));
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(api.appels, isEmpty);

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();
    expect(api.appels, ['supprimer']);
    expect(auth.estConnecte, isFalse);
    expect(auth.finsDeSession, ['identite']);
  });

  testWidgets("l'appli passe en arabe (RTL) depuis le selecteur et memorise le choix",
      (tester) async {
    await tester.pumpWidget(TabibiApp(api: FakeEspaceApi(), auth: SessionTest()));
    await tester.pumpAndSettle();
    expect(find.text('Nom du médecin'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Nom du médecin'))), TextDirection.ltr);

    await tester.tap(find.byTooltip('Langue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('اسم الطبيب'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('اسم الطبيب'))), TextDirection.rtl);
    expect((await SharedPreferences.getInstance()).getString(Langue.cle), 'ar');
  });
}
