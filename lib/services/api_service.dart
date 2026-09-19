import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur renvoyee par l'API Tabibi : statut HTTP et message lisible.
///
/// Le message vient du corps JSON `{"erreur": "..."}` quand le backend en
/// fournit un, sinon d'un libelle par defaut selon le statut (401, 403, 404, 409...).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  /// 401 : jeton absent ou expire.
  bool get nonAutorise => statusCode == 401;

  /// 403 : role insuffisant (PATIENT requis).
  bool get interdit => statusCode == 403;

  /// 404 : ressource inexistante.
  bool get introuvable => statusCode == 404;

  /// 409 : creneau deja pris.
  bool get conflit => statusCode == 409;

  @override
  String toString() => 'ApiException($statusCode) : $message';
}

/// Message a afficher a l'utilisateur pour une erreur survenue lors d'un appel API.
String messageErreur(Object erreur) =>
    erreur is ApiException ? erreur.message : 'Impossible de joindre le serveur';

/// Appels a l'API Tabibi.
class ApiService {
  const ApiService();

  // Emulateur Android -> 10.0.2.2 ; iOS -> localhost.
  static const String _base = 'http://10.0.2.2:8080';

  /// Recherche publique de praticiens (sans jeton).
  Future<List<Map<String, dynamic>>> rechercherMedecins({
    String? specialite,
    String? wilaya,
    String? q,
  }) async {
    final params = <String, String>{};
    if (specialite != null && specialite.isNotEmpty) params['specialite'] = specialite;
    if (wilaya != null && wilaya.isNotEmpty) params['wilaya'] = wilaya;
    if (q != null && q.isNotEmpty) params['q'] = q;
    final uri = Uri.parse('$_base/api/medecins').replace(queryParameters: params);
    final res = await http.get(uri);
    return _liste(res, '/api/medecins');
  }

  /// Fiche publique d'un praticien.
  Future<Map<String, dynamic>> medecin(int id) async {
    final res = await http.get(Uri.parse('$_base/api/medecins/$id'));
    return _objet(res, '/api/medecins/$id');
  }

  /// Creneaux d'un praticien : {id, medecinId, debut (ISO 8601), dureeMinutes, disponible}.
  Future<List<Map<String, dynamic>>> creneaux(int medecinId) async {
    final res = await http.get(Uri.parse('$_base/api/medecins/$medecinId/creneaux'));
    return _liste(res, '/api/medecins/$medecinId/creneaux');
  }

  /// Reserve un creneau pour le patient connecte (201) ; 409 s'il vient d'etre pris.
  Future<Map<String, dynamic>> reserverCreneau(int creneauId, String token) async {
    final res = await http.post(
      Uri.parse('$_base/api/creneaux/$creneauId/reserver'),
      headers: _bearer(token),
    );
    return _objet(res, '/api/creneaux/$creneauId/reserver');
  }

  /// Rendez-vous du patient connecte : {id, patientId, medecinId, debut, statut, creneauId}.
  Future<List<Map<String, dynamic>>> mesRendezVous(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/rendezvous/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/rendezvous/mes');
  }

  /// Annule un rendez-vous du patient connecte.
  Future<void> annuler(int rdvId, String token) async {
    final res = await http.post(
      Uri.parse('$_base/api/rendezvous/$rdvId/annuler'),
      headers: _bearer(token),
    );
    _verifier(res, '/api/rendezvous/$rdvId/annuler');
  }

  /// Ordonnances du patient connecte : {id, medecinId, patientId, rendezVousId,
  /// lignes: [{medicament, posologie, duree}], emiseLe (ISO 8601), codeVerification, statut}.
  Future<List<Map<String, dynamic>>> mesOrdonnances(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/ordonnances/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/ordonnances/mes');
  }

