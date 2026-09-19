import 'package:flutter_appauth/flutter_appauth.dart';

import '../config/configuration.dart';
import '../utils/jetons.dart';

/// Authentification OIDC contre le realm Keycloak « tabibi ».
///
/// Une seule instance est partagee par toute l'application (voir `session.dart`)
/// afin de conserver le jeton d'un ecran a l'autre. L'emetteur, le client et l'URI de
/// redirection viennent de la configuration par environnement ([Configuration],
/// `--dart-define=TABIBI_ISSUER=...`).
class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  String? accessToken;

  /// Vrai si un jeton d'acces est disponible.
  bool get estConnecte => accessToken != null;

  /// Identifiant de l'utilisateur connecte (sujet du jeton, voir [sujetDuJeton]) ;
  /// null hors connexion ou si le jeton ne porte pas de sujet lisible.
  String? get sujet => sujetDuJeton(accessToken);

  /// Ouvre la connexion Keycloak ; false si l'utilisateur annule ou en cas d'echec.
  Future<bool> seConnecter() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          Configuration.clientId,
          Configuration.redirect,
          issuer: Configuration.issuer,
          scopes: ['openid', 'profile'],
        ),
      );
      accessToken = result.accessToken;
    } on Exception {
      // Annulation par l'utilisateur ou erreur de plateforme : non connecte.
      return false;
    }
    return accessToken != null;
  }

  void seDeconnecter() => accessToken = null;
}
