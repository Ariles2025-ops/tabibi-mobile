import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/main.dart';
import 'package:tabibi_mobile/models/conversation.dart';
import 'package:tabibi_mobile/pages/conversation_page.dart';
import 'package:tabibi_mobile/pages/deposer_avis_page.dart';
import 'package:tabibi_mobile/pages/detail_ordonnance_page.dart';
import 'package:tabibi_mobile/pages/fiche_medecin_page.dart';
import 'package:tabibi_mobile/pages/mes_avis_page.dart';
import 'package:tabibi_mobile/pages/mes_conversations_page.dart';
import 'package:tabibi_mobile/pages/mes_notifications_page.dart';
import 'package:tabibi_mobile/pages/mes_ordonnances_page.dart';
import 'package:tabibi_mobile/pages/mes_rendez_vous_page.dart';
import 'package:tabibi_mobile/pages/mes_teleconsultations_page.dart';
import 'package:tabibi_mobile/pages/verifier_ordonnance_page.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/services/auth_service.dart';

import 'outils.dart';

/// API factice : aucune requete reseau, donnees fixes.
class FakeApiService extends ApiService {
  const FakeApiService();

  /// Code de verification de l'ordonnance factice (seul code reconnu par [verifierOrdonnance]).
  static const String codeValide = 'ABC123';

  /// Identifiant (sujet du jeton) du patient de test : ses messages sont alignes a droite.
  static const String sujetPatient = 'patient-7';

  @override
  Future<List<Map<String, dynamic>>> rechercherMedecins({
    String? specialite,
    String? wilaya,
    String? q,
  }) async =>
      [await medecin(1)];

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

  /// Deux notifications : la plus recente (n-1) non lue, l'autre deja lue.
  @override
  Future<List<Map<String, dynamic>>> mesNotifications(String token) async => [
        _notification('n-1', lue: false),
        _notification('n-2', lue: true),
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

  /// Deux teleconsultations : la plus recente (tc-1) planifiee sans consentement,
  /// l'autre (tc-2) terminee avec consentement (lien remis mais session close).
  @override
  Future<List<Map<String, dynamic>>> mesTeleconsultations(String token) async => [
        _teleconsultation('tc-1', 'PLANIFIEE', consentie: false),
        _teleconsultation('tc-2', 'TERMINEE', consentie: true),
      ];

  @override
  Future<Map<String, dynamic>> teleconsultation(String id, String token) async =>
      _teleconsultation(id, 'PLANIFIEE', consentie: false);

  @override
  Future<Map<String, dynamic>> consentir(String teleconsultationId, String token) async =>
      _teleconsultation(teleconsultationId, 'PLANIFIEE', consentie: true);

  /// Une conversation avec le praticien 1, deux messages non lus.
  @override
  Future<List<Map<String, dynamic>>> mesConversations(String token) async =>
      [_conversation('conv-1', nonLus: 2)];

  @override
  Future<Map<String, dynamic>> ouvrirConversation(int medecinId, String token) async =>
      _conversation('conv-1', nonLus: 0);

  /// Deux messages : le premier du praticien, le second du patient de test.
  @override
  Future<List<Map<String, dynamic>>> messages(String conversationId, String token) async => [
        _messageJson('m-1', 'medecin-1', 'Bonjour, comment allez-vous ?', '2026-12-01T09:00:00'),
        _messageJson('m-2', sujetPatient, 'Bonjour docteur, mieux merci.', '2026-12-01T09:05:00'),
      ];

  @override
  Future<Map<String, dynamic>> envoyerMessage(
    String conversationId,
    String contenu,
    String token,
  ) async =>
      _messageJson('m-3', sujetPatient, contenu, '2026-12-01T09:10:00');

  /// Trois rendez-vous : 3 honore sans avis, 4 confirme (annulable), 5 honore deja evalue.
  @override
  Future<List<Map<String, dynamic>>> mesRendezVous(String token) async => [
        _rendezVous(3, 'HONORE', '2026-09-01T09:00:00'),
        _rendezVous(4, 'CONFIRME', '2026-12-03T09:00:00'),
        _rendezVous(5, 'HONORE', '2026-08-10T14:30:00'),
      ];

  /// Un seul avis depose, sur le rendez-vous 5.
  @override
  Future<List<Map<String, dynamic>>> mesAvis(String token) async => [_avis('avis-5', 5)];

  @override
  Future<Map<String, dynamic>> deposerAvis(
    int rendezVousId,
    int note,
    String? commentaire,
    String token,
  ) async =>
      _avis('avis-$rendezVousId', rendezVousId, note: note, commentaire: commentaire);

  /// Synthese publique du praticien : 12 avis, moyenne 4,5, deux derniers avis.
  @override
  Future<Map<String, dynamic>> avisDuMedecin(int medecinId) async => {
        'moyenne': 4.5,
        'nombre': 12,
        'avis': [
          {
            'id': 'avis-a',
            'note': 5,
            'commentaire': "Très bon médecin, à l'écoute.",
            'deposeLe': '2026-11-20T10:15:00',
          },
          {'id': 'avis-b', 'note': 4, 'commentaire': null, 'deposeLe': '2026-11-05T16:30:00'},
        ],
      };

  static Map<String, dynamic> _rendezVous(int id, String statut, String debut) => {
        'id': id,
        'patientId': sujetPatient,
        'medecinId': 1,
        'creneauId': null,
        'debut': debut,
        'statut': statut,
      };

  static Map<String, dynamic> _avis(
    String id,
    int rendezVousId, {
    int note = 4,
    String? commentaire = 'Explications claires, merci.',
  }) =>
      {
        'id': id,
        'rendezVousId': rendezVousId,
        'medecinId': 1,
        'note': note,
        'commentaire': commentaire,
        'statut': 'PUBLIE',
        'deposeLe': '2026-08-11T18:00:00',
      };

  static Map<String, dynamic> _conversation(String id, {required int nonLus}) => {
        'id': id,
        'patientId': sujetPatient,
        'medecinId': 1,
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
        'conversationId': 'conv-1',
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
        'rendezVousId': 'rdv-3',
        'patientId': 'patient-7',
        'medecinId': 'medecin-1',
        'statut': statut,
        'consentementPatientLe': consentie ? '2026-12-03T08:30:00' : null,
        'lienSalle': consentie ? lienSalle : null,
        'creeLe': id == 'tc-1' ? '2026-12-03T08:00:00' : '2026-11-20T09:00:00',
        'demarreeLe': statut == 'TERMINEE' ? '2026-11-20T09:05:00' : null,
        'termineeLe': statut == 'TERMINEE' ? '2026-11-20T09:40:00' : null,
      };

  static Map<String, dynamic> _notification(String id, {required bool lue}) => {
        'id': id,
        'destinataireId': 'patient-7',
        'canal': 'INTERNE',
        'sujet': id == 'n-1' ? 'Teleconsultation proposee' : 'Rendez-vous confirme',
        'message': id == 'n-1'
            ? 'Votre medecin vous propose une teleconsultation pour votre rendez-vous '
                'du 3 dec. 2026 09:00.'
            : 'Votre rendez-vous du 3 dec. 2026 09:00 est confirme.',
        'lue': lue,
        'creeLe': id == 'n-1' ? '2026-12-03T10:15:00' : '2026-12-01T18:00:00',
      };

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
  Future<Map<String, dynamic>> ouvrirConversation(int medecinId, String token) async =>
      throw const ApiException(403, 'Aucun rendez-vous avec ce medecin');
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
    int rendezVousId,
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
    int rendezVousId,
    int note,
    String? commentaire,
    String token,
  ) async =>
      throw const ApiException(409, 'Un avis existe deja pour ce rendez-vous');
}

