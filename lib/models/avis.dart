/// Avis depose par un patient apres un rendez-vous honore, tel que renvoye par
/// `POST /api/avis` et `GET /api/avis/mes` :
/// {id, rendezVousId, medecinId, note (1..5), commentaire, statut (PUBLIE, SIGNALE, MASQUE),
///  deposeLe (ISO 8601)}.
///
/// Les avis publics d'un praticien (`GET /api/medecins/{id}/avis`) n'exposent que
/// {id, note, commentaire, deposeLe} : les autres champs restent alors vides.
class Avis {
  const Avis({
    required this.id,
    required this.rendezVousId,
    required this.medecinId,
    required this.note,
    this.commentaire,
    required this.statut,
    this.deposeLe,
  });

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide,
  /// une note a zero, un commentaire absent ou une date absente ; identifiants en texte.
  factory Avis.fromJson(Map<String, dynamic> json) {
    return Avis(
      id: _texte(json['id']),
      rendezVousId: _texte(json['rendezVousId']),
      medecinId: _texte(json['medecinId']),
      note: _entier(json['note']),
      commentaire: _texteOuNull(json['commentaire']),
      statut: _texte(json['statut']),
      deposeLe: _date(json['deposeLe']),
    );
  }

  final String id;
  final String rendezVousId;
  final String medecinId;

  /// Note de 1 a 5 ; 0 si absente.
  final int note;

  /// Commentaire libre ; null s'il est absent ou vide.
  final String? commentaire;

  /// PUBLIE, SIGNALE ou MASQUE (valeur brute de l'API) ; vide pour un avis public.
  final String statut;

  /// Date de depot ; null si absente ou illisible.
  final DateTime? deposeLe;

  /// Vrai si le patient a laisse un commentaire.
  bool get aCommentaire => commentaire != null;

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  /// Chaine non vide (espaces retires), ou null si le champ est absent, nul ou vide.
  static String? _texteOuNull(Object? valeur) {
    final texte = _texte(valeur).trim();
    return texte.isEmpty ? null : texte;
  }

  static int _entier(Object? valeur) => valeur is num ? valeur.toInt() : 0;

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;
}
