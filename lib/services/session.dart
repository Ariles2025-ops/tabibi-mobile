import 'auth_service.dart';

/// Session partagee par toutes les pages : une seule instance d'[AuthService],
/// pour que le jeton obtenu sur un ecran reste disponible sur les autres.
///
/// Les pages acceptent aussi un [AuthService] injecte (tests), sinon elles
/// utilisent cette instance.
final AuthService session = AuthService();
