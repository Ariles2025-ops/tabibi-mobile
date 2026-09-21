import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_service.dart';
import 'supabase_service.dart';

/// Acces aux fonctions d'administration (RPC protegees par `is_admin()` cote base :
/// seul un compte role='admin' peut les executer).
class AdminSupabase {
  const AdminSupabase();

  Future<bool> estAdmin() async {
    try {
      final r = await sb.rpc('is_admin');
      return r == true;
    } on Object {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Tableau de bord
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> stats() async {
    try {
      final r = await sb.rpc('admin_stats');
      final m = (r is List && r.isNotEmpty) ? r.first as Map : (r as Map? ?? const {});
      return <String, dynamic>{
        'patients': m['patients'] ?? 0,
        'medecinsActifs': m['medecins_actifs'] ?? 0,
        'medecinsAttente': m['medecins_attente'] ?? 0,
        'rdv': m['rdv'] ?? 0,
        'candidatures': m['candidatures'] ?? 0,
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Medecins en attente
  // ---------------------------------------------------------------------------
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

  Future<void> validerMedecin(String email) => _rpcVide('admin_valider_medecin', {'p_email': email});

  // ---------------------------------------------------------------------------
  // Utilisateurs
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> listerUtilisateurs({String? role, String? q, int limite = 50}) async {
    try {
      final r = await sb.rpc('admin_lister_utilisateurs', params: {'p_role': role, 'p_query': q, 'p_limit': limite});
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'email': m['email'],
          'nom': m['nom'],
          'role': m['role'],
          'actif': m['actif'],
          'estMedecin': m['est_medecin'],
          'creeLe': m['cree_le'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

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

  Future<void> activerCompte(String email) => _rpcVide('admin_activer_compte', {'p_email': email});
  Future<void> desactiverCompte(String email) => _rpcVide('admin_desactiver_compte', {'p_email': email});
  Future<void> supprimerCompte(String email) => _rpcVide('admin_supprimer_compte', {'p_email': email});

  // ---------------------------------------------------------------------------
  // Rendez-vous
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> listerRdv({int limite = 50}) async {
    try {
      final r = await sb.rpc('admin_lister_rdv', params: {'p_limit': limite});
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'patientNom': m['patient_nom'],
          'medecinNom': m['medecin_nom'],
          'debut': m['debut'],
          'statut': m['statut'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Moderation des avis
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> avisAModerer({int limite = 50}) async {
    try {
      final r = await sb.rpc('admin_avis_a_moderer', params: {'p_limit': limite});
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'note': m['note'],
          'commentaire': m['commentaire'],
          'statut': m['statut'],
          'signalements': m['signalements'],
          'medecinNom': m['medecin_nom'],
          'creeLe': m['cree_le'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<void> publierAvis(String id) => _rpcVide('admin_moderer_avis', {'p_id': id, 'p_action': 'publier'});
  Future<void> rejeterAvis(String id) => _rpcVide('admin_moderer_avis', {'p_id': id, 'p_action': 'rejeter'});

  // ---------------------------------------------------------------------------
  // Dawini
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> dawiniStats() async {
    try {
      final r = await sb.rpc('admin_dawini_stats');
      final m = (r is List && r.isNotEmpty) ? r.first as Map : (r as Map? ?? const {});
      return <String, dynamic>{'demandes': m['demandes'] ?? 0, 'pharmacies': m['pharmacies'] ?? 0};
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<List<Map<String, dynamic>>> listerDawini({int limite = 50}) async {
    try {
      final r = await sb.rpc('admin_lister_dawini', params: {'p_limit': limite});
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'medicaments': m['medicaments'],
          'wilaya': m['wilaya'],
          'statut': m['statut'],
          'nbReponses': m['nb_reponses'],
          'creeLe': m['cree_le'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Cabinets & membres
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> listerCabinets({int limite = 50}) async {
    try {
      final r = await sb.rpc('admin_lister_cabinets', params: {'p_limit': limite});
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'nom': m['nom'],
          'wilaya': m['wilaya'],
          'commune': m['commune'],
          'phone': m['phone'],
          'nbMembres': m['nb_membres'],
          'creeLe': m['cree_le'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<List<Map<String, dynamic>>> membresCabinet(String cabinetId) async {
    try {
      final r = await sb.rpc('admin_lister_membres_cabinet', params: {'p_cabinet_id': cabinetId});
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'email': m['email'],
          'nom': m['nom'],
          'role': m['role'],
          'actif': m['actif'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<void> retirerMembreCabinet(String membreId) =>
      _rpcVide('admin_retirer_membre_cabinet', {'p_membre_id': membreId});

  // ---------------------------------------------------------------------------
  // Validation des fiches medecins (75k importees / reclamees)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fichesAValider(
      {String tab = 'pending', String? q, String? wilaya, int limite = 30, int offset = 0}) async {
    try {
      final r = await sb.rpc('admin_validation_list', params: {
        'p_tab': tab,
        'p_search': q,
        'p_wilaya': wilaya,
        'p_limit': limite,
        'p_offset': offset,
      });
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'nom': m['full_name'],
          'specialite': m['specialty_raw'],
          'wilayaCode': m['wilaya_code']?.toString(),
          'phone': m['phone'],
          'email': m['email'],
          'ordre': m['ordre_number'],
          'statut': m['validation_status'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<void> validerFiche(String doctorId) => _validerFiche(doctorId, 'validate', null);
  Future<void> rejeterFiche(String doctorId, String motif) => _validerFiche(doctorId, 'reject', motif);

  Future<void> _validerFiche(String doctorId, String action, String? notes) async {
    try {
      final r = await sb.rpc('admin_validate_doctor', params: {
        'p_doctor_id': doctorId,
        'p_action': action,
        if (notes != null) 'p_notes': notes,
      });
      if (r is Map && r['ok'] == true) return;
      final err = r is Map ? '${r['error'] ?? 'echec'}' : 'echec';
      throw ApiException(400, err);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  Future<void> _rpcVide(String fn, Map<String, dynamic> params) async {
    try {
      await sb.rpc(fn, params: params);
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
