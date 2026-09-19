import 'avis.dart';

/// Synthese publique des avis d'un praticien, telle que renvoyee par
/// `GET /api/medecins/{id}/avis` : {moyenne (nombre decimal ou null), nombre,
/// avis: [{id, note, commentaire, deposeLe}]} (derniers avis, anonymes).
class SyntheseAvis {
  const SyntheseAvis({this.moyenne, this.nombre = 0, this.avis = const []});

  /// Lecture tolerante d'une carte JSON : moyenne absente ou nulle, nombre a zero et liste
  /// vide quand les champs manquent ; les elements de `avis` qui ne sont pas des cartes
  /// sont ignores.
  factory SyntheseAvis.fromJson(Map<String, dynamic> json) {
    final Object? moyenne = json['moyenne'];
    final Object? nombre = json['nombre'];
    final Object? liste = json['avis'];
    return SyntheseAvis(
      moyenne: moyenne is num ? moyenne.toDouble() : null,
      nombre: nombre is num ? nombre.toInt() : 0,
      avis: liste is List
          ? [
              for (final Object? element in liste)
                if (element is Map) Avis.fromJson(element.cast<String, dynamic>()),
            ]
          : const [],
    );
  }

  /// Moyenne des notes (1..5) ; null tant qu'aucun avis n'est publie.
  final double? moyenne;

  /// Nombre d'avis publies.
  final int nombre;

  /// Derniers avis publies, anonymes.
  final List<Avis> avis;

  /// Vrai si au moins un avis est publie (moyenne connue).
  bool get aDesAvis => moyenne != null && nombre > 0;
}
