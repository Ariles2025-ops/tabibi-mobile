import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/lancement.dart';
import 'config/referentiel.dart';
import 'config/theme.dart';
import 'i18n/langue.dart';

import 'pages/compte_page.dart';
import 'pages/connexion_page.dart';
import 'pages/dawini_page.dart';
import 'pages/espace/mon_espace_page.dart';
import 'pages/fiche_medecin_page.dart';
import 'pages/mes_avis_page.dart';
import 'pages/mes_conversations_page.dart';
import 'pages/mes_listes_attente_page.dart';
import 'pages/mes_notifications_page.dart';
import 'pages/mes_ordonnances_page.dart';
import 'pages/mes_rendez_vous_page.dart';
import 'pages/mes_teleconsultations_page.dart';
import 'pages/mon_profil_page.dart';
import 'pages/verifier_ordonnance_page.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/session.dart';
import 'utils/espace_pro.dart';
import 'utils/identifiants.dart';
import 'utils/notifications.dart';
import 'utils/liens_appli.dart';
import 'utils/praticien.dart';
import 'widgets/composants.dart';
import 'widgets/selecteur_langue.dart';
import 'widgets/vue_erreur.dart';

/// Navigateur racine : l'ecran de connexion s'ouvre par-dessus la page qui le demande.
final navigateurPrincipal = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Langue.initialiser();
  brancherRafraichissement();
  // Connexion dans l'appli (ecran natif), sans page web.
  AuthService.ecranConnexion = (auth) async {
    final navigateur = navigateurPrincipal.currentState;
    if (navigateur == null) return auth.seConnecterParNavigateur();
    final ok = await navigateur.push<bool>(
        MaterialPageRoute(builder: (_) => ConnexionPage(auth: auth)));
    return ok ?? false;
  };
  // Session enregistree (jeton rafraichi si besoin) : l'appli fermee ne deconnecte plus.
  await session.restaurer();
  runApp(const TabibiApp());
}

/// Appli : francais ou arabe (RTL) selon [Langue.courante] ; tout l'arbre se reconstruit
/// quand la langue change, ecrans ouverts compris.
class TabibiApp extends StatefulWidget {
  const TabibiApp({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<TabibiApp> createState() => _TabibiAppState();
}

class _TabibiAppState extends State<TabibiApp> {
  @override
  void initState() {
    super.initState();
    Langue.courante.addListener(_changement);
  }

  @override
  void dispose() {
    Langue.courante.removeListener(_changement);
    super.dispose();
  }

  /// Les textes passent par `t()` sans dependance d'heritage : chaque element est marque a
  /// reconstruire pour que les ecrans deja ouverts changent aussi de langue.
  void _changement() {
    setState(() {});
    void reconstruire(Element e) {
      e.markNeedsBuild();
      e.visitChildren(reconstruire);
    }

    (context as Element).visitChildren(reconstruire);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ndawik',
      navigatorKey: navigateurPrincipal,
      debugShowCheckedModeBanner: false,
      theme: Charte.theme(arabe: Langue.estArabe),
      locale: Langue.locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: CoqueApp(api: widget.api, auth: widget.auth),
      // Lien profond https://ndawik.com/medecins/{id} : ouvre la fiche au-dessus de l'accueil.
      onGenerateRoute: (reglages) {
        final id = medecinIdDepuisRoute(reglages.name);
        if (id == null) return null;
        return MaterialPageRoute<void>(
          settings: reglages,
          builder: (_) => FicheMedecinPage(medecinId: id, api: widget.api, auth: widget.auth),
        );
      },
    );
  }
}

/// Ecran d'accueil : recherche de praticiens, acces a la fiche, aux rendez-vous,
/// aux ordonnances (les miennes, ou la verification publique d'un code), aux
/// notifications (entree « Notifications (n) » avec le nombre de non lues), aux
/// teleconsultations, a la messagerie avec mes medecins, a mes avis, a Dawini
/// (demander un medicament aux pharmacies), a mes listes d'attente et a mon profil.
class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  late final AuthService _auth = widget.auth ?? session;
  final _nom = TextEditingController();
  String? _specialite;
  String? _wilaya;
  String? _commune;

  /// Communes proposees pour la wilaya choisie (GET /api/medecins/communes) ; vide sinon.
  List<String> _communes = [];
  int _seqCommunes = 0;
  List<Map<String, dynamic>> _resultats = [];
  bool _charge = false;

