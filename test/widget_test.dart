import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/main.dart';
import 'package:tabibi_mobile/models/besoin_medicament.dart';
import 'package:tabibi_mobile/models/conversation.dart';
import 'package:tabibi_mobile/pages/conversation_page.dart';
import 'package:tabibi_mobile/pages/dawini_page.dart';
import 'package:tabibi_mobile/pages/deposer_avis_page.dart';
import 'package:tabibi_mobile/pages/detail_ordonnance_page.dart';
import 'package:tabibi_mobile/pages/fiche_medecin_page.dart';
import 'package:tabibi_mobile/pages/mes_avis_page.dart';
import 'package:tabibi_mobile/pages/mes_conversations_page.dart';
import 'package:tabibi_mobile/pages/mes_notifications_page.dart';
import 'package:tabibi_mobile/pages/mes_ordonnances_page.dart';
import 'package:tabibi_mobile/pages/mes_rendez_vous_page.dart';
import 'package:tabibi_mobile/pages/mes_teleconsultations_page.dart';
import 'package:tabibi_mobile/pages/reponses_besoin_page.dart';
import 'package:tabibi_mobile/pages/verifier_ordonnance_page.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/services/auth_service.dart';

import 'outils.dart';

/// API factice : aucune requete reseau, donnees fixes. Tous les identifiants sont des UUID en
/// texte, comme ceux que le backend serialise (jamais des nombres).
class FakeApiService extends ApiService {
  const FakeApiService();

  /// Code de verification de l'ordonnance factice (seul code reconnu par [verifierOrdonnance]).
  static const String codeValide = 'ABC123';

  /// Identifiant fixe du premier praticien de demonstration de l'annuaire du backend.
  static const String medecinDemo = '00000000-0000-0000-0000-000000000001';

  /// Identifiant (sujet du jeton) du patient de test : ses messages sont alignes a droite.
  static const String sujetPatient = 'a1a1a1a1-0000-4000-8000-000000000007';

  /// Creneaux du praticien de demonstration : le premier disponible, le second deja pris.
  static const String creneauLibre = 'c1c1c1c1-0000-4000-8000-000000000010';
  static const String creneauPris = 'c1c1c1c1-0000-4000-8000-000000000011';

  /// Rendez-vous du patient de test : honore sans avis, confirme (annulable), honore deja evalue.
  static const String rdvHonore = 'b2b2b2b2-0000-4000-8000-000000000003';
  static const String rdvConfirme = 'b2b2b2b2-0000-4000-8000-000000000004';
  static const String rdvEvalue = 'b2b2b2b2-0000-4000-8000-000000000005';

  /// Ordonnance du patient de test (rendez-vous [rdvHonore]).
  static const String ordonnanceDemo = 'd4d4d4d4-0000-4000-8000-000000000042';

  /// Conversation du patient de test avec le praticien de demonstration.
  static const String conversationDemo = 'e5e5e5e5-0000-4000-8000-000000000001';

  /// Notifications : la plus recente non lue, l'autre deja lue.
  static const String notificationNonLue = 'f6f6f6f6-0000-4000-8000-000000000001';
  static const String notificationLue = 'f6f6f6f6-0000-4000-8000-000000000002';

  /// Teleconsultations : la plus recente planifiee sans consentement, l'autre terminee.
  static const String teleconsultationPlanifiee = 'a7a7a7a7-0000-4000-8000-000000000001';
  static const String teleconsultationTerminee = 'a7a7a7a7-0000-4000-8000-000000000002';

  /// Demandes Dawini : ouverte avec deux reponses, cloturee sans reponse.
  static const String besoinOuvert = 'b8b8b8b8-0000-4000-8000-000000000001';
  static const String besoinCloture = 'b8b8b8b8-0000-4000-8000-000000000002';

  @override
  Future<List<Map<String, dynamic>>> rechercherMedecins({
    String? specialite,
    String? wilaya,
    String? q,
  }) async =>
      [await medecin(medecinDemo)];

  @override
  Future<Map<String, dynamic>> medecin(String id) async => {
        'id': id,
        'nomComplet': 'Dr Amina Benali',
        'specialiteSlug': 'cardiologue',
        'specialiteFr': 'Cardiologue',
        'wilayaCode': '16',
        'wilayaFr': 'Alger',
        'ville': 'Alger',
      };

