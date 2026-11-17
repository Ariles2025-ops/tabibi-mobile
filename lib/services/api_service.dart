import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/configuration.dart';
import '../i18n/langue.dart';

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

/// Delai maximal d'un appel HTTP ; au-dela, l'appel echoue (TimeoutException).
const Duration delaiApi = Duration(seconds: 15);

/// Appels HTTP avec un delai maximal de [delaiApi].
///
/// Sur un 401 portant un jeton Bearer, l'appel est rejoue UNE seule fois avec un jeton
/// rafraichi si [ApiService.rafraichisseur] en fournit un ; sinon le 401 est renvoye tel quel
/// (les ecrans deconnectent alors l'utilisateur).
class _Http {
  const _Http._();

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _avecRejeu(headers, (h) => http.get(url, headers: h).timeout(delaiApi));

  static Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _avecRejeu(headers, (h) => http.post(url, headers: h, body: body).timeout(delaiApi));

  static Future<http.Response> put(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _avecRejeu(headers, (h) => http.put(url, headers: h, body: body).timeout(delaiApi));

  static Future<http.Response> delete(Uri url,
          {Map<String, String>? headers}) =>
      _avecRejeu(headers, (h) => http.delete(url, headers: h).timeout(delaiApi));

  static Future<http.Response> _avecRejeu(Map<String, String>? headers,
      Future<http.Response> Function(Map<String, String>?) envoyer) async {
    final res = await envoyer(headers);
    final auth = headers?['Authorization'];
    final rafraichir = ApiService.rafraichisseur;
    if (res.statusCode != 401 || rafraichir == null || auth == null || !auth.startsWith('Bearer ')) {
      return res;
    }
    final neuf = await rafraichir(auth.substring(7));
    if (neuf == null) return res;
    return envoyer({...headers!, 'Authorization': 'Bearer $neuf'});
  }
}

/// Vrai si [erreur] vient du reseau : pas de connexion, serveur injoignable ou delai depasse.
bool estErreurReseau(Object erreur) =>
    erreur is SocketException ||
    erreur is TimeoutException ||
    erreur is http.ClientException ||
    erreur is HandshakeException;

/// Message affiche quand le reseau est coupe ou que le serveur ne repond pas.
String messageReseau() => t('Pas de connexion. Vérifiez votre réseau.',
    'لا يوجد اتصال. تحقق من الشبكة.');

/// Message a afficher a l'utilisateur pour une erreur survenue lors d'un appel API :
/// jamais de texte technique, un message clair en francais ou en arabe.
String messageErreur(Object erreur) {
  if (erreur is ApiException) return erreur.message;
  if (estErreurReseau(erreur)) return messageReseau();
  return t('Un problème est survenu. Réessayez.', 'حدث خطأ. حاول مرة أخرى.');
}

/// Appels a l'API Tabibi.
///
/// Tous les identifiants (id, medecinId, creneauId, rendezVousId, conversationId, besoinId...)
/// sont des UUID que le backend serialise en texte : ils sont recus, transmis dans les chemins
/// et envoyes dans les corps JSON sous forme de chaines, jamais de nombres.
///
/// L'adresse de base vient de la configuration par environnement ([Configuration.apiUrl],
/// `--dart-define=TABIBI_API_URL=...`) ; les tests peuvent en fournir une autre.
class ApiService {
  const ApiService({this.base = Configuration.apiUrl});

  /// Adresse de base de l'API, sans barre oblique finale.
  final String base;

  /// Fournit un jeton frais apres un 401 (recoit le jeton refuse) ; null si la session est perdue.
  static Future<String?> Function(String ancien)? rafraichisseur;

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
    final uri = Uri.parse('$base/api/medecins').replace(queryParameters: params);
    final res = await _Http.get(uri);
    return _liste(res, '/api/medecins');
  }

  /// Fiche publique d'un praticien ([id] : UUID en texte) :
  /// {id, nomComplet, specialiteSlug, specialiteFr, wilayaCode, wilayaFr, ville}.
  Future<Map<String, dynamic>> medecin(String id) async {
    final chemin = '/api/medecins/${Uri.encodeComponent(id)}';
    final res = await _Http.get(Uri.parse('$base$chemin'));
    return _objet(res, chemin);
  }

