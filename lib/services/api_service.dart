import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/configuration.dart';
import '../i18n/traductions.dart';

/// Erreur renvoyee par l'API Tabibi : statut HTTP et message lisible.
///
/// Le message vient du corps JSON `{"erreur": "..."}` quand le backend en
/// fournit un, sinon d'un libelle par defaut selon le statut (401, 403, 404, 409...).
///
/// Dans ce second cas, [cle] et [params] designent le libelle dans les dictionnaires de
/// `lib/i18n/traductions.dart` : les ecrans l'affichent dans la langue de l'interface
/// (`messageApi`), [message] n'etant qu'un repli en francais. Un message venu du serveur
/// est affiche tel quel (il n'est pas traduisible ici) et laisse [cle] nulle.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.cle, this.params = const {}});

  final int statusCode;
  final String message;

  /// Cle du libelle par defaut, ou null si [message] vient du serveur.
  final String? cle;

  /// Parametres du libelle par defaut (`{chemin}`, `{statut}`).
  final Map<String, Object?> params;

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

/// Message a afficher pour une erreur survenue lors d'un appel API, en francais : repli hors
/// de tout widget (les ecrans utilisent `messageApi(context, erreur)`, qui suit la langue).
String messageErreur(Object erreur) => erreur is ApiException
    ? erreur.message
    : traduire(langueParDefaut, 'api.serveurInjoignable');

/// Type de contenu d'un document PDF (`GET /api/ordonnances/{id}/pdf`).
const String typePdf = 'application/pdf';

/// Cle du libelle affiche quand le serveur repond 2xx sans renvoyer un PDF.
const String clePasUnPdf = 'api.pasUnPdf';

