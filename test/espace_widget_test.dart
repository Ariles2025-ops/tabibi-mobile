import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/main.dart';
import 'package:tabibi_mobile/pages/compte_page.dart';
import 'package:tabibi_mobile/pages/dawini_page.dart';
import 'package:tabibi_mobile/pages/espace/agenda_page.dart';
import 'package:tabibi_mobile/pages/espace/avis_medecin_page.dart';
import 'package:tabibi_mobile/pages/espace/candidature_page.dart';
import 'package:tabibi_mobile/pages/espace/cabinet.dart';
import 'package:tabibi_mobile/pages/espace/cabinet_pages.dart';
import 'package:tabibi_mobile/pages/espace/creneaux_page.dart';
import 'package:tabibi_mobile/pages/espace/fiche_semaine_pages.dart';
import 'package:tabibi_mobile/pages/espace/mon_espace_page.dart';
import 'package:tabibi_mobile/pages/espace/nouvelle_ordonnance_page.dart';
import 'package:tabibi_mobile/pages/espace/ordonnances_redigees_page.dart';
import 'package:tabibi_mobile/pages/espace/pharmacie_pages.dart';
import 'package:tabibi_mobile/pages/espace/secretaires_page.dart';
import 'package:tabibi_mobile/pages/mon_profil_page.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/services/auth_service.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';

const medecinId = '00000000-0000-0000-0000-000000000001';
const patientId = 'a1a1a1a1-0000-4000-8000-000000000007';

/// API factice sans cabinet rattache ni patient en liste d'attente.
class FakeEspaceVide extends FakeEspaceApi {
  @override
  Future<List<Map<String, dynamic>>> cabinetsSecretaire(String token) async => [];

  @override
  Future<List<Map<String, dynamic>>> listeAttenteMedecin(String token) async => [];
}

/// API factice des espaces professionnels : donnees fixes, appels notes dans [appels].
class FakeEspaceApi extends ApiService {
  FakeEspaceApi({this.roles = const ['PATIENT'], this.wilayaProfil = '16'});

  final List<String> roles;
  final String? wilayaProfil;
  final appels = <String>[];
  final nomsPharmacie = <String?>[];

  /// Quand vrai, les routes semaine type / fiche / RDV telephone repondent 404.
  bool routesAbsentes = false;

