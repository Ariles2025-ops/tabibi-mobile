// Lecture et validation du profil (voir `Profil`) : telephone algerien, langues de
// l'interface, dates affichees.

import '../models/profil.dart';
import 'dates.dart';

/// Libelles des langues de l'interface, par code accepte par l'API et dans l'ordre du menu :
/// francais, arabe, kabyle (taqbaylit), anglais.
const Map<String, String> libellesLangues = {
  'fr': 'Français',
  'ar': 'العربية',
  'kab': 'Taqbaylit',
  'en': 'English',
};

/// Message affiche quand le telephone saisi n'est pas un numero algerien valide.
const String messageTelephoneInvalide =
    'Le téléphone doit compter 9 à 10 chiffres et commencer par 0 (ex. 0550123456).';

/// Numero algerien, mobile (« 0550123456 ») ou fixe (« 021123456 ») : chiffres seulement,
/// 9 a 10 chiffres commencant par 0 (meme regle que l'API).
final RegExp _telephoneAlgerien = RegExp(r'^0[0-9]{8,9}$');

/// « Français » pour « fr », « English » pour « en »... ; le code lui-meme s'il est inconnu.
String libelleLangue(String code) => libellesLangues[code] ?? code;

/// Numero sans espaces (« 05 50 12 34 56 » -> « 0550123456 ») ; null s'il est vide, le
/// telephone etant facultatif.
String? normaliserTelephone(String? telephone) {
  if (telephone == null) return null;
  final chiffres = telephone.replaceAll(RegExp(r'\s+'), '');
  return chiffres.isEmpty ? null : chiffres;
}

/// Vrai si le numero, une fois les espaces retires, est un numero algerien de 9 a 10 chiffres
/// commencant par 0 ; un numero vide est accepte (telephone facultatif).
bool telephoneValide(String? telephone) {
  final chiffres = normaliserTelephone(telephone);
  return chiffres == null || _telephoneAlgerien.hasMatch(chiffres);
}

/// « 14 mai 1990 » ; « Non renseignée » sans date.
String libelleDateNaissance(DateTime? dateNaissance) =>
    dateNaissance == null ? 'Non renseignée' : formaterJour(dateNaissance);

/// « Mis à jour le jeu. 4 dec. 09:00 » ; « Profil non enregistré » tant que le serveur n'a
/// jamais date le profil.
String libelleMiseAJour(Profil profil) {
  final misAJourLe = profil.misAJourLe;
  if (misAJourLe == null) return 'Profil non enregistré';
  return 'Mis à jour le ${formaterDateHeure(misAJourLe)}';
}