  /// Vrai une fois une recherche terminee (evite « Aucun médecin » avant la premiere).
  bool _recherchee = false;

  /// Message affiche a la place de la liste quand la recherche echoue (reseau, delai...).
  String? _erreur;

  /// Nombre de notifications non lues ; null tant qu'il est inconnu (hors connexion, echec).
  int? _nonLues;

  /// Roles du compte connecte (GET /api/moi) ; vide hors connexion.
  Set<String> _roles = {};

  /// Nombre total de praticiens trouves (X-Total-Count) ; null s'il est inconnu.
  int? _total;

  /// Page deja chargee (0 = la premiere).
  int _page = 0;

  /// Numero de la derniere demande : une reponse plus ancienne est ignoree.
  int _seq = 0;

  /// Remet la commune a zero et recharge la liste des communes (wilaya ou specialite change).
  Future<void> _chargerCommunes() async {
    final id = ++_seqCommunes;
    setState(() {
      _commune = null;
      _communes = [];
    });
    final wilaya = _wilaya;
    if (wilaya == null) return;
    try {
      final liste = await widget.api.communes(specialite: _specialite, wilaya: wilaya);
      if (mounted && id == _seqCommunes) setState(() => _communes = liste);
    } on Exception {
      // Liste indisponible : pas de menu, la recherche par wilaya reste possible.
    }
  }

