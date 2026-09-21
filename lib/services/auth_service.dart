import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/connexion_page.dart';
import '../utils/jetons.dart';
import 'supabase_service.dart';

/// Session de l'application, adossee a **Supabase Auth**.
///
/// Historiquement branchee sur Keycloak, elle lit desormais la session Supabase
/// (ouverte par [ConnexionPage] : e-mail ou telephone + code). L'interface est
/// conservee (`estConnecte`, `accessToken`, `sujet`, `seConnecter`, `seDeconnecter`)
/// pour que les ecrans n'aient rien a changer.
///
/// [accessToken] reste assignable : les tests peuvent simuler une session en posant un
/// jeton, sans dependre de Supabase. En fonctionnement reel, la session Supabase prime.
class AuthService {
  /// Jeton pose manuellement (tests). En production il reste nul : c'est la session
  /// Supabase qui fait foi.
  String? _jetonManuel;

  /// Jeton d'acces courant : celui de la session Supabase s'il y en a une, sinon le
  /// jeton pose manuellement (tests).
  String? get accessToken => sb.auth.currentSession?.accessToken ?? _jetonManuel;

  set accessToken(String? valeur) => _jetonManuel = valeur;

  /// Vrai si une session est ouverte (Supabase, ou jeton de test pose).
  bool get estConnecte => accessToken != null;

  /// Identifiant de l'utilisateur connecte : l'`id` Supabase, sinon le sujet du jeton
  /// de test. Sert notamment a reconnaitre ses propres messages.
  String? get sujet => sb.auth.currentUser?.id ?? sujetDuJeton(_jetonManuel);

  /// Ouvre l'ecran de connexion Supabase ([ConnexionPage]) et renvoie vrai si une session
  /// est ouverte au retour. Utilise le navigateur global de l'application.
  Future<bool> seConnecter() async {
    final navigateur = navigatorCle.currentState;
    if (navigateur == null) return estConnecte;
    await navigateur.push(
      MaterialPageRoute<bool>(builder: (_) => const ConnexionPage()),
    );
    return estConnecte;
  }

  /// Ferme la session (Supabase + jeton de test).
  void seDeconnecter() {
    _jetonManuel = null;
    sb.auth.signOut();
  }
}
