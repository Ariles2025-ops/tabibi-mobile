/// Reponse d'une pharmacie a un besoin en medicament (Dawini), telle que renvoyee par
/// `GET /api/dawini/besoins/{id}/reponses` :
/// {id, besoinId, pharmacieId, nomPharmacie, disponible, prixDa, commentaire, repondueLe}.
///
/// `prixDa` est un prix en dinars algeriens ; null si la pharmacie ne l'a pas indique.
class ReponsePharmacie {
  const ReponsePharmacie({
    required this.id,
    required this.besoinId,
    required this.pharmacieId,
    required this.nomPharmacie,
    required this.disponible,
    this.prixDa,
    this.commentaire,
    this.repondueLe,
  });

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide,
  /// « indisponible », un prix ou un commentaire absent ou une date absente.
  factory ReponsePharmacie.fromJson(Map<String, dynamic> json) {
    final Object? prix = json['prixDa'];
    return ReponsePharmacie(
      id: _texte(json['id']),
      besoinId: _texte(json['besoinId']),
      pharmacieId: _texte(json['pharmacieId']),
      nomPharmacie: _texte(json['nomPharmacie']),
      disponible: json['disponible'] == true,
      prixDa: prix is num ? prix.toInt() : null,
      commentaire: _texteOuNull(json['commentaire']),
      repondueLe: _date(json['repondueLe']),
    );
  }

  final String id;
  final String besoinId;
  final String pharmacieId;
  final String nomPharmacie;

  /// Vrai si la pharmacie dispose du medicament.
  final bool disponible;

  /// Prix en dinars ; null s'il n'a pas ete indique.
  final int? prixDa;

  /// Commentaire de la pharmacie ; null s'il est absent ou vide.
  final String? commentaire;

  /// Date de la reponse ; null si absente ou illisible.
  final DateTime? repondueLe;

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  /// Chaine non vide (espaces retires), ou null si le champ est absent, nul ou vide.
  static String? _texteOuNull(Object? valeur) {
    final texte = _texte(valeur).trim();
    return texte.isEmpty ? null : texte;
  }

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;
}
