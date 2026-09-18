import 'package:flutter_appauth/flutter_appauth.dart';

/// Authentification OIDC contre le realm Keycloak « tabibi ».
class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  // En dev : emulateur Android -> 10.0.2.2 ; iOS -> localhost.
  static const String _issuer = 'http://10.0.2.2:8081/realms/tabibi';
  static const String _clientId = 'tabibi-mobile';
  static const String _redirect = 'dz.tabibi.app:/oauthredirect';

  String? accessToken;

  Future<bool> seConnecter() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirect,
        issuer: _issuer,
        scopes: ['openid', 'profile'],
      ),
    );
    accessToken = result.accessToken;
    return accessToken != null;
  }

  void seDeconnecter() => accessToken = null;
}
