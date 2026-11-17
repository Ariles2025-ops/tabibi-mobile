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
      if (mounted) setState(() => _resultats = r);
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

  Future<void> _ouvrirMesRendezVous() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesRendezVousPage(api: widget.api, auth: _auth),
      ),
    );
    await _apresRetour();
  }

  Future<void> _ouvrirMesOrdonnances() async {
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

  @override
  Widget build(BuildContext context) {
    final connecte = _auth.estConnecte;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/img/logo-ndawik.png',
                  width: 28, height: 28, excludeFromSemantics: true),
            ),
            const SizedBox(width: 10),
            const Text('Ndawik', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          const SelecteurLangue(),
          IconButton(
            tooltip: t('Mes ordonnances', 'وصفاتي الطبية'),
            onPressed: _ouvrirMesOrdonnances,
            icon: const Icon(Icons.description_outlined),
          ),
          IconButton(
            tooltip: t('Mes rendez-vous', 'مواعيدي'),
            onPressed: _ouvrirMesRendezVous,
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: connecte
                ? t('Connecté', 'متصل')
                : t('Se connecter', 'تسجيل الدخول'),
            onPressed: _seConnecter,
            icon: Icon(connecte ? Icons.person : Icons.person_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _enTete(context),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (prelancement) const _BandeauLancement(),
                  _entrees(),
                  const SizedBox(height: 12),
                  if (_charge) const LinearProgressIndicator(),
                  if (_erreur != null)
                    VueErreur(message: _erreur!, onReessayer: _rechercher),
                  for (final m in _resultats)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarteTabibi(
                        onTap: () => _ouvrirFiche(identifiant(m['id'])),
                        child: Row(children: [
                          AvatarInitiales(nom: m['nomComplet'] as String),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m['nomComplet'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(sousTitrePraticien(m),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Charte.doux)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// En-tete vert en degrade : titre d'accroche et recherche (nom, specialite, wilaya)
  /// dans une carte blanche.
  Widget _enTete(BuildContext context) {
    final clair = Theme.of(context).colorScheme.onPrimary;
    return Container(
      decoration: const BoxDecoration(gradient: Charte.degrade),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('Votre santé ne devrait jamais attendre', 'صحتك لا يجب أن تنتظر'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: clair, fontWeight: FontWeight.w800, height: 1.25),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: Charte.carte(),
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _nom,
                    decoration: InputDecoration(
                        labelText: t('Nom du médecin', 'اسم الطبيب')),
                    onSubmitted: (_) => _rechercher(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: t('Rechercher', 'بحث'),
                  onPressed: _rechercher,
                  icon: const Icon(Icons.search),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
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
            ]),
          ),
        ],
      ),
    );
  }

  /// Entrees de l'espace personnel sous la recherche, sur une seule rangee defilante
  /// horizontalement (la liste des medecins garde la place) : « Mon espace » (selon le role),
  /// « Notifications (n) », « Téléconsultation · Bientôt » (desactivee tant que la visio est
  /// fermee), « Messagerie », « Mes avis », « Dawini (pharmacies) », « Liste d'attente »,
  /// « Mon profil ».
  Widget _entrees() {
    Widget puce(IconData icone, String libelle, VoidCallback? action) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ActionChip(
            avatar: Icon(icone, size: 18),
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
          puce(Icons.star_outline, t('Mes avis', 'تقييماتي'), _ouvrirMesAvis),
          puce(Icons.local_pharmacy_outlined,
              t('Dawini (pharmacies)', 'دَويني (الصيدليات)'), _ouvrirDawini),
          puce(Icons.hourglass_top_outlined,
              t("Liste d'attente", 'قائمة الانتظار'), _ouvrirListesAttente),
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

/// Bandeau de pré-lancement, identique à celui du site.
class _BandeauLancement extends StatelessWidget {
  const _BandeauLancement();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: Charte.degrade,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary, fontSize: 13, height: 1.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Lancement prochainement', 'الإطلاق قريبًا'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(t(
                "La prise de rendez-vous en ligne ouvre très bientôt. Trouvez déjà un médecin sur la plateforme.",
                'حجز المواعيد عبر الإنترنت يفتح قريبًا جدًا. منصة طبية: ابحث عن طبيب من الآن.')),
          ],
        ),
      ),
    );
  }
}