  @override
  Future<List<Map<String, dynamic>>> creneaux(String medecinId) async => [
        {
          'id': creneauLibre,
          'medecinId': medecinId,
          'debut': '2026-12-03T09:00:00',
          'dureeMinutes': 30,
          'disponible': true,
        },
        {
          'id': creneauPris,
          'medecinId': medecinId,
          'debut': '2026-12-03T09:30:00',
          'dureeMinutes': 30,
          'disponible': false,
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> mesOrdonnances(String token) async =>
      [_ordonnance(ordonnanceDemo)];

  @override
  Future<Map<String, dynamic>> ordonnance(String id, String token) async => _ordonnance(id);

  @override
  Future<Map<String, dynamic>> verifierOrdonnance(String code) async => code == codeValide
      ? {'valide': true, 'emiseLe': '2026-12-03T10:15:00', 'statut': 'EMISE'}
      : {'valide': false};

  /// Deux notifications : la plus recente non lue, l'autre deja lue.
  @override
  Future<List<Map<String, dynamic>>> mesNotifications(String token) async => [
        _notification(notificationNonLue, lue: false),
        _notification(notificationLue, lue: true),
      ];

  @override
  Future<int> nombreNonLues(String token) async => 1;

  @override
  Future<Map<String, dynamic>> marquerLue(String notificationId, String token) async =>
      _notification(notificationId, lue: true);

  @override
  Future<int> toutMarquerLu(String token) async => 1;

  /// Lien de salle remis une fois le consentement donne.
  static const String lienSalle = 'https://meet.jit.si/tabibi-salle-test';

  /// Deux teleconsultations : la plus recente planifiee sans consentement,
  /// l'autre terminee avec consentement (lien remis mais session close).
  @override
  Future<List<Map<String, dynamic>>> mesTeleconsultations(String token) async => [
        _teleconsultation(teleconsultationPlanifiee, 'PLANIFIEE', consentie: false),
        _teleconsultation(teleconsultationTerminee, 'TERMINEE', consentie: true),
      ];

  @override
  Future<Map<String, dynamic>> teleconsultation(String id, String token) async =>
      _teleconsultation(id, 'PLANIFIEE', consentie: false);

  @override
  Future<Map<String, dynamic>> consentir(String teleconsultationId, String token) async =>
      _teleconsultation(teleconsultationId, 'PLANIFIEE', consentie: true);

  /// Une conversation avec le praticien de demonstration, deux messages non lus.
  @override
  Future<List<Map<String, dynamic>>> mesConversations(String token) async =>
      [_conversation(conversationDemo, nonLus: 2)];

  @override
  Future<Map<String, dynamic>> ouvrirConversation(String medecinId, String token) async =>
      _conversation(conversationDemo, nonLus: 0);

  /// Deux messages : le premier du praticien, le second du patient de test.
  @override
  Future<List<Map<String, dynamic>>> messages(String conversationId, String token) async => [
        _messageJson(
          'd9d9d9d9-0000-4000-8000-000000000001',
          medecinDemo,
          'Bonjour, comment allez-vous ?',
          '2026-12-01T09:00:00',
        ),
        _messageJson(
          'd9d9d9d9-0000-4000-8000-000000000002',
          sujetPatient,
          'Bonjour docteur, mieux merci.',
          '2026-12-01T09:05:00',
        ),
      ];

  @override
  Future<Map<String, dynamic>> envoyerMessage(
    String conversationId,
    String contenu,
    String token,
  ) async =>
      _messageJson(
        'd9d9d9d9-0000-4000-8000-000000000003',
        sujetPatient,
        contenu,
        '2026-12-01T09:10:00',
      );

  /// Trois rendez-vous : honore sans avis, confirme (annulable), honore deja evalue.
  @override
  Future<List<Map<String, dynamic>>> mesRendezVous(String token) async => [
        _rendezVous(rdvHonore, 'HONORE', '2026-09-01T09:00:00'),
        _rendezVous(rdvConfirme, 'CONFIRME', '2026-12-03T09:00:00'),
        _rendezVous(rdvEvalue, 'HONORE', '2026-08-10T14:30:00'),
      ];

  /// Un seul avis depose, sur le rendez-vous [rdvEvalue].
  @override
  Future<List<Map<String, dynamic>>> mesAvis(String token) async =>
      [_avis('e0e0e0e0-0000-4000-8000-000000000005', rdvEvalue)];

  @override
  Future<Map<String, dynamic>> deposerAvis(
    String rendezVousId,
    int note,
    String? commentaire,
    String token,
  ) async =>
      _avis(
        'e0e0e0e0-0000-4000-8000-000000000099',
        rendezVousId,
        note: note,
        commentaire: commentaire,
      );

  /// Synthese publique du praticien : 12 avis, moyenne 4,5, deux derniers avis.
  @override
  Future<Map<String, dynamic>> avisDuMedecin(String medecinId) async => {
        'moyenne': 4.5,
        'nombre': 12,
        'avis': [
          {
            'id': 'e0e0e0e0-0000-4000-8000-00000000000a',
            'note': 5,
            'commentaire': "Très bon médecin, à l'écoute.",
            'deposeLe': '2026-11-20T10:15:00',
          },
          {
            'id': 'e0e0e0e0-0000-4000-8000-00000000000b',
            'note': 4,
            'commentaire': null,
            'deposeLe': '2026-11-05T16:30:00',
          },
        ],
      };

  /// Deux demandes Dawini : l'une ouverte avec deux reponses, l'autre cloturee sans reponse.
  @override
  Future<List<Map<String, dynamic>>> mesBesoins(String token) async => [
        _besoin(besoinOuvert, 'Doliprane 1000', 'OUVERT', nombreReponses: 2),
        _besoin(besoinCloture, 'Ventoline', 'CLOTURE', nombreReponses: 0),
      ];

  @override
  Future<Map<String, dynamic>> publierBesoin(
    String medicament,
    String wilayaCode,
    String token, {
    String? commune,
    String? precision,
  }) async =>
      _besoin('b8b8b8b8-0000-4000-8000-000000000003', medicament, 'OUVERT', nombreReponses: 0)
        ..['wilayaCode'] = wilayaCode
        ..['commune'] = commune
        ..['precision'] = precision;

  @override
  Future<void> cloturerBesoin(String besoinId, String token) async {}

  /// Deux reponses : El Amel dispose du medicament a 850 DA, Ibn Sina non.
  @override
  Future<List<Map<String, dynamic>>> reponsesBesoin(String besoinId, String token) async => [
        {
          'id': 'c9c9c9c9-0000-4000-8000-000000000001',
          'besoinId': besoinId,
          'pharmacieId': 'aa11aa11-0000-4000-8000-000000000001',
          'nomPharmacie': 'Pharmacie El Amel',
          'disponible': true,
          'prixDa': 850,
          'commentaire': 'En stock, boite de 8.',
          'repondueLe': '2026-11-20T10:15:00',
        },
        {
          'id': 'c9c9c9c9-0000-4000-8000-000000000002',
          'besoinId': besoinId,
          'pharmacieId': 'aa11aa11-0000-4000-8000-000000000002',
          'nomPharmacie': 'Pharmacie Ibn Sina',
          'disponible': false,
          'prixDa': null,
          'commentaire': null,
          'repondueLe': '2026-11-20T11:00:00',
        },
      ];

  static Map<String, dynamic> _besoin(
    String id,
    String medicament,
    String statut, {
    required int nombreReponses,
  }) =>
      {
        'id': id,
        'patientId': sujetPatient,
        'medicament': medicament,
        'wilayaCode': '16',
        'commune': 'Alger-Centre',
        'precision': id == besoinOuvert ? 'Boite de 8, urgent' : null,
        'statut': statut,
        'publieLe': id == besoinOuvert ? '2026-11-20T09:00:00' : '2026-11-10T09:00:00',
        'clotureLe': statut == 'CLOTURE' ? '2026-11-12T18:30:00' : null,
        'nombreReponses': nombreReponses,
      };

  static Map<String, dynamic> _rendezVous(String id, String statut, String debut) => {
        'id': id,
        'patientId': sujetPatient,
        'medecinId': medecinDemo,
        'creneauId': null,
        'debut': debut,
        'statut': statut,
      };

  static Map<String, dynamic> _avis(
    String id,
    String rendezVousId, {
    int note = 4,
    String? commentaire = 'Explications claires, merci.',
  }) =>
      {
        'id': id,
        'rendezVousId': rendezVousId,
        'medecinId': medecinDemo,
        'note': note,
        'commentaire': commentaire,
        'statut': 'PUBLIE',
        'deposeLe': '2026-08-11T18:00:00',
      };

  static Map<String, dynamic> _conversation(String id, {required int nonLus}) => {
        'id': id,
        'patientId': sujetPatient,
        'medecinId': medecinDemo,
        'creeLe': '2026-11-20T09:00:00',
        'dernierMessageLe': '2026-12-01T09:05:00',
        'nonLus': nonLus,
      };

  static Map<String, dynamic> _messageJson(
    String id,
    String auteurId,
    String contenu,
    String envoyeLe,
  ) =>
      {
        'id': id,
        'conversationId': conversationDemo,
        'auteurId': auteurId,
        'contenu': contenu,
        'envoyeLe': envoyeLe,
        'luLe': null,
      };

  static Map<String, dynamic> _teleconsultation(
    String id,
    String statut, {
    required bool consentie,
  }) =>
      {
        'id': id,
        'rendezVousId': rdvHonore,
        'patientId': sujetPatient,
        'medecinId': medecinDemo,
        'statut': statut,
        'consentementPatientLe': consentie ? '2026-12-03T08:30:00' : null,
        'lienSalle': consentie ? lienSalle : null,
        'creeLe': id == teleconsultationPlanifiee ? '2026-12-03T08:00:00' : '2026-11-20T09:00:00',
        'demarreeLe': statut == 'TERMINEE' ? '2026-11-20T09:05:00' : null,
        'termineeLe': statut == 'TERMINEE' ? '2026-11-20T09:40:00' : null,
      };

  static Map<String, dynamic> _notification(String id, {required bool lue}) => {
        'id': id,
        'destinataireId': sujetPatient,
        'canal': 'INTERNE',
        'sujet': id == notificationNonLue ? 'Teleconsultation proposee' : 'Rendez-vous confirme',
        'message': id == notificationNonLue
            ? 'Votre medecin vous propose une teleconsultation pour votre rendez-vous '
                'du 3 dec. 2026 09:00.'
            : 'Votre rendez-vous du 3 dec. 2026 09:00 est confirme.',
        'lue': lue,
        'creeLe': id == notificationNonLue ? '2026-12-03T10:15:00' : '2026-12-01T18:00:00',
      };

  static Map<String, dynamic> _ordonnance(String id) => {
        'id': id,
        'medecinId': medecinDemo,
        'patientId': sujetPatient,
        'rendezVousId': rdvHonore,
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

/// Variante sans aucune notification (etat vide).
class FakeApiServiceSansNotification extends FakeApiService {
  const FakeApiServiceSansNotification();

  @override
  Future<List<Map<String, dynamic>>> mesNotifications(String token) async => [];

  @override
  Future<int> nombreNonLues(String token) async => 0;
}

/// Variante qui conserve les messages envoyes : le fil les montre apres rafraichissement.
class FakeApiServiceMessagerie extends FakeApiService {
  FakeApiServiceMessagerie();

  final List<Map<String, dynamic>> envoyes = [];

  @override
  Future<List<Map<String, dynamic>>> messages(String conversationId, String token) async =>
      [...await super.messages(conversationId, token), ...envoyes];

  @override
  Future<Map<String, dynamic>> envoyerMessage(
    String conversationId,
    String contenu,
    String token,
  ) async {
    final envoye = await super.envoyerMessage(conversationId, contenu, token);
    envoyes.add(envoye);
    return envoye;
  }
}

/// Variante d'un patient sans rendez-vous avec le praticien : la messagerie est refusee (403).
class FakeApiServiceSansRendezVous extends FakeApiService {
  const FakeApiServiceSansRendezVous();

  @override
  Future<Map<String, dynamic>> ouvrirConversation(String medecinId, String token) async =>
      throw const ApiException(403, 'Aucun rendez-vous avec ce medecin');
}

/// Variante dont l'annuaire ne repond plus (404 sur la fiche publique) : les ecrans montrent
/// « Médecin » suivi de l'identifiant abrege a la place du nom.
class FakeApiServiceSansFiche extends FakeApiService {
  const FakeApiServiceSansFiche();

  @override
  Future<Map<String, dynamic>> medecin(String id) async =>
      throw const ApiException(404, 'Praticien introuvable');
}

/// Variante qui conserve les avis deposes : « Mes rendez-vous » les voit au rechargement.
class FakeApiServiceAvis extends FakeApiService {
  FakeApiServiceAvis();

  final List<Map<String, dynamic>> deposes = [];

  @override
  Future<List<Map<String, dynamic>>> mesAvis(String token) async =>
      [...await super.mesAvis(token), ...deposes];

  @override
  Future<Map<String, dynamic>> deposerAvis(
    String rendezVousId,
    int note,
    String? commentaire,
    String token,
  ) async {
    final depose = await super.deposerAvis(rendezVousId, note, commentaire, token);
    deposes.add(depose);
    return depose;
  }
}

/// Variante ou l'avis existe deja cote serveur (409 au depot).
class FakeApiServiceAvisDejaDonne extends FakeApiService {
  const FakeApiServiceAvisDejaDonne();

  @override
  Future<Map<String, dynamic>> deposerAvis(
    String rendezVousId,
    int note,
    String? commentaire,
    String token,
  ) async =>
      throw const ApiException(409, 'Un avis existe deja pour ce rendez-vous');
}

/// Variante qui conserve les demandes publiees et les clotures demandees.
class FakeApiServiceDawini extends FakeApiService {
  FakeApiServiceDawini();

  final List<Map<String, dynamic>> publies = [];
  final List<String> clotures = [];

  @override
  Future<List<Map<String, dynamic>>> mesBesoins(String token) async =>
      [...publies, ...await super.mesBesoins(token)];

  @override
  Future<Map<String, dynamic>> publierBesoin(
    String medicament,
    String wilayaCode,
    String token, {
    String? commune,
    String? precision,
  }) async {
    final publie = await super.publierBesoin(
      medicament,
      wilayaCode,
      token,
      commune: commune,
      precision: precision,
    );
    publies.add(publie);
    return publie;
  }

  @override
  Future<void> cloturerBesoin(String besoinId, String token) async {
    clotures.add(besoinId);
  }
}

/// Variante ou la demande est deja cloturee cote serveur (409 a la cloture).
class FakeApiServiceDemandeDejaCloturee extends FakeApiService {
  const FakeApiServiceDemandeDejaCloturee();

  @override
  Future<void> cloturerBesoin(String besoinId, String token) async =>
      throw const ApiException(409, 'Cette demande est deja cloturee');
}

/// Variante d'un praticien sans aucun avis publie.
class FakeApiServiceSansAvis extends FakeApiService {
  const FakeApiServiceSansAvis();

  @override
  Future<Map<String, dynamic>> avisDuMedecin(String medecinId) async =>
      {'moyenne': null, 'nombre': 0, 'avis': []};
}

/// Session de test deja munie d'un jeton (JWT factice au sujet [FakeApiService.sujetPatient],
/// aucun appel a Keycloak).
AuthService sessionConnectee() =>
    AuthService()..accessToken = jetonAvecSujet(FakeApiService.sujetPatient);

/// Surface de test haute (800 x 1600 points) pour les ecrans longs : les elements sous la
/// ligne de flottaison d'une liste ne sont pas visibles des finders. Retablie en fin de test.
void surfaceHaute(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Laisse disparaitre le message (SnackBar) affiche, les suivants etant mis en attente.
Future<void> laisserPasserLeMessage(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

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
      home: FicheMedecinPage(medecinId: FakeApiService.medecinDemo, api: FakeApiService()),
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
        ordonnanceId: FakeApiService.ordonnanceDemo,
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

  testWidgets("l'accueil affiche l'entree Notifications avec le nombre de non lues",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecherchePage(api: const FakeApiService(), auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Notifications (1)'), findsOneWidget);
  });

  testWidgets("l'accueil sans jeton affiche l'entree Notifications sans compteur",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecherchePage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.textContaining('Notifications ('), findsNothing);
  });

  testWidgets('mes notifications sans jeton propose de se connecter', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesNotificationsPage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Teleconsultation proposee'), findsNothing);
  });

  testWidgets('mes notifications liste sujet, message et date, puis marque une notification lue',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesNotificationsPage(api: const FakeApiService(), auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mes notifications'), findsOneWidget);
    expect(find.text('Teleconsultation proposee'), findsOneWidget);
    expect(find.text('Rendez-vous confirme'), findsOneWidget);
    expect(find.text('Votre rendez-vous du 3 dec. 2026 09:00 est confirme.'), findsOneWidget);
    expect(find.text('jeu. 3 dec. 10:15'), findsOneWidget);
    expect(find.text('mar. 1 dec. 18:00'), findsOneWidget);
    // Sujet en gras pour la non lue seulement.
    expect(
      tester.widget<Text>(find.text('Teleconsultation proposee')).style?.fontWeight,
      FontWeight.bold,
    );
    expect(tester.widget<Text>(find.text('Rendez-vous confirme')).style?.fontWeight, isNull);
    // Une seule action « Marquer comme lue » (la non lue).
    expect(find.byTooltip('Marquer comme lue'), findsOneWidget);

    await tester.tap(find.byTooltip('Marquer comme lue'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Marquer comme lue'), findsNothing);
    expect(tester.widget<Text>(find.text('Teleconsultation proposee')).style?.fontWeight, isNull);
  });

  testWidgets("mes notifications permet de tout marquer lu depuis l'AppBar", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesNotificationsPage(api: const FakeApiService(), auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Marquer comme lue'), findsOneWidget);

    await tester.tap(find.byTooltip('Tout marquer comme lu'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Marquer comme lue'), findsNothing);
    expect(find.text('1 notification(s) marquee(s) lue(s)'), findsOneWidget);
  });

  testWidgets('mes notifications affiche un etat vide sans notification', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesNotificationsPage(
        api: const FakeApiServiceSansNotification(),
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aucune notification pour le moment.'), findsOneWidget);
    expect(find.byTooltip('Marquer comme lue'), findsNothing);
  });

  testWidgets("l'accueil propose l'entree Teleconsultations", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecherchePage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Teleconsultations'), findsOneWidget);
  });

  testWidgets('mes teleconsultations sans jeton propose de se connecter', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesTeleconsultationsPage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Je donne mon consentement'), findsNothing);
  });

  testWidgets(
      'mes teleconsultations demande le consentement, puis propose de rejoindre la salle',
      (tester) async {
    Uri? ouvert;
    await tester.pumpWidget(MaterialApp(
      home: MesTeleconsultationsPage(
        api: const FakeApiService(),
        auth: sessionConnectee(),
        ouvrirLien: (lien) async {
          ouvert = lien;
          return true;
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mes teleconsultations'), findsOneWidget);
    // Session planifiee sans consentement : carte de consentement, pas de lien.
    expect(find.text('Proposee le jeu. 3 dec. 08:00'), findsOneWidget);
    expect(find.text('Planifiee'), findsOneWidget);
    expect(find.text(texteConsentement), findsOneWidget);
    expect(find.text('Je donne mon consentement'), findsOneWidget);
    expect(find.text('Rejoindre la teleconsultation'), findsNothing);
    // Session terminee (consentement donne, lien remis) : texte d'etat seulement.
    expect(find.text('Terminee le ven. 20 nov. 09:40'), findsOneWidget);
    expect(find.text('Terminee'), findsOneWidget);
    expect(find.text('Cette teleconsultation est terminee.'), findsOneWidget);

    await tester.tap(find.text('Je donne mon consentement'));
    await tester.pumpAndSettle();
    expect(find.text('Je donne mon consentement'), findsNothing);
    expect(find.text('Consentement enregistre'), findsOneWidget);
    expect(find.text('Rejoindre la teleconsultation'), findsOneWidget);

    await tester.tap(find.text('Rejoindre la teleconsultation'));
    await tester.pumpAndSettle();
    expect(ouvert, Uri.parse(FakeApiService.lienSalle));
  });

  testWidgets("l'accueil propose l'entree Messagerie", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecherchePage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Messagerie'), findsOneWidget);
  });

  testWidgets('mes conversations sans jeton propose de se connecter', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesConversationsPage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Dr Amina Benali'), findsNothing);
  });

  testWidgets('mes conversations liste le praticien, la date du dernier message et les non lus, '
      'puis ouvre le fil', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesConversationsPage(api: const FakeApiService(), auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Messagerie'), findsOneWidget);
    // Nom resolu via la fiche publique, en gras tant qu'il reste des non lus.
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Dr Amina Benali')).style?.fontWeight,
      FontWeight.bold,
    );
    expect(find.text('Dernier message le mar. 1 dec. 09:05'), findsOneWidget);
    expect(find.text('2 non lus'), findsOneWidget);

    await tester.tap(find.text('Dr Amina Benali'));
    await tester.pumpAndSettle();
    // Le fil porte le nom du praticien en titre et ses messages.
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(find.text('Bonjour, comment allez-vous ?'), findsOneWidget);
    expect(find.text('Bonjour docteur, mieux merci.'), findsOneWidget);
  });

  testWidgets("mes conversations affiche « Médecin » et l'identifiant abrege si la fiche du "
      'praticien est indisponible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesConversationsPage(api: const FakeApiServiceSansFiche(), auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();

    // Repli sur les 8 premiers caracteres de l'UUID, jamais l'identifiant entier.
    expect(find.text('Médecin 00000000'), findsOneWidget);
    expect(find.textContaining(FakeApiService.medecinDemo), findsNothing);
    expect(find.text('2 non lus'), findsOneWidget);

    await tester.tap(find.text('Médecin 00000000'));
    await tester.pumpAndSettle();
    // Sans nom, le fil garde son titre generique mais s'ouvre bien sur les messages.
    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Bonjour docteur, mieux merci.'), findsOneWidget);
  });

  testWidgets('le fil aligne mes messages a droite et ceux du medecin a gauche, '
      "n'envoie pas un message vide et se rafraichit apres un envoi", (tester) async {
    final api = FakeApiServiceMessagerie();
    await tester.pumpWidget(MaterialApp(
      home: ConversationPage(
        conversation: Conversation.fromJson({
          'id': FakeApiService.conversationDemo,
          'patientId': FakeApiService.sujetPatient,
          'medecinId': FakeApiService.medecinDemo,
        }),
        api: api,
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();

    // Sans nom de praticien, le titre est generique.
    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('mar. 1 dec. 09:00'), findsOneWidget);
    expect(find.text('mar. 1 dec. 09:05'), findsOneWidget);
    Alignment alignementDe(String contenu) => tester
        .widget<Align>(find.ancestor(of: find.text(contenu), matching: find.byType(Align)).first)
        .alignment as Alignment;
    expect(alignementDe('Bonjour, comment allez-vous ?'), Alignment.centerLeft);
    expect(alignementDe('Bonjour docteur, mieux merci.'), Alignment.centerRight);

    // Bouton « Envoyer » desactive tant que la saisie est vide (ou blanche).
    FilledButton envoyer() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Envoyer'));
    expect(envoyer().onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(envoyer().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Merci docteur, a bientot.');
    await tester.pump();
    expect(envoyer().onPressed, isNotNull);
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    // Message envoye (contenu epure), fil recharge et champ vide.
    expect(api.envoyes.single['contenu'], 'Merci docteur, a bientot.');
    expect(find.text('Merci docteur, a bientot.'), findsOneWidget);
    expect(alignementDe('Merci docteur, a bientot.'), Alignment.centerRight);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
    expect(envoyer().onPressed, isNull);
  });

  testWidgets('la fiche medecin ouvre une conversation avec le praticien', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FicheMedecinPage(
        medecinId: FakeApiService.medecinDemo,
        api: const FakeApiService(),
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir une conversation'), findsOneWidget);

    await tester.tap(find.text('Ouvrir une conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour docteur, mieux merci.'), findsOneWidget);
    expect(find.text('Envoyer'), findsOneWidget);
  });

  testWidgets('la fiche medecin explique le refus (403) sans rendez-vous avec le praticien',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FicheMedecinPage(
        medecinId: FakeApiService.medecinDemo,
        api: const FakeApiServiceSansRendezVous(),
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ouvrir une conversation'));
    await tester.pumpAndSettle();
    expect(find.text(messageConversationRefusee), findsOneWidget);
    expect(find.text('Envoyer'), findsNothing);
  });

  testWidgets("l'accueil propose l'entree Mes avis", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecherchePage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mes avis'), findsOneWidget);
  });

  testWidgets('la fiche medecin affiche la moyenne des avis et les derniers avis anonymes',
      (tester) async {
    surfaceHaute(tester);
    await tester.pumpWidget(const MaterialApp(
      home: FicheMedecinPage(medecinId: FakeApiService.medecinDemo, api: FakeApiService()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('4,5 / 5 (12 avis)'), findsOneWidget);
    expect(find.text('Avis des patients'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text("Très bon médecin, à l'écoute."), findsOneWidget);
    expect(find.text('ven. 20 nov. 10:15'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('jeu. 5 nov. 16:30'), findsOneWidget);
    // Les creneaux restent proposes au-dessus des avis.
    expect(find.text('Reserver'), findsOneWidget);
  });

  testWidgets('la fiche medecin sans avis publie le signale', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FicheMedecinPage(medecinId: FakeApiService.medecinDemo, api: FakeApiServiceSansAvis()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aucun avis'), findsOneWidget);
    expect(find.text('Aucun avis pour le moment.'), findsOneWidget);
    expect(find.textContaining('/ 5'), findsNothing);
  });

  testWidgets('mes rendez-vous propose de donner mon avis sur un rendez-vous honore, '
      "exige une note, puis affiche l'avis comme donne", (tester) async {
    final api = FakeApiServiceAvis();
    await tester.pumpWidget(MaterialApp(
      home: MesRendezVousPage(api: api, auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();

    // Honore sans avis -> bouton ; honore deja evalue -> « Avis donné » ; confirme -> Annuler.
    expect(find.text('Donner mon avis'), findsOneWidget);
    expect(find.text('Avis donné'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.text('Donner mon avis'));
    await tester.pumpAndSettle();
    expect(find.text('Mon avis'), findsOneWidget);
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(find.text('mar. 1 sept. 09:00'), findsOneWidget);
    // Note obligatoire : le bouton reste inactif tant qu'aucune note n'est choisie.
    FilledButton envoyer() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Envoyer mon avis'));
    expect(envoyer().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Explications claires, merci.');
    await tester.pump();
    expect(envoyer().onPressed, isNull);

    await tester.tap(find.widgetWithText(ChoiceChip, '4'));
    await tester.pump();
    expect(envoyer().onPressed, isNotNull);
    await tester.tap(find.text('Envoyer mon avis'));
    await tester.pumpAndSettle();

    // Avis envoye (note et commentaire), retour a la liste rechargee.
    expect(api.deposes.single['rendezVousId'], FakeApiService.rdvHonore);
    expect(api.deposes.single['note'], 4);
    expect(api.deposes.single['commentaire'], 'Explications claires, merci.');
    expect(find.text('Merci pour votre avis.'), findsOneWidget);
    expect(find.text('Mes rendez-vous'), findsOneWidget);
    expect(find.text('Donner mon avis'), findsNothing);
    expect(find.text('Avis donné'), findsNWidgets(2));
  });

  testWidgets("mes rendez-vous et le detail d'une ordonnance replient sur « Médecin » et "
      "l'identifiant abrege si la fiche du praticien est indisponible", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesRendezVousPage(api: const FakeApiServiceSansFiche(), auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();

    // Trois rendez-vous du meme praticien : le libelle de repli, jamais l'UUID entier.
    expect(find.text('Médecin 00000000 · Confirme'), findsOneWidget);
    expect(find.text('Médecin 00000000 · Honore'), findsNWidgets(2));
    expect(find.textContaining(FakeApiService.medecinDemo), findsNothing);
    // Les actions restent disponibles (identifiants en texte).
    expect(find.text('Donner mon avis'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: DetailOrdonnancePage(
        ordonnanceId: FakeApiService.ordonnanceDemo,
        api: const FakeApiServiceSansFiche(),
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Médecin 00000000'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets("deposer un avis deja donne explique le conflit (409) sans fermer l'ecran",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DeposerAvisPage(
        rendezVousId: FakeApiService.rdvEvalue,
        api: const FakeApiServiceAvisDejaDonne(),
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.pump();
    await tester.tap(find.text('Envoyer mon avis'));
    await tester.pumpAndSettle();
    expect(find.text(messageAvisDejaDonne), findsOneWidget);
    expect(find.text('Mon avis'), findsOneWidget);
  });

  testWidgets('mes avis liste praticien, note, statut, commentaire et date', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MesAvisPage(api: const FakeApiService(), auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mes avis'), findsOneWidget);
    expect(find.text('Dr Amina Benali'), findsOneWidget);
    expect(find.text('4 / 5 · Publié'), findsOneWidget);
    expect(find.text('Explications claires, merci.'), findsOneWidget);
    expect(find.text('Déposé le mar. 11 aout 18:00'), findsOneWidget);
  });

  testWidgets("l'accueil propose l'entree Dawini (pharmacies)", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecherchePage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Dawini (pharmacies)'), findsOneWidget);
  });

  testWidgets('dawini sans jeton propose de se connecter', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DawiniPage(api: const FakeApiService(), auth: AuthService()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Publier la demande'), findsNothing);
  });

  testWidgets('dawini refuse une demande sans medicament ni wilaya, puis publie et liste '
      'mes demandes avec leur statut et leurs reponses', (tester) async {
    surfaceHaute(tester);
    final api = FakeApiServiceDawini();
    await tester.pumpWidget(MaterialApp(
      home: DawiniPage(api: api, auth: sessionConnectee()),
    ));
    await tester.pumpAndSettle();

    // Mes demandes : statut et nombre de reponses.
    expect(find.text('Doliprane 1000'), findsOneWidget);
    expect(find.text('Wilaya 16 · Alger-Centre · Ouverte'), findsOneWidget);
    expect(find.text('2 réponses'), findsOneWidget);
    expect(find.text('Ventoline'), findsOneWidget);
    expect(find.text('Wilaya 16 · Alger-Centre · Clôturée'), findsOneWidget);
    expect(find.text('0 réponse'), findsOneWidget);

    // Formulaire vide : refus sans medicament, puis sans wilaya.
    final medicament = find.widgetWithText(TextField, 'Médicament recherché *');
    await tester.tap(find.text('Publier la demande'));
    await tester.pumpAndSettle();
    expect(find.text(messageMedicamentRequis), findsOneWidget);
    expect(api.publies, isEmpty);
    await laisserPasserLeMessage(tester);

    await tester.enterText(medicament, 'Insuline');
    await tester.tap(find.text('Publier la demande'));
    await tester.pumpAndSettle();
    expect(find.text(messageWilayaRequise), findsOneWidget);
    expect(api.publies, isEmpty);
    await laisserPasserLeMessage(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Wilaya (code) *'), '16');
    await tester.enterText(find.widgetWithText(TextField, 'Commune'), 'Bab Ezzouar');
    await tester.tap(find.text('Publier la demande'));
    await tester.pumpAndSettle();
    expect(api.publies.single['medicament'], 'Insuline');
    expect(api.publies.single['wilayaCode'], '16');
    expect(api.publies.single['commune'], 'Bab Ezzouar');
    expect(api.publies.single['precision'], isNull);
    expect(find.text('Demande publiée.'), findsOneWidget);
    // La nouvelle demande apparait dans la liste, le formulaire est vide.
    expect(find.text('Insuline'), findsOneWidget);
    expect(find.text('Wilaya 16 · Bab Ezzouar · Ouverte'), findsOneWidget);
    expect(tester.widget<TextField>(medicament).controller?.text, isEmpty);
  });

  testWidgets("les reponses d'une demande affichent la pharmacie, la disponibilite, le prix "
      'et la date, puis permettent de cloturer la demande', (tester) async {
    surfaceHaute(tester);
    final api = FakeApiServiceDawini();
    await tester.pumpWidget(MaterialApp(
      home: ReponsesBesoinPage(
        besoin: BesoinMedicament.fromJson({
          'id': FakeApiService.besoinOuvert,
          'medicament': 'Doliprane 1000',
          'wilayaCode': '16',
          'commune': 'Alger-Centre',
          'precision': 'Boite de 8, urgent',
          'statut': 'OUVERT',
          'publieLe': '2026-11-20T09:00:00',
          'nombreReponses': 2,
        }),
        api: api,
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Réponses des pharmacies'), findsOneWidget);
    expect(find.text('Doliprane 1000'), findsOneWidget);
    expect(find.text('Wilaya 16 · Alger-Centre · Ouverte'), findsOneWidget);
    expect(find.text('Boite de 8, urgent'), findsOneWidget);
    expect(find.text('Publiée le ven. 20 nov. 09:00'), findsOneWidget);
    expect(find.text('Pharmacie El Amel'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('850 DA'), findsOneWidget);
    expect(find.text('En stock, boite de 8.'), findsOneWidget);
    expect(find.text('ven. 20 nov. 10:15'), findsOneWidget);
    expect(find.text('Pharmacie Ibn Sina'), findsOneWidget);
    expect(find.text('Indisponible'), findsOneWidget);
    expect(find.text('ven. 20 nov. 11:00'), findsOneWidget);

    await tester.tap(find.text('Clôturer la demande'));
    await tester.pumpAndSettle();
    expect(find.text('Clôturer cette demande ?'), findsOneWidget);
    await tester.tap(find.text('Oui, clôturer'));
    await tester.pumpAndSettle();
    expect(api.clotures, [FakeApiService.besoinOuvert]);
    expect(find.text('Demande clôturée.'), findsOneWidget);
    expect(find.text('Clôturer la demande'), findsNothing);
    expect(find.text('Wilaya 16 · Alger-Centre · Clôturée'), findsOneWidget);
  });

  testWidgets('cloturer une demande deja cloturee explique le conflit (409)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReponsesBesoinPage(
        besoin: BesoinMedicament.fromJson({
          'id': FakeApiService.besoinOuvert,
          'medicament': 'Doliprane 1000',
          'wilayaCode': '16',
          'statut': 'OUVERT',
        }),
        api: const FakeApiServiceDemandeDejaCloturee(),
        auth: sessionConnectee(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clôturer la demande'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, clôturer'));
    await tester.pumpAndSettle();
    expect(find.text(messageDemandeDejaCloturee), findsOneWidget);
    expect(find.text('Clôturer la demande'), findsNothing);
    expect(find.text('Wilaya 16 · Clôturée'), findsOneWidget);
  });
}
