/// Teleconsultation du patient connecte, telle que renvoyee par `GET /api/teleconsultations/mes` :
/// {id, rendezVousId, patientId, medecinId, statut (PLANIFIEE, EN_COURS, TERMINEE, ANNULEE),
///  consentementPatientLe, lienSalle, creeLe, demarreeLe, termineeLe} (dates ISO 8601).
///
/// `consentementPatientLe` vaut null tant que le patient n'a pas consenti ; `lienSalle` reste
/// null pour le patient tant qu'il n'a pas consenti (le nom de salle donne acces a la session).
class Teleconsultation {
  const Teleconsultation({
    required this.id,
    required this.rendezVousId,
    required this.patientId,
    required this.medecinId,
    required this.statut,
    this.consentementPatientLe,
    this.lienSalle,
    this.creeLe,
    this.demarreeLe,
    this.termineeLe,
  });

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide
  /// ou une valeur absente ; les identifiants (UUID) sont conserves en texte.
  factory Teleconsultation.fromJson(Map<String, dynamic> json) {
    return Teleconsultation(
      id: _texte(json['id']),
      rendezVousId: _texte(json['rendezVousId']),
      patientId: _texte(json['patientId']),
      medecinId: _texte(json['medecinId']),
      statut: _texte(json['statut']),
      consentementPatientLe: _date(json['consentementPatientLe']),
      lienSalle: _texteOuNull(json['lienSalle']),
      creeLe: _date(json['creeLe']),
      demarreeLe: _date(json['demarreeLe']),
      termineeLe: _date(json['termineeLe']),
    );
  }

  final String id;
  final String rendezVousId;
  final String patientId;
  final String medecinId;

  /// PLANIFIEE, EN_COURS, TERMINEE ou ANNULEE (valeur brute de l'API).
  final String statut;

  /// Date du consentement du patient ; null tant qu'il n'a pas consenti.
  final DateTime? consentementPatientLe;

  /// Lien de la salle video (Jitsi Meet) ; null tant que le patient n'a pas consenti.
  final String? lienSalle;

  /// Date de planification par le medecin ; null si absente ou illisible.
  final DateTime? creeLe;

  /// Date de demarrage par le medecin ; null tant que la session n'a pas demarre.
  final DateTime? demarreeLe;

  /// Date de cloture ; null tant que la session n'est pas terminee.
  final DateTime? termineeLe;

  /// Vrai si le patient a donne son consentement.
  bool get aConsenti => consentementPatientLe != null;

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  /// Chaine non vide, ou null si le champ est absent, nul ou vide.
  static String? _texteOuNull(Object? valeur) {
    final texte = _texte(valeur);
    return texte.isEmpty ? null : texte;
  }

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;
}
