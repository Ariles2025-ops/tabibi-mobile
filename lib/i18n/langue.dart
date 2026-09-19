// Langue de l'interface : etat global, portee dans l'arbre de widgets et fonction `t`.
//
// Aucune generation de code (pas de `flutter gen-l10n`) : les textes viennent des cartes de
// `traductions.dart`. Un seul [ControleurLangue] est partage par l'application ([langues],
// comme `session` pour l'authentification) ; il est expose par [LangueScope] pour que `t`,
// [MaterialApp] (`locale`) et les widgets Material suivent le meme choix.
//
// Choix initial : la langue enregistree par l'utilisateur (`shared_preferences`), sinon la
// locale du telephone (ar -> ar, en -> en, sinon fr), sinon la langue du profil serveur tant
// que l'utilisateur n'a rien choisi manuellement.

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'traductions.dart';

/// Cle sous laquelle la langue choisie est memorisee sur le telephone.
const String cleLangueMemorisee = 'tabibi.langue';

/// Langue de l'interface, partagee par toute l'application.
///
/// Les pages ne l'utilisent pas directement : elles passent par [t] (ou [langueDe]), qui lit
/// le [LangueScope] le plus proche et retombe sur cette instance dans les tests unitaires.
final ControleurLangue langues = ControleurLangue();

/// Direction d'ecriture d'une langue : de droite a gauche pour l'arabe.
TextDirection directionDe(String langue) =>
    langue == 'ar' ? TextDirection.rtl : TextDirection.ltr;

/// Locale d'une langue de l'interface (« fr » -> `Locale('fr')`).
Locale localeDe(String langue) => Locale(langue);

/// Langue de l'interface correspondant a une locale du telephone : `ar` -> ar, `en` -> en,
/// toute autre (ou aucune) -> [langueParDefaut].
String langueDeLocale(Locale? locale) {
  final code = (locale?.languageCode ?? '').toLowerCase();
  return languesInterface.contains(code) ? code : langueParDefaut;
}

/// Locale du telephone ; null tant que le moteur ne l'a pas fournie.
Locale? localeDuTelephone() {
  final locales = WidgetsBinding.instance.platformDispatcher.locales;
  return locales.isEmpty ? null : locales.first;
}

/// Langue courante, son origine et sa persistance.
class ControleurLangue extends ChangeNotifier {
  String _langue = langueParDefaut;
  bool _choisie = false;

  /// Code de la langue affichee (fr, ar ou en).
  String get langue => _langue;

  /// Vrai si l'utilisateur a choisi la langue lui-meme : ni le telephone ni le profil ne la
  /// remplacent alors.
  bool get choisieManuellement => _choisie;

  Locale get locale => localeDe(_langue);

  TextDirection get direction => directionDe(_langue);

  /// Langues proposees par le selecteur, dans l'ordre.
  List<Locale> get localesPrisesEnCharge => [for (final l in languesInterface) localeDe(l)];

  /// Langue de depart : celle que l'utilisateur a enregistree, sinon celle du telephone.
  /// [preferences] n'est fourni que par les tests.
  Future<void> initialiser({Locale? locale, SharedPreferences? preferences}) async {
    final memorisee = await _lireMemorisee(preferences);
    if (memorisee != null) {
      _appliquer(memorisee, choisie: true);
      return;
    }
    _appliquer(langueDeLocale(locale), choisie: false);
  }

  /// Choix explicite de l'utilisateur (selecteur de langue) : applique et memorise.
  Future<void> choisir(String langue, {SharedPreferences? preferences}) async {
    if (!languesInterface.contains(langue)) return;
    _appliquer(langue, choisie: true);
    await _memoriser(langue, preferences);
  }

  /// Langue du profil serveur (`GET /api/moi/profil`) : elle n'est suivie que si l'utilisateur
  /// n'a rien choisi manuellement, et seulement si l'interface la connait (« kab » est accepte
  /// par l'API mais pas encore traduit).
  void suivreLeProfil(String? langue) {
    if (_choisie || langue == null || !languesInterface.contains(langue)) return;
    _appliquer(langue, choisie: false);
  }

  /// Remet la langue a [langue] sans rien memoriser (helper des tests, qui forcent « fr »).
  void reinitialiser([String langue = langueParDefaut]) =>
      _appliquer(languesInterface.contains(langue) ? langue : langueParDefaut, choisie: false);

  void _appliquer(String langue, {required bool choisie}) {
    if (_langue == langue && _choisie == choisie) return;
    _langue = langue;
    _choisie = choisie;
    notifyListeners();
  }

  /// Langue memorisee ; null si aucune, si elle n'est plus proposee ou si le stockage du
  /// telephone est indisponible (tests sans greffon).
  Future<String?> _lireMemorisee(SharedPreferences? preferences) async {
    final prefs = preferences ?? await _preferences();
    final memorisee = prefs?.getString(cleLangueMemorisee);
    return memorisee != null && languesInterface.contains(memorisee) ? memorisee : null;
  }

  Future<void> _memoriser(String langue, SharedPreferences? preferences) async {
    final prefs = preferences ?? await _preferences();
    await prefs?.setString(cleLangueMemorisee, langue);
  }

  /// Stockage du telephone ; null s'il est indisponible (greffon absent dans les tests, ou
  /// stockage refuse) : la langue est alors seulement appliquee, pas memorisee.
  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } on Exception {
      return null;
    }
  }
}

/// Porte la langue courante dans l'arbre de widgets : les dependants sont rebatis a chaque
/// changement de langue.
class LangueScope extends InheritedNotifier<ControleurLangue> {
  const LangueScope({super.key, required ControleurLangue controleur, required Widget child})
      : super(notifier: controleur, child: child);

  /// Controleur de la portee la plus proche ; [langues] a defaut (tests d'un ecran isole).
  static ControleurLangue de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LangueScope>()?.notifier ?? langues;
}

/// Langue courante pour ce contexte (a passer aux utilitaires de `lib/utils`).
String langueDe(BuildContext context) => LangueScope.de(context).langue;

/// Texte de [cle] dans la langue courante ; chaque `{nom}` de [params] est remplace.
String t(BuildContext context, String cle, {Map<String, Object?> params = const {}}) =>
    traduire(langueDe(context), cle, params: params);

/// Forme plurielle de [cleBase] pour [n] dans la langue courante (`{n}` remplace).
String tp(BuildContext context, String cleBase, int n) =>
    traduirePluriel(langueDe(context), cleBase, n);

/// Message a afficher pour une erreur d'appel a l'API, dans la langue courante : le message
/// du serveur quand il en donne un (il n'est pas traduisible ici), sinon le libelle par
/// defaut porte par [ApiException.cle].
String messageApi(BuildContext context, Object erreur) {
  final langue = langueDe(context);
  if (erreur is ApiException) {
    final cle = erreur.cle;
    return cle == null ? erreur.message : traduire(langue, cle, params: erreur.params);
  }
  return traduire(langue, 'api.serveurInjoignable');
}
