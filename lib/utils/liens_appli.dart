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
  final decode = Uri.decodeComponent(id).trim();
  return decode.isEmpty ? null : decode;
}
