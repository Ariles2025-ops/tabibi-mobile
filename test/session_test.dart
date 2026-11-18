import 'dart:convert';
import 'dart:io';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/services/auth_service.dart';

class StockageMemoire implements StockageJetons {
  final Map<String, String> donnees = {};

  @override
  Future<String?> lire(String cle) async => donnees[cle];

  @override
  Future<void> ecrire(String cle, String? valeur) async {
    if (valeur == null) {
      donnees.remove(cle);
    } else {
      donnees[cle] = valeur;
    }
  }

  @override
  Future<void> effacerTout() async => donnees.clear();
}

class AuthTest extends AuthService {
  AuthTest(StockageMemoire s, this.maintenantFixe) : super(stockage: s, maintenant: () => maintenantFixe);

  final DateTime maintenantFixe;
  int echanges = 0;
  bool refuser = false;
  bool horsLigne = false;
  final List<String> refreshRecus = [];

  @override
  Future<TokenResponse?> echangerRefreshToken(String refresh) async {
    echanges++;
    refreshRecus.add(refresh);
    if (horsLigne) throw const SocketException('hors ligne');
    if (refuser) throw Exception('invalid_grant');
    return TokenResponse('acces$echanges', 'refresh$echanges', maintenantFixe.add(const Duration(minutes: 5)),
        'id$echanges', 'Bearer', null, null);
  }
}

void main() {
  final maintenant = DateTime.utc(2026, 11, 17, 12);

  Future<StockageMemoire> avecSession({required Duration validite}) async {
    final s = StockageMemoire();
    await s.ecrire('access_token', 'ancien');
    await s.ecrire('refresh_token', 'r0');
    await s.ecrire('id_token', 'i0');
    await s.ecrire('expiration', maintenant.add(validite).millisecondsSinceEpoch.toString());
    return s;
  }

  test('restaurer : jeton encore valide, repris sans appel reseau', () async {
    final s = await avecSession(validite: const Duration(minutes: 3));
    final auth = AuthTest(s, maintenant);
    expect(await auth.restaurer(), isTrue);
    expect(auth.accessToken, 'ancien');
    expect(auth.idToken, 'i0');
    expect(auth.echanges, 0);
    auth.seDeconnecter();
  });

  test('restaurer : jeton expire, rafraichi avec le refresh token puis enregistre', () async {
    final s = await avecSession(validite: const Duration(minutes: -1));
    final auth = AuthTest(s, maintenant);
    expect(await auth.restaurer(), isTrue);
    expect(auth.refreshRecus, ['r0']);
    expect(auth.accessToken, 'acces1');
    expect(s.donnees['refresh_token'], 'refresh1');
    auth.seDeconnecter();
  });

  test('restaurer : rien d\'enregistre ou rafraichissement refuse = non connecte', () async {
    expect(await AuthTest(StockageMemoire(), maintenant).restaurer(), isFalse);
    final s = await avecSession(validite: const Duration(minutes: -1));
    final auth = AuthTest(s, maintenant)..refuser = true;
    expect(await auth.restaurer(), isFalse);
    expect(auth.estConnecte, isFalse);
  });

  test('scopes : offline_access demande', () {
    expect(AuthService.scopes, contains('offline_access'));
  });

  test('restaurer : sans reseau, jetons gardes puis nouvel essai reussi', () async {
    final s = await avecSession(validite: const Duration(minutes: -1));
    final auth = AuthTest(s, maintenant)..horsLigne = true;
    expect(await auth.restaurer(), isTrue);
    expect(auth.estConnecte, isTrue);
    expect(s.donnees['refresh_token'], 'r0');
    auth.horsLigne = false;
    expect(await auth.jetonApres401('ancien'), 'acces2');
    expect(auth.refreshRecus, ['r0', 'r0']);
    auth.seDeconnecter();
  });

  test('rafraichir : appels simultanes = un seul echange', () async {
    final auth = AuthTest(await avecSession(validite: const Duration(minutes: -1)), maintenant);
    await auth.restaurer();
    auth.echanges = 0;
    final r = await Future.wait([auth.rafraichir(), auth.rafraichir()]);
    expect(r, [true, true]);
    expect(auth.echanges, 1);
    auth.seDeconnecter();
  });

  test('seDeconnecter efface les jetons du stockage', () async {
    final s = await avecSession(validite: const Duration(minutes: 3));
    final auth = AuthTest(s, maintenant);
    await auth.restaurer();
    auth.seDeconnecter();
    await Future<void>.delayed(Duration.zero);
    expect(auth.estConnecte, isFalse);
    expect(s.donnees, isEmpty);
  });

  test('jetonApres401 : rafraichit une fois, ou reutilise un jeton deja renouvele', () async {
    final auth = AuthTest(await avecSession(validite: const Duration(minutes: 3)), maintenant);
    await auth.restaurer();
    expect(await auth.jetonApres401('ancien'), 'acces1');
    expect(await auth.jetonApres401('ancien'), 'acces1');
    expect(auth.echanges, 1);
    auth.refuser = true;
    expect(await auth.jetonApres401('acces1'), isNull);
    auth.seDeconnecter();
  });

  group('ApiService', () {
    tearDown(() => ApiService.rafraichisseur = null);

    Future<List<String>> appeler(List<int> statuts) async {
      final vus = <String>[];
      await http.runWithClient(
        () async {
          try {
            await const ApiService(base: 'https://api.test').mesRendezVous('vieux');
          } on ApiException {
            // statut final observe par les tests
          }
        },
        () => MockClient((r) async {
          vus.add(r.headers['Authorization']!);
          return http.Response('[]', statuts[vus.length - 1]);
        }),
      );
      return vus;
    }

    test('401 : un seul rejeu avec le jeton rafraichi', () async {
      ApiService.rafraichisseur = (ancien) async => 'neuf';
      expect(await appeler([401, 200]), ['Bearer vieux', 'Bearer neuf']);
    });

    test('401 : pas de rejeu infini, le 401 final remonte', () async {
      ApiService.rafraichisseur = (ancien) async => 'neuf';
      expect(await appeler([401, 401]), ['Bearer vieux', 'Bearer neuf']);
    });

    test('401 sans nouveau jeton : aucun rejeu', () async {
      ApiService.rafraichisseur = (ancien) async => null;
      expect(await appeler([401]), ['Bearer vieux']);
    });

    Future<ApiException> erreur(int statut, Object corps) async {
      try {
        await http.runWithClient(
          () => const ApiService(base: 'https://api.test').mesRendezVous('j'),
          // Corps en UTF-8 comme le vrai serveur : http.Response(String) encoderait en latin-1
          // sans charset, ce qui n'est pas du UTF-8 valide pour « é ».
          () => MockClient((r) async => http.Response.bytes(utf8.encode(jsonEncode(corps)), statut,
              headers: {'content-type': 'application/json; charset=utf-8'})),
        );
      } on ApiException catch (e) {
        return e;
      }
      throw StateError('aucune erreur');
    }

    test('le champ message du serveur est lu', () async {
      expect((await erreur(400, {'message': 'Heure invalide'})).message, 'Heure invalide');
      expect((await erreur(404, {'erreur': 'Créneau disparu'})).message, 'Créneau disparu');
    });

    test('429 et 500 : message clair, sans texte technique', () async {
      final e429 = await erreur(429, {'message': 'Too many requests'});
      expect(e429.message, contains('Trop de demandes'));
      final e500 = await erreur(500, {'message': 'NullPointer at /api/x'});
      expect(e500.message, isNot(contains('/api')));
      expect(e500.message, contains('serveur'));
    });
  });
}
