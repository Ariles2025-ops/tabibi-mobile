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

  /// Jeton d'identite conserve a la connexion : il designe la session Keycloak a fermer
  /// lors de la deconnexion ([seDeconnecterCompletement]).
  String? idToken;

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
          // Comme le site : mot de passe (ou code) exige a chaque connexion.
          promptValues: ['login'],
          // Developpement local uniquement (http://localhost) ; la production est en https.
          allowInsecureConnections: Configuration.issuer.startsWith('http://'),
        ),
      );
      accessToken = result.accessToken;
      idToken = result.idToken;
    } on Exception {
      // Annulation par l'utilisateur ou erreur de plateforme : non connecte.
      return false;
    }
    return accessToken != null;
  }

  /// Oublie les jetons locaux (jeton expire, par exemple) sans fermer la session Keycloak.
  void seDeconnecter() {
    accessToken = null;
    idToken = null;
  }

  /// Deconnexion demandee par l'utilisateur : efface les jetons puis ferme la session Keycloak
  /// (fin de session OIDC avec l'idToken, retour sur `dz.tabibi.app:/oauthredirect`), pour que
  /// la prochaine connexion redemande le mot de passe. Les jetons sont effaces meme si la fin de
  /// session echoue (hors ligne, navigateur ferme).
  Future<void> seDeconnecterCompletement() async {
    final jeton = idToken;
    seDeconnecter();
    if (jeton == null) return;
    try {
      await finDeSession(jeton);
    } on Exception {
      // Session Keycloak non fermee : elle expirera d'elle-meme ; l'appli est deconnectee.
    }
  }

  /// Fin de session Keycloak (surchargeable dans les tests).
  Future<void> finDeSession(String jeton) async {
    await _appAuth.endSession(
      EndSessionRequest(
        idTokenHint: jeton,
        postLogoutRedirectUrl: Configuration.redirect,
        issuer: Configuration.issuer,
        allowInsecureConnections: Configuration.issuer.startsWith('http://'),
      ),
    );
  }
}
