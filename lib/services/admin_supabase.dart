import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_service.dart';
import 'supabase_service.dart';

/// Acces aux fonctions d'administration (RPC protegees par `is_admin()` cote base :
/// seul un compte role='admin' peut les executer).
class AdminSupabase {
  const AdminSupabase();

  /// Vrai si le compte connecte est administrateur.
  Future<bool> estAdmin() async {
    try {
      final r = await sb.rpc('is_admin');
      return r == true;
    } on Object {
      return false;
    }
  }

  /// Medecins en attente de validation : {email, nom, telephone, specialite, wilaya, creeLe}.
  Future<List<Map<String, dynamic>>> medecinsEnAttente() async {
    try {
      final r = await sb.rpc('admin_medecins_en_attente');
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'email': m['email'],
          'nom': m['nom'],
          'telephone': m['telephone'],
          'specialite': m['specialite'],
          'wilaya': m['wilaya'],
          'creeLe': m['cree_le'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Valide un medecin par e-mail (cree sa fiche + active le compte).
  Future<void> validerMedecin(String email) async {
    try {
      await sb.rpc('admin_valider_medecin', params: {'p_email': email});
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Recherche un compte par e-mail : {email, nom, role, statut, actif, estMedecin, creeLe} ;
  /// null s'il n'existe pas.
  Future<Map<String, dynamic>?> rechercherCompte(String email) async {
    try {
      final r = await sb.rpc('admin_rechercher_compte', params: {'p_email': email});
      final liste = (r as List?) ?? const [];
      if (liste.isEmpty) return null;
      final m = liste.first as Map;
      return <String, dynamic>{
        'email': m['email'],
        'nom': m['nom'],
        'role': m['role'],
        'statut': m['statut'],
        'actif': m['actif'],
        'estMedecin': m['est_medecin'],
        'creeLe': m['cree_le'],
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Active un compte par e-mail (et confirme son e-mail cote auth).
  Future<void> activerCompte(String email) async {
    try {
      await sb.rpc('admin_activer_compte', params: {'p_email': email});
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Supprime un compte par e-mail (delie la fiche, supprime le profil et le compte auth).
  Future<void> supprimerCompte(String email) async {
    try {
      await sb.rpc('admin_supprimer_compte', params: {'p_email': email});
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  ApiException _erreur(PostgrestException e) {
    final statut = switch (e.code) {
      '42501' => 403,
      'P0001' => 400,
      _ => 400,
    };
    return ApiException(statut, e.message);
  }
}