/// Vrai si l'en-tete `Content-Type` designe un PDF (parametres tels que `charset` toleres,
/// casse ignoree) ; faux s'il est absent.
bool estPdf(String? contentType) =>
    contentType != null && contentType.trim().toLowerCase().startsWith(typePdf);

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
    final res = await http.get(uri);
    return _liste(res, '/api/medecins');
  }

  /// Statistiques publiques de l'annuaire : {total, wilayas}. Total reel de la base.
  Future<Map<String, dynamic>> statsAnnuaire() async {
    final res = await http.get(Uri.parse('$base/api/medecins/stats'));
    if (res.statusCode >= 300) return const {};
    final d = jsonDecode(res.body);
    return d is Map<String, dynamic> ? d : const {};
  }

  /// Fiche publique d'un praticien ([id] : UUID en texte) :
  /// {id, nomComplet, specialiteSlug, specialiteFr, wilayaCode, wilayaFr, ville}.
  Future<Map<String, dynamic>> medecin(String id) async {
    final chemin = '/api/medecins/${Uri.encodeComponent(id)}';
    final res = await http.get(Uri.parse('$base$chemin'));
    return _objet(res, chemin);
  }

  /// Creneaux d'un praticien : {id, medecinId, debut (ISO 8601), dureeMinutes, disponible}.
  Future<List<Map<String, dynamic>>> creneaux(String medecinId) async {
    final chemin = '/api/medecins/${Uri.encodeComponent(medecinId)}/creneaux';
    final res = await http.get(Uri.parse('$base$chemin'));
    return _liste(res, chemin);
  }

  /// Reserve un creneau pour le patient connecte (201) ; 409 s'il vient d'etre pris.
  Future<Map<String, dynamic>> reserverCreneau(String creneauId, String token) async {
    final chemin = '/api/creneaux/${Uri.encodeComponent(creneauId)}/reserver';
    final res = await http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Rendez-vous du patient connecte : {id, patientId, medecinId, debut, statut, creneauId}.
  Future<List<Map<String, dynamic>>> mesRendezVous(String token) async {
    final res = await http.get(
      Uri.parse('$base/api/rendezvous/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/rendezvous/mes');
  }

  /// Annule un rendez-vous du patient connecte.
  Future<void> annuler(String rdvId, String token) async {
    final chemin = '/api/rendezvous/${Uri.encodeComponent(rdvId)}/annuler';
    final res = await http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

  /// Ordonnances du patient connecte : {id, medecinId, patientId, rendezVousId,
  /// lignes: [{medicament, posologie, duree}], emiseLe (ISO 8601), codeVerification, statut}.
  Future<List<Map<String, dynamic>>> mesOrdonnances(String token) async {
    final res = await http.get(
      Uri.parse('$base/api/ordonnances/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/ordonnances/mes');
  }

  /// Une ordonnance par identifiant (jeton requis), memes champs que [mesOrdonnances].
  Future<Map<String, dynamic>> ordonnance(String id, String token) async {
    final chemin = '/api/ordonnances/${Uri.encodeComponent(id)}';
    final res = await http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Version imprimable d'une ordonnance (jeton requis) : octets du document PDF, avec le QR
  /// code de verification, tel que renvoye par `GET /api/ordonnances/{id}/pdf`
  /// (`application/pdf`) ; 403 si elle est a un autre patient, 404 si elle est inconnue.
  /// Une reponse 2xx qui n'est pas un PDF est refusee ([clePasUnPdf]).
  Future<Uint8List> ordonnancePdf(String id, String token) async {
    final chemin = '/api/ordonnances/${Uri.encodeComponent(id)}/pdf';
    final res = await http.get(
      Uri.parse('$base$chemin'),
      headers: {..._bearer(token), 'Accept': typePdf},
    );
    _verifier(res, chemin);
    if (!estPdf(res.headers['content-type'])) {
      throw ApiException(
        res.statusCode,
        traduire(langueParDefaut, clePasUnPdf),
        cle: clePasUnPdf,
      );
    }
    return res.bodyBytes;
  }

  /// Verification publique (sans jeton) d'un code d'ordonnance : {valide, emiseLe, statut}.
  Future<Map<String, dynamic>> verifierOrdonnance(String code) async {
    final chemin = '/api/ordonnances/verifier/${Uri.encodeComponent(code)}';
    final res = await http.get(Uri.parse('$base$chemin'));
    return _objet(res, chemin);
  }

  /// Notifications de l'utilisateur connecte, les plus recentes d'abord :
  /// {id, destinataireId, canal, sujet, message, lue, creeLe (ISO 8601)}.
  Future<List<Map<String, dynamic>>> mesNotifications(String token) async {
    final res = await http.get(
      Uri.parse('$base/api/notifications/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/notifications/mes');
  }

  /// Nombre de notifications non lues de l'utilisateur connecte (corps { "nombre": n }).
  Future<int> nombreNonLues(String token) async {
    final res = await http.get(
      Uri.parse('$base/api/notifications/non-lues/nombre'),
      headers: _bearer(token),
    );
    return _nombre(_objet(res, '/api/notifications/non-lues/nombre'));
  }

  /// Marque une notification lue et renvoie la notification mise a jour
  /// (403 si elle est adressee a un autre utilisateur, 404 si elle est inconnue).
  Future<Map<String, dynamic>> marquerLue(String notificationId, String token) async {
    final chemin = '/api/notifications/${Uri.encodeComponent(notificationId)}/lue';
    final res = await http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Marque lues toutes les notifications de l'utilisateur connecte ;
  /// renvoie le nombre de notifications passees a lues (corps { "nombre": n }).
  Future<int> toutMarquerLu(String token) async {
    final res = await http.post(
      Uri.parse('$base/api/notifications/toutes-lues'),
      headers: _bearer(token),
    );
    return _nombre(_objet(res, '/api/notifications/toutes-lues'));
  }

  /// Teleconsultations du patient connecte, les plus recentes d'abord : {id, rendezVousId,
  /// patientId, medecinId, statut, consentementPatientLe, lienSalle (null tant que le patient
  /// n'a pas consenti), creeLe, demarreeLe, termineeLe} (dates ISO 8601).
  Future<List<Map<String, dynamic>>> mesTeleconsultations(String token) async {
    final res = await http.get(
      Uri.parse('$base/api/teleconsultations/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/teleconsultations/mes');
  }

  /// Une teleconsultation par identifiant, memes champs que [mesTeleconsultations]
  /// (403 si elle concerne un autre patient, 404 si elle est inconnue).
  Future<Map<String, dynamic>> teleconsultation(String id, String token) async {
    final chemin = '/api/teleconsultations/${Uri.encodeComponent(id)}';
    final res = await http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Consentement explicite du patient : la vue renvoyee porte desormais le lien de salle
  /// (409 si la teleconsultation est terminee ou annulee).
  Future<Map<String, dynamic>> consentir(String teleconsultationId, String token) async {
    final chemin = '/api/teleconsultations/${Uri.encodeComponent(teleconsultationId)}/consentir';
    final res = await http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Conversations du patient connecte, activite la plus recente d'abord :
  /// {id, patientId, medecinId, creeLe, dernierMessageLe (ISO 8601), nonLus}.
  Future<List<Map<String, dynamic>>> mesConversations(String token) async {
    final res = await http.get(
      Uri.parse('$base/api/conversations'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/conversations');
  }

  /// Ouvre la conversation avec un praticien (201) ou retrouve celle qui existe (200) ;
  /// 403 si le patient n'a aucun rendez-vous avec lui. Memes champs que [mesConversations].
  /// Corps `{"medecinId": "<uuid>"}` (identifiant en texte).
  Future<Map<String, dynamic>> ouvrirConversation(String medecinId, String token) async {
    final res = await http.post(
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
    final res = await http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
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
    final res = await http.post(
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
    final res = await http.get(Uri.parse('$base/api/avis/mes'), headers: _bearer(token));
    return _liste(res, '/api/avis/mes');
  }

  /// Synthese publique (sans jeton) des avis d'un praticien :
  /// {moyenne (decimal ou null), nombre, avis: [{id, note, commentaire, deposeLe}]}.
  Future<Map<String, dynamic>> avisDuMedecin(String medecinId) async {
    final chemin = '/api/medecins/${Uri.encodeComponent(medecinId)}/avis';
    final res = await http.get(Uri.parse('$base$chemin'));
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
    final res = await http.post(
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
    final res = await http.get(
      Uri.parse('$base/api/dawini/besoins/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/dawini/besoins/mes');
  }

  /// Cloture un besoin du patient connecte (200) ; 409 s'il est deja cloture.
  Future<void> cloturerBesoin(String besoinId, String token) async {
    final chemin = '/api/dawini/besoins/${Uri.encodeComponent(besoinId)}/cloturer';
    final res = await http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

  /// Reponses des pharmacies a un besoin : {id, besoinId, pharmacieId, nomPharmacie,
  /// disponible, prixDa (entier ou null), commentaire, repondueLe (ISO 8601)}.
  Future<List<Map<String, dynamic>>> reponsesBesoin(String besoinId, String token) async {
    final chemin = '/api/dawini/besoins/${Uri.encodeComponent(besoinId)}/reponses';
    final res = await http.get(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _liste(res, chemin);
  }

  /// Inscrit le patient connecte sur la liste d'attente d'un praticien (201) :
  /// {id, patientId, medecinId, inscritLe (ISO 8601)} ; 409 s'il y est deja inscrit.
  Future<Map<String, dynamic>> inscrireListeAttente(String medecinId, String token) async {
    final chemin = '/api/medecins/${Uri.encodeComponent(medecinId)}/liste-attente';
    final res = await http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    return _objet(res, chemin);
  }

  /// Inscriptions du patient connecte en liste d'attente, les plus anciennes d'abord ; memes
  /// champs que [inscrireListeAttente].
  Future<List<Map<String, dynamic>>> mesInscriptionsAttente(String token) async {
    final res = await http.get(
      Uri.parse('$base/api/liste-attente/mes'),
      headers: _bearer(token),
    );
    return _liste(res, '/api/liste-attente/mes');
  }

  /// Retire le patient connecte d'une liste d'attente (204 sans corps ; 404 si l'inscription
  /// est inconnue, 403 si elle est a un autre patient).
  Future<void> retirerListeAttente(String inscriptionId, String token) async {
    final chemin = '/api/liste-attente/${Uri.encodeComponent(inscriptionId)}/retirer';
    final res = await http.post(Uri.parse('$base$chemin'), headers: _bearer(token));
    _verifier(res, chemin);
  }

  /// Identite de l'utilisateur connecte.
  Future<Map<String, dynamic>> moi(String token) async {
    final res = await http.get(
      Uri.parse('$base/api/moi'),
      headers: _bearer(token),
    );
    return _objet(res, '/api/moi');
  }

  /// Profil de l'utilisateur connecte : {utilisateurId, nomComplet, telephone, dateNaissance
  /// (yyyy-MM-dd), wilayaCode, langue, misAJourLe (ISO 8601)} ; 404 tant qu'il n'a jamais ete
  /// renseigne.
  Future<Map<String, dynamic>> monProfil(String token) async {
    final res = await http.get(Uri.parse('$base/api/moi/profil'), headers: _bearer(token));
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
    final res = await http.put(
      Uri.parse('$base/api/moi/profil'),
      headers: _bearerJson(token),
      body: jsonEncode(profil),
    );
    return _objet(res, '/api/moi/profil');
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

  /// Leve une [ApiException] si la reponse n'est pas un succes (2xx) : message du serveur
  /// s'il en donne un, sinon libelle par defaut traduisible (cle et parametres conserves).
  void _verifier(http.Response res, String chemin) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final duServeur = _messageDuServeur(res);
    if (duServeur != null) throw ApiException(res.statusCode, duServeur);
    final cle = _cleErreur(res.statusCode);
    final params = <String, Object?>{'chemin': chemin, 'statut': res.statusCode};
    throw ApiException(
      res.statusCode,
      traduire(langueParDefaut, cle, params: params),
      cle: cle,
      params: params,
    );
  }

  /// Message `{"erreur": "..."}` du backend ; null si le corps est vide, non JSON ou muet.
  String? _messageDuServeur(http.Response res) {
    try {
      final corps = _json(res);
      if (corps is Map && corps['erreur'] is String) return corps['erreur'] as String;
    } on FormatException {
      // Corps vide ou non JSON : libelle par defaut de l'application.
    }
    return null;
  }

  /// Cle du libelle par defaut selon le statut HTTP.
  String _cleErreur(int statut) => switch (statut) {
        401 => 'api.connexionRequise',
        403 => 'api.accesRefuse',
        404 => 'api.introuvable',
        409 => 'api.creneauPris',
        _ => 'api.echec',
      };
}
