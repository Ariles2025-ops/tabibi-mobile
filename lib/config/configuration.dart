/// Configuration par environnement, fixee a la compilation par `--dart-define`
/// (`flutter run --dart-define=TABIBI_API_URL=http://localhost:8080`) ; aucune valeur n'est
/// lue a l'execution, aucun secret n'est embarque (le client Keycloak est public, PKCE).
///
/// Sans `--dart-define`, les valeurs par defaut visent l'environnement de developpement vu
/// depuis l'emulateur Android : `10.0.2.2` est la machine hote (API sur 8080, Keycloak sur
/// 8081). Sur le simulateur iOS, la machine hote est `localhost` : lancer avec
/// `--dart-define=TABIBI_API_URL=http://localhost:8080` et
/// `--dart-define=TABIBI_ISSUER=http://localhost:8081/realms/tabibi`.
class Configuration {
  const Configuration._();

  /// Valeurs par defaut (emulateur Android, realm Keycloak « tabibi »).
  static const String apiUrlParDefaut = 'http://10.0.2.2:8080';
  static const String issuerParDefaut = 'http://10.0.2.2:8081/realms/tabibi';
  static const String clientIdParDefaut = 'tabibi-mobile';
  static const String redirectParDefaut = 'dz.tabibi.app:/oauthredirect';

  /// Adresse de base de l'API Tabibi, sans barre oblique finale (`TABIBI_API_URL`).
  static const String apiUrl = String.fromEnvironment(
    'TABIBI_API_URL',
    defaultValue: apiUrlParDefaut,
  );

  /// Emetteur OIDC : le realm Keycloak (`TABIBI_ISSUER`).
  static const String issuer = String.fromEnvironment(
    'TABIBI_ISSUER',
    defaultValue: issuerParDefaut,
  );

  /// Identifiant du client public declare dans Keycloak (`TABIBI_CLIENT_ID`).
  static const String clientId = String.fromEnvironment(
    'TABIBI_CLIENT_ID',
    defaultValue: clientIdParDefaut,
  );

  /// URI de redirection apres connexion (`TABIBI_REDIRECT`) ; son schema
  /// (`dz.tabibi.app`) doit etre declare dans les projets natifs (voir README).
  static const String redirect = String.fromEnvironment(
    'TABIBI_REDIRECT',
    defaultValue: redirectParDefaut,
  );
}