  /// Lance la recherche ; avec [suite], ajoute la page suivante aux resultats affiches.
  Future<void> _rechercher({bool suite = false}) async {
    final page = suite ? _page + 1 : 0;
    int? total;
    final id = ++_seq;
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final r = await widget.api.rechercherMedecins(
          specialite: _specialite,
          wilaya: _wilaya,
          commune: _commune,
          q: _nom.text,
          page: page,
          surTotal: (n) => total = n);
      if (mounted && id == _seq) {
        setState(() {
          _resultats = suite ? [..._resultats, ...r] : r;
          _page = page;
          _total = total;
          _recherchee = true;
        });
      }
    } on Exception catch (e) {
      if (mounted && id == _seq) {
        setState(() {
          _erreur = messageErreur(e);
          if (!suite) {
            _resultats = [];
            _total = null;
          }
        });
      }
    } finally {
      if (mounted && id == _seq) setState(() => _charge = false);
    }
  }

  /// Connexion Keycloak si necessaire, puis confirmation « Connecte ».
  Future<void> _seConnecter() async {
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      setState(() {}); // met a jour l'icone de l'AppBar
      if (!ok) {
        _message(t('Connexion annulée', 'تم إلغاء تسجيل الدخول'));
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    var texte = t('Connecté', 'تم تسجيل الدخول');
    try {
      final moi = await widget.api.moi(token);
      texte = messageConnecte(moi);
      if (mounted) setState(() => _roles = rolesDe(moi));
    } on Exception {
      // Identite indisponible : message generique.
    }
    _message(texte);
    await _chargerNonLues();
  }

  /// Roles du compte (entree « Mon espace ») ; vides hors connexion ou en cas d'echec.
  Future<void> _chargerRoles() async {
    final token = _auth.accessToken;
    var roles = <String>{};
    if (token != null) {
      try {
        roles = rolesDe(await widget.api.moi(token));
      } on Exception {
        roles = _roles;
      }
    }
    if (mounted) setState(() => _roles = roles);
  }

  /// Nombre de notifications non lues (jeton requis) ; inconnu hors connexion ou en cas d'echec.
  Future<void> _chargerNonLues() async {
    final token = _auth.accessToken;
    int? nonLues;
    if (token != null) {
      try {
        nonLues = await widget.api.nombreNonLues(token);
      } on ApiException catch (e) {
        // Jeton expire : l'icone de connexion repasse a « Se connecter ».
        if (e.nonAutorise) _auth.seDeconnecter();
      } on Exception {
        // Compteur indisponible : l'entree reste « Notifications ».
      }
    }
    if (mounted && nonLues != _nonLues) setState(() => _nonLues = nonLues);
  }

  /// Au retour d'un ecran : l'utilisateur a pu se connecter (ou etre deconnecte)
  /// et lire des notifications.
  Future<void> _apresRetour() async {
    if (!mounted) return;
    setState(() {});
    await _chargerNonLues();
    await _chargerRoles();
  }

  Future<void> _ouvrirMonEspace() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MonEspacePage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  /// Ouvre la fiche d'un praticien ([medecinId] : UUID en texte).
  Future<void> _ouvrirFiche(String medecinId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FicheMedecinPage(
            medecinId: medecinId, api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  Future<void> _ouvrirNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesNotificationsPage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour(); // des notifications ont pu etre lues
  }

  Future<void> _ouvrirTeleconsultations() async {
    if (!visioActive) return; // entree desactivee « Bientôt »
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesTeleconsultationsPage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  Future<void> _ouvrirMessagerie() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesConversationsPage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  Future<void> _ouvrirMesAvis() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesAvisPage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  Future<void> _ouvrirDawini() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DawiniPage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  Future<void> _ouvrirListesAttente() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesListesAttentePage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  Future<void> _ouvrirMonProfil() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MonProfilPage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  /// Verification publique d'un code d'ordonnance : aucun jeton necessaire.
  void _ouvrirVerification() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifierOrdonnancePage(api: widget.api),
      ),
    );
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  void initState() {
    super.initState();
    _rechercher();
    _chargerNonLues();
    _chargerRoles();
  }

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  /// Specialites mises en avant : (slug, emoji, libelle court FR, AR, fond doux de la charte).
  static const _populaires = <(String, String, String, String, Color)>[
    ('medecin-generaliste', '🩺', 'Généraliste', 'طبيب عام', Charte.pastille),
    ('dentiste', '🦷', 'Dentiste', 'أسنان', Charte.orClair),
    ('pediatre', '👶', 'Pédiatre', 'أطفال', Charte.fondDoux),
    ('gynecologue', '🤰', 'Gynéco', 'نساء وتوليد', Charte.vertTresClair),
    ('cardiologue', '❤️', 'Cardio', 'قلب', Charte.orClair),
    ('dermatologue', '✨', 'Dermato', 'جلد', Charte.pastille),
    ('ophtalmologue', '👁️', 'Ophtalmo', 'عيون', Charte.vertTresClair),
    ('ORL', '👂', 'ORL', 'أنف وأذن', Charte.fondDoux),
  ];

  /// Sans filtre, l'accueil montre quelques praticiens puis « Voir tous les médecins ».
  static const _apercu = 5;
  bool _tousMedecins = false;

  bool get _filtre =>
      _specialite != null || _wilaya != null || _nom.text.trim().isNotEmpty;

  void _choisirSpecialite(String slug) {
    setState(() => _specialite = _specialite == slug ? null : slug);
    _chargerCommunes();
    _rechercher();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final tous = _tousMedecins || _filtre;
    final affiches = tous ? _resultats : _resultats.take(_apercu).toList();
    return Scaffold(
      body: RefreshIndicator(
        color: Charte.vert,
        onRefresh: _rechercher,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _enTete(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (prelancement) const _BandeauLancement(),
                    _TitreSection(t('Spécialités', 'التخصصات')),
                    const SizedBox(height: 12),
                    _grilleSpecialites(),
                    const SizedBox(height: 24),
                    _TitreSection(t('Raccourcis', 'اختصارات')),
                    const SizedBox(height: 12),
                    _entrees(),
                    const SizedBox(height: 24),
                    _TitreSection(
                      _specialite == null
                          ? t('Médecins sur Ndawik', 'الأطباء على نداويك')
                          : nomSpecialite(specialites
                              .firstWhere((s) => s.slug == _specialite)),
                    ),
                    const SizedBox(height: 4),
                    if (_total != null && _resultats.isNotEmpty)
                      Text(messageNombreMedecins(_resultats.length, _total!),
                          style: tt.bodySmall),
                    const SizedBox(height: 12),
                    if (_charge) const LinearProgressIndicator(),
                    if (_erreur != null)
                      VueErreur(message: _erreur!, onReessayer: _rechercher),
                    if (_recherchee &&
                        !_charge &&
                        _erreur == null &&
                        _resultats.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(messageAucunMedecin(),
                            textAlign: TextAlign.center, style: tt.bodyMedium),
                      ),
                    for (final m in affiches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CarteMedecin(
                            medecin: m,
                            onTap: () => _ouvrirFiche(identifiant(m['id']))),
                      ),
                    if (!tous && _resultats.length > _apercu)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _tousMedecins = true),
                        icon: const Icon(Icons.expand_more),
                        label:
                            Text(t('Voir tous les médecins', 'عرض كل الأطباء')),
                      )
                    else if (_total != null &&
                        _resultats.length < _total! &&
                        !_charge)
                      OutlinedButton(
                        onPressed: () => _rechercher(suite: true),
                        child: Text(messageAfficherPlus()),
                      ),
                    const SizedBox(height: 24),
                    const _CommentCaMarche(),
                    const SizedBox(height: 16),
                    const _BandeauConfiance(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// En-tete de marque : logo, langue et connexion, accroche, puis la carte de recherche.
  Widget _enTete(BuildContext context) {
    const clair = Colors.white;
    final connecte = _auth.estConnecte;
    return Container(
      decoration: const BoxDecoration(
        gradient: Charte.degrade,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconTheme(
                data: const IconThemeData(color: clair),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/img/logo-ndawik.png',
                        width: 32, height: 32, excludeFromSemantics: true),
                  ),
                  const SizedBox(width: 10),
                  const Text('Ndawik',
                      style: TextStyle(
                          color: clair,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                  const Spacer(),
                  const SelecteurLangue(),
                  IconButton(
                    tooltip: connecte
                        ? t('Connecté', 'متصل')
                        : t('Se connecter', 'تسجيل الدخول'),
                    onPressed: _seConnecter,
                    icon: Icon(connecte
                        ? Icons.account_circle
                        : Icons.account_circle_outlined),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        t('Votre santé ne devrait jamais attendre',
                            'صحتك لا تحتمل الانتظار'),
                        style: const TextStyle(
                            color: clair,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('Trouvez un médecin et prenez rendez-vous, gratuitement.',
                            'ابحث عن طبيب واحجز موعدك مجانًا.'),
                        style: TextStyle(
                            color: clair.withValues(alpha: 0.85),
                            fontSize: 15,
                            height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: Charte.ombreRecherche,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          TextField(
                            controller: _nom,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              labelText: t('Nom du médecin', 'اسم الطبيب'),
                              prefixIcon:
                                  const Icon(Icons.search, color: Charte.vert),
                            ),
                            onSubmitted: (_) => _rechercher(),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('specialite-$_specialite'),
                                initialValue: _specialite,
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: t('Spécialité', 'التخصص')),
                                items: [
                                  DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(t('Toutes', 'الكل'))),
                                  for (final sp in specialites)
                                    DropdownMenuItem(
                                        value: sp.slug,
                                        child: Text(nomSpecialite(sp),
                                            overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (v) {
                                  setState(() => _specialite = v);
                                  _chargerCommunes();
                                  _rechercher();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _wilaya,
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: t('Wilaya', 'الولاية')),
                                items: [
                                  DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(t('Toutes', 'الكل'))),
                                  for (final w in wilayas)
                                    DropdownMenuItem(
                                        value: w.code,
                                        child: Text(
                                            '${w.code} - ${nomWilaya(w)}',
                                            overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (v) {
                                  setState(() => _wilaya = v);
                                  _chargerCommunes();
                                  _rechercher();
                                },
                              ),
                            ),
                          ]),
                          if (_wilaya != null && _communes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              key: ValueKey('commune-$_wilaya-$_commune'),
                              initialValue: _commune,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: t('Commune', 'البلدية')),
                              items: [
                                DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(t('Toutes', 'الكل'))),
                                for (final c in _communes)
                                  DropdownMenuItem(
                                      value: c,
                                      child: Text(c,
                                          overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) {
                                setState(() => _commune = v);
                                _rechercher();
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _rechercher,
                              icon: const Icon(Icons.search),
                              label: Text(t('Rechercher', 'بحث')),
                            ),
                          ),
                        ]),
                      ),
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Grille 4 x 2 de specialites en cartes de couleur douce ; un appui filtre la liste.
  Widget _grilleSpecialites() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: [
        for (final (slug, emoji, court, courtAr, fond) in _populaires)
          Material(
            color: _specialite == slug ? Charte.vert : fond,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _choisirSpecialite(slug),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(t(court, courtAr),
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _specialite == slug
                                    ? Colors.white
                                    : Charte.texte)),
                      ),
                    ),
                  ]),
            ),
          ),
      ],
    );
  }

  /// Raccourcis de l'espace personnel, sur une rangee defilante : « Mon espace » (selon le role),
  /// « Notifications (n) », « Téléconsultation · Bientôt » (desactivee tant que la visio est
  /// fermee), « Messagerie », « Mes avis », « Dawini (pharmacies) », « Mes listes d'attente »,
  /// « Mon profil », « Vérifier une ordonnance ».
  Widget _entrees() {
    Widget puce(IconData icone, String libelle, VoidCallback? action) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ActionChip(
            avatar: Icon(icone,
                size: 18,
                color: action == null ? Charte.placeholder : Charte.vert),
            label: Text(libelle),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            onPressed: action,
          ),
        );
    return SingleChildScrollView(
      key: const ValueKey('entrees-accueil'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (aUnEspacePro(_roles))
            puce(
                Icons.work_outline, t('Mon espace', 'فضائي'), _ouvrirMonEspace),
          puce(Icons.notifications_outlined, libelleNotifications(_nonLues),
              _ouvrirNotifications),
          puce(
            Icons.videocam_outlined,
            visioActive
                ? t('Téléconsultations', 'الاستشارات عن بُعد')
                : t('Téléconsultation · Bientôt', 'الاستشارة عن بُعد · قريبًا'),
            visioActive ? _ouvrirTeleconsultations : null,
          ),
          puce(Icons.chat_bubble_outline, t('Messagerie', 'الرسائل'),
              _ouvrirMessagerie),
          puce(Icons.star_outline, t('Mes avis', 'آرائي'), _ouvrirMesAvis),
          puce(Icons.local_pharmacy_outlined,
              t('Dawini (pharmacies)', 'داويني (الصيدليات)'), _ouvrirDawini),
          puce(
              Icons.hourglass_top_outlined,
              t("Mes listes d'attente", 'قوائم الانتظار'),
              _ouvrirListesAttente),
          puce(Icons.badge_outlined, t('Mon profil', 'ملفي الشخصي'),
              _ouvrirMonProfil),
          puce(
              Icons.verified_outlined,
              t('Vérifier une ordonnance', 'التحقق من وصفة طبية'),
              _ouvrirVerification),
        ],
      ),
    );
  }
}

