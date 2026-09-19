/// Inscription du patient connecte sur la liste d'attente d'un praticien, telle que renvoyee
/// par `POST /api/medecins/{id}/liste-attente` et `GET /api/liste-attente/mes` :
/// {id, patientId, medecinId, inscritLe (ISO 8601)}.
///
/// Une seule inscription par praticien : le patient est prevenu (notification) des qu'un
/// creneau se libere chez lui. Valeur immuable.
class InscriptionAttente {
  const InscriptionAttente({
    required this.id,
    required this.patientId,
    required this.medecinId,
    this.inscritLe,
  });

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide
  /// ou une date absente ; les identifiants (UUID) sont conserves en texte.
  factory InscriptionAttente.fromJson(Map<String, dynamic> json) {
    return InscriptionAttente(
      id: _texte(json['id']),
      patientId: _texte(json['patientId']),
      medecinId: _texte(json['medecinId']),
      inscritLe: _date(json['inscritLe']),
    );
  }

  final String id;
  final String patientId;
  final String medecinId;

  /// Date d'inscription ; null si absente ou illisible.
  final DateTime? inscritLe;

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;
}
