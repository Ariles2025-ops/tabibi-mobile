/// Profil de l'utilisateur connecte, tel que renvoye par `GET /api/moi/profil` et
/// `PUT /api/moi/profil` :
/// {utilisateurId, nomComplet, telephone, dateNaissance (yyyy-MM-dd), wilayaCode, langue,
///  misAJourLe (ISO 8601)}.
///
/// Seul le nom complet est obligatoire ; `langue` vaut fr, ar, kab ou en (fr par defaut).
/// [toJson] produit le corps attendu par `PUT /api/moi/profil`, sans l'identifiant ni la date
/// de mise a jour, qui sont fixes par le serveur. Valeur immuable.
class Profil {
  const Profil({
    this.utilisateurId = '',
    required this.nomComplet,
    this.telephone,
    this.dateNaissance,
    this.wilayaCode,
    this.langue = langueParDefaut,
    this.misAJourLe,
  });

  /// Langue retenue par l'API quand aucune n'est indiquee.
  static const String langueParDefaut = 'fr';

  /// Codes de langue acceptes par l'API, dans l'ordre du menu de l'application.
  static const List<String> langues = ['fr', 'ar', 'kab', 'en'];

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide,
  /// une valeur absente, une date absente ou la langue par defaut ; identifiant en texte.
  factory Profil.fromJson(Map<String, dynamic> json) {
    return Profil(
      utilisateurId: _texte(json['utilisateurId']),
      nomComplet: _texte(json['nomComplet']).trim(),
      telephone: _texteOuNull(json['telephone']),
      dateNaissance: _jour(json['dateNaissance']),
      wilayaCode: _texteOuNull(json['wilayaCode']),
      langue: _texteOuNull(json['langue']) ?? langueParDefaut,
      misAJourLe: _date(json['misAJourLe']),
    );
  }

  /// Sujet du jeton de l'utilisateur (UUID en texte) ; vide tant que le serveur ne l'a pas
  /// renvoye.
  final String utilisateurId;
  final String nomComplet;

  /// Numero algerien sans espaces (« 0550123456 ») ; null s'il n'a pas ete renseigne.
  final String? telephone;

  /// Date de naissance (jour seulement, heure locale a minuit) ; null si absente.
  final DateTime? dateNaissance;

  /// Code de la wilaya (« 16 » pour Alger) ; null s'il n'a pas ete renseigne.
  final String? wilayaCode;

  /// fr, ar, kab ou en.
  final String langue;

  /// Date de derniere mise a jour ; null tant que le profil n'a pas ete enregistre.
  final DateTime? misAJourLe;

  /// Corps de `PUT /api/moi/profil` : {nomComplet, telephone, dateNaissance (yyyy-MM-dd ou
  /// null), wilayaCode, langue}.
  Map<String, dynamic> toJson() => {
        'nomComplet': nomComplet,
        'telephone': telephone,
        'dateNaissance': _jourIso(dateNaissance),
        'wilayaCode': wilayaCode,
        'langue': langue,
      };

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  /// Chaine non vide (espaces retires), ou null si le champ est absent, nul ou vide.
  static String? _texteOuNull(Object? valeur) {
    final texte = _texte(valeur).trim();
    return texte.isEmpty ? null : texte;
  }

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;

  /// Date seule (« 1990-05-14 »), ramenee a minuit en heure locale.
  static DateTime? _jour(Object? valeur) {
    final date = _date(valeur);
    return date == null ? null : DateTime(date.year, date.month, date.day);
  }

  /// « 1990-05-14 » (yyyy-MM-dd, les dix premiers caracteres de la forme ISO 8601) ; null
  /// sans date.
  static String? _jourIso(DateTime? date) => date?.toIso8601String().substring(0, 10);
}