/// Titre de section de l'accueil.
class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(texte,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18));
  }
}

/// Carte praticien : avatar, nom, specialite et ville, pastille « Voir ».
class _CarteMedecin extends StatelessWidget {
  const _CarteMedecin({required this.medecin, required this.onTap});

  final Map<String, dynamic> medecin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nom = identifiant(medecin['nomComplet']);
    final tt = Theme.of(context).textTheme;
    return CarteTabibi(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        AvatarInitiales(nom: nom, rayon: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Charte.meta),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(sousTitrePraticien(medecin),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall),
                ),
              ]),
              if (estReservable(medecin)) ...[
                const SizedBox(height: 8),
                PastilleStatut(
                    key: const ValueKey('badge-reservable'),
                    libelle: libelleReservable(),
                    statut: 'CONFIRME'),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: Charte.pastille, borderRadius: BorderRadius.circular(999)),
          child: Text(t('Voir', 'عرض'),
              style: const TextStyle(
                  color: Charte.vert,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ]),
    );
  }
}

/// Trois etapes : chercher, choisir un creneau, recevoir la confirmation.
class _CommentCaMarche extends StatelessWidget {
  const _CommentCaMarche();

  @override
  Widget build(BuildContext context) {
    Widget etape(String numero, String titre, String texte) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: Charte.vert, shape: BoxShape.circle),
              child: Text(numero,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Charte.texte,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(texte,
                        style: const TextStyle(
                            color: Charte.doux, fontSize: 14, height: 1.4)),
                  ]),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      decoration: BoxDecoration(
          color: Charte.pastille, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Comment ça marche ?', 'كيف يعمل؟'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Charte.vertFonce)),
        const SizedBox(height: 16),
        etape(
            '1',
            t('Cherchez', 'ابحث'),
            t('Un médecin par nom, spécialité ou wilaya.',
                'عن طبيب بالاسم أو التخصص أو الولاية.')),
        etape(
            '2',
            t('Choisissez un créneau', 'اختر موعدًا'),
            t('Les disponibilités réelles du cabinet.',
                'المواعيد المتاحة فعلًا في العيادة.')),
        etape('3', t('Recevez la confirmation', 'استلم التأكيد'),
            t('Et un rappel avant votre rendez-vous.', 'وتذكيرًا قبل موعدك.')),
      ]),
    );
  }
}

