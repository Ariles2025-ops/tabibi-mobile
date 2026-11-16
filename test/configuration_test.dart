import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/config/configuration.dart';
import 'package:tabibi_mobile/services/api_service.dart';

void main() {
  // `flutter test` n'est lance ici sans aucun --dart-define : les valeurs par defaut s'appliquent.
  test('la configuration par defaut est la production, meme plateforme que le site', () {
    expect(Configuration.apiUrl, 'https://api.tabibi.doctor');
    expect(Configuration.issuer, 'https://auth.tabibi.doctor/realms/tabibi');
    expect(Configuration.clientId, 'tabibi-mobile');
    expect(Configuration.redirect, 'dz.tabibi.app:/oauthredirect');
  });

  test('les valeurs par defaut sont exposees telles quelles pour la documentation', () {
    expect(Configuration.apiUrlParDefaut, Configuration.apiUrl);
    expect(Configuration.issuerParDefaut, Configuration.issuer);
    expect(Configuration.clientIdParDefaut, Configuration.clientId);
    expect(Configuration.redirectParDefaut, Configuration.redirect);
    // Adresses sans barre oblique finale : les chemins `/api/...` s'y concatenent directement.
    expect(Configuration.apiUrl.endsWith('/'), isFalse);
    expect(Configuration.issuer.endsWith('/'), isFalse);
  });

  test("ApiService lit l'adresse de l'API dans la configuration, ou celle fournie", () {
    expect(const ApiService().base, Configuration.apiUrl);
    expect(const ApiService(base: 'http://localhost:8080').base, 'http://localhost:8080');
  });

  test('aucune adresse de developpement (10.0.2.2, localhost, Supabase) par defaut', () {
    for (final url in [Configuration.apiUrl, Configuration.issuer]) {
      expect(url.startsWith('https://'), isTrue);
      expect(url.contains('10.0.2.2') || url.contains('localhost') || url.contains('supabase'), isFalse);
    }
  });
}
