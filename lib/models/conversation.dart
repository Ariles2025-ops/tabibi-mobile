/// Conversation entre le patient connecte et un praticien, telle que renvoyee par
/// `GET /api/conversations` et `POST /api/conversations` :
/// {id, patientId, medecinId, creeLe, dernierMessageLe (ISO 8601), nonLus}.
///
/// `dernierMessageLe` vaut null tant qu'aucun message n'a ete echange ; `nonLus` est le
/// nombre de messages du praticien que le patient n'a pas encore lus.
class Conversation {
  const Conversation({
    required this.id,
    required this.patientId,
    required this.medecinId,
    this.creeLe,
    this.dernierMessageLe,
    this.nonLus = 0,
  });

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide,
  /// une date absente ou zero non lu ; les identifiants (UUID) sont conserves en texte.
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: _texte(json['id']),
      patientId: _texte(json['patientId']),
      medecinId: _texte(json['medecinId']),
      creeLe: _date(json['creeLe']),
      dernierMessageLe: _date(json['dernierMessageLe']),
      nonLus: _entier(json['nonLus']),
    );
  }

  final String id;
  final String patientId;
  final String medecinId;

  /// Date d'ouverture de la conversation ; null si absente ou illisible.
  final DateTime? creeLe;

  /// Date du dernier message echange ; null tant qu'il n'y en a aucun.
  final DateTime? dernierMessageLe;

  /// Nombre de messages recus non encore lus.
  final int nonLus;

  /// Date de la derniere activite : dernier message, sinon ouverture.
  DateTime? get derniereActivite => dernierMessageLe ?? creeLe;

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  static int _entier(Object? valeur) => valeur is num ? valeur.toInt() : 0;

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;
}
