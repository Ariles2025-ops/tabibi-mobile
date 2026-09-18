/// Notification adressee a l'utilisateur connecte (boite de reception interne de Tabibi),
/// telle que renvoyee par `GET /api/notifications/mes` :
/// {id, destinataireId, canal, sujet, message, lue, creeLe (ISO 8601)}.
///
/// Nommee `NotificationUtilisateur` pour ne pas masquer la classe `Notification` de Flutter.
/// Valeur immuable : la marquer lue produit une copie ([marquerLue]).
class NotificationUtilisateur {
  const NotificationUtilisateur({
    required this.id,
    required this.destinataireId,
    required this.canal,
    required this.sujet,
    required this.message,
    required this.lue,
    this.creeLe,
  });

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide,
  /// « non lue » ou une date absente ; les identifiants (UUID) sont conserves en texte.
  factory NotificationUtilisateur.fromJson(Map<String, dynamic> json) {
    return NotificationUtilisateur(
      id: _texte(json['id']),
      destinataireId: _texte(json['destinataireId']),
      canal: _texte(json['canal']),
      sujet: _texte(json['sujet']),
      message: _texte(json['message']),
      lue: json['lue'] == true,
      creeLe: _date(json['creeLe']),
    );
  }

  final String id;
  final String destinataireId;

  /// Canal de remise : INTERNE, SMS ou EMAIL (valeur brute de l'API).
  final String canal;
  final String sujet;
  final String message;
  final bool lue;

  /// Date de creation ; null si absente ou illisible.
  final DateTime? creeLe;

  /// Copie de la notification une fois lue.
  NotificationUtilisateur marquerLue() => NotificationUtilisateur(
        id: id,
        destinataireId: destinataireId,
        canal: canal,
        sujet: sujet,
        message: message,
        lue: true,
        creeLe: creeLe,
      );

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;
}
