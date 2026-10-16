import 'dart:typed_data';

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

  /// Statistiques detaillees du praticien (6 mois, revenus, presence, patients).
  Future<Map<String, dynamic>> statsDetaillees() async {
    final r = await sb.rpc('medecin_stats_detaillees');
    return (r as Map).cast<String, dynamic>();
  }

  /// Champs utiles a l'ecran de verification (n° d'Ordre, statut, complétude).
  Future<Map<String, dynamic>?> profilVerification() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return null;
    final r = await sb
        .from('doctor_profiles')
        .select('ordre_number, validation_status, is_verified, ordre_card_path, bio, photo_url, consultation_fee_dzd, working_hours, full_name')
        .eq('user_id', uid)
        .maybeSingle();
    return r == null ? null : (r as Map).cast<String, dynamic>();
  }

  /// Enregistre le numero d'Ordre (retourne 'ok' / 'invalid_format' / ...).
  Future<String> setNumeroOrdre(String ordre) async {
    final r = await sb.rpc('doctor_set_ordre_number', params: {'p_ordre': ordre});
    return r?.toString() ?? '';
  }

  /// Televerse un document (carte d'Ordre / diplome) dans le bucket doctor-docs.
  Future<void> uploaderDocOrdre(Uint8List bytes, String ext) async {
    final uid = sb.auth.currentUser!.id;
    final chemin = '$uid/ordre_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await sb.storage.from('doctor-docs').uploadBinary(
          chemin,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
  }

  /// Demande la verification du profil (passe en 'pending').
  Future<String> demanderVerification() async {
    final r = await sb.rpc('demander_verification_medecin');
    return r?.toString() ?? '';
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
        'wilayaCode': v['wilaya_code'],
        'latitude': v['latitude'],
        'longitude': v['longitude'],
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

  /// Enregistre la localisation du cabinet (adresse, ville, wilaya, coordonnees GPS).
  /// Les champs null gardent leur valeur actuelle (COALESCE cote base).
  Future<Map<String, dynamic>?> enregistrerLocalisation({
    String? address,
    String? ville,
    int? wilayaCode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await sb.rpc('update_my_cabinet_location', params: {
        'p_address': address,
        'p_city': ville,
        'p_wilaya_code': wilayaCode,
        'p_latitude': latitude,
        'p_longitude': longitude,
      });
      return monProfil();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Liste des wilayas (code + nom FR) pour le selecteur de localisation.
  Future<List<Map<String, dynamic>>> listerWilayas() async {
    try {
      final r = await sb.from('wilayas').select('code, name_fr').order('code', ascending: true);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{'code': m['code'], 'nom': m['name_fr']};
      }).toList();
    } on PostgrestException catch (_) {
      return const [];
    }
  }

  /// Rendez-vous recus par le praticien (RLS : uniquement les siens), les plus recents
  /// d'abord, avec le nom du patient : {id, patientId, patientNom, debut, statut, motif,
  /// consultType, dureeMinutes}.
  Future<List<Map<String, dynamic>>> rdvRecus() async {
    try {
      final pid = await sb.rpc('current_doctor_profile_id');
      if (pid == null) return const [];
      final r = await sb
          .from('appointments')
          .select('id, patient_id, scheduled_at, status, reason, consult_type, duration_minutes, prix')
          .eq('doctor_id', pid)
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
          'prix': m['prix'],
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

  // ---------------------------------------------------------------------------
  // Patients (agreges depuis les rendez-vous)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> mesPatients() async {
    final rdvs = await rdvRecus();
    final parPatient = <String, Map<String, dynamic>>{};
    for (final r in rdvs) {
      final pid = '${r['patientId'] ?? ''}';
      if (pid.isEmpty) continue;
      final e = parPatient.putIfAbsent(pid, () => <String, dynamic>{
            'patientId': r['patientId'],
            'nom': r['patientNom'],
            'nbRdv': 0,
            'dernierRdv': null,
          });
      e['nbRdv'] = (e['nbRdv'] as int) + 1;
      final d = r['debut'];
      if (e['dernierRdv'] == null || '$d'.compareTo('${e['dernierRdv']}') > 0) {
        e['dernierRdv'] = d;
      }
    }
    final list = parPatient.values.toList();
    list.sort((a, b) => '${b['dernierRdv']}'.compareTo('${a['dernierRdv']}'));
    return list;
  }

  /// Dossier medical d'un patient (accessible uniquement si le medecin a un RDV
  /// avec ce patient). Renvoie null si aucune donnee saisie.
  Future<Map<String, dynamic>?> dossierPatient(String patientId) async {
    try {
      final r = await sb.rpc('get_patient_medical_data_for_doctor', params: {'p_patient_id': patientId});
      final row = r is List ? (r.isEmpty ? null : r.first as Map) : (r as Map?);
      if (row == null) return null;
      return <String, dynamic>{
        'groupeSanguin': row['blood_type'],
        'tailleCm': row['height_cm'],
        'poidsKg': row['weight_kg'],
        'allergies': row['allergies'],
        'antecedents': row['medical_history'],
        'traitements': row['current_medications'],
        'antecedentsFamiliaux': row['family_history'],
        'vaccinations': row['vaccinations'],
        'fumeur': row['smoker'],
        'buveur': row['drinker'],
        'assurance': row['insurance'],
        'mutuelle': row['mutual'],
        'urgenceNom': row['emergency_name'],
        'urgenceLien': row['emergency_relation'],
        'urgenceTel': row['emergency_phone'],
        'majLe': row['updated_at'],
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Messagerie (cote medecin : conversations ou doctor_user_id = moi)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> mesConversations() async {
    try {
      final r = await sb
          .from('conversations')
          .select('id, patient_id, doctor_id, created_at, last_message_at')
          .eq('doctor_user_id', _uid)
          .order('last_message_at', ascending: false);
      final lignes = (r as List).cast<Map>();
      final noms = await _nomsPatients(
          lignes.map((m) => '${m['patient_id']}').where((x) => x.isNotEmpty).toSet());
      return lignes.map((m) {
        final pid = '${m['patient_id']}';
        return <String, dynamic>{
          'id': m['id'],
          'patientId': m['patient_id'],
          'patientNom': noms[pid],
          'creeLe': m['created_at'],
          'dernierMessageLe': m['last_message_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    try {
      final r = await sb
          .from('messages')
          .select('id, conversation_id, sender_id, body, created_at, read_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      try {
        await sb
            .from('messages')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('conversation_id', conversationId)
            .neq('sender_id', _uid)
            .isFilter('read_at', null);
      } on PostgrestException catch (_) {}
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'auteurId': m['sender_id'],
          'contenu': m['body'],
          'envoyeLe': m['created_at'],
          'luLe': m['read_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<void> envoyerMessage(String conversationId, String contenu) async {
    try {
      await sb.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': _uid,
        'body': contenu,
      });
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  String get moiId => _uid;

  // ---------------------------------------------------------------------------
  // Ordonnances emises (prescriptions.doctor_id = mon compte)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> mesOrdonnances() async {
    try {
      final r = await sb
          .from('prescriptions')
          .select('id, patient_id, prescription_number, status, issue_date, created_at, medications, diagnosis')
          .eq('doctor_id', _uid)
          .order('created_at', ascending: false);
      final lignes = (r as List).cast<Map>();
      final noms = await _nomsPatients(
          lignes.map((m) => '${m['patient_id']}').where((x) => x.isNotEmpty).toSet());
      return lignes.map((m) {
        final meds = (m['medications'] as List?) ?? const [];
        return <String, dynamic>{
          'id': m['id'],
          'patientId': m['patient_id'],
          'patientNom': noms['${m['patient_id']}'],
          'numero': m['prescription_number'],
          'statut': m['status'],
          'diagnostic': m['diagnosis'],
          'emiseLe': m['issue_date'] ?? m['created_at'],
          'nbMedicaments': meds.length,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Cree une ordonnance (brouillon) pour un patient, puis demande la signature.
  /// medications = liste d'objets {name, dosage, duration, ...}.
  Future<String> creerOrdonnance({
    required String patientId,
    required List<Map<String, dynamic>> medications,
    String? diagnostic,
    String? notes,
    int validite = 30,
  }) async {
    try {
      final id = await sb.rpc('create_prescription_draft', params: {
        'p_patient_id': patientId,
        'p_appointment_id': null,
        'p_medications': medications,
        'p_diagnosis': diagnostic,
        'p_clinical_notes': notes,
        'p_validity_days': validite,
      });
      final pid = id is String ? id : '$id';
      try {
        await sb.rpc('request_prescription_signature', params: {'p_prescription_id': pid});
      } on PostgrestException catch (_) {}
      return pid;
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Avis recus (reviews.doctor_id = id de ma fiche)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> avisRecus() async {
    try {
      final pid = await sb.rpc('current_doctor_profile_id');
      if (pid == null) return const [];
      final r = await sb
          .from('reviews')
          .select('id, rating_overall, comment, status, created_at, doctor_reply, doctor_reply_at')
          .eq('doctor_id', pid)
          .order('created_at', ascending: false);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'note': m['rating_overall'],
          'commentaire': m['comment'],
          'statut': m['status'],
          'creeLe': m['created_at'],
          'reponse': m['doctor_reply'],
          'reponseLe': m['doctor_reply_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }


  /// Répond à un avis (ou efface la réponse si [reponse] est vide).
  Future<void> repondreAvis(String avisId, String reponse) async {
    try {
      await sb.rpc('repondre_avis', params: {'p_review_id': avisId, 'p_reply': reponse});
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications (table notifications : user_id = moi)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> notifications() async {
    try {
      final r = await sb
          .from('notifications')
          .select('id, type, title, message, data, created_at, read_at')
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .limit(100);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'type': m['type'],
          'titre': m['title'],
          'message': m['message'],
          'donnees': m['data'],
          'creeLe': m['created_at'],
          'luLe': m['read_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<int> nbNotificationsNonLues() async {
    try {
      final r = await sb
          .from('notifications')
          .select('id')
          .eq('user_id', _uid)
          .isFilter('read_at', null);
      return (r as List).length;
    } on PostgrestException catch (_) {
      return 0;
    }
  }

  Future<void> marquerNotificationLue(String id) async {
    try {
      await sb
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<void> toutMarquerLues() async {
    try {
      await sb
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', _uid)
          .isFilter('read_at', null);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Conges / absences (doctor_unavailable_slots : doctor_id = ma fiche)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> mesAbsences() async {
    try {
      final pid = await sb.rpc('current_doctor_profile_id');
      if (pid == null) return const [];
      final r = await sb
          .from('doctor_unavailable_slots')
          .select('id, starts_at, ends_at, reason, all_day')
          .eq('doctor_id', pid)
          .order('starts_at', ascending: false);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'debut': m['starts_at'],
          'fin': m['ends_at'],
          'motif': m['reason'],
          'journeeEntiere': m['all_day'] == true,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<void> ajouterAbsence({
    required DateTime debut,
    required DateTime fin,
    String? motif,
    bool journeeEntiere = false,
  }) async {
    try {
      final pid = await sb.rpc('current_doctor_profile_id');
      if (pid == null) {
        throw const ApiException(403, 'Fiche médecin introuvable', cle: 'api.ficheIntrouvable');
      }
      await sb.from('doctor_unavailable_slots').insert({
        'doctor_id': pid,
        'starts_at': debut.toUtc().toIso8601String(),
        'ends_at': fin.toUtc().toIso8601String(),
        'reason': (motif == null || motif.trim().isEmpty) ? null : motif.trim(),
        'all_day': journeeEntiere,
      });
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  Future<void> supprimerAbsence(String id) async {
    try {
      await sb.from('doctor_unavailable_slots').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Teleconsultation (video_sessions via RPC create_video_session)
  // ---------------------------------------------------------------------------
  /// Cree (ou recupere) la salle video d'un rendez-vous et renvoie l'URL + le jeton medecin.
  Future<Map<String, dynamic>> demarrerTeleconsultation(String appointmentId) async {
    try {
      final r = await sb.rpc('create_video_session', params: {'p_appointment_id': appointmentId});
      final m = (r is Map) ? r : <String, dynamic>{};
      return <String, dynamic>{
        'ok': m['ok'] == true,
        'erreur': m['error'],
        'sessionId': m['session_id'],
        'salleUrl': m['daily_room_url'],
        'salleNom': m['daily_room_name'],
        'statut': m['status'],
        'cree': m['created'] == true,
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Préférences de notification de l'utilisateur connecté (crée les valeurs par défaut si besoin).
  Future<Map<String, dynamic>> mesPreferencesNotifs() async {
    final r = await sb.rpc('mes_preferences_notifs');
    final Map? row = r is List ? (r.isEmpty ? null : r.first as Map) : r as Map?;
    return row == null ? <String, dynamic>{} : row.cast<String, dynamic>();
  }

  /// Met à jour les préférences de notification.
  Future<void> majPreferencesNotifs({
    required bool rdv,
    required bool messages,
    required bool avis,
    required bool rappels,
  }) async {
    await sb.rpc('maj_preferences_notifs', params: {
      'p_rdv': rdv,
      'p_messages': messages,
      'p_avis': avis,
      'p_rappels': rappels,
    });
  }

  /// Change le mot de passe du compte (Supabase Auth).
  Future<void> changerMotDePasse(String nouveau) async {
    await sb.auth.updateUser(UserAttributes(password: nouveau));
  }

  /// Change l'e-mail du compte ; Supabase envoie un e-mail de confirmation à la nouvelle adresse.
  Future<void> changerEmail(String nouveau) async {
    await sb.auth.updateUser(UserAttributes(email: nouveau));
  }

  /// Suppression du compte (RGPD) : désactive le compte côté application puis déconnecte.
  Future<void> supprimerMonCompte() async {
    await sb.rpc('supprimer_mon_compte');
    await sb.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Cabinet & secrétariat
  // ---------------------------------------------------------------------------

  /// Cabinets dont je suis membre (avec mon rôle et le nombre de membres).
  Future<List<Map<String, dynamic>>> mesCabinets() async {
    final r = await sb.rpc('get_my_cabinets');
    return (r as List? ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Crée un cabinet et m'en désigne propriétaire.
  Future<Map<String, dynamic>> creerCabinet({
    required String nom,
    String? formeJuridique,
    String? wilaya,
    String? commune,
    String? adresse,
    String? telephone,
    String? email,
    String? rc,
    String? nif,
    String tier = 'solo',
  }) async {
    final r = await sb.rpc('create_cabinet', params: {
      'p_name': nom,
      'p_legal_form': formeJuridique,
      'p_wilaya': wilaya,
      'p_commune': commune,
      'p_address': adresse,
      'p_phone': telephone,
      'p_email': email,
      'p_rc_number': rc,
      'p_nif': nif,
      'p_subscription_tier': tier,
    });
    return (r as Map).cast<String, dynamic>();
  }

  /// Membres actifs d'un cabinet (annuaire filtré par la RLS).
  Future<List<Map<String, dynamic>>> membresCabinet(String cabinetId) async {
    final r = await sb
        .from('cabinet_members_directory_view')
        .select('membership_id, user_id, full_name, specialty_fr, role, accepted, created_at')
        .eq('cabinet_id', cabinetId)
        .order('created_at');
    return (r as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Retrouve un utilisateur par e-mail exact (pour l'invitation). Null si introuvable.
  Future<Map<String, dynamic>?> chercherUtilisateurParEmail(String email) async {
    final r = await sb.rpc('chercher_utilisateur_par_email', params: {'p_email': email});
    final list = r as List? ?? const [];
    if (list.isEmpty) return null;
    return (list.first as Map).cast<String, dynamic>();
  }

  /// Invite un utilisateur (déjà inscrit) comme membre du cabinet.
  Future<void> inviterMembre(String cabinetId, String userId, String role) async {
    await sb.rpc('invite_cabinet_member', params: {
      'p_cabinet_id': cabinetId,
      'p_target_user_id': userId,
      'p_role': role,
      'p_permissions': <String, dynamic>{},
    });
  }

  /// Retire un membre du cabinet.
  Future<void> retirerMembre(String cabinetId, String userId) async {
    await sb.rpc('remove_cabinet_member', params: {
      'p_cabinet_id': cabinetId,
      'p_user_id': userId,
    });
  }

  // ---------------------------------------------------------------------------
  // Aperçu de la fiche publique (ce que voient les patients) & modèles d'ordonnances
  // ---------------------------------------------------------------------------

  /// Fiche telle que la voient les patients (vue RGPD `public_doctors`).
  Future<Map<String, dynamic>?> apercuFichePublique() async {
    final pid = await sb.rpc('current_doctor_profile_id');
    if (pid == null) return null;
    final r = await sb
        .from('public_doctors')
        .select('full_name, specialty_fr, wilaya_fr, city, address, bio, '
            'consultation_fee_dzd, telehealth_enabled, telehealth_fee_dzd, '
            'accepts_card, accepts_chifa, accepts_cash, photo_url, rating, '
            'review_count, is_verified, languages')
        .eq('id', pid)
        .maybeSingle();
    return r == null ? null : (r as Map).cast<String, dynamic>();
  }

  /// Mes modèles d'ordonnances.
  Future<List<Map<String, dynamic>>> mesModelesOrdonnance() async {
    final r = await sb
        .from('prescription_templates')
        .select('id, name, medications, diagnostic, notes, created_at')
        .order('created_at', ascending: false);
    return (r as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Crée un modèle d'ordonnance.
  Future<void> creerModeleOrdonnance({
    required String nom,
    required List<Map<String, dynamic>> medications,
    String? diagnostic,
    String? notes,
  }) async {
    await sb.from('prescription_templates').insert({
      'name': nom,
      'medications': medications,
      'diagnostic': diagnostic,
      'notes': notes,
    });
  }

  /// Supprime un modèle d'ordonnance.
  Future<void> supprimerModeleOrdonnance(String id) async {
    await sb.from('prescription_templates').delete().eq('id', id);
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
