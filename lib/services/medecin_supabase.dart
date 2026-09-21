import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_service.dart';
import 'patient_supabase.dart';
import 'supabase_service.dart';

/// Acces direct aux donnees du praticien connecte via Supabase (RPC + tables, proteges par
/// la RLS : le medecin est le `doctor_profiles` dont `user_id = auth.uid()`).
///
/// Les rendez-vous sont deja filtres cote base (politique `appointments_select_doctor`) :
/// une simple lecture de `appointments` ne renvoie que ceux du medecin connecte.
class MedecinSupabase {
  const MedecinSupabase();

  String get _uid {
    final id = sb.auth.currentUser?.id;
    if (id == null) {
      throw const ApiException(401, 'Session requise', cle: 'api.connexionRequise');
    }
    return id;
  }

  /// Vrai si le compte connecte est un praticien (il possede une fiche `doctor_profiles`).
  Future<bool> estMedecin() async {
    try {
      final id = await sb.rpc('current_doctor_profile_id');
      return id != null && '$id'.isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Fiche du praticien connecte (cles FR, comme la fiche patient) ; null si le compte n'est
  /// pas un praticien.
  Future<Map<String, dynamic>?> monProfil() async {
    try {
      final r = await sb.rpc('get_my_doctor_profile');
      final Map? row = r is List ? (r.isEmpty ? null : r.first as Map) : r as Map?;
      if (row == null) return null;
      return _map(row);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Map<String, dynamic> _map(Map v) => <String, dynamic>{
        'id': v['id'],
        'nomComplet': v['full_name'],
        'specialiteFr': v['specialty_fr'],
        'ville': v['city'],
        'wilayaFr': v['wilaya_fr'],
        'bio': v['bio'],
        'langues': v['languages'],
        'tarif': v['consultation_fee_dzd'],
        'teleTarif': v['telehealth_fee_dzd'],
        'accepteChifa': v['accepts_chifa'],
        'accepteCarte': v['accepts_card'],
        'accepteEspeces': v['accepts_cash'],
        'teleconsultation': v['telehealth_enabled'],
        'photo': v['photo_url'],
        'phone': v['phone'],
        'address': v['address'],
        'note': v['rating'],
        'nombreAvis': v['review_count'],
        'verifie': v['is_verified'],
        'horaires': v['working_hours'],
      };

  /// Met a jour la fiche du praticien (RPC `update_my_doctor_profile`) et renvoie la fiche
  /// mise a jour. Toutes les valeurs sont transmises (celles non modifiees gardent leur
  /// valeur courante).
  Future<Map<String, dynamic>?> enregistrerProfil({
    String? bio,
    List<String>? langues,
    int? tarif,
    int? teleTarif,
    bool? accepteChifa,
    bool? accepteCarte,
    bool? accepteEspeces,
    bool? teleconsultation,
    String? photo,
    String? phone,
    String? address,
  }) async {
    try {
      await sb.rpc('update_my_doctor_profile', params: {
        'p_bio': bio,
        'p_languages': langues,
        'p_consultation_fee': tarif,
        'p_accepts_chifa': accepteChifa,
        'p_accepts_card': accepteCarte,
        'p_accepts_cash': accepteEspeces,
        'p_working_hours': null,
        'p_telehealth_enabled': teleconsultation,
        'p_telehealth_fee': teleTarif,
        'p_photo_url': photo,
        'p_phone': phone,
        'p_address': address,
      });
      return monProfil();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Enregistre uniquement les horaires (working_hours), sans toucher au reste.
  Future<void> enregistrerHoraires(Map<String, dynamic> horaires) async {
    try {
      await sb.rpc('update_my_doctor_profile', params: {'p_working_hours': horaires});
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Rendez-vous recus par le praticien (RLS : uniquement les siens), les plus recents
  /// d'abord, avec le nom du patient : {id, patientId, patientNom, debut, statut, motif,
  /// consultType, dureeMinutes}.
  Future<List<Map<String, dynamic>>> rdvRecus() async {
    try {
      final r = await sb
          .from('appointments')
          .select('id, patient_id, scheduled_at, status, reason, consult_type, duration_minutes')
          .order('scheduled_at', ascending: false);
      final lignes = (r as List).cast<Map>();
      final noms = await _nomsPatients(
        lignes.map((m) => '${m['patient_id']}').where((s) => s.isNotEmpty).toSet(),
      );
      return lignes.map((m) {
        final pid = '${m['patient_id']}';
        return <String, dynamic>{
          'id': m['id'],
          'patientId': m['patient_id'],
          'patientNom': noms[pid],
          'debut': m['scheduled_at'],
          'statut': PatientSupabase.statutRdv(m['status']),
          'motif': m['reason'],
          'consultType': m['consult_type'],
          'dureeMinutes': m['duration_minutes'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<Map<String, String>> _nomsPatients(Set<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final r = await sb
          .from('users')
          .select('id, full_name, first_name, last_name')
          .inFilter('id', ids.toList());
      final noms = <String, String>{};
      for (final e in (r as List).cast<Map>()) {
        final nom = _nomComplet(e);
        if (nom != null) noms['${e['id']}'] = nom;
      }
      return noms;
    } on PostgrestException catch (_) {
      return {};
    }
  }

  /// Confirme un rendez-vous en attente.
  Future<void> confirmer(String rdvId) => _statut(rdvId, 'confirmed');

  /// Marque un rendez-vous honore (consultation effectuee).
  Future<void> terminer(String rdvId) => _statut(rdvId, 'completed');

  /// Marque un patient absent (no-show).
  Future<void> marquerAbsent(String rdvId) => _statut(rdvId, 'no_show');

  /// Annule un rendez-vous (cote medecin).
  Future<void> annuler(String rdvId) async {
    try {
      await sb.from('appointments').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        'cancelled_by_user_id': _uid,
        'cancellation_reason': 'Annulé par le médecin',
      }).eq('id', rdvId);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<void> _statut(String rdvId, String statut) async {
    try {
      await sb.from('appointments').update({'status': statut}).eq('id', rdvId);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  String? _nomComplet(Map m) {
    final full = (m['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final prenom = (m['first_name'] as String?)?.trim() ?? '';
    final nom = (m['last_name'] as String?)?.trim() ?? '';
    final assemble = '$prenom $nom'.trim();
    return assemble.isEmpty ? null : assemble;
  }

  ApiException _erreur(PostgrestException e) {
    final statut = switch (e.code) {
      '23505' => 409,
      '42501' => 403,
      'PGRST116' => 404,
      _ => 400,
    };
    return ApiException(statut, e.message);
  }
}