  /// Réponse imposée à la vérification d'un code d'ordonnance (sinon : valide, émise).
  Map<String, dynamic>? resultatVerification;
  bool codeInconnu404 = false;
  bool besoinDejaRepondu = false;

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
          {String? specialite,
            String? wilaya,
            String? commune,
            String? q,
            int page = 0,
            void Function(int total)? surTotal}) async =>
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
  Future<Map<String, dynamic>> avisDuMedecin(String medecinId) async {
    appels.add('avis $medecinId');
    return {
      'moyenne': 4.5,
      'nombre': 2,
      'avis': [
        {'id': 'a1', 'note': 4, 'commentaire': 'Ancien avis', 'deposeLe': '2026-11-01T09:00:00Z'},
        {'id': 'a2', 'note': 5, 'commentaire': 'Très bien', 'deposeLe': '2026-11-10T09:00:00Z'},
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> ordonnancesRedigees(String token) async => [
        {'id': 'o1', 'patientId': patientId, 'emiseLe': '2026-11-01T09:00:00Z', 'statut': 'ANNULEE',
         'motifAnnulation': 'Erreur de dose', 'codeVerification': 'AAAA1111'},
        {'id': 'o2', 'patientId': patientId, 'emiseLe': '2026-11-10T09:00:00Z', 'statut': 'EMISE',
         'codeVerification': 'BBBB2222'},
      ];

  @override
  Future<Map<String, dynamic>> annulerOrdonnance(String id, String motif, String token) async {
    appels.add('annuler-ordonnance $id $motif');
    return {'id': id, 'patientId': patientId, 'emiseLe': '2026-11-10T09:00:00Z', 'statut': 'ANNULEE',
        'motifAnnulation': motif, 'codeVerification': 'BBBB2222'};
  }

  Map<String, dynamic>? refusEmission;

  @override
  Future<Map<String, dynamic>> emettreOrdonnance(Map<String, dynamic> corps, String token) async {
    final refus = refusEmission;
    if (refus != null) throw ApiException(409, '${refus['erreur']}');
    appels.add('emettre ${corps['patientId']} ${corps['rendezVousId'] ?? '-'} '
        '${(corps['lignes'] as List).map((l) => (l as Map)['medicament']).join(',')}');
    return {'id': 'o3', 'statut': 'EMISE'};
  }

  @override
  Future<void> signalerAvis(String avisId, String token) async => appels.add('signaler $avisId');

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
  Future<List<Map<String, dynamic>>> agendaMedecin(String token) async {
    appelsAgenda++;
    return [_rdv('r1', 'RESERVE'), _rdv('r2', 'HONORE')];
  }

  /// Nombre de chargements de l'agenda du médecin.
  int appelsAgenda = 0;

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

  /// Quand renseigné, honorer / absent / annuler répondent 409 avec ce motif.
  String? motifConflit;

  @override
  Future<void> honorerRendezVous(String rdvId, String token) async {
    if (motifConflit != null) throw ApiException(409, motifConflit!);
    appels.add('honorer $rdvId');
  }

  @override
  Future<void> marquerAbsentMedecin(String rdvId, String token) async =>
      appels.add('absent $rdvId');

  @override
  Future<void> annulerParMedecin(String rdvId, String token) async => appels.add('annuler $rdvId');

  @override
  Future<void> annulerParSecretaire(String rdvId, String token) async =>
      appels.add('annuler secretaire $rdvId');

  /// Quand vrai, le déplacement répond 409 (créneau pris entre-temps).
  bool creneauPris = false;

  @override
  Future<Map<String, dynamic>> deplacerParMedecin(
      String rdvId, String nouveauCreneauId, String token) async {
    if (creneauPris) throw const ApiException(409, 'pris');
    appels.add('deplacer $rdvId $nouveauCreneauId');
    return {};
  }

  @override
  Future<Map<String, dynamic>> deplacerParSecretaire(
      String rdvId, String nouveauCreneauId, String token) async {
    appels.add('deplacer secretaire $rdvId $nouveauCreneauId');
    return {};
  }

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
  Future<List<Map<String, dynamic>>> secretairesMedecin(String token) async => [
        if (!appels.contains('retirer-secretaire r1'))
          {
            'id': 'r1',
            'secretaireId': 'bbbbbbbb-0000-4000-8000-000000000001',
            'secretaireNom': 'Samia Kaci',
            'secretaireEmail': 'samia@exemple.dz',
            'creeLe': '2026-11-20T09:00:00Z',
            'accepte': true,
          },
        if (appels.contains('inviter-secretaire nouvelle@exemple.dz'))
          {
            'id': 'r2',
            'secretaireId': 'cccccccc-0000-4000-8000-000000000002',
            'secretaireEmail': 'nouvelle@exemple.dz',
            'creeLe': '2026-11-21T09:00:00Z',
            'accepte': false,
          },
      ];

  @override
  Future<Map<String, dynamic>> inviterSecretaire(String email, String token) async {
    if (email == 'doublon@exemple.dz') {
      throw const ApiException(409, 'Cette secrétaire est déjà rattachée à votre cabinet.');
    }
    appels.add('inviter-secretaire $email');
    return {'id': 'r2'};
  }

  @override
  Future<void> retirerSecretaire(String rattachementId, String token) async =>
      appels.add('retirer-secretaire $rattachementId');

  /// Derniere candidature (null : aucune, 404) ; mise a jour par [deposerCandidature].
  Map<String, dynamic>? candidature;

  @override
  Future<Map<String, dynamic>> maCandidature(String token) async {
    final c = candidature;
    if (c == null) throw const ApiException(404, 'Aucune candidature');
    return c;
  }

  @override
  Future<Map<String, dynamic>> deposerCandidature(Map<String, dynamic> corps, String token) async {
    appels.add('candidature ${corps['nomComplet']} ${corps['specialiteSlug']} ${corps['wilayaCode']} ${corps['numeroOrdre']}');
    return candidature = {...corps, 'statut': 'EN_ATTENTE', 'deposeeLe': '2026-11-18T09:00:00Z'};
  }

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
      {
        'id': 'b1',
        'medicament': 'Ventoline',
        'wilayaCode': wilayaCode,
        'commune': 'Bab Ezzouar',
        'publieLe': '2026-11-20T09:00:00',
        'nombreReponses': 2,
        'dejaRepondu': besoinDejaRepondu,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> repondreBesoin(String besoinId, bool disponible, String token,
      {int? prixDa, String? commentaire, String? nomPharmacie}) async {
    appels.add('repondre $besoinId $disponible $prixDa');
    nomsPharmacie.add(nomPharmacie);
    return {};
  }

  @override
  Future<Map<String, dynamic>> verifierOrdonnance(String code) async {
    if (codeInconnu404) throw const ApiException(404, 'Ressource introuvable');
    return resultatVerification ?? {'valide': true, 'emiseLe': '2026-12-03T10:15:00Z', 'statut': 'EMISE'};
  }

  @override
  Future<Map<String, dynamic>> delivrerOrdonnance(String code, String token) async {
    appels.add('delivrer $code');
    // Comme le vrai serveur : ResultatVerification.de renvoie valide=false une fois délivrée.
    return {'valide': false, 'statut': 'DELIVREE', 'delivreeLe': '2026-12-04T10:00:00Z'};
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

/// Session dont le renouvellement du jeton reussit (compte devenu secretaire).
class SessionRenouvelable extends SessionTest {
  int renouvelements = 0;

  @override
  Future<bool> rafraichir() async {
    renouvelements++;
    return true;
  }
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
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Disponibilités'), findsOneWidget);
    expect(find.text("Liste d'attente"), findsOneWidget);
    expect(find.text('Demandes de médicaments'), findsOneWidget);
    expect(find.text('Vérifier / délivrer une ordonnance'), findsOneWidget);
    expect(find.text('Besoins Dawini'), findsNothing);
    expect(find.text('Cabinets'), findsNothing);
    expect(find.text('Invitations de cabinet'), findsOneWidget);
  });

  testWidgets("l'agenda du medecin nomme le patient, traite RESERVE comme confirme et honore",
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, AgendaPage(api: api, auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 3, 9)));
    expect(find.text('Karim Haddad · Confirmé'), findsOneWidget);
    expect(find.text('Karim Haddad · Honoré'), findsOneWidget);
    // Menu sur le rendez-vous confirme (actions) et sur l'honoré (« Rédiger une ordonnance »).
    expect(find.byTooltip('Actions'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marquer honoré'));
    await tester.pumpAndSettle();
    expect(api.appels, ['honorer r1']);
    expect(find.textContaining('marqué honoré.'), findsOneWidget);
    expect(find.text('Rendez-vous honoré'), findsNothing);
  });

  testWidgets("agenda vide : même phrase que le site et lien « Ouvrir des créneaux »", (tester) async {
    await afficher(tester, AgendaPage(api: _AgendaVideApi(), auth: SessionTest()));
    expect(find.text('Aucun rendez-vous pour le moment.'), findsOneWidget);
    expect(find.text('Ouvrir des créneaux'), findsOneWidget);
    await tester.tap(find.text('Ouvrir des créneaux'));
    await tester.pumpAndSettle();
    expect(find.byType(CreneauxPage), findsOneWidget);
  });

  testWidgets("l'agenda du médecin propose « Rédiger une ordonnance » avec patient et rendez-vous préremplis",
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, AgendaPage(api: api, auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 3, 9)));
    await tester.tap(find.byTooltip('Actions').last); // rendez-vous honoré
    await tester.pumpAndSettle();
    expect(find.text('Patient absent'), findsNothing);
    await tester.tap(find.text('Rédiger une ordonnance'));
    await tester.pumpAndSettle();
    expect(find.text('Prescription'), findsOneWidget);
    expect(find.text('Karim Haddad · 0550123456'), findsOneWidget); // patient déjà choisi
  });

  testWidgets("l'agenda de la secrétaire ne propose pas d'ordonnance", (tester) async {
    final api = FakeEspaceApi(roles: ['SECRETAIRE']);
    await afficher(
        tester,
        AgendaPage(
            cabinet: const Cabinet.pourSecretaire('m1'),
            api: api,
            auth: SessionTest(),
            maintenant: () => DateTime.utc(2026, 12, 3, 9)));
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    expect(find.text('Rédiger une ordonnance'), findsNothing);
  });

  testWidgets("agenda : un 409 sur « Marquer honoré » affiche le motif et recharge l'agenda (comme le site)",
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN'])..motifConflit = "Ce rendez-vous n'est plus confirmé.";
    await afficher(tester, AgendaPage(api: api, auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 3, 9)));
    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marquer honoré'));
    await tester.pumpAndSettle();
    expect(api.appels, isEmpty);
    expect(find.text("Ce rendez-vous n'est plus confirmé."), findsOneWidget);
    expect(find.textContaining('marqué honoré.'), findsNothing);
    expect(api.appelsAgenda, 2); // chargement initial + rechargement après le refus
  });

  testWidgets("l'agenda demande confirmation avant « Patient absent » (comme le site)",
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, AgendaPage(api: api, auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 3, 9)));
    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patient absent'));
    await tester.pumpAndSettle();
    expect(find.text('Signaler le patient absent à ce rendez-vous ?'), findsOneWidget);
    expect(api.appels, isEmpty);
    await tester.tap(find.text('Oui'));
    await tester.pumpAndSettle();
    expect(api.appels, ['absent r1']);
    expect(find.textContaining('Patient signalé absent au rendez-vous du'), findsOneWidget);
  });

  testWidgets("l'agenda met Aujourd'hui en tete, puis A venir, puis Passes (heure d'Alger)",
      (tester) async {
    final api = _AgendaDatesApi();
    // 22 h 30 UTC le 3 dec. = 23 h 30 a Alger, le 3.
    await afficher(
        tester,
        AgendaPage(
            api: api, auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 3, 22, 30)));
    double y(String texte) => tester.getTopLeft(find.text(texte)).dy;
    expect(y("Aujourd'hui"), lessThan(y('À venir')));
    expect(y('À venir'), lessThan(y('Passés')));
    // Le 3 a 23 h 30 Alger (22 h 30 UTC) est du jour ; le 4 a 00 h 30 Alger (23 h 30 UTC le 3)
    // est demain, meme si le jour UTC est identique.
    expect(find.text('Karim Haddad · Confirmé'), findsNWidgets(2));
    expect(y("Aujourd'hui"), lessThan(tester.getTopLeft(find.text('Karim Haddad · Confirmé').first).dy));
    expect(find.text('Karim Haddad · Annulé'), findsOneWidget);
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

  testWidgets("le medecin deplace un rendez-vous a venir vers un autre creneau libre",
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester,
        AgendaPage(api: api, auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 1, 9)));
    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Marquer honoré'), findsNothing); // pas encore commence
    await tester.tap(find.text('Déplacer'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez un nouveau créneau'), findsOneWidget);
    // Seul c1 est libre (c2 est reserve).
    await tester.tap(find.byType(SimpleDialogOption));
    await tester.pumpAndSettle();
    expect(find.text('Déplacer ce rendez-vous ?'), findsOneWidget);
    expect(find.textContaining('Le patient sera prévenu.'), findsOneWidget);
    await tester.tap(find.text('Oui, déplacer'));
    await tester.pumpAndSettle();
    expect(api.appels, ['deplacer r1 c1']);
    expect(find.textContaining('Rendez-vous déplacé'), findsOneWidget);
  });

  testWidgets("la secretaire deplace par sa propre route, et un creneau pris (409) ne change rien",
      (tester) async {
    final api = FakeEspaceApi(roles: ['SECRETAIRE']);
    await afficher(
        tester,
        AgendaPage(
            cabinet: const Cabinet.pourSecretaire(medecinId),
            api: api,
            auth: SessionTest(),
            maintenant: () => DateTime.utc(2026, 12, 1, 9)));
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déplacer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SimpleDialogOption));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, déplacer'));
    await tester.pumpAndSettle();
    expect(api.appels, ['deplacer secretaire r3 c1']);
  });

  testWidgets("deplacer un rendez-vous dont le creneau est pris dit que rien n'a change",
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN'])..creneauPris = true;
    await afficher(tester,
        AgendaPage(api: api, auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 1, 9)));
    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déplacer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SimpleDialogOption));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, déplacer'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Ce créneau vient d'être pris"), findsOneWidget);
    expect(find.textContaining('Rendez-vous déplacé'), findsNothing);
  });

  testWidgets("annuler un rendez-vous pris par telephone n'annonce pas que le patient sera prevenu",
      (tester) async {
    await afficher(tester,
        AgendaPage(api: _AgendaSourceApi('TELEPHONE'), auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 3, 9)));
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Le patient sera prévenu.'), findsNothing);
    expect(find.textContaining('Pensez à prévenir le patient par téléphone.'), findsOneWidget);
  });

  testWidgets('annuler un rendez-vous pris en ligne annonce que le patient sera prevenu',
      (tester) async {
    await afficher(tester,
        AgendaPage(api: _AgendaSourceApi('EN_LIGNE'), auth: SessionTest(), maintenant: () => DateTime.utc(2026, 12, 3, 9)));
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Le patient sera prévenu.'), findsOneWidget);
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
    expect(find.text('1 créneau ajouté'), findsOneWidget);
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
    expect(find.text("Aucun message n'est envoyé au patient."), findsOneWidget);
    await tester.tap(find.text('Enregistrer le rendez-vous'));
    await tester.pumpAndSettle();
    expect(api.appels.last, 'tel c1 Karim');
    expect(find.text('Rendez-vous enregistré'), findsOneWidget);
  });

  testWidgets('RDV pris au telephone : mêmes refus que le site (nom, numéro, créneau pris)',
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
    await tester.tap(find.text('Enregistrer le rendez-vous'));
    await tester.pumpAndSettle();
    expect(find.text('Indiquez le nom du patient.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.enterText(find.byType(TextField).at(0), 'Karim');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Enregistrer le rendez-vous'));
    await tester.pumpAndSettle();
    expect(find.text('Indiquez un numéro algérien valide (ex. 0550 12 34 56).'), findsOneWidget);
    expect(api.appels.where((a) => a.startsWith('tel')), isEmpty);
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
    expect(find.text('Disponibilités'), findsOneWidget);
    expect(find.text('Ma fiche'), findsNothing);
  });

  testWidgets('avis des patients : le medecin les lit (recents d\'abord) et en signale un',
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, AvisMedecinPage(api: api, auth: SessionTest()));
    expect(api.appels.first, 'avis $patientId');
    expect(find.textContaining('4,5 / 5 (2 avis)'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Très bien')).dy,
        lessThan(tester.getTopLeft(find.text('Ancien avis')).dy));
    await tester.tap(find.text('Signaler').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Signaler').last);
    await tester.pumpAndSettle();
    expect(api.appels.last, 'signaler a2');
    expect(find.text('Signalé'), findsOneWidget);
    expect(find.text('Signaler'), findsOneWidget);
  });

  testWidgets('ordonnances rédigées : recentes d\'abord, le medecin annule une ordonnance émise',
      (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, OrdonnancesRedigeesPage(api: api, auth: SessionTest()));
    expect(find.textContaining('Motif : Erreur de dose'), findsOneWidget);
    expect(tester.getTopLeft(find.textContaining('BBBB2222')).dy,
        lessThan(tester.getTopLeft(find.textContaining('AAAA1111')).dy));
    expect(find.text('Annuler'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, annuler'));
    await tester.pumpAndSettle();
    expect(api.appels.last, 'annuler-ordonnance o2 ');
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('nouvelle ordonnance : patient, medicament obligatoire, emission', (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, NouvelleOrdonnancePage(api: api, auth: SessionTest()));
    await tester.tap(find.text("Émettre l'ordonnance"));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez le patient et indiquez le médicament de chaque ligne.'),
        findsOneWidget);
    expect(api.appels.where((a) => a.startsWith('emettre')), isEmpty);

    await tester.tap(find.byKey(const ValueKey('champ-patient')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Karim Haddad · 0550123456').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Médicament'), 'Paracétamol 1 g');
    await tester.tap(find.text("Émettre l'ordonnance"));
    await tester.pumpAndSettle();
    expect(api.appels.last, 'emettre $patientId - Paracétamol 1 g');
  });

  testWidgets('nouvelle ordonnance : le refus de l\'API est affiche', (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN'])..refusEmission = {'erreur': 'Aucun rendez-vous.'};
    await afficher(tester, NouvelleOrdonnancePage(api: api, auth: SessionTest()));
    await tester.tap(find.byKey(const ValueKey('champ-patient')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Karim Haddad · 0550123456').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Médicament'), 'Doliprane');
    await tester.tap(find.text("Émettre l'ordonnance"));
    await tester.pumpAndSettle();
    expect(find.text('Aucun rendez-vous.'), findsOneWidget);
  });

  testWidgets('ordonnances rédigées : « Rédiger une ordonnance » ouvre le formulaire', (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, OrdonnancesRedigeesPage(api: api, auth: SessionTest()));
    await tester.tap(find.text('Rédiger une ordonnance'));
    await tester.pumpAndSettle();
    expect(find.text('Prescription'), findsOneWidget);
  });

  testWidgets('mes secretaires : liste, invitation par e-mail puis retrait confirme', (tester) async {
    final api = FakeEspaceApi(roles: ['MEDECIN']);
    await afficher(tester, SecretairesPage(api: api, auth: SessionTest()));
    expect(find.text('Samia Kaci'), findsOneWidget);
    expect(find.textContaining('samia@exemple.dz'), findsOneWidget);
    expect(find.textContaining('Rattachée le'), findsOneWidget);

    await tester.tap(find.text('Inviter cette secrétaire'));
    await tester.pumpAndSettle();
    expect(find.text("Indiquez l'adresse e-mail du compte Ndawik de votre secrétaire."),
        findsOneWidget);
    expect(api.appels, isEmpty);

    await tester.enterText(find.byType(TextField), ' Nouvelle@Exemple.dz ');
    await tester.tap(find.text('Inviter cette secrétaire'));
    await tester.pumpAndSettle();
    expect(api.appels, ['inviter-secretaire nouvelle@exemple.dz']);
    expect(find.textContaining('pas encore acceptée'), findsOneWidget);
    expect(find.text('nouvelle@exemple.dz'), findsWidgets);

    await tester.tap(find.text('Retirer').first);
    await tester.pumpAndSettle();
    expect(find.text('Retirer cette secrétaire ?'), findsOneWidget);
    await tester.tap(find.text('Oui, retirer'));
    await tester.pumpAndSettle();
    expect(api.appels.last, 'retirer-secretaire r1');
    expect(find.text('Samia Kaci'), findsNothing);
  });

  testWidgets('mes secretaires : un doublon (409) affiche le message de l\'API', (tester) async {
    await afficher(tester, SecretairesPage(api: FakeEspaceApi(), auth: SessionTest()));
    await tester.enterText(find.byType(TextField), 'doublon@exemple.dz');
    await tester.tap(find.text('Inviter cette secrétaire'));
    await tester.pumpAndSettle();
    expect(find.text('Cette secrétaire est déjà rattachée à votre cabinet.'), findsOneWidget);
  });

  testWidgets('mes secretaires : l\'aide dit ou la secretaire accepte l\'invitation, comme le site', (tester) async {
    await afficher(tester, SecretairesPage(api: FakeEspaceApi(), auth: SessionTest()));
    expect(
        find.text(
            'La secrétaire doit avoir créé son compte Ndawik. Elle reçoit une invitation à accepter depuis ses notifications.'),
        findsOneWidget);
  });

  testWidgets('mon espace medecin propose « Mes secrétaires », comme le site', (tester) async {
    await afficher(tester, MonEspacePage(api: FakeEspaceApi(roles: ['MEDECIN']), auth: SessionTest()));
    expect(find.text('Mes secrétaires'), findsOneWidget);
    await tester.tap(find.text('Mes secrétaires'));
    await tester.pumpAndSettle();
    expect(find.text('Secrétaires rattachées'), findsOneWidget);
  });

  testWidgets(
      'mon compte : un patient trouve « Invitations de cabinet » ; un compte professionnel '
      "n'a plus les pages réservées aux patients, comme le site", (tester) async {
    await afficher(tester, ComptePage(api: FakeEspaceApi(roles: ['PATIENT']), auth: SessionTest()));
    expect(find.text('Invitations de cabinet'), findsOneWidget);
    expect(find.text('Mes avis'), findsOneWidget);
    expect(find.text("Mes listes d'attente"), findsOneWidget);
    expect(find.text('Dawini (pharmacies)'), findsOneWidget);
    expect(find.text('Mon espace'), findsNothing);

    await afficher(
        tester,
        ComptePage(
            key: const ValueKey('compte-pro'),
            api: FakeEspaceApi(roles: ['MEDECIN']),
            auth: SessionTest()));
    expect(find.text('Mon espace'), findsOneWidget);
    expect(find.text('Invitations de cabinet'), findsNothing);
    expect(find.text('Mes avis'), findsNothing);
    expect(find.text("Mes listes d'attente"), findsNothing);
    expect(find.text('Dawini (pharmacies)'), findsNothing);
    expect(find.text('Vérifier une ordonnance'), findsOneWidget);
  });

  testWidgets(
      'mon compte : « Messagerie » est cachée à une secrétaire ou une pharmacie (réservée aux patients et médecins), comme le site',
      (tester) async {
    await afficher(tester, ComptePage(api: FakeEspaceApi(roles: ['PATIENT']), auth: SessionTest()));
    expect(find.text('Messagerie'), findsOneWidget);

    await afficher(
        tester,
        ComptePage(
            key: const ValueKey('compte-secretaire'),
            api: FakeEspaceApi(roles: ['SECRETAIRE']),
            auth: SessionTest()));
    expect(find.text('Messagerie'), findsNothing);

    await afficher(
        tester,
        ComptePage(
            key: const ValueKey('compte-medecin'),
            api: FakeEspaceApi(roles: ['MEDECIN']),
            auth: SessionTest()));
    expect(find.text('Messagerie'), findsOneWidget);
  });

  testWidgets('mon espace medecin propose les ordonnances rédigées', (tester) async {
    await afficher(tester, MonEspacePage(api: FakeEspaceApi(roles: ['MEDECIN']), auth: SessionTest()));
    expect(find.text('Mes ordonnances rédigées'), findsOneWidget);
  });

  testWidgets('mon espace medecin propose les avis des patients', (tester) async {
    await afficher(tester, MonEspacePage(api: FakeEspaceApi(roles: ['MEDECIN']), auth: SessionTest()));
    expect(find.text('Avis des patients'), findsOneWidget);
  });

  testWidgets("ma liste d'attente affiche les patients inscrits", (tester) async {
    await afficher(tester, ListeAttenteMedecinPage(api: FakeEspaceApi(), auth: SessionTest()));
    expect(find.text('Karim Haddad'), findsOneWidget);
    expect(find.textContaining('0550123456'), findsOneWidget);
    expect(find.textContaining('du plus ancien au plus récent'), findsOneWidget);
  });

  testWidgets("liste d'attente sans date ni nom : « Date d'inscription inconnue », comme le site",
      (tester) async {
    await afficher(tester, ListeAttenteMedecinPage(api: _ListeAttenteSansDate(), auth: SessionTest()));
    expect(find.text('Patient'), findsOneWidget);
    expect(find.text("Date d'inscription inconnue"), findsOneWidget);
  });

  testWidgets('la secretaire voit ses cabinets avec le nom du medecin', (tester) async {
    await afficher(tester, CabinetsPage(api: FakeEspaceApi(), auth: SessionTest()));
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Créneaux'), findsOneWidget);
  });

  testWidgets('sans cabinet ni patient, les textes vides sont ceux du site', (tester) async {
    await afficher(tester, CabinetsPage(api: FakeEspaceVide(), auth: SessionTest()));
    expect(find.text('Agenda du cabinet'), findsOneWidget);
    expect(
        find.text('Aucun médecin ne vous a encore rattachée à son cabinet. '
            "Communiquez-lui l'adresse e-mail de votre compte Ndawik."),
        findsOneWidget);
    await afficher(tester, ListeAttenteMedecinPage(api: FakeEspaceVide(), auth: SessionTest()));
    expect(find.text("Liste d'attente"), findsOneWidget);
    expect(find.text("Aucun patient en liste d'attente pour le moment."), findsOneWidget);
    expect(find.text('Ouvrir des créneaux'), findsOneWidget);
  });

  testWidgets('une invitation de cabinet peut etre acceptee', (tester) async {
    final api = FakeEspaceApi();
    await afficher(tester, InvitationsCabinetPage(api: api, auth: SessionTest()));
    expect(find.text('Dr Amina Benali vous invite à gérer l\'agenda de son cabinet.'), findsOneWidget);
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(api.appels, ['accepter i1']);
    // Renouvellement impossible : repli sur le message « reconnectez-vous ».
    expect(find.textContaining('reconnectez-vous'), findsOneWidget);
    expect(find.text('Aucune invitation en attente.'), findsOneWidget);
  });

  testWidgets('invitation acceptee : jeton renouvele, page fermee sans reconnexion', (tester) async {
    final api = FakeEspaceApi();
    final auth = SessionRenouvelable();
    await afficher(
        tester,
        Builder(
            builder: (c) => TextButton(
                onPressed: () => Navigator.of(c).push(MaterialPageRoute<bool>(
                    builder: (_) => InvitationsCabinetPage(api: api, auth: auth))),
                child: const Text('ouvrir'))));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(api.appels, ['accepter i1']);
    expect(auth.renouvelements, 1);
    expect(find.textContaining('reconnectez-vous'), findsNothing);
    expect(find.text('Invitations de cabinet'), findsNothing); // page fermee
  });

  testWidgets('la pharmacie voit les besoins de sa wilaya et y repond', (tester) async {
    final api = FakeEspaceApi(roles: ['PHARMACIE']);
    await afficher(tester, BesoinsPharmaciePage(api: api, auth: SessionTest()));
    expect(api.appels, ['besoins 16']);
    expect(find.text('Demandes de médicaments'), findsOneWidget); // même titre que sur le site
    expect(find.text('16 - Alger'), findsOneWidget);
    expect(find.text('Ventoline'), findsOneWidget);
    // Lieu, date et nombre de réponses, comme sur le site.
    expect(find.text('16 - Alger · Bab Ezzouar · Publiée le ven. 20 nov. 09:00 · 2 réponses'),
        findsOneWidget);
    await tester.tap(find.text('Répondre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Prix (DA)'), '850');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(api.appels, contains('repondre b1 true 850'));
    expect(api.nomsPharmacie, ['Karim Haddad']); // nom du profil, comme le site
  });

  testWidgets('un besoin deja repondu affiche « Déjà répondu » comme le site', (tester) async {
    final api = FakeEspaceApi(roles: ['PHARMACIE'])..besoinDejaRepondu = true;
    await afficher(tester, BesoinsPharmaciePage(api: api, auth: SessionTest()));
    expect(find.text('Déjà répondu'), findsOneWidget);
    expect(find.text('Répondre'), findsNothing);
  });

  testWidgets('un prix mal saisi bloque la reponse de la pharmacie', (tester) async {
    final api = FakeEspaceApi(roles: ['PHARMACIE']);
    await afficher(tester, BesoinsPharmaciePage(api: api, auth: SessionTest()));
    await tester.tap(find.text('Répondre'));
    await tester.pumpAndSettle();
    for (final saisie in ['12.5', '1 250', '850 DA']) {
      await tester.enterText(find.widgetWithText(TextField, 'Prix (DA)'), saisie);
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(find.text('Indiquez un prix en dinars valide (nombre entier positif ou nul).'), findsOneWidget);
    }
    expect(api.appels.where((a) => a.startsWith('repondre')), isEmpty);
    await tester.enterText(find.widgetWithText(TextField, 'Prix (DA)'), '');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(api.appels, contains('repondre b1 true null'));
  });

  testWidgets('la pharmacie verifie un code puis marque l\'ordonnance delivree', (tester) async {
    final api = FakeEspaceApi(roles: ['PHARMACIE']);
    await afficher(tester, DelivrerOrdonnancePage(api: api, auth: SessionTest()));
    expect(find.text('Vérifier / délivrer une ordonnance'), findsOneWidget); // titre du site
    expect(find.text("Saisissez le code de 8 caractères imprimé sur l'ordonnance."), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Ordonnance valide · Émise'), findsOneWidget);
    await tester.tap(find.text('Marquer comme délivrée'));
    await tester.pumpAndSettle();
    expect(api.appels, ['delivrer ABC123']);
    expect(find.textContaining('Ordonnance délivrée le'), findsOneWidget);
    expect(find.text('Ordonnance marquée comme délivrée.'), findsOneWidget); // message du site
    expect(find.textContaining('Aucune ordonnance'), findsNothing);
    expect(find.text('Marquer comme délivrée'), findsNothing);
  });

  testWidgets('modifier le code apres verification retire le resultat et le bouton delivrer',
      (tester) async {
    final api = FakeEspaceApi(roles: ['PHARMACIE']);
    await afficher(tester, DelivrerOrdonnancePage(api: api, auth: SessionTest()));
    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Marquer comme délivrée'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc124');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ordonnance valide'), findsNothing);
    expect(find.text('Marquer comme délivrée'), findsNothing);
    expect(api.appels.where((a) => a.startsWith('delivrer')), isEmpty);
  });

  testWidgets('la pharmacie voit un refus net pour une ordonnance expiree, annulee ou delivree',
      (tester) async {
    final cas = {
      'EXPIREE': 'Expirée : ordonnance plus valable, ne pas délivrer.',
      'ANNULEE':
          'Annulée par le médecin : ne pas délivrer.',
      'DELIVREE': 'Déjà délivrée : ne pas délivrer une nouvelle fois.',
    };
    for (final e in cas.entries) {
      final api = FakeEspaceApi(roles: ['PHARMACIE'])
        ..resultatVerification = {'valide': true, 'statut': e.key};
      await afficher(tester, DelivrerOrdonnancePage(api: api, auth: SessionTest()));
      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.tap(find.text('Vérifier'));
      await tester.pumpAndSettle();
      expect(find.text(e.value), findsOneWidget, reason: e.key);
      expect(find.textContaining('Ordonnance valide'), findsNothing);
      expect(find.text('Marquer comme délivrée'), findsNothing);
    }
  });

  testWidgets('la pharmacie voit « Code inconnu » (et non une erreur generique) sur un code 404',
      (tester) async {
    final api = FakeEspaceApi(roles: ['PHARMACIE'])..codeInconnu404 = true;
    await afficher(tester, DelivrerOrdonnancePage(api: api, auth: SessionTest()));
    await tester.enterText(find.byType(TextField), 'zzzz9999');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Code inconnu : aucune ordonnance ne correspond à ce code.'), findsOneWidget);
    expect(find.text('Ressource introuvable'), findsNothing);
    expect(find.text('Marquer comme délivrée'), findsNothing);
  });

  testWidgets('dawini sans wilaya au profil exige le choix de la wilaya', (tester) async {
    await afficher(tester, DawiniPage(api: FakeEspaceApi(wilayaProfil: null), auth: SessionTest()));
    await tester.enterText(find.widgetWithText(TextField, 'Médicament recherché *'), 'Insuline');
    await tester.tap(find.text('Publier ma demande'));
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
    expect(find.textContaining("vos rendez-vous à venir sont annulés. Les ordonnances"), findsOneWidget);
    await tester.tap(find.text('Oui, supprimer définitivement'));
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

  testWidgets('ma candidature : formulaire, champs obligatoires puis dépôt, état « En attente »',
      (tester) async {
    final api = FakeEspaceApi();
    await afficher(tester, CandidaturePage(api: api, auth: SessionTest()));
    expect(find.text('Déposer ma candidature'), findsOneWidget);

    await tester.tap(find.text('Déposer ma candidature'));
    await tester.pumpAndSettle();
    expect(find.textContaining("numéro d'inscription à l'ordre"), findsOneWidget);
    expect(api.appels, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Nom complet *'), ' Dr Amina Belkacem ');
    await tester.enterText(
        find.widgetWithText(TextField, "Numéro d'inscription à l'ordre *"), '12345');
    await tester.tap(find.text('Spécialité *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cardiologue').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wilaya *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('16 - Alger').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déposer ma candidature'));
    await tester.pumpAndSettle();

    expect(api.appels, ['candidature Dr Amina Belkacem cardiologue 16 12345']);
    expect(find.textContaining('En attente'), findsOneWidget);
    expect(find.text("Votre candidature est en cours d'examen."), findsOneWidget);
    expect(find.text('Nouvelle candidature'), findsNothing);
  });

  testWidgets('ma candidature : refusée, le motif est affiché et un nouveau dépôt est possible',
      (tester) async {
    final api = FakeEspaceApi()
      ..candidature = {
        'nomComplet': 'Dr Amina Belkacem',
        'specialiteSlug': 'cardiologue',
        'wilayaCode': '16',
        'numeroOrdre': '12345',
        'statut': 'REFUSEE',
        'motifRefus': 'Numéro illisible',
        'deposeeLe': '2026-11-10T09:00:00Z',
      };
    await afficher(tester, CandidaturePage(api: api, auth: SessionTest()));
    expect(find.textContaining('Refusée'), findsOneWidget);
    expect(find.textContaining('Motif : Numéro illisible'), findsOneWidget);
    expect(find.text('Nouvelle candidature'), findsOneWidget);
    expect(find.text('Déposer ma candidature'), findsOneWidget);
  });

  testWidgets('réclamer une fiche : champs préremplis, titre et bouton dédiés, fiche envoyée avec la demande',
      (tester) async {
    final api = FakeEspaceApi();
    await afficher(tester, CandidaturePage(api: api, auth: SessionTest(), ficheReclamee: 'f-42'));
    expect(find.text('Réclamer ma fiche'), findsNWidgets(2)); // titre + bouton
    expect(find.textContaining('un administrateur confirme que c\'est bien vous'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'Dr Amina Benali'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, "Numéro d'inscription à l'ordre *"), '777');
    await tester.tap(find.widgetWithText(FilledButton, 'Réclamer ma fiche'));
    await tester.pumpAndSettle();
    expect(api.appels, ['candidature Dr Amina Benali cardiologue 16 777']);
    expect(api.candidature?['ficheReclamee'], 'f-42');
  });

  testWidgets('mon profil propose « Ma candidature de médecin », comme le site', (tester) async {
    await afficher(tester, MonProfilPage(api: FakeEspaceApi(), auth: SessionTest()));
    await tester.ensureVisible(find.text('Ma candidature de médecin'));
    await tester.tap(find.text('Ma candidature de médecin'));
    await tester.pumpAndSettle();
    expect(find.text('Ma candidature'), findsOneWidget);
  });

  test('corpsCandidature : champs nettoyés, libellés du référentiel, null si incomplet', () {
    final corps = corpsCandidature(
        nomComplet: ' Dr A ',
        specialiteSlug: 'cardiologue',
        wilayaCode: '16',
        ville: ' Bab Ezzouar ',
        numeroOrdre: ' 42 ',
        telephone: '');
    expect(corps, {
      'nomComplet': 'Dr A',
      'specialiteSlug': 'cardiologue',
      'specialiteFr': 'Cardiologue',
      'wilayaCode': '16',
      'wilayaFr': 'Alger',
      'ville': 'Bab Ezzouar',
      'numeroOrdre': '42',
      'telephone': '',
    });
    expect(
        corpsCandidature(
            nomComplet: 'Dr A',
            specialiteSlug: null,
            wilayaCode: '16',
            ville: '',
            numeroOrdre: '42',
            telephone: ''),
        isNull);
    expect(
        corpsCandidature(
            nomComplet: 'Dr A',
            specialiteSlug: 'cardiologue',
            wilayaCode: '16',
            ville: '',
            numeroOrdre: '42',
            telephone: '',
            ficheReclamee: 'f-1')?['ficheReclamee'],
        'f-1');
  });
}

/// Agenda : un passe annule, un du jour (heure d'Alger), un de demain (minuit passe a Alger).
class _AgendaVideApi extends FakeEspaceApi {
  _AgendaVideApi() : super(roles: ['MEDECIN']);

  @override
  Future<List<Map<String, dynamic>>> agendaMedecin(String token) async => [];
}

class _AgendaDatesApi extends FakeEspaceApi {
  _AgendaDatesApi() : super(roles: ['MEDECIN']);

  Map<String, dynamic> _r(String id, String statut, String debut) =>
      {'id': id, 'statut': statut, 'debut': debut, 'patientId': patientId};

  @override
  Future<List<Map<String, dynamic>>> agendaMedecin(String token) async => [
        _r('p', 'ANNULE', '2026-11-20T09:00:00Z'),
        _r('f', 'CONFIRME', '2026-12-03T23:30:00Z'),
        _r('j', 'CONFIRME', '2026-12-03T09:00:00Z'),
      ];
}

class _AgendaSourceApi extends FakeEspaceApi {
  _AgendaSourceApi(this.source) : super(roles: ['MEDECIN']);
  final String source;

  @override
  Future<List<Map<String, dynamic>>> agendaMedecin(String token) async => [
        {
          'id': 's1',
          'statut': 'CONFIRME',
          'debut': '2026-12-03T09:00:00Z',
          'patientId': patientId,
          'source': source,
        },
      ];
}

/// Liste d'attente dont l'inscription n'a ni identifiant patient ni date.
class _ListeAttenteSansDate extends FakeEspaceApi {
  @override
  Future<List<Map<String, dynamic>>> listeAttenteMedecin(String token) async => [
        {'id': 'l1'}
      ];
}