  /// Creneaux d'un praticien : {id, medecinId, debut (ISO 8601), dureeMinutes, disponible}.
  Future<List<Map<String, dynamic>>> creneaux(String medecinId) async {
    final chemin = '/api/medecins/${Uri.encodeComponent(medecinId)}/creneaux';
    final res = await _Http.get(Uri.parse('$base$chemin'));
    return _liste(res, chemin);
  }

  /// Reserve un creneau pour le patient connecte (201) ; 409 s'il vient d'etre pris.
  Future<Map<String, dynamic>> reserverCreneau(String creneauId, String token) async {
    final chemin = '/api/creneaux/${Uri.encodeComponent(creneauId)}/reserver';
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Rendez-vous du patient connecte : {id, patientId, medecinId, debut, statut, creneauId}.
  Future<List<Map<String, dynamic>>> mesRendezVous(String token) async {
    final res = await _Http.get(
      Uri.parse('$base/api/rendezvous/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/rendezvous/mes');
  }

  /// Annule un rendez-vous du patient connecte.
  Future<void> annuler(String rdvId, String token) async {
    final chemin = '/api/rendezvous/${Uri.encodeComponent(rdvId)}/annuler';
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

  /// Ordonnances du patient connecte : {id, medecinId, patientId, rendezVousId,
  /// lignes: [{medicament, posologie, duree}], emiseLe (ISO 8601), codeVerification, statut}.
  Future<List<Map<String, dynamic>>> mesOrdonnances(String token) async {
    final res = await _Http.get(
      Uri.parse('$base/api/ordonnances/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/ordonnances/mes');
  }

  /// Une ordonnance par identifiant (jeton requis), memes champs que [mesOrdonnances].
  Future<Map<String, dynamic>> ordonnance(String id, String token) async {
    final chemin = '/api/ordonnances/${Uri.encodeComponent(id)}';
    final res = await _Http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Verification publique (sans jeton) d'un code d'ordonnance : {valide, emiseLe, statut}.
  Future<Map<String, dynamic>> verifierOrdonnance(String code) async {
    final chemin = '/api/ordonnances/verifier/${Uri.encodeComponent(code)}';
    final res = await _Http.get(Uri.parse('$base$chemin'));
    return _objet(res, chemin);
  }

  /// Notifications de l'utilisateur connecte, les plus recentes d'abord :
  /// {id, destinataireId, canal, sujet, message, lue, creeLe (ISO 8601)}.
  Future<List<Map<String, dynamic>>> mesNotifications(String token) async {
    final res = await _Http.get(
      Uri.parse('$base/api/notifications/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/notifications/mes');
  }

  /// Nombre de notifications non lues de l'utilisateur connecte (corps { "nombre": n }).
  Future<int> nombreNonLues(String token) async {
    final res = await _Http.get(
      Uri.parse('$base/api/notifications/non-lues/nombre'),
      headers: _bearer(token),
    );
    return _nombre(_objet(res, '/api/notifications/non-lues/nombre'));
  }

  /// Marque une notification lue et renvoie la notification mise a jour
  /// (403 si elle est adressee a un autre utilisateur, 404 si elle est inconnue).
  Future<Map<String, dynamic>> marquerLue(String notificationId, String token) async {
    final chemin = '/api/notifications/${Uri.encodeComponent(notificationId)}/lue';
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Marque lues toutes les notifications de l'utilisateur connecte ;
  /// renvoie le nombre de notifications passees a lues (corps { "nombre": n }).
  Future<int> toutMarquerLu(String token) async {
    final res = await _Http.post(
      Uri.parse('$base/api/notifications/toutes-lues'),
      headers: _bearer(token),
    );
    return _nombre(_objet(res, '/api/notifications/toutes-lues'));
  }

  /// Teleconsultations du patient connecte, les plus recentes d'abord : {id, rendezVousId,
  /// patientId, medecinId, statut, consentementPatientLe, lienSalle (null tant que le patient
  /// n'a pas consenti), creeLe, demarreeLe, termineeLe} (dates ISO 8601).
  Future<List<Map<String, dynamic>>> mesTeleconsultations(String token) async {
    final res = await _Http.get(
      Uri.parse('$base/api/teleconsultations/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/teleconsultations/mes');
  }

  /// Une teleconsultation par identifiant, memes champs que [mesTeleconsultations]
  /// (403 si elle concerne un autre patient, 404 si elle est inconnue).
  Future<Map<String, dynamic>> teleconsultation(String id, String token) async {
    final chemin = '/api/teleconsultations/${Uri.encodeComponent(id)}';
    final res = await _Http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Consentement explicite du patient : la vue renvoyee porte desormais le lien de salle
  /// (409 si la teleconsultation est terminee ou annulee).
  Future<Map<String, dynamic>> consentir(String teleconsultationId, String token) async {
    final chemin = '/api/teleconsultations/${Uri.encodeComponent(teleconsultationId)}/consentir';
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Conversations du patient connecte, activite la plus recente d'abord :
  /// {id, patientId, medecinId, creeLe, dernierMessageLe (ISO 8601), nonLus}.
  Future<List<Map<String, dynamic>>> mesConversations(String token) async {
    final res = await _Http.get(
      Uri.parse('$base/api/conversations'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/conversations');
  }

  /// Ouvre la conversation avec un praticien (201) ou retrouve celle qui existe (200) ;
  /// 403 si le patient n'a aucun rendez-vous avec lui. Memes champs que [mesConversations].
  /// Corps `{"medecinId": "<uuid>"}` (identifiant en texte).
  Future<Map<String, dynamic>> ouvrirConversation(String medecinId, String token) async {
    final res = await _Http.post(
      Uri.parse('$base/api/conversations'),
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
    final res = await _Http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
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
    final res = await _Http.post(
      Uri.parse('$base$chemin'),
      headers: _bearerJson(token),
      body: jsonEncode({'contenu': contenu}),
    );
    return _objet(res, chemin);
  }

  /// Depose un avis sur un rendez-vous honore (201) : {id, rendezVousId, medecinId, note,
  /// commentaire, statut (PUBLIE, SIGNALE, MASQUE), deposeLe (ISO 8601)} ; 400 si la note sort
  /// de 1..5, 409 si le rendez-vous n'est pas honore ou si un avis existe deja.
  /// Corps `{"rendezVousId": "<uuid>", "note": n, "commentaire": "..."}` (identifiant en texte).
  Future<Map<String, dynamic>> deposerAvis(
    String rendezVousId,
    int note,
    String? commentaire,
    String token,
  ) async {
    final res = await _Http.post(
      Uri.parse('$base/api/avis'),
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
    final res = await _Http.get(Uri.parse('$base/api/avis/mes'), headers: _bearer(token));
    return _liste(res, '/api/avis/mes');
  }

  /// Synthese publique (sans jeton) des avis d'un praticien :
  /// {moyenne (decimal ou null), nombre, avis: [{id, note, commentaire, deposeLe}]}.
  Future<Map<String, dynamic>> avisDuMedecin(String medecinId) async {
    final chemin = '/api/medecins/${Uri.encodeComponent(medecinId)}/avis';
    final res = await _Http.get(Uri.parse('$base$chemin'));
    return _objet(res, chemin);
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
    final res = await _Http.post(
      Uri.parse('$base/api/dawini/besoins'),
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
    final res = await _Http.get(
      Uri.parse('$base/api/dawini/besoins/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/dawini/besoins/mes');
  }

  /// Cloture un besoin du patient connecte (200) ; 409 s'il est deja cloture.
  Future<void> cloturerBesoin(String besoinId, String token) async {
    final chemin = '/api/dawini/besoins/${Uri.encodeComponent(besoinId)}/cloturer';
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

  /// Reponses des pharmacies a un besoin : {id, besoinId, pharmacieId, nomPharmacie,
  /// disponible, prixDa (entier ou null), commentaire, repondueLe (ISO 8601)}.
  Future<List<Map<String, dynamic>>> reponsesBesoin(String besoinId, String token) async {
    final chemin = '/api/dawini/besoins/${Uri.encodeComponent(besoinId)}/reponses';
    final res = await _Http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _liste(res, chemin);
  }

  /// Inscrit le patient connecte sur la liste d'attente d'un praticien (201) :
  /// {id, patientId, medecinId, inscritLe (ISO 8601)} ; 409 s'il y est deja inscrit.
  Future<Map<String, dynamic>> inscrireListeAttente(String medecinId, String token) async {
    final chemin = '/api/medecins/${Uri.encodeComponent(medecinId)}/liste-attente';
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Inscriptions du patient connecte en liste d'attente, les plus anciennes d'abord ; memes
  /// champs que [inscrireListeAttente].
  Future<List<Map<String, dynamic>>> mesInscriptionsAttente(String token) async {
    final res = await _Http.get(
      Uri.parse('$base/api/liste-attente/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/liste-attente/mes');
  }

  /// Retire le patient connecte d'une liste d'attente (204 sans corps ; 404 si l'inscription
  /// est inconnue, 403 si elle est a un autre patient).
  Future<void> retirerListeAttente(String inscriptionId, String token) async {
    final chemin = '/api/liste-attente/${Uri.encodeComponent(inscriptionId)}/retirer';
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

  /// Identite de l'utilisateur connecte.
  Future<Map<String, dynamic>> moi(String token) async {
    final res = await _Http.get(
      Uri.parse('$base/api/moi'),
      headers: _bearer(token),
    );
    return _objet(res, '/api/moi');
  }

  /// Profil de l'utilisateur connecte : {utilisateurId, nomComplet, telephone, dateNaissance
  /// (yyyy-MM-dd), wilayaCode, langue, misAJourLe (ISO 8601)} ; 404 tant qu'il n'a jamais ete
  /// renseigne.
  Future<Map<String, dynamic>> monProfil(String token) async {
    final res = await _Http.get(Uri.parse('$base/api/moi/profil'), headers: _bearer(token));
    return _objet(res, '/api/moi/profil');
  }

  /// Renseigne ou remplace le profil de l'utilisateur connecte et renvoie la vue enregistree
  /// (memes champs que [monProfil]) ; 400 si une regle n'est pas respectee (nom absent,
  /// telephone mal forme, date de naissance future, langue inconnue).
  /// Corps `{"nomComplet": ..., "telephone": ..., "dateNaissance": "yyyy-MM-dd" ou null,
  /// "wilayaCode": ..., "langue": ...}`, tel que produit par `Profil.toJson()`.
  Future<Map<String, dynamic>> enregistrerProfil(
    Map<String, dynamic> profil,
    String token,
  ) async {
    final res = await _Http.put(
      Uri.parse('$base/api/moi/profil'),
      headers: _bearerJson(token),
      body: jsonEncode(profil),
    );
    return _objet(res, '/api/moi/profil');
  }

  /// Supprime le compte de l'utilisateur connecte (204) : exige par Google Play.
  Future<void> supprimerMonCompte(String token) async {
    final res = await _Http.delete(Uri.parse('$base/api/moi'), headers: _bearer(token));
    _verifier(res, '/api/moi');
  }

  // --- Espace medecin ---

  /// Agenda du medecin connecte : {id, patientId, medecinId, creneauId, debut, statut}.
  Future<List<Map<String, dynamic>>> agendaMedecin(String token) =>
      _get('/api/medecin/rendezvous', token);

  /// Le patient est venu : rendez-vous HONORE (409 s'il n'est pas confirme).
  Future<void> honorerRendezVous(String rdvId, String token) =>
      _post('/api/rendezvous/${Uri.encodeComponent(rdvId)}/honorer', token);

  /// Le patient n'est pas venu : rendez-vous ABSENT.
  Future<void> marquerAbsentMedecin(String rdvId, String token) =>
      _post('/api/medecin/rendezvous/${Uri.encodeComponent(rdvId)}/absent', token);

  /// Annulation par le medecin : creneau libere, patient prevenu.
  Future<void> annulerParMedecin(String rdvId, String token) =>
      _post('/api/medecin/rendezvous/${Uri.encodeComponent(rdvId)}/annuler', token);

  /// Creneaux a venir du medecin connecte : {id, medecinId, debut, dureeMinutes, disponible}.
  Future<List<Map<String, dynamic>>> creneauxMedecin(String token) =>
      _get('/api/medecin/creneaux', token);

  /// Ouvre un creneau (201) ; [debut] est envoye en UTC (ISO 8601), 400 si passe ou duree invalide.
  Future<Map<String, dynamic>> ouvrirCreneauMedecin(
          DateTime debut, int dureeMinutes, String token) =>
      _postJson('/api/medecin/creneaux', token, corpsCreneau(debut, dureeMinutes));

  /// Supprime un creneau libre (204 ; 409 s'il est reserve).
  Future<void> supprimerCreneauMedecin(String creneauId, String token) =>
      _delete('/api/medecin/creneaux/${Uri.encodeComponent(creneauId)}', token);

  /// Semaine type (POST, 404 tant que la route n'existe pas) : {crees, ignores}.
  Future<Map<String, dynamic>> semaineTypeMedecin(Map<String, dynamic> corps, String token) =>
      _postJson('/api/medecin/creneaux/semaine-type', token, corps);

  /// Fiche publique du medecin connecte (404 tant que la route n'existe pas).
  Future<Map<String, dynamic>> ficheMedecin(String token) async {
    final res = await _Http.get(Uri.parse('$base/api/medecin/fiche'), headers: _bearer(token));
    return _objet(res, '/api/medecin/fiche');
  }

  /// Modifie adresse, telephone du cabinet, horaires, presentation et langues.
  Future<Map<String, dynamic>> modifierFicheMedecin(Map<String, dynamic> corps, String token) async {
    final res = await _Http.put(Uri.parse('$base/api/medecin/fiche'),
        headers: _bearerJson(token), body: jsonEncode(corps));
    return _objet(res, '/api/medecin/fiche');
  }

  /// Liste d'attente du medecin connecte : {id, patientId, medecinId, inscritLe}.
  Future<List<Map<String, dynamic>>> listeAttenteMedecin(String token) =>
      _get('/api/medecin/liste-attente', token);

  /// Patients du medecin connecte : {patientId, nomComplet, telephone, email}.
  Future<List<Map<String, dynamic>>> patientsMedecin(String token) =>
      _get('/api/medecin/patients', token);

  // --- Espace secretaire ---

  /// Patients du cabinet d'un medecin, pour une secretaire rattachee (memes champs).
  Future<List<Map<String, dynamic>>> patientsCabinet(String medecinId, String token) =>
      _get('/api/secretaire/medecins/${Uri.encodeComponent(medecinId)}/patients', token);

  /// Cabinets de la secretaire connectee : {id, medecinId, secretaireId, creeLe, accepte}.
  Future<List<Map<String, dynamic>>> cabinetsSecretaire(String token) =>
      _get('/api/secretaire/medecins', token);

  /// Agenda d'un medecin pour une secretaire rattachee.
  Future<List<Map<String, dynamic>>> agendaSecretaire(String medecinId, String token) =>
      _get('/api/secretaire/medecins/${Uri.encodeComponent(medecinId)}/rendezvous', token);

  Future<List<Map<String, dynamic>>> creneauxSecretaire(String medecinId, String token) =>
      _get('/api/secretaire/medecins/${Uri.encodeComponent(medecinId)}/creneaux', token);

  Future<Map<String, dynamic>> ouvrirCreneauSecretaire(
          String medecinId, DateTime debut, int dureeMinutes, String token) =>
      _postJson('/api/secretaire/medecins/${Uri.encodeComponent(medecinId)}/creneaux', token,
          corpsCreneau(debut, dureeMinutes));

  Future<Map<String, dynamic>> semaineTypeSecretaire(
          String medecinId, Map<String, dynamic> corps, String token) =>
      _postJson(
          '/api/secretaire/medecins/${Uri.encodeComponent(medecinId)}/creneaux/semaine-type',
          token,
          corps);

  /// RDV pris au telephone sur un creneau libre (404 tant que la route n'existe pas).
  Future<Map<String, dynamic>> rdvTelephoneSecretaire(
          String medecinId, Map<String, dynamic> corps, String token) =>
      _postJson('/api/secretaire/medecins/${Uri.encodeComponent(medecinId)}/rendezvous', token,
          corps);

  Future<void> supprimerCreneauSecretaire(String medecinId, String creneauId, String token) => _delete(
      '/api/secretaire/medecins/${Uri.encodeComponent(medecinId)}/creneaux/${Uri.encodeComponent(creneauId)}',
      token);

  Future<void> honorerParSecretaire(String rdvId, String token) =>
      _post('/api/secretaire/rendezvous/${Uri.encodeComponent(rdvId)}/honorer', token);

  Future<void> absentParSecretaire(String rdvId, String token) =>
      _post('/api/secretaire/rendezvous/${Uri.encodeComponent(rdvId)}/absent', token);

  Future<void> annulerParSecretaire(String rdvId, String token) =>
      _post('/api/secretaire/rendezvous/${Uri.encodeComponent(rdvId)}/annuler', token);

  // --- Invitations a rejoindre un cabinet (tout compte connecte) ---

  /// Invitations en attente : {id, medecinId, creeLe}.
  Future<List<Map<String, dynamic>>> invitationsCabinet(String token) =>
      _get('/api/moi/invitations-cabinet', token);

  /// Accepter : le compte recoit le role SECRETAIRE (effectif a la prochaine connexion).
  Future<void> accepterInvitation(String invitationId, String token) =>
      _post('/api/moi/invitations-cabinet/${Uri.encodeComponent(invitationId)}/accepter', token);

  Future<void> refuserInvitation(String invitationId, String token) =>
      _post('/api/moi/invitations-cabinet/${Uri.encodeComponent(invitationId)}/refuser', token);

  // --- Espace pharmacie ---

  /// Besoins ouverts d'une wilaya : {id, medicament, wilayaCode, commune, precision, statut,
  /// publieLe, nombreReponses, dejaRepondu}.
  Future<List<Map<String, dynamic>>> besoinsWilaya(String wilayaCode, String token) async {
    final uri =
        Uri.parse('$base/api/dawini/besoins').replace(queryParameters: {'wilaya': wilayaCode});
    final res = await _Http.get(uri, headers: _bearer(token));
    return _liste(res, '/api/dawini/besoins');
  }

  /// Reponse de la pharmacie connectee a un besoin (201) ; le nom affiche est celui de son profil.
  Future<Map<String, dynamic>> repondreBesoin(
    String besoinId,
    bool disponible,
    String token, {
    int? prixDa,
    String? commentaire,
  }) =>
      _postJson('/api/dawini/besoins/${Uri.encodeComponent(besoinId)}/reponses', token, {
        'disponible': disponible,
        'prixDa': prixDa,
        'commentaire': commentaire,
      });

  /// Marque delivree l'ordonnance de ce code : {valide, emiseLe, statut, delivreeLe}
  /// (409 si deja delivree ou annulee, 404 si code inconnu).
  Future<Map<String, dynamic>> delivrerOrdonnance(String code, String token) async {
    final chemin = '/api/pharmacie/ordonnances/${Uri.encodeComponent(code)}/delivrer';
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  // --- Outils internes ---

  Future<List<Map<String, dynamic>>> _get(String chemin, String token) async {
    final res = await _Http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _liste(res, chemin);
  }

  Future<void> _post(String chemin, String token) async {
    final res = await _Http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

  Future<Map<String, dynamic>> _postJson(
      String chemin, String token, Map<String, dynamic> corps) async {
    final res = await _Http.post(Uri.parse('$base$chemin'),
        headers: _bearerJson(token), body: jsonEncode(corps));
    return _objet(res, chemin);
  }

  Future<void> _delete(String chemin, String token) async {
    final res = await _Http.delete(Uri.parse('$base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

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
      if (corps is Map) {
        // `erreur` (API) ou `message` (limiteurs du serveur) ; jamais pour un 429/5xx techniques.
        for (final cle in ['erreur', 'message']) {
          final v = corps[cle];
          if (v is String && v.isNotEmpty && res.statusCode != 429 && res.statusCode < 500) {
            return v;
          }
        }
      }
    } on FormatException {
      // Corps vide ou non JSON : libelle par defaut ci-dessous.
    }
    return switch (res.statusCode) {
      429 => t('Trop de demandes, réessayez dans une minute.',
          'طلبات كثيرة جدًا، حاول مرة أخرى بعد دقيقة.'),
      >= 500 => t('Le serveur rencontre un problème. Réessayez plus tard.',
          'يواجه الخادم مشكلة. حاول لاحقًا.'),
      401 => t('Connexion requise', 'يجب تسجيل الدخول'),
      403 => t('Accès refusé : ce compte n\'a pas les droits nécessaires',
          'تم رفض الوصول: هذا الحساب لا يملك الصلاحيات اللازمة'),
      404 => t('Ressource introuvable', 'العنصر غير موجود'),
      409 => t('Action impossible : la situation a changé entre-temps',
          'تعذّر الإجراء: تغيّر الوضع في الأثناء'),
      _ => t('Un problème est survenu. Réessayez.', 'حدث خطأ. حاول مرة أخرى.'),
    };
  }
}

/// Corps d'ouverture de creneau : `{"debut": "<instant UTC ISO 8601>", "dureeMinutes": n}`.
Map<String, dynamic> corpsCreneau(DateTime debut, int dureeMinutes) => {
      'debut': debut.toUtc().toIso8601String(),
      'dureeMinutes': dureeMinutes,
    };
