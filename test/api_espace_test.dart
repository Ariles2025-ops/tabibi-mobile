import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/services/auth_service.dart';

/// Execute [appel] avec un client HTTP factice qui note les requetes et repond [corps] / [statut].
Future<List<http.Request>> requetes(
  Future<Object?> Function(ApiService api) appel, {
  Object? corps = const <String, dynamic>{},
  int statut = 200,
}) async {
  final vues = <http.Request>[];
  await http.runWithClient(
    () => appel(const ApiService(base: 'https://api.test')),
    () => MockClient((r) async {
      vues.add(r);
      return http.Response(corps == null ? '' : jsonEncode(corps), statut,
          headers: {'content-type': 'application/json'});
    }),
  );
  return vues;
}

void main() {
  test('corpsCreneau envoie le debut en UTC ISO 8601 et la duree', () {
    final c = corpsCreneau(DateTime.utc(2026, 12, 3, 8), 30);
    expect(c, {'debut': '2026-12-03T08:00:00.000Z', 'dureeMinutes': 30});
  });

  test('supprimerMonCompte appelle DELETE /api/moi avec le jeton', () async {
    final r = (await requetes((a) => a.supprimerMonCompte('j'), corps: null, statut: 204)).single;
    expect(r.method, 'DELETE');
    expect(r.url.toString(), 'https://api.test/api/moi');
    expect(r.headers['Authorization'], 'Bearer j');
  });

  test('supprimerMonCompte leve une ApiException en cas de refus', () async {
    expect(requetes((a) => a.supprimerMonCompte('j'), statut: 401),
        throwsA(isA<ApiException>().having((e) => e.nonAutorise, 'nonAutorise', isTrue)));
  });

  test('espace medecin : agenda, actions, creneaux et liste d\'attente', () async {
    final routes = <String>[];
    Future<void> noter(Future<Object?> Function(ApiService) f, {Object? corps}) async {
      final r = (await requetes(f, corps: corps ?? <String, dynamic>{})).single;
      routes.add('${r.method} ${r.url.path}');
    }

    await noter((a) => a.agendaMedecin('j'), corps: []);
    await noter((a) => a.honorerRendezVous('r1', 'j'));
    await noter((a) => a.marquerAbsentMedecin('r1', 'j'));
    await noter((a) => a.annulerParMedecin('r1', 'j'));
    await noter((a) => a.creneauxMedecin('j'), corps: []);
    await noter((a) => a.supprimerCreneauMedecin('c1', 'j'));
    await noter((a) => a.listeAttenteMedecin('j'), corps: []);
    await noter((a) => a.patientsMedecin('j'), corps: []);
    expect(routes, [
      'GET /api/medecin/rendezvous',
      'POST /api/rendezvous/r1/honorer',
      'POST /api/medecin/rendezvous/r1/absent',
      'POST /api/medecin/rendezvous/r1/annuler',
      'GET /api/medecin/creneaux',
      'DELETE /api/medecin/creneaux/c1',
      'GET /api/medecin/liste-attente',
      'GET /api/medecin/patients',
    ]);
  });

  test('ouvrirCreneauMedecin poste le corps JSON du creneau', () async {
    final r = (await requetes((a) => a.ouvrirCreneauMedecin(DateTime.utc(2026, 12, 3, 8), 20, 'j')))
        .single;
    expect('${r.method} ${r.url.path}', 'POST /api/medecin/creneaux');
    expect(jsonDecode(r.body), {'debut': '2026-12-03T08:00:00.000Z', 'dureeMinutes': 20});
  });

  test('espace secretaire et invitations : routes /api/secretaire et /api/moi', () async {
    final routes = <String>[];
    Future<void> noter(Future<Object?> Function(ApiService) f, {Object? corps}) async {
      final r = (await requetes(f, corps: corps ?? <String, dynamic>{})).single;
      routes.add('${r.method} ${r.url.path}');
    }

    await noter((a) => a.cabinetsSecretaire('j'), corps: []);
    await noter((a) => a.agendaSecretaire('m1', 'j'), corps: []);
    await noter((a) => a.creneauxSecretaire('m1', 'j'), corps: []);
    await noter((a) => a.ouvrirCreneauSecretaire('m1', DateTime.utc(2026, 12, 3), 30, 'j'));
    await noter((a) => a.supprimerCreneauSecretaire('m1', 'c1', 'j'));
    await noter((a) => a.honorerParSecretaire('r1', 'j'));
    await noter((a) => a.absentParSecretaire('r1', 'j'));
    await noter((a) => a.annulerParSecretaire('r1', 'j'));
    await noter((a) => a.patientsCabinet('m1', 'j'), corps: []);
    await noter((a) => a.invitationsCabinet('j'), corps: []);
    await noter((a) => a.accepterInvitation('i1', 'j'));
    await noter((a) => a.refuserInvitation('i1', 'j'));
    expect(routes, [
      'GET /api/secretaire/medecins',
      'GET /api/secretaire/medecins/m1/rendezvous',
      'GET /api/secretaire/medecins/m1/creneaux',
      'POST /api/secretaire/medecins/m1/creneaux',
      'DELETE /api/secretaire/medecins/m1/creneaux/c1',
      'POST /api/secretaire/rendezvous/r1/honorer',
      'POST /api/secretaire/rendezvous/r1/absent',
      'POST /api/secretaire/rendezvous/r1/annuler',
      'GET /api/secretaire/medecins/m1/patients',
      'GET /api/moi/invitations-cabinet',
      'POST /api/moi/invitations-cabinet/i1/accepter',
      'POST /api/moi/invitations-cabinet/i1/refuser',
    ]);
  });

  test('espace pharmacie : besoins de la wilaya, reponse et delivrance', () async {
    final besoins = (await requetes((a) => a.besoinsWilaya('16', 'j'), corps: [])).single;
    expect(besoins.url.toString(), 'https://api.test/api/dawini/besoins?wilaya=16');

    final reponse = (await requetes(
            (a) => a.repondreBesoin('b1', true, 'j', prixDa: 850, commentaire: 'En stock')))
        .single;
    expect('${reponse.method} ${reponse.url.path}', 'POST /api/dawini/besoins/b1/reponses');
    expect(
        jsonDecode(reponse.body), {'disponible': true, 'prixDa': 850, 'commentaire': 'En stock'});

    final delivre = (await requetes((a) => a.delivrerOrdonnance('ABC123', 'j'),
            corps: {'valide': true, 'statut': 'DELIVREE'}))
        .single;
    expect(
        '${delivre.method} ${delivre.url.path}', 'POST /api/pharmacie/ordonnances/ABC123/delivrer');
  });

  test('seDeconnecterCompletement efface les jetons et ferme la session Keycloak', () async {
    final auth = _AuthEspion()
      ..accessToken = 'acces'
      ..idToken = 'identite';
    await auth.seDeconnecterCompletement();
    expect(auth.accessToken, isNull);
    expect(auth.idToken, isNull);
    expect(auth.finsDeSession, ['identite']);
  });

  test('seDeconnecterCompletement deconnecte meme si la fin de session echoue', () async {
    final auth = _AuthEspion(echec: true)
      ..accessToken = 'acces'
      ..idToken = 'identite';
    await auth.seDeconnecterCompletement();
    expect(auth.estConnecte, isFalse);
  });
}

class _AuthEspion extends AuthService {
  _AuthEspion({this.echec = false});
  final bool echec;
  final finsDeSession = <String>[];

  @override
  Future<void> finDeSession(String jeton) async {
    finsDeSession.add(jeton);
    if (echec) throw Exception('hors ligne');
  }
}
