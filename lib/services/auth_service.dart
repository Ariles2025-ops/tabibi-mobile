import 'dart:async';
import 'dart:io';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/configuration.dart';
import '../utils/jetons.dart';

/// Stockage persistant des jetons (surchargeable dans les tests).
abstract class StockageJetons {
  Future<String?> lire(String cle);
  Future<void> ecrire(String cle, String? valeur);
  Future<void> effacerTout();
}

/// Stockage chiffre du systeme (Keystore Android / Keychain iOS).
class StockageSecurise implements StockageJetons {
  const StockageSecurise();
  static const FlutterSecureStorage _s = FlutterSecureStorage();

  @override
  Future<String?> lire(String cle) => _s.read(key: cle);

  @override
  Future<void> ecrire(String cle, String? valeur) =>
      valeur == null ? _s.delete(key: cle) : _s.write(key: cle, value: valeur);

  @override
  Future<void> effacerTout() => _s.deleteAll();
}

/// Authentification OIDC contre le realm Keycloak « tabibi ».
///
/// Une seule instance est partagee par toute l'application (voir `session.dart`)
/// afin de conserver le jeton d'un ecran a l'autre. L'emetteur, le client et l'URI de
/// redirection viennent de la configuration par environnement ([Configuration],
/// `--dart-define=TABIBI_ISSUER=...`).
class AuthService {
  AuthService({StockageJetons? stockage, DateTime Function()? maintenant})
      : _stockage = stockage ?? const StockageSecurise(),
        _maintenant = maintenant ?? DateTime.now;

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final StockageJetons _stockage;
  final DateTime Function() _maintenant;

  /// Marge avant l'expiration a partir de laquelle le jeton est rafraichi.
  static const Duration marge = Duration(seconds: 30);

  /// Perimetre demande : `offline_access` donne un refresh token hors ligne, qui ne meurt pas
  /// apres 30 min d'inactivite (ssoSessionIdleTimeout) comme un jeton de session ordinaire.
  static const List<String> scopes = ['openid', 'profile', 'offline_access'];

  String? accessToken;
  String? _refreshToken;
  DateTime? _expiration;
  Timer? _minuteur;
  Future<bool>? _rafraichissement;
  bool _echecReseau = false;

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
          scopes: scopes,
          // Comme le site : mot de passe (ou code) exige a chaque connexion.
          promptValues: ['login'],
          // Developpement local uniquement (http://localhost) ; la production est en https.
          allowInsecureConnections: Configuration.issuer.startsWith('http://'),
        ),
      );
      await _adopter(result.accessToken, result.refreshToken, result.idToken,
          result.accessTokenExpirationDateTime);
    } on Exception {
      // Annulation par l'utilisateur ou erreur de plateforme : non connecte.
      return false;
    }
    return accessToken != null;
  }

  /// Retient (en memoire et dans le stockage chiffre) les jetons recus et programme leur
  /// rafraichissement. Un jeton absent de la reponse conserve l'ancienne valeur.
  Future<void> _adopter(
      String? acces, String? refresh, String? identite, DateTime? expiration) async {
    accessToken = acces;
    _refreshToken = refresh ?? _refreshToken;
    idToken = identite ?? idToken;
    _expiration = expiration;
    _programmer();
    try {
      await _stockage.ecrire('access_token', accessToken);
      await _stockage.ecrire('refresh_token', _refreshToken);
      await _stockage.ecrire('id_token', idToken);
      await _stockage.ecrire('expiration', expiration?.millisecondsSinceEpoch.toString());
    } on Exception {
      // Stockage indisponible : la session reste valable tant que l'appli tourne.
    }
  }

  void _programmer() {
    _minuteur?.cancel();
    _minuteur = null;
    final fin = _expiration;
    if (fin == null || _refreshToken == null) return;
    var attente = fin.difference(_maintenant()) - marge;
    if (attente < Duration.zero) attente = Duration.zero;
    _minuteur = Timer(attente, () => rafraichir());
  }

  /// Restaure la session enregistree au demarrage : jeton encore valide, sinon rafraichi.
  /// Faux (sans effacer le stockage) si rien n'est enregistre ou si le rafraichissement est refuse ;
  /// sans reseau, les jetons sont conserves et la session reste ouverte (nouvel essai au premier appel).
  Future<bool> restaurer() async {
    try {
      accessToken = await _stockage.lire('access_token');
      _refreshToken = await _stockage.lire('refresh_token');
      idToken = await _stockage.lire('id_token');
      final ms = int.tryParse(await _stockage.lire('expiration') ?? '');
      _expiration = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } on Exception {
      return false;
    }
    final fin = _expiration;
    if (accessToken != null && fin != null && fin.isAfter(_maintenant().add(marge))) {
      _programmer();
      return true;
    }
    if (_refreshToken == null) {
      accessToken = null;
      return false;
    }
    final ok = await rafraichir();
    if (ok) return true;
    // Reseau absent (et non refus) : on garde les jetons ; le premier appel en 401 (ou un
    // prochain rafraichir) retentera l'echange. Seul un refus declare la session perdue.
    if (_echecReseau && accessToken != null) return true;
    if (!_echecReseau) accessToken = null;
    return false;
  }

  /// Obtient de nouveaux jetons avec le refresh token (un seul appel a la fois).
  /// Vrai si la session est renouvelee ; faux sinon (refresh absent, refuse ou reseau coupe).
  Future<bool> rafraichir() =>
      _rafraichissement ??= _rafraichirVraiment().whenComplete(() => _rafraichissement = null);

  Future<bool> _rafraichirVraiment() async {
    final refresh = _refreshToken;
    if (refresh == null) return false;
    _echecReseau = false;
    try {
      final r = await echangerRefreshToken(refresh);
      if (r == null || r.accessToken == null) return false;
      await _adopter(r.accessToken, r.refreshToken, r.idToken, r.accessTokenExpirationDateTime);
      return true;
    } on SocketException {
      _echecReseau = true;
      return false;
    } on TimeoutException {
      _echecReseau = true;
      return false;
    } on Exception {
      return false;
    }
  }

  /// Echange du refresh token contre de nouveaux jetons (surchargeable dans les tests).
  Future<TokenResponse?> echangerRefreshToken(String refresh) => _appAuth.token(
        TokenRequest(
          Configuration.clientId,
          Configuration.redirect,
          issuer: Configuration.issuer,
          refreshToken: refresh,
          scopes: scopes,
          allowInsecureConnections: Configuration.issuer.startsWith('http://'),
        ),
      );

  /// Reaction a un 401 : renvoie un jeton frais pour rejouer l'appel une seule fois, ou null
  /// (session perdue : l'appelant se deconnecte). Si un autre appel a deja rafraichi le jeton
  /// ([ancien] differe du jeton courant), le jeton courant est renvoye sans nouvel echange.
  Future<String?> jetonApres401(String ancien) async {
    if (accessToken != null && accessToken != ancien) return accessToken;
    return await rafraichir() ? accessToken : null;
  }

  /// Oublie les jetons locaux (jeton expire, par exemple) sans fermer la session Keycloak.
  void seDeconnecter() {
    accessToken = null;
    idToken = null;
    _refreshToken = null;
    _expiration = null;
    _minuteur?.cancel();
    _minuteur = null;
    // Efface aussi le stockage : une session perdue ne doit pas revenir au prochain demarrage.
    unawaited(_stockage.effacerTout().catchError((Object _) {}));
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