/// Variante d'un praticien sans aucun avis publie.
class FakeApiServiceSansAvis extends FakeApiService {
  const FakeApiServiceSansAvis();

  @override
  Future<Map<String, dynamic>> avisDuMedecin(int medecinId) async =>
      {'moyenne': null, 'nombre': 0, 'avis': []};
}

/// Session de test deja munie d'un jeton (JWT factice au sujet [FakeApiService.sujetPatient],
/// aucun appel a Keycloak).
AuthService sessionConnectee() =>
    AuthService()..accessToken = jetonAvecSujet(FakeApiService.sujetPatient);

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

  testWidgets('le fil aligne mes messages a droite et ceux du medecin a gauche, '
      "n'envoie pas un message vide et se rafraichit apres un envoi", (tester) async {
    final api = FakeApiServiceMessagerie();
    await tester.pumpWidget(MaterialApp(
      home: ConversationPage(
        conversation: Conversation.fromJson({
          'id': 'conv-1',
          'patientId': FakeApiService.sujetPatient,
          'medecinId': 1,
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
      home: FicheMedecinPage(medecinId: 1, api: const FakeApiService(), auth: sessionConnectee()),
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
        medecinId: 1,
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
    await tester.pumpWidget(const MaterialApp(
      home: FicheMedecinPage(medecinId: 1, api: FakeApiService()),
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
      home: FicheMedecinPage(medecinId: 1, api: FakeApiServiceSansAvis()),
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
    expect(api.deposes.single['rendezVousId'], 3);
    expect(api.deposes.single['note'], 4);
    expect(api.deposes.single['commentaire'], 'Explications claires, merci.');
    expect(find.text('Merci pour votre avis.'), findsOneWidget);
    expect(find.text('Mes rendez-vous'), findsOneWidget);
    expect(find.text('Donner mon avis'), findsNothing);
    expect(find.text('Avis donné'), findsNWidgets(2));
  });

  testWidgets("deposer un avis deja donne explique le conflit (409) sans fermer l'ecran",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DeposerAvisPage(
        rendezVousId: 5,
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
}