/// Bandeau de confiance en bas de l'accueil.
class _BandeauConfiance extends StatelessWidget {
  const _BandeauConfiance();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icone, String texte) => Expanded(
          child: Column(children: [
            Icon(icone, color: Charte.or, size: 24),
            const SizedBox(height: 8),
            Text(texte,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Charte.texte)),
          ]),
        );
    return CarteTabibi(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(children: [
        point(Icons.volunteer_activism_outlined,
            t('Gratuit pour les patients', 'مجاني للمرضى')),
        point(Icons.map_outlined, t('69 wilayas', '69 ولاية')),
        point(Icons.lock_outline, t('Données protégées', 'بيانات محمية')),
      ]),
    );
  }
}

/// Bandeau de pré-lancement, même texte que le site, en or clair (distinction).
class _BandeauLancement extends StatelessWidget {
  const _BandeauLancement();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Charte.orClair,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Charte.or.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.rocket_launch_outlined,
            color: Charte.orTexte, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Lancement prochainement', 'الإطلاق قريبًا'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Charte.orTexte,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Text(
                t("La prise de rendez-vous en ligne ouvre très bientôt. Trouvez déjà un médecin sur la plateforme.",
                    'حجز المواعيد عبر الإنترنت يفتح قريبًا جدًا. منصة طبية: ابحث عن طبيب من الآن.'),
                style: const TextStyle(
                    color: Charte.texte, fontSize: 14, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

/// Coque de l'appli : barre de navigation en bas (Accueil, Rendez-vous, Ordonnances, Compte).
/// L'onglet choisi est reconstruit a chaque visite pour refleter la connexion du moment.
class CoqueApp extends StatefulWidget {
  const CoqueApp({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<CoqueApp> createState() => _CoqueAppState();
}

class _CoqueAppState extends State<CoqueApp> {
  int _onglet = 0;
  int _visite = 0;

  /// Roles du compte connecte : un compte pro sans role PATIENT est renvoye vers « Mon espace »
  /// sur les onglets Rendez-vous et Ordonnances.
  Set<String> _roles = {};

  AuthService get _auth => widget.auth ?? session;

  @override
  void initState() {
    super.initState();
    _chargerRoles();
  }

  Future<void> _chargerRoles() async {
    final token = _auth.accessToken;
    var roles = <String>{};
    if (token != null) {
      try {
        roles = rolesDe(await widget.api.moi(token));
      } on Exception {
        roles = _roles;
      }
    }
    if (mounted) setState(() => _roles = roles);
  }

  /// Page reservee aux patients : message guide et acces direct a « Mon espace ».
  Widget _reservePatient(String titre) => Scaffold(
        appBar: AppBar(title: Text(titre)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(messagePageReservee(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            MonEspacePage(api: widget.api, auth: _auth))),
                icon: const Icon(Icons.work_outline),
                label: Text(t('Mon espace', 'فضائي')),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    final pro = comptePro(_roles);
    final pages = <Widget>[
      RecherchePage(api: widget.api, auth: auth),
      pro
          ? _reservePatient(t('Mes rendez-vous', 'مواعيدي'))
          : MesRendezVousPage(
              key: ValueKey('rdv-$_visite'),
              api: widget.api,
              auth: auth,
              onTrouverPraticien: () => setState(() => _onglet = 0)),
      pro
          ? _reservePatient(t('Mes ordonnances', 'وصفاتي الطبية'))
          : MesOrdonnancesPage(
              key: ValueKey('ord-$_visite'), api: widget.api, auth: auth),
      ComptePage(key: ValueKey('compte-$_visite'), api: widget.api, auth: auth),
    ];
    return Scaffold(
      body: IndexedStack(index: _onglet, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Charte.bordure))),
        child: NavigationBar(
          selectedIndex: _onglet,
          onDestinationSelected: (i) {
            setState(() {
              _onglet = i;
              _visite++;
            });
            _chargerRoles();
          },
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: t('Accueil', 'الرئيسية')),
            NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: t('Rendez-vous', 'المواعيد')),
            NavigationDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: const Icon(Icons.description),
                label: t('Ordonnances', 'الوصفات')),
            NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: t('Compte', 'الحساب')),
          ],
        ),
      ),
    );
  }
}
