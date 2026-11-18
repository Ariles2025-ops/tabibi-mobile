import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/lancement.dart';
import 'config/referentiel.dart';
import 'config/theme.dart';
import 'i18n/langue.dart';

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
import 'utils/praticien.dart';
import 'widgets/composants.dart';
import 'widgets/selecteur_langue.dart';
import 'widgets/vue_erreur.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Langue.initialiser();
  brancherRafraichissement();
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
      debugShowCheckedModeBanner: false,
      theme: Charte.theme(arabe: Langue.estArabe),
      locale: Langue.locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: RecherchePage(api: widget.api, auth: widget.auth),
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

  Future<void> _rechercher() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final r = await widget.api.rechercherMedecins(
          specialite: _specialite, wilaya: _wilaya, q: _nom.text);
      if (mounted) {
        setState(() {
          _resultats = r;
          _recherchee = true;
        });
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
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

  /// Message clair si un compte professionnel (sans role PATIENT) ouvre une page patient.
  bool _refuserSiPro() {
    if (!comptePro(_roles)) return false;
    _message(messagePageReservee());
    return true;
  }

  Future<void> _ouvrirMesRendezVous() async {
    if (_refuserSiPro()) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesRendezVousPage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  Future<void> _ouvrirMesOrdonnances() async {
    if (_refuserSiPro()) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesOrdonnancesPage(api: widget.api, auth: _auth),
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

  /// Specialites mises en avant sur l'accueil (emoji sur pastille verte).
  static const _populaires = <(String, String, String, String)>[
    ('medecin-generaliste', '🩺', 'Généraliste', 'طبيب عام'),
    ('dentiste', '🦷', 'Dentiste', 'أسنان'),
    ('pediatre', '👶', 'Pédiatre', 'أطفال'),
    ('gynecologue', '🤰', 'Gynéco', 'نساء وتوليد'),
    ('cardiologue', '❤️', 'Cardiologue', 'قلب'),
    ('dermatologue', '✨', 'Dermato', 'جلد'),
    ('ophtalmologue', '👁️', 'Ophtalmo', 'عيون'),
    ('ORL', '👂', 'ORL', 'أنف وأذن'),
  ];

  /// Sans filtre, l'accueil montre quelques praticiens puis « Voir tous les médecins ».
  static const _apercu = 5;
  bool _tousMedecins = false;

  bool get _filtre =>
      _specialite != null || _wilaya != null || _nom.text.trim().isNotEmpty;

  void _choisirSpecialite(String? slug) {
    setState(() => _specialite = _specialite == slug ? null : slug);
    _rechercher();
  }

  @override
  Widget build(BuildContext context) {
    final connecte = _auth.estConnecte;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/img/logo-ndawik.png',
                  width: 30, height: 30, excludeFromSemantics: true),
            ),
            const SizedBox(width: 10),
            const Text('Ndawik',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ],
        ),
        actions: [
          const SelecteurLangue(),
          IconButton(
            tooltip: connecte
                ? t('Connecté', 'متصل')
                : t('Se connecter', 'تسجيل الدخول'),
            onPressed: _seConnecter,
            icon: Icon(connecte ? Icons.account_circle : Icons.account_circle_outlined),
          ),
        ],
      ),
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
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (prelancement) const _BandeauLancement(),
                    _raccourcis(),
                    const SizedBox(height: 24),
                    _TitreSection(t('Spécialités populaires', 'التخصصات الأكثر طلبًا')),
                    const SizedBox(height: 12),
                    _specialitesPopulaires(),
                    const SizedBox(height: 24),
                    _TitreSection(t('Mon compte', 'حسابي')),
                    const SizedBox(height: 10),
                    _entrees(),
                    const SizedBox(height: 24),
                    const _CommentCaMarche(),
                    const SizedBox(height: 24),
                    _TitreSection(
                      _specialite == null
                          ? t('Médecins sur Ndawik', 'الأطباء على نداويك')
                          : nomSpecialite(
                              specialites.firstWhere((s) => s.slug == _specialite)),
                      suffixe: _resultats.isEmpty ? null : '${_resultats.length}',
                    ),
                    const SizedBox(height: 12),
                    if (_charge) const LinearProgressIndicator(),
                    if (_erreur != null)
                      VueErreur(message: _erreur!, onReessayer: _rechercher),
                    if (_recherchee && !_charge && _erreur == null && _resultats.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(messageAucunMedecin(),
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium?.copyWith(color: Charte.doux)),
                      ),
                    for (final m in (_tousMedecins || _filtre)
                        ? _resultats
                        : _resultats.take(_apercu))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CarteMedecin(
                            medecin: m, onTap: () => _ouvrirFiche(identifiant(m['id']))),
                      ),
                    if (!_tousMedecins && !_filtre && _resultats.length > _apercu)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _tousMedecins = true),
                        icon: const Icon(Icons.expand_more),
                        label: Text(t('Voir tous les médecins', 'عرض كل الأطباء')),
                      ),
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

  /// En-tete vert en degrade : accroche, puis carte de recherche (nom, specialite, wilaya)
  /// qui deborde legerement sur le fond.
  Widget _enTete(BuildContext context) {
    final clair = Theme.of(context).colorScheme.onPrimary;
    return Container(
      decoration: const BoxDecoration(
        gradient: Charte.degrade,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('Votre santé ne devrait jamais attendre', 'صحتك لا تحتمل الانتظار'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: clair, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            t('Trouvez un médecin et prenez rendez-vous, gratuitement.', 'ابحث عن طبيب واحجز موعدك مجانًا.'),
            style: TextStyle(color: clair.withValues(alpha: 0.85), fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x1A102822), blurRadius: 24, offset: Offset(0, 8)),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(
                controller: _nom,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: t('Nom du médecin', 'اسم الطبيب'),
                  prefixIcon: const Icon(Icons.search, color: Charte.vert),
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
                    decoration:
                        InputDecoration(labelText: t('Spécialité', 'التخصص')),
                    items: [
                      DropdownMenuItem<String>(
                          value: null, child: Text(t('Toutes', 'الكل'))),
                      for (final sp in specialites)
                        DropdownMenuItem(
                            value: sp.slug,
                            child: Text(nomSpecialite(sp),
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      setState(() => _specialite = v);
                      _rechercher();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _wilaya,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: t('Wilaya', 'الولاية')),
                    items: [
                      DropdownMenuItem<String>(
                          value: null, child: Text(t('Toutes', 'الكل'))),
                      for (final w in wilayas)
                        DropdownMenuItem(
                            value: w.code,
                            child: Text('${w.code} - ${nomWilaya(w)}',
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      setState(() => _wilaya = v);
                      _rechercher();
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 10),
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
        ],
      ),
    );
  }

  /// Quatre grandes tuiles : rendez-vous, ordonnances, Dawini, verification d'ordonnance.
  Widget _raccourcis() {
    Widget tuile(IconData icone, String titre, String sous, VoidCallback action) => Expanded(
          child: CarteTabibi(
            onTap: action,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: Charte.pastille, borderRadius: BorderRadius.circular(14)),
                child: Icon(icone, color: Charte.vert),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(titre,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: Charte.texte)),
              ),
              const SizedBox(height: 2),
              Text(sous,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: Charte.doux)),
            ]),
          ),
        );
    return Row(children: [
      tuile(Icons.calendar_month, t('Mes RDV', 'مواعيدي'), t('À venir', 'القادمة'),
          _ouvrirMesRendezVous),
      const SizedBox(width: 8),
      tuile(Icons.description_outlined, t('Ordonnances', 'الوصفات'), t('Les miennes', 'وصفاتي'),
          _ouvrirMesOrdonnances),
      const SizedBox(width: 8),
      tuile(Icons.local_pharmacy_outlined, 'Dawini', t('Pharmacies', 'الصيدليات'),
          _ouvrirDawini),
      const SizedBox(width: 8),
      tuile(Icons.verified_outlined, t('Vérifier', 'تحقق'), t('Une ordonnance', 'من وصفة'),
          _ouvrirVerification),
    ]);
  }

  /// Rangee defilante de specialites : un appui filtre la liste (second appui : retire le filtre).
  Widget _specialitesPopulaires() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _populaires.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (slug, emoji, court, courtAr) = _populaires[i];
          final choisie = _specialite == slug;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _choisirSpecialite(slug),
            child: SizedBox(
              width: 76,
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: choisie ? Charte.vert : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: choisie ? Charte.vert : Charte.bordure),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 6),
                Text(t(court, courtAr),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: choisie ? FontWeight.w800 : FontWeight.w600,
                        color: choisie ? Charte.vert : Charte.texte)),
              ]),
            ),
          );
        },
      ),
    );
  }

  /// Entrees de l'espace personnel, sur une rangee defilante : « Mon espace » (selon le role),
  /// « Notifications (n) », « Téléconsultation · Bientôt » (desactivee tant que la visio est
  /// fermee), « Messagerie », « Mes avis », « Mes listes d'attente », « Mon profil ».
  Widget _entrees() {
    Widget puce(IconData icone, String libelle, VoidCallback? action) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ActionChip(
            avatar: Icon(icone, size: 18, color: Charte.vert),
            label: Text(libelle),
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
                ? t('Téléconsultations', 'الاستشارات عن بعد')
                : t('Téléconsultation · Bientôt', 'الاستشارة عن بعد · قريبًا'),
            visioActive ? _ouvrirTeleconsultations : null,
          ),
          puce(Icons.chat_bubble_outline, t('Messagerie', 'الرسائل'),
              _ouvrirMessagerie),
          puce(Icons.star_outline, t('Mes avis', 'آرائي'), _ouvrirMesAvis),
          puce(Icons.hourglass_top_outlined,
              t("Mes listes d'attente", 'قوائم الانتظار'), _ouvrirListesAttente),
          puce(Icons.badge_outlined, t('Mon profil', 'ملفي الشخصي'),
              _ouvrirMonProfil),
        ],
      ),
    );
  }
}

