// Identifiants renvoyes par l'API : le backend identifie tout (praticien, creneau, rendez-vous,
// ordonnance, conversation, avis, besoin...) par un UUID serialise en texte dans le JSON, par
// exemple « 00000000-0000-0000-0000-000000000001 » pour les praticiens de demonstration.
// Un identifiant n'est donc jamais lu comme un nombre (`as int`, `int.parse`) ni compare ou
// trie numeriquement : il est conserve en texte de bout en bout.

/// Nombre de caracteres conserves par [abreger] : le premier groupe d'un UUID.
const int longueurAbregee = 8;

/// Identifiant en texte, quelle que soit la forme recue (chaine, nombre...) ; chaine vide si
/// la valeur est absente. A utiliser a la place d'un `as int` ou d'un `as String` sur un champ
/// `id`, `medecinId`, `rendezVousId`...
String identifiant(Object? valeur) => valeur?.toString() ?? '';

/// Forme abregee pour l'affichage : les 8 premiers caracteres (« 00000000 » pour
/// « 00000000-0000-0000-0000-000000000001 ») ; l'identifiant entier s'il est plus court.
String abreger(String id) => id.length <= longueurAbregee ? id : id.substring(0, longueurAbregee);

/// Libelle d'un praticien dont la fiche est indisponible : « Médecin 00000000 »
/// (identifiant abrege) ; « Médecin inconnu » sans identifiant.
String libelleMedecin(String id) => id.isEmpty ? 'Médecin inconnu' : 'Médecin ${abreger(id)}';
