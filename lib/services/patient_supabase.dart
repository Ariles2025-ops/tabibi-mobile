import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_service.dart';
import 'supabase_service.dart';

/// Acces direct aux donnees du patient connecte via Supabase (tables + RPC, proteges
/// par la RLS : `auth.uid()` = identifiant du patient).
///
/// Les methodes reproduisent les formes de sortie de [ApiService] (cles en francais) afin
/// que les ecrans n'aient a changer que la source des donnees, pas leur affichage. Aucun
/// jeton n'est requis : le client Supabase porte la session.
class PatientSupabase {
  const PatientSupabase();

  String get _uid {
    final id = sb.auth.currentUser?.id;
    if (id == null) {
      throw const ApiException(401, 'Session requise', cle: 'api.connexionRequise');
    }
    return id;
  }

  /// Traduit un statut de rendez-vous Supabase (anglais) vers le jeton attendu par l'UI
  /// (majuscules francaises : CONFIRME, EN_ATTENTE, HONORE, ANNULE, ABSENT).
  static String statutRdv(Object? s) => switch (s?.toString()) {
        'pending' => 'EN_ATTENTE',
        'confirmed' => 'CONFIRME',
        'completed' => 'HONORE',
        'cancelled' => 'ANNULE',
        'no_show' => 'ABSENT',
        _ => (s?.toString() ?? '').toUpperCase(),
      };

  // ---------------------------------------------------------------------------
  // Rendez-vous
  // ---------------------------------------------------------------------------

