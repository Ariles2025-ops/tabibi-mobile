/// Besoin en medicament publie par le patient aupres des pharmacies (Dawini), tel que
/// renvoye par `POST /api/dawini/besoins` et `GET /api/dawini/besoins/mes` :
/// {id, patientId, medicament, wilayaCode, commune, precision, statut (OUVERT, CLOTURE),
///  publieLe, clotureLe (ISO 8601), nombreReponses}.
///
/// Valeur immuable : la cloturer produit une copie ([cloturer]).
class BesoinMedicament {
  const BesoinMedicament({
    required this.id,
    required this.patientId,
    required this.medicament,
    required this.wilayaCode,
    this.commune,
    this.precision,
    required this.statut,
    this.publieLe,
    this.clotureLe,
    this.nombreReponses = 0,
  });

  /// Lecture tolerante d'une carte JSON : un champ absent ou nul devient une chaine vide,
  /// une valeur absente, une date absente ou zero reponse ; identifiants en texte.
  factory BesoinMedicament.fromJson(Map<String, dynamic> json) {
    return BesoinMedicament(
      id: _texte(json['id']),
      patientId: _texte(json['patientId']),
      medicament: _texte(json['medicament']),
      wilayaCode: _texte(json['wilayaCode']),
      commune: _texteOuNull(json['commune']),
      precision: _texteOuNull(json['precision']),
      statut: _texte(json['statut']),
      publieLe: _date(json['publieLe']),
      clotureLe: _date(json['clotureLe']),
      nombreReponses: _entier(json['nombreReponses']),
    );
  }

  final String id;
  final String patientId;
  final String medicament;

  /// Code de la wilaya (« 16 » pour Alger).
  final String wilayaCode;

  /// Commune ; null si elle n'a pas ete precisee.
  final String? commune;

  /// Precision libre (dosage, forme, urgence...) ; null si absente.
  final String? precision;

  /// OUVERT ou CLOTURE (valeur brute de l'API).
  final String statut;

  /// Date de publication ; null si absente ou illisible.
  final DateTime? publieLe;

  /// Date de cloture ; null tant que la demande est ouverte.
  final DateTime? clotureLe;

  /// Nombre de reponses de pharmacies recues.
  final int nombreReponses;

  /// Copie de la demande une fois cloturee (statut CLOTURE, date de cloture [le]).
  BesoinMedicament cloturer(DateTime le) => BesoinMedicament(
        id: id,
        patientId: patientId,
        medicament: medicament,
        wilayaCode: wilayaCode,
        commune: commune,
        precision: precision,
        statut: 'CLOTURE',
        publieLe: publieLe,
        clotureLe: le,
        nombreReponses: nombreReponses,
      );

  static String _texte(Object? valeur) => valeur?.toString() ?? '';

  /// Chaine non vide (espaces retires), ou null si le champ est absent, nul ou vide.
  static String? _texteOuNull(Object? valeur) {
    final texte = _texte(valeur).trim();
    return texte.isEmpty ? null : texte;
  }

  static int _entier(Object? valeur) => valeur is num ? valeur.toInt() : 0;

  static DateTime? _date(Object? valeur) => valeur is String ? DateTime.tryParse(valeur) : null;
}
