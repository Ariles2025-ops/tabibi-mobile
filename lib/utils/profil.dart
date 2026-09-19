// Lecture et validation du profil (voir `Profil`) : telephone algerien, langues acceptees
// par l'API, dates affichees.

import '../i18n/traductions.dart' as i18n;
import '../models/profil.dart';
import 'dates.dart';

/// Nom de chaque langue acceptee par l'API, dans sa propre langue et dans l'ordre du menu :
/// francais, arabe, kabyle (taqbaylit), anglais. Un nom de langue ne se traduit pas : il
/// s'ecrit toujours de la meme facon, quelle que soit la langue de l'interface (voir
/// `nomsLangues` pour les seules langues de l'interface).
const Map<String, String> libellesLangues = {
  'fr': 'Français',
  'ar': 'العربية',
  'kab': 'Taqbaylit',
  'en': 'English',
};

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
String libelleDateNaissance(String langue, DateTime? dateNaissance) =>
    dateNaissance == null
        ? i18n.traduire(langue, 'profil.nonRenseignee')
        : formaterJour(langue, dateNaissance);

/// « Mis à jour le jeu. 4 déc. 09:00 » ; « Profil non enregistré » tant que le serveur n'a
/// jamais date le profil.
String libelleMiseAJour(String langue, Profil profil) {
  final misAJourLe = profil.misAJourLe;
  if (misAJourLe == null) return i18n.traduire(langue, 'profil.nonEnregistre');
  return i18n.traduire(langue, 'profil.misAJourLe',
      params: {'date': formaterDateHeure(langue, misAJourLe)});
}