  /// Rendez-vous du patient connecte, les plus recents d'abord :
  /// {id, medecinId, debut (ISO 8601), statut}.
  Future<List<Map<String, dynamic>>> mesRendezVous() async {
    try {
      final r = await sb
          .from('appointments')
          .select('id, doctor_id, scheduled_at, status, consult_type, pay_method, prix')
          .eq('patient_id', _uid)
          .order('scheduled_at', ascending: false);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'medecinId': m['doctor_id'],
          'debut': m['scheduled_at'],
          'statut': statutRdv(m['status']),
          'consultType': m['consult_type'],
          'payMethod': m['pay_method'],
          'prix': m['prix'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Annule un rendez-vous du patient (statut -> cancelled). La RLS n'autorise que les
  /// rendez-vous encore en attente ou confirmes.
  Future<void> annuler(String rdvId) async {
    try {
      await sb.from('appointments').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        'cancelled_by_user_id': _uid,
        'cancellation_reason': 'Annulé par le patient',
      }).eq('id', rdvId);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Avis
  // ---------------------------------------------------------------------------

  /// Avis deposes par le patient : {id, rendezVousId, medecinId, note, commentaire,
  /// statut, deposeLe}.
  Future<List<Map<String, dynamic>>> mesAvis() async {
    try {
      final r = await sb
          .from('reviews')
          .select('id, appointment_id, doctor_id, rating_overall, comment, status, created_at')
          .eq('patient_id', _uid)
          .order('created_at', ascending: false);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'rendezVousId': m['appointment_id'],
          'medecinId': m['doctor_id'],
          'note': m['rating_overall'],
          'commentaire': m['comment'],
          'statut': (m['status']?.toString() ?? '').toUpperCase(),
          'deposeLe': m['created_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Depose un avis sur un rendez-vous honore. Le medecin est retrouve depuis le
  /// rendez-vous ; la RLS exige un rendez-vous honore avec ce medecin.
  Future<void> deposerAvis(String rendezVousId, int note, String? commentaire) async {
    try {
      final app = await sb
          .from('appointments')
          .select('doctor_id')
          .eq('id', rendezVousId)
          .maybeSingle();
      final doctorId = app?['doctor_id'];
      if (doctorId == null) {
        throw const ApiException(404, 'Rendez-vous introuvable', cle: 'api.introuvable');
      }
      await sb.from('reviews').insert({
        'patient_id': _uid,
        'doctor_id': doctorId,
        'appointment_id': rendezVousId,
        'rating_overall': note,
        if (commentaire != null && commentaire.isNotEmpty) 'comment': commentaire,
        'status': 'pending',
      });
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Notifications du patient, les plus recentes d'abord : {id, destinataireId, canal,
  /// sujet, message, lue, creeLe}.
  Future<List<Map<String, dynamic>>> mesNotifications() async {
    try {
      final r = await sb
          .from('notifications')
          .select('id, user_id, type, title, message, read_at, created_at')
          .eq('user_id', _uid)
          .order('created_at', ascending: false);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'destinataireId': m['user_id'],
          'canal': m['type'],
          'sujet': m['title'],
          'message': m['message'],
          'lue': m['read_at'] != null,
          'creeLe': m['created_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Nombre de notifications non lues.
  Future<int> nombreNonLues() async {
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

  /// Marque une notification lue et renvoie la notification mise a jour (memes cles que
  /// [mesNotifications]).
  Future<Map<String, dynamic>> marquerLue(String notificationId) async {
    try {
      final row = await sb
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId)
          .select('id, user_id, type, title, message, read_at, created_at')
          .single();
      final m = row as Map;
      return <String, dynamic>{
        'id': m['id'],
        'destinataireId': m['user_id'],
        'canal': m['type'],
        'sujet': m['title'],
        'message': m['message'],
        'lue': m['read_at'] != null,
        'creeLe': m['created_at'],
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Marque lues toutes les notifications du patient ; renvoie le nombre traite.
  Future<int> toutMarquerLu() async {
    try {
      final r = await sb
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', _uid)
          .isFilter('read_at', null)
          .select('id');
      return (r as List).length;
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Messagerie
  // ---------------------------------------------------------------------------

  /// Conversations du patient, activite la plus recente d'abord : {id, patientId,
  /// medecinId, creeLe, dernierMessageLe, nonLus}.
  Future<List<Map<String, dynamic>>> mesConversations() async {
    try {
      final r = await sb
          .from('conversations')
          .select('id, patient_id, doctor_id, created_at, last_message_at')
          .eq('patient_id', _uid)
          .order('last_message_at', ascending: false);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'patientId': m['patient_id'],
          'medecinId': m['doctor_id'],
          'creeLe': m['created_at'],
          'dernierMessageLe': m['last_message_at'],
          'nonLus': 0,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Ouvre (ou retrouve) la conversation avec un praticien via `ensure_conversation`.
  Future<Map<String, dynamic>> ouvrirConversation(String medecinId) async {
    try {
      final id = await sb.rpc('ensure_conversation', params: {'p_doctor_id': medecinId});
      final convId = id is Map ? id['id'] : id;
      final row = await sb
          .from('conversations')
          .select('id, patient_id, doctor_id, created_at, last_message_at')
          .eq('id', convId)
          .single();
      final m = row as Map;
      return <String, dynamic>{
        'id': m['id'],
        'patientId': m['patient_id'],
        'medecinId': m['doctor_id'],
        'creeLe': m['created_at'],
        'dernierMessageLe': m['last_message_at'],
        'nonLus': 0,
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Messages d'une conversation, du plus ancien au plus recent ; marque au passage lus
  /// les messages recus. {id, conversationId, auteurId, contenu, envoyeLe, luLe}.
  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    try {
      final r = await sb
          .from('messages')
          .select('id, conversation_id, sender_id, body, created_at, read_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      // Marque lus les messages recus (envoyes par l'autre participant).
      try {
        await sb
            .from('messages')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('conversation_id', conversationId)
            .neq('sender_id', _uid)
            .isFilter('read_at', null);
      } on PostgrestException catch (_) {
        // Marquage best-effort : un echec n'empeche pas l'affichage.
      }
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'conversationId': m['conversation_id'],
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

  /// Envoie un message et renvoie le message cree.
  Future<Map<String, dynamic>> envoyerMessage(String conversationId, String contenu) async {
    try {
      final row = await sb.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': _uid,
        'body': contenu,
      }).select('id, conversation_id, sender_id, body, created_at, read_at').single();
      final m = row as Map;
      return <String, dynamic>{
        'id': m['id'],
        'conversationId': m['conversation_id'],
        'auteurId': m['sender_id'],
        'contenu': m['body'],
        'envoyeLe': m['created_at'],
        'luLe': m['read_at'],
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Profil
  // ---------------------------------------------------------------------------

  /// Identite de l'utilisateur connecte : {id, email, nomComplet, role}.
  Future<Map<String, dynamic>> moi() async {
    try {
      final row = await sb
          .from('users')
          .select('id, email, full_name, first_name, last_name, role')
          .eq('id', _uid)
          .maybeSingle();
      final m = (row as Map?) ?? const {};
      return <String, dynamic>{
        'id': m['id'] ?? _uid,
        'email': m['email'] ?? sb.auth.currentUser?.email,
        'nomComplet': _nomComplet(m),
        'role': m['role'],
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Profil du patient : {utilisateurId, nomComplet, telephone, dateNaissance, wilayaCode,
  /// langue, misAJourLe}. Carte vide si le profil n'a jamais ete renseigne.
  Future<Map<String, dynamic>> monProfil() async {
    try {
      final row = await sb
          .from('users')
          .select('id, full_name, first_name, last_name, phone, date_of_birth, wilaya_code, locale, updated_at')
          .eq('id', _uid)
          .maybeSingle();
      if (row == null) return <String, dynamic>{};
      final m = row as Map;
      return <String, dynamic>{
        'utilisateurId': m['id'],
        'nomComplet': _nomComplet(m),
        'telephone': m['phone'],
        'dateNaissance': m['date_of_birth'],
        'wilayaCode': m['wilaya_code']?.toString(),
        'langue': m['locale'],
        'misAJourLe': m['updated_at'],
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Enregistre le profil du patient (table users) et renvoie la vue mise a jour.
  Future<Map<String, dynamic>> enregistrerProfil(Map<String, dynamic> profil) async {
    try {
      final maj = <String, dynamic>{
        if (profil['nomComplet'] != null) 'full_name': profil['nomComplet'],
        if (profil['telephone'] != null) 'phone': profil['telephone'],
        'date_of_birth': profil['dateNaissance'],
        if (profil['wilayaCode'] != null && '${profil['wilayaCode']}'.isNotEmpty)
          'wilaya_code': int.tryParse('${profil['wilayaCode']}'),
        if (profil['langue'] != null) 'locale': profil['langue'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await sb.from('users').update(maj).eq('id', _uid);
      return monProfil();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Dawini (besoin en medicament)
  // ---------------------------------------------------------------------------

  /// Publie un besoin en medicament aupres des pharmacies (RPC dawini_create_request).
  Future<void> publierBesoin(
    String medicament,
    String wilayaCode, {
    String? precision,
  }) async {
    try {
      await sb.rpc('dawini_create_request', params: {
        'p_medicaments': [medicament],
        'p_wilaya': int.tryParse(wilayaCode) ?? 0,
        'p_image_path': null,
        'p_note': precision,
        'p_lat': null,
        'p_lng': null,
      });
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Besoins publies par le patient, les plus recents d'abord : {id, patientId, medicament,
  /// wilayaCode, statut, publieLe, nombreReponses}.
  Future<List<Map<String, dynamic>>> mesBesoins() async {
    try {
      final r = await sb
          .from('dawini_requests')
          .select('id, patient_id, medicaments, wilaya_code, status, created_at, note')
          .eq('patient_id', _uid)
          .order('created_at', ascending: false);
      return (r as List).map((e) {
        final m = e as Map;
        final meds = (m['medicaments'] as List?)?.cast<Object?>() ?? const [];
        return <String, dynamic>{
          'id': m['id'],
          'patientId': m['patient_id'],
          'medicament': meds.map((x) => '$x').join(', '),
          'wilayaCode': m['wilaya_code']?.toString(),
          'precision': m['note'],
          'statut': (m['status']?.toString() ?? '').toUpperCase(),
          'publieLe': m['created_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Cloture un besoin du patient.
  Future<void> cloturerBesoin(String besoinId) async {
    try {
      await sb.from('dawini_requests').update({'status': 'closed'}).eq('id', besoinId);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Reponses des pharmacies a un besoin : {id, besoinId, pharmacieId, disponible,
  /// generique, medicamentsDispo, commentaire, repondueLe}.
  Future<List<Map<String, dynamic>>> reponsesBesoin(String besoinId) async {
    try {
      final r = await sb
          .from('dawini_responses')
          .select('id, request_id, pharmacie_id, disponible, generique, medicaments_dispo, commentaire, created_at')
          .eq('request_id', besoinId)
          .order('created_at', ascending: false);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'besoinId': m['request_id'],
          'pharmacieId': m['pharmacie_id'],
          'disponible': m['disponible'],
          'generique': m['generique'],
          'commentaire': m['commentaire'],
          'repondueLe': m['created_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }


  // ---------------------------------------------------------------------------
  // Ordonnances
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _mapOrdonnance(Map m) {
    final meds = (m['medications'] as List?) ?? const [];
    return <String, dynamic>{
      'id': m['id'],
      'medecinId': m['doctor_id'],
      'patientId': m['patient_id'],
      'rendezVousId': m['appointment_id'],
      'codeVerification': m['prescription_number'],
      'statut': (m['status']?.toString() ?? '').toUpperCase(),
      'emiseLe': m['issue_date'] ?? m['created_at'],
      'lignes': meds.map<Map<String, dynamic>>((e) {
        final x = e as Map;
        return <String, dynamic>{
          'medicament': x['name'] ?? x['medicament'] ?? x['nom'],
          'posologie': x['posology'] ?? x['posologie'] ?? x['dosage'],
          'duree': x['duration'] ?? x['duree'],
        };
      }).toList(),
    };
  }

  /// Ordonnances du patient, les plus recentes d'abord (memes cles que l'API).
  Future<List<Map<String, dynamic>>> mesOrdonnances() async {
    try {
      final r = await sb
          .from('prescriptions')
          .select('id, doctor_id, patient_id, appointment_id, prescription_number, status, issue_date, created_at, medications')
          .eq('patient_id', _uid)
          .order('created_at', ascending: false);
      return (r as List).map((e) => _mapOrdonnance(e as Map)).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Une ordonnance du patient par identifiant.
  Future<Map<String, dynamic>> ordonnance(String id) async {
    try {
      final row = await sb
          .from('prescriptions')
          .select('id, doctor_id, patient_id, appointment_id, prescription_number, status, issue_date, created_at, medications')
          .eq('id', id)
          .single();
      return _mapOrdonnance(row as Map);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Version imprimable (PDF) d'une ordonnance, telechargee depuis le stockage Supabase.
  Future<Uint8List> ordonnancePdf(String id) async {
    try {
      final row = await sb
          .from('prescriptions')
          .select('pdf_storage_path')
          .eq('id', id)
          .single();
      final chemin = (row as Map)['pdf_storage_path'] as String?;
      if (chemin == null || chemin.isEmpty) {
        throw const ApiException(404, 'PDF indisponible', cle: 'api.pasUnPdf');
      }
      return await sb.storage.from('prescriptions').download(chemin);
    } on StorageException catch (e) {
      throw ApiException(404, e.message, cle: 'api.pasUnPdf');
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Verification publique (sans session) d'un code d'ordonnance : {valide, emiseLe, statut}.
  Future<Map<String, dynamic>> verifierOrdonnance(String code) async {
    try {
      final r = await sb.rpc('verifier_ordonnance', params: {'p_code': code});
      final liste = (r as List?) ?? const [];
      if (liste.isEmpty) return <String, dynamic>{'valide': false};
      final m = liste.first as Map;
      return <String, dynamic>{
        'valide': true,
        'emiseLe': m['emise_le'],
        'statut': (m['statut']?.toString() ?? '').toUpperCase(),
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }


  // ---------------------------------------------------------------------------
  // Avis publics d'un praticien
  // ---------------------------------------------------------------------------

  /// Synthese publique des avis d'un praticien : {moyenne, nombre, avis:[{id, note,
  /// commentaire, deposeLe}]} (avis publies uniquement).
  Future<Map<String, dynamic>> avisDuMedecin(String medecinId) async {
    try {
      final r = await sb
          .from('reviews')
          .select('id, rating_overall, comment, created_at')
          .eq('doctor_id', medecinId)
          .eq('status', 'published')
          .order('created_at', ascending: false);
      final rows = (r as List).cast<Map>();
      final notes = rows
          .map((e) => e['rating_overall'])
          .whereType<num>()
          .map((n) => n.toInt())
          .toList();
      final moyenne =
          notes.isEmpty ? null : notes.reduce((a, b) => a + b) / notes.length;
      return <String, dynamic>{
        'moyenne': moyenne,
        'nombre': rows.length,
        'avis': rows
            .map((m) => <String, dynamic>{
                  'id': m['id'],
                  'note': m['rating_overall'],
                  'commentaire': m['comment'],
                  'deposeLe': m['created_at'],
                })
            .toList(),
      };
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Listes d'attente (file patient<->medecin)
  // ---------------------------------------------------------------------------

  /// Inscrit le patient sur la liste d'attente d'un praticien (une par praticien).
  Future<void> inscrireListeAttente(String medecinId) async {
    try {
      await sb.from('appointment_waitlist').insert({
        'patient_id': _uid,
        'doctor_id': medecinId,
      });
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Inscriptions du patient en liste d'attente : {id, patientId, medecinId, inscritLe}.
  Future<List<Map<String, dynamic>>> mesInscriptionsAttente() async {
    try {
      final r = await sb
          .from('appointment_waitlist')
          .select('id, patient_id, doctor_id, created_at')
          .eq('patient_id', _uid)
          .order('created_at', ascending: true);
      return (r as List).map((e) {
        final m = e as Map;
        return <String, dynamic>{
          'id': m['id'],
          'patientId': m['patient_id'],
          'medecinId': m['doctor_id'],
          'inscritLe': m['created_at'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  /// Retire une inscription de la liste d'attente.
  Future<void> retirerListeAttente(String inscriptionId) async {
    try {
      await sb.from('appointment_waitlist').delete().eq('id', inscriptionId);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Teleconsultations
  // ---------------------------------------------------------------------------

  static String statutTele(Object? s) => switch (s?.toString()) {
        'scheduled' || 'created' || 'pending' => 'PLANIFIEE',
        'started' || 'in_progress' || 'live' => 'EN_COURS',
        'ended' || 'completed' => 'TERMINEE',
        'cancelled' => 'ANNULEE',
        _ => (s?.toString() ?? '').toUpperCase(),
      };

  Map<String, dynamic> _mapTele(Map m) {
    final app = (m['appointments'] as Map?) ?? const {};
    final consenti = m['consent_patient_recording_at'] != null;
    return <String, dynamic>{
      'id': m['id'],
      'rendezVousId': m['appointment_id'],
      'patientId': app['patient_id'],
      'medecinId': app['doctor_id'],
      'statut': statutTele(m['status']),
      'consentementPatientLe': m['consent_patient_recording_at'],
      'lienSalle': consenti ? m['daily_room_url'] : null,
      'creeLe': m['created_at'],
      'demarreeLe': m['started_at'],
      'termineeLe': m['ended_at'],
    };
  }

  /// Teleconsultations du patient (video_sessions liees a ses rendez-vous).
  Future<List<Map<String, dynamic>>> mesTeleconsultations() async {
    try {
      final r = await sb
          .from('video_sessions')
          .select('id, appointment_id, status, daily_room_url, started_at, ended_at, consent_patient_recording_at, created_at, appointments!inner(patient_id, doctor_id)')
          .eq('appointments.patient_id', _uid)
          .order('created_at', ascending: false);
      return (r as List).map((e) => _mapTele(e as Map)).toList();
    } on PostgrestException catch (_) {
      return const [];
    }
  }

  /// Consentement du patient : enregistre le consentement et renvoie la session mise a jour
  /// (avec le lien de salle).
  Future<Map<String, dynamic>> consentir(String teleconsultationId) async {
    try {
      await sb.rpc('set_video_recording_consent',
          params: {'p_session_id': teleconsultationId, 'p_consent': true});
      final row = await sb
          .from('video_sessions')
          .select('id, appointment_id, status, daily_room_url, started_at, ended_at, consent_patient_recording_at, created_at, appointments!inner(patient_id, doctor_id)')
          .eq('id', teleconsultationId)
          .single();
      return _mapTele(row as Map);
    } on PostgrestException catch (e) {
      throw _erreur(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Outils internes
  // ---------------------------------------------------------------------------

  String? _nomComplet(Map m) {
    final full = (m['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final prenom = (m['first_name'] as String?)?.trim() ?? '';
    final nom = (m['last_name'] as String?)?.trim() ?? '';
    final assemble = '$prenom $nom'.trim();
    return assemble.isEmpty ? null : assemble;
  }

  /// Traduit une erreur Postgrest en [ApiException] avec un statut HTTP proche, pour que les
  /// ecrans reutilisent leur gestion existante (409 conflit, 403 interdit...).
  ApiException _erreur(PostgrestException e) {
    final statut = switch (e.code) {
      '23505' => 409, // violation d'unicite (avis deja donne, deja inscrit...)
      '42501' => 403, // RLS : action interdite
      'PGRST116' => 404, // aucune ligne
      _ => 400,
    };
    return ApiException(statut, e.message);
  }
}