  /// Une ordonnance par identifiant (jeton requis), memes champs que [mesOrdonnances].
  Future<Map<String, dynamic>> ordonnance(int id, String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/ordonnances/$id'),
      headers: _bearer(token),
    );
    return _objet(res, '/api/ordonnances/$id');
  }

  /// Verification publique (sans jeton) d'un code d'ordonnance : {valide, emiseLe, statut}.
  Future<Map<String, dynamic>> verifierOrdonnance(String code) async {
    final chemin = '/api/ordonnances/verifier/${Uri.encodeComponent(code)}';
    final res = await http.get(Uri.parse('$_base$chemin'));
    return _objet(res, chemin);
  }

  /// Notifications de l'utilisateur connecte, les plus recentes d'abord :
  /// {id, destinataireId, canal, sujet, message, lue, creeLe (ISO 8601)}.
  Future<List<Map<String, dynamic>>> mesNotifications(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/notifications/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/notifications/mes');
  }

  /// Nombre de notifications non lues de l'utilisateur connecte (corps { "nombre": n }).
  Future<int> nombreNonLues(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/notifications/non-lues/nombre'),
      headers: _bearer(token),
    );
    return _nombre(_objet(res, '/api/notifications/non-lues/nombre'));
  }

  /// Marque une notification lue et renvoie la notification mise a jour
  /// (403 si elle est adressee a un autre utilisateur, 404 si elle est inconnue).
  Future<Map<String, dynamic>> marquerLue(String notificationId, String token) async {
    final chemin = '/api/notifications/${Uri.encodeComponent(notificationId)}/lue';
    final res = await http.post(Uri.parse('$_base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Marque lues toutes les notifications de l'utilisateur connecte ;
  /// renvoie le nombre de notifications passees a lues (corps { "nombre": n }).
  Future<int> toutMarquerLu(String token) async {
    final res = await http.post(
      Uri.parse('$_base/api/notifications/toutes-lues'),
      headers: _bearer(token),
    );
    return _nombre(_objet(res, '/api/notifications/toutes-lues'));
  }

  /// Teleconsultations du patient connecte, les plus recentes d'abord : {id, rendezVousId,
  /// patientId, medecinId, statut, consentementPatientLe, lienSalle (null tant que le patient
  /// n'a pas consenti), creeLe, demarreeLe, termineeLe} (dates ISO 8601).
  Future<List<Map<String, dynamic>>> mesTeleconsultations(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/teleconsultations/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/teleconsultations/mes');
  }

  /// Une teleconsultation par identifiant, memes champs que [mesTeleconsultations]
  /// (403 si elle concerne un autre patient, 404 si elle est inconnue).
  Future<Map<String, dynamic>> teleconsultation(String id, String token) async {
    final chemin = '/api/teleconsultations/${Uri.encodeComponent(id)}';
    final res = await http.get(Uri.parse('$_base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Consentement explicite du patient : la vue renvoyee porte desormais le lien de salle
  /// (409 si la teleconsultation est terminee ou annulee).
  Future<Map<String, dynamic>> consentir(String teleconsultationId, String token) async {
    final chemin = '/api/teleconsultations/${Uri.encodeComponent(teleconsultationId)}/consentir';
    final res = await http.post(Uri.parse('$_base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Conversations du patient connecte, activite la plus recente d'abord :
  /// {id, patientId, medecinId, creeLe, dernierMessageLe (ISO 8601), nonLus}.
  Future<List<Map<String, dynamic>>> mesConversations(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/conversations'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/conversations');
  }

  /// Ouvre la conversation avec un praticien (201) ou retrouve celle qui existe (200) ;
  /// 403 si le patient n'a aucun rendez-vous avec lui. Memes champs que [mesConversations].
  Future<Map<String, dynamic>> ouvrirConversation(int medecinId, String token) async {
    final res = await http.post(
      Uri.parse('$_base/api/conversations'),
      headers: _bearerJson(token),
      body: jsonEncode({'medecinId': medecinId}),
    );
    return _objet(res, '/api/conversations');
  }

  /// Messages d'une conversation, du plus ancien au plus recent : {id, conversationId,
  /// auteurId, contenu, envoyeLe, luLe (ISO 8601)} ; l'appel marque lus les messages recus
  /// (403 si la conversation est a un autre patient, 404 si elle est inconnue).
  Future<List<Map<String, dynamic>>> messages(String conversationId, String token) async {
    final chemin = '/api/conversations/${Uri.encodeComponent(conversationId)}/messages';
    final res = await http.get(Uri.parse('$_base$chemin'), headers: _bearer(token));
    return _liste(res, chemin);
  }

  /// Envoie un message dans une conversation (201) et renvoie le message cree ;
  /// 400 si le contenu est vide ou depasse 2000 caracteres.
  Future<Map<String, dynamic>> envoyerMessage(
    String conversationId,
    String contenu,
    String token,
  ) async {
    final chemin = '/api/conversations/${Uri.encodeComponent(conversationId)}/messages';
    final res = await http.post(
      Uri.parse('$_base$chemin'),
      headers: _bearerJson(token),
      body: jsonEncode({'contenu': contenu}),
    );
    return _objet(res, chemin);
  }

  /// Depose un avis sur un rendez-vous honore (201) : {id, rendezVousId, medecinId, note,
  /// commentaire, statut (PUBLIE, SIGNALE, MASQUE), deposeLe (ISO 8601)} ; 400 si la note sort
  /// de 1..5, 409 si le rendez-vous n'est pas honore ou si un avis existe deja.
  Future<Map<String, dynamic>> deposerAvis(
    int rendezVousId,
    int note,
    String? commentaire,
    String token,
  ) async {
    final res = await http.post(
      Uri.parse('$_base/api/avis'),
      headers: _bearerJson(token),
      body: jsonEncode({
        'rendezVousId': rendezVousId,
        'note': note,
        if (commentaire != null) 'commentaire': commentaire,
      }),
    );
    return _objet(res, '/api/avis');
  }

  /// Avis deposes par le patient connecte, memes champs que [deposerAvis].
  Future<List<Map<String, dynamic>>> mesAvis(String token) async {
    final res = await http.get(Uri.parse('$_base/api/avis/mes'), headers: _bearer(token));
    return _liste(res, '/api/avis/mes');
  }

  /// Synthese publique (sans jeton) des avis d'un praticien :
  /// {moyenne (decimal ou null), nombre, avis: [{id, note, commentaire, deposeLe}]}.
  Future<Map<String, dynamic>> avisDuMedecin(int medecinId) async {
    final res = await http.get(Uri.parse('$_base/api/medecins/$medecinId/avis'));
    return _objet(res, '/api/medecins/$medecinId/avis');
  }

  /// Publie un besoin en medicament aupres des pharmacies (Dawini, 201) : {id, patientId,
  /// medicament, wilayaCode, commune, precision, statut (OUVERT, CLOTURE), publieLe, clotureLe,
  /// nombreReponses} ; 400 si le medicament ou le code de wilaya est vide.
  Future<Map<String, dynamic>> publierBesoin(
    String medicament,
    String wilayaCode,
    String token, {
    String? commune,
    String? precision,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/dawini/besoins'),
      headers: _bearerJson(token),
      body: jsonEncode({
        'medicament': medicament,
        'wilayaCode': wilayaCode,
        'commune': commune,
        'precision': precision,
      }),
    );
    return _objet(res, '/api/dawini/besoins');
  }

  /// Besoins publies par le patient connecte, les plus recents d'abord ; memes champs
  /// que [publierBesoin].
  Future<List<Map<String, dynamic>>> mesBesoins(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/dawini/besoins/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/dawini/besoins/mes');
  }

  /// Cloture un besoin du patient connecte (200) ; 409 s'il est deja cloture.
  Future<void> cloturerBesoin(String besoinId, String token) async {
    final chemin = '/api/dawini/besoins/${Uri.encodeComponent(besoinId)}/cloturer';
    final res = await http.post(Uri.parse('$_base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

  /// Reponses des pharmacies a un besoin : {id, besoinId, pharmacieId, nomPharmacie,
  /// disponible, prixDa (entier ou null), commentaire, repondueLe (ISO 8601)}.
  Future<List<Map<String, dynamic>>> reponsesBesoin(String besoinId, String token) async {
    final chemin = '/api/dawini/besoins/${Uri.encodeComponent(besoinId)}/reponses';
    final res = await http.get(Uri.parse('$_base$chemin'), headers: _bearer(token));
    return _liste(res, chemin);
  }

  /// Identite de l'utilisateur connecte.
  Future<Map<String, dynamic>> moi(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/moi'),
      headers: _bearer(token),
    );
    return _objet(res, '/api/moi');
  }

  // --- Outils internes ---

  Map<String, String> _bearer(String token) => {'Authorization': 'Bearer $token'};

  /// En-tetes d'un envoi JSON (corps encode en UTF-8) avec le jeton.
  Map<String, String> _bearerJson(String token) => {
        ..._bearer(token),
        'Content-Type': 'application/json; charset=utf-8',
      };

  /// Valeur du champ `nombre` d'un corps { "nombre": n } ; 0 s'il est absent.
  int _nombre(Map<String, dynamic> corps) {
    final Object? nombre = corps['nombre'];
    return nombre is num ? nombre.toInt() : 0;
  }

  /// Corps decode en UTF-8 (les accents sont preserves meme sans charset dans l'en-tete).
  Object? _json(http.Response res) => jsonDecode(utf8.decode(res.bodyBytes));

  Map<String, dynamic> _objet(http.Response res, String chemin) {
    _verifier(res, chemin);
    return _json(res) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _liste(http.Response res, String chemin) {
    _verifier(res, chemin);
    return (_json(res) as List).cast<Map<String, dynamic>>();
  }

  /// Leve une [ApiException] si la reponse n'est pas un succes (2xx).
  void _verifier(http.Response res, String chemin) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ApiException(res.statusCode, _libelleErreur(res, chemin));
  }

  String _libelleErreur(http.Response res, String chemin) {
    try {
      final corps = _json(res);
      if (corps is Map && corps['erreur'] is String) return corps['erreur'] as String;
    } on FormatException {
      // Corps vide ou non JSON : libelle par defaut ci-dessous.
    }
    return switch (res.statusCode) {
      401 => 'Connexion requise',
      403 => 'Acces refuse : un compte patient est necessaire',
      404 => 'Ressource introuvable',
      409 => "Ce creneau vient d'etre pris",
      _ => 'Echec $chemin : ${res.statusCode}',
    };
  }
}
