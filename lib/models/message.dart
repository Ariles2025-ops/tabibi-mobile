/// Message d'une conversation, tel que renvoye par `GET /api/conversations/{id}/messages`
/// et `POST /api/conversations/{id}/messages` :
/// {id, conversationId, auteurId, contenu, envoyeLe, luLe (ISO 8601)}.
///
/// `auteurId` est l'identifiant (sujet du jeton) de l'auteur, patient ou praticien : le
/// comparer a celui de la session permet de reconnaitre ses propres messages. `luLe` vaut
/// null tant que le destinataire n'a pas consulte le fil.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.auteurId,
    required this.contenu,
    this.envoyeLe,
    this.luLe,
  });

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide
  /// ou une date absente ; les identifiants (UUID) sont conserves en texte.
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: _texte(json['id']),
      conversationId: _texte(json['conversationId']),
      auteurId: _texte(json['auteurId']),
      contenu: _texte(json['contenu']),
      envoyeLe: _date(json['envoyeLe']),
      luLe: _date(json['luLe']),
    );
  }

  final String id;
  final String conversationId;
  final String auteurId;
  final String contenu;

  /// Date d'envoi ; null si absente ou illisible.
  final DateTime? envoyeLe;

  /// Date de lecture par le destinataire ; null tant qu'il n'a pas consulte le fil.
  final DateTime? luLe;

  /// Vrai si le destinataire a lu le message.
  bool get estLu => luLe != null;

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;
}
