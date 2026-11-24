// Liens profonds : https://ndawik.com/medecins/{id} (declare dans AndroidManifest.xml) ouvre la
// fiche du praticien, comme sur le site. Les pages publiques /praticiens/{id}[/slug] et leur
// version arabe /ar/... pointent vers la meme fiche.

final RegExp _lienMedecin = RegExp(r'^(?:/ar)?/(?:medecins|praticiens)/([^/?#]+)(?:/[^/?#]*)?/?$');

/// Identifiant du praticien d'un lien ou d'une route (« /medecins/abc », « /ar/praticiens/abc/dr-x »,
/// avec ou sans requete) ; null si la route n'est pas une fiche de praticien.
String? medecinIdDepuisRoute(String? route) {
  if (route == null) return null;
  final chemin = route.split(RegExp(r'[?#]')).first;
  final id = _lienMedecin.firstMatch(chemin)?.group(1);
  if (id == null) return null;
  final decode = decoderSegment(id)?.trim();
  return decode == null || decode.isEmpty ? null : decode;
}

/// Decode un segment de lien (« %20 » -> espace) ; null si l'encodage est invalide (« %E0%A4% »),
/// pour qu'un lien mal forme n'ouvre rien au lieu de faire planter l'ecran.
String? decoderSegment(String segment) {
  try {
    return Uri.decodeComponent(segment);
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}
