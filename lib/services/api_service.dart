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