/// Titre de section de l'accueil, avec un compteur facultatif en pastille.
class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte, {this.suffixe});

  final String texte;
  final String? suffixe;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Flexible(
        child: Text(texte,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: Charte.texte, letterSpacing: -0.2)),
      ),
      if (suffixe != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: Charte.pastille, borderRadius: BorderRadius.circular(999)),
          child: Text(suffixe!,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Charte.vertFonce)),
        ),
      ],
    ]);
  }
}

/// Carte praticien de la liste : avatar, nom, specialite et ville, bouton « Prendre RDV ».
class _CarteMedecin extends StatelessWidget {
  const _CarteMedecin({required this.medecin, required this.onTap});

  final Map<String, dynamic> medecin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nom = identifiant(medecin['nomComplet']);
    return CarteTabibi(
      onTap: onTap,
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Charte.doux),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(sousTitrePraticien(medecin),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Charte.doux)),
                ),
              ]),
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
                  color: Charte.vert, fontWeight: FontWeight.w700, fontSize: 13)),
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Charte.vert, shape: BoxShape.circle),
              child: Text(numero,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Charte.texte, fontSize: 14)),
                const SizedBox(height: 2),
                Text(texte,
                    style: const TextStyle(color: Charte.doux, fontSize: 13, height: 1.4)),
              ]),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: Charte.carte(fond: Charte.pastille),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Comment ça marche ?', 'كيف يعمل؟'),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Charte.vertFonce)),
        const SizedBox(height: 12),
        etape('1', t('Cherchez', 'ابحث'),
            t('Un médecin par nom, spécialité ou wilaya.', 'عن طبيب بالاسم أو التخصص أو الولاية.')),
        etape('2', t('Choisissez un créneau', 'اختر موعدًا'),
            t('Les disponibilités réelles du cabinet.', 'المواعيد المتاحة فعلًا في العيادة.')),
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
            Icon(icone, color: Charte.or, size: 22),
            const SizedBox(height: 4),
            Text(texte,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: Charte.texte)),
          ]),
        );
    return CarteTabibi(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(children: [
        point(Icons.money_off_outlined, t('Gratuit pour les patients', 'مجاني للمرضى')),
        point(Icons.map_outlined, t('58 wilayas', '58 ولاية')),
        point(Icons.lock_outline, t('Données protégées', 'بيانات محمية')),
      ]),
    );
  }
}

/// Bandeau de pré-lancement, identique à celui du site.
class _BandeauLancement extends StatelessWidget {
  const _BandeauLancement();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Charte.orClair,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Charte.or.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.rocket_launch_outlined, color: Charte.orTexte, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Lancement prochainement', 'الإطلاق قريبًا'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Charte.orTexte, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                  t("La prise de rendez-vous en ligne ouvre très bientôt. Trouvez déjà un médecin sur la plateforme.",
                      'حجز المواعيد عبر الإنترنت يفتح قريبًا جدًا. منصة طبية: ابحث عن طبيب من الآن.'),
                  style: const TextStyle(color: Charte.texte, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ]),
    );
  }
}
