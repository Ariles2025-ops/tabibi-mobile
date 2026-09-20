import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/theme_tabibi.dart';
import 'utils/libelles.dart';

import 'i18n/langue.dart';
import 'i18n/traductions.dart';
import 'pages/dawini_page.dart';
import 'pages/fiche_medecin_page.dart';
import 'pages/langue_page.dart';
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
import 'utils/dates.dart';
import 'utils/identifiants.dart';
import 'utils/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await preparerDates(); // donnees de date de toutes les locales (intl)
  await langues.initialiser(); // defaut francais (sauf choix memorise de l'utilisateur)
  runApp(const TabibiApp());
}

/// Application : la langue courante ([ControleurLangue]) est portee par [LangueScope] et
/// donnee a [MaterialApp] (`locale`, `supportedLocales`, `localizationsDelegates`), afin que
/// les widgets Material (selecteur de date, champs de saisie...) et la direction d'ecriture
/// (RTL en arabe) suivent le meme choix. Changer de langue rebatit toute l'application.
class TabibiApp extends StatelessWidget {
  const TabibiApp({super.key, this.controleur, this.api = const ApiService(), this.auth});

  /// Controleur de langue a utiliser ; par defaut le controleur partage [langues].
  final ControleurLangue? controleur;

  /// API et session de l'ecran d'accueil (injectables dans les tests).
  final ApiService api;
  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    final controleurLangue = controleur ?? langues;
    return LangueScope(
      controleur: controleurLangue,
      child: ListenableBuilder(
        listenable: controleurLangue,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => t(context, 'accueil.titre'),
          locale: controleurLangue.locale,
          supportedLocales: controleurLangue.localesPrisesEnCharge,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: themeTabibi(),
          home: RecherchePage(api: api, auth: auth),
        ),
      ),
    );
  }
}

/// Ecran d'accueil : recherche de praticiens, acces a la fiche, aux rendez-vous,
/// aux ordonnances (les miennes, ou la verification publique d'un code), aux
/// notifications (entree « Notifications (n) » avec le nombre de non lues), aux
/// teleconsultations, a la messagerie avec mes medecins, a mes avis, a Dawini
/// (demander un medicament aux pharmacies), a mes listes d'attente, a mon profil
/// et au choix de la langue de l'interface.
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
  List<Map<String, dynamic>> _resultats = [];

  /// Total reel de praticiens dans la base (null tant qu'inconnu).
  int? _totalMedecins;

  /// Wilayas et specialites reelles (filtres de recherche), chargees au demarrage.
  List<Map<String, dynamic>> _wilayasRef = [];
  List<Map<String, dynamic>> _specialitesRef = [];

  /// Filtre wilaya selectionne (code officiel, ex. « 16 »).
  String? _wilaya;
  bool _charge = false;

  /// Nombre de notifications non lues ; null tant qu'il est inconnu (hors connexion, echec).
  int? _nonLues;

  /// Onglet de la barre de navigation basse (0 = accueil).
  int _ongletActif = 0;

  Future<void> _rechercher() async {
    setState(() => _charge = true);
    try {
      final r = await widget.api.rechercherMedecins(
          specialite: _specialite, wilaya: _wilaya, q: _nom.text);
      if (mounted) setState(() => _resultats = r);
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Charge le total reel de praticiens (affiche dans la tuile « Medecins »).
  Future<void> _chargerStats() async {
    try {
      final s = await widget.api.statsAnnuaire();
      final t = s['total'];
      if (mounted && t is num) setState(() => _totalMedecins = t.toInt());
    } on Exception {
      // total indisponible : la tuile garde son repli.
    }
  }

  /// Charge les wilayas et specialites reelles (filtres de recherche).
  Future<void> _chargerReferentiel() async {
    try {
      final w = await widget.api.wilayas();
      final sp = await widget.api.specialites();
      if (mounted) {
        setState(() {
          _wilayasRef = w;
          _specialitesRef = sp;
        });
      }
    } on Exception {
      // referentiel indisponible : la recherche reste en texte libre.
    }
  }

  /// Connexion Keycloak si necessaire, puis confirmation « Connecté ».
  Future<void> _seConnecter() async {
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      setState(() {}); // met a jour l'icone de l'AppBar
      if (!ok) {
        _message(t(context, 'commun.connexionAnnulee'));
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    var texte = t(context, 'commun.connecte');
    try {
      final moi = await widget.api.moi(token);
      if (!mounted) return;
      texte = t(context, 'commun.connecteNom', params: {'nom': moi['nom']});
    } on Exception {
      // Identite indisponible : message generique.
    }
    _message(texte);
    await _chargerNonLues();
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
  }

  /// Ouvre la fiche d'un praticien ([medecinId] : UUID en texte).
  Future<void> _ouvrirFiche(String medecinId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FicheMedecinPage(medecinId: medecinId, api: widget.api, auth: _auth),
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

  /// Choix de la langue de l'interface (francais, arabe, anglais) : aucun jeton necessaire.
  Future<void> _ouvrirLangue() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LanguePage()),
    );
    if (mounted) setState(() {});
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
    _chargerStats();
    _chargerReferentiel();
    _chargerNonLues();
  }

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  /// Puce de langue dans la barre (globe + code) ouvrant le selecteur.
  Widget _boutonLangue(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _ouvrirLangues(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Tabibi.pastille,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Tabibi.pastilleBd),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.language, size: 16, color: Tabibi.vert),
            const SizedBox(width: 5),
            Text(langueDe(context).toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13, color: Tabibi.vert)),
          ]),
        ),
      ),
    );
  }

  /// Selecteur de langue (FR / AR / EN) en bas d'ecran, applique et memorise le choix.
  Future<void> _ouvrirLangues(BuildContext context) async {
    const langs = [
      ['fr', 'Français', 'FR'],
      ['ar', 'العربية', 'DZ'],
      ['en', 'English', 'GB'],
    ];
    final courant = langueDe(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Tabibi.bord, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(t(context, 'langue.titre'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Tabibi.ink)),
            ),
          ),
          for (final l in langs)
            ListTile(
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Tabibi.pastille,
                    borderRadius: BorderRadius.circular(9)),
                child: Text(l[2],
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Tabibi.vert)),
              ),
              title: Text(l[1],
                  style: TextStyle(
                      fontWeight:
                          courant == l[0] ? FontWeight.w700 : FontWeight.w500,
                      color: courant == l[0] ? Tabibi.vert : Tabibi.texte)),
              trailing: courant == l[0]
                  ? const Icon(Icons.check, color: Tabibi.vert)
                  : null,
              onTap: () {
                langues.choisir(l[0]);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  /// Vrai des qu'un critere est saisi (texte, wilaya ou specialite) : on replie
  /// l'accueil et on montre les resultats directement.
  bool get _rechercheActive =>
      _nom.text.trim().isNotEmpty || _wilaya != null || _specialite != null;

  @override
  Widget build(BuildContext context) {
    final connecte = _auth.estConnecte;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          SvgPicture.asset('assets/logo-mark-vert.svg', width: 28, height: 28),
          const SizedBox(width: 8),
          const Text('Tabibi',
              style: TextStyle(
                  color: Tabibi.vert,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
        ]),
        actions: [
          _boutonLangue(context),
          IconButton(
            tooltip: t(context, 'accueil.notifications'),
            onPressed: _ouvrirNotifications,
            icon: Badge(
              isLabelVisible: (_nonLues ?? 0) > 0,
              label: Text('${_nonLues ?? 0}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: t(context, connecte ? 'commun.connecte' : 'commun.seConnecter'),
            onPressed: _seConnecter,
            icon: Icon(connecte ? Icons.person : Icons.person_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: Tabibi.vert,
        onRefresh: () => Future.wait([_rechercher(), _chargerStats()]),
        child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _heroClair(context),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_rechercheActive) ...[
                Text(t(context, 'accueil.services'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.ink)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _tuileService(Icons.calendar_month,
                          t(context, 'accueil.mesRendezVous'), _ouvrirMesRendezVous)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tuileService(Icons.videocam_outlined,
                          t(context, 'accueil.teleconsultations'),
                          _ouvrirTeleconsultations)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tuileService(Icons.local_pharmacy_outlined,
                          t(context, 'accueil.dawini'), _ouvrirDawini)),
                ]),
                const SizedBox(height: 26),
                ],
                Text(
                    _rechercheActive
                        ? t(context, 'accueil.resultats')
                        : t(context, 'accueil.praticiens'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.ink)),
                const SizedBox(height: 12),
                if (_charge)
                  for (int i = 0; i < 3; i++) _squeletteMedecin(),
                for (final m in (_rechercheActive
                    ? _resultats
                    : _resultats.take(4).toList()))
                  _carteMedecin(context, m),
                if (!_charge && _resultats.isEmpty)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: Tabibi.ombreDouce),
                    child: Column(children: [
                      const Icon(Icons.search_off, size: 32, color: Tabibi.texte4),
                      const SizedBox(height: 8),
                      Text(t(context, 'accueil.aucunMedecin'),
                          style: const TextStyle(color: Tabibi.texteDoux)),
                    ]),
                  ),
                if (!_rechercheActive) ...[
                  const SizedBox(height: 28),
                  _blocMedecin(context),
                  const SizedBox(height: 28),
                  _faq(context),
                  const SizedBox(height: 28),
                  _miniFooter(context),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _ongletActif,
        onDestinationSelected: (i) {
          if (i == 1) {
            _ouvrirMesRendezVous();
          } else if (i == 2) {
            _ouvrirMessagerie();
          } else if (i == 3) {
            _ouvrirCompte();
          } else {
            setState(() => _ongletActif = 0);
          }
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: t(context, 'accueil.ongletAccueil')),
          NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: t(context, 'accueil.mesRendezVous')),
          NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: const Icon(Icons.chat_bubble),
              label: t(context, 'accueil.messagerie')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: t(context, 'accueil.compte')),
        ],
      ),
    );
  }

  /// Hero clair pleine largeur — copie fidele de tabibi.doctor (fond degrade doux).
  Widget _heroClair(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
      ),
      child: Container(
      width: double.infinity,
      color: Tabibi.bg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: Tabibi.ombreDouce,
      ),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      child: Column(
        children: [
          if (!_rechercheActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: Tabibi.pastille,
              border: Border.all(color: Tabibi.pastilleBd),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration:
                        const BoxDecoration(color: Tabibi.or, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(t(context, 'accueil.badge'),
                      style: const TextStyle(
                          color: Tabibi.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            t(context, 'accueil.accroche'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Tabibi.ink,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.7),
          ),
          const SizedBox(height: 10),
          Text(
            t(context, 'accueil.sousTitre', params: {
              'n': _wilayasRef.isNotEmpty ? '${_wilayasRef.length}' : '69',
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Tabibi.texteDoux, fontSize: 14, height: 1.5),
          ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _nom,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _rechercher(),
            decoration: InputDecoration(
              hintText: t(context, 'accueil.recherchePlaceholder'),
              prefixIcon: const Icon(Icons.search, color: Tabibi.vert),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Tabibi.r16),
                borderSide: const BorderSide(color: Tabibi.bord),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Tabibi.r16),
                borderSide: const BorderSide(color: Tabibi.bord),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Tabibi.r16),
                borderSide: const BorderSide(color: Tabibi.vert, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _pillFiltre(
                  icone: Icons.location_on_outlined,
                  libelle: _nomWilaya() ?? t(context, 'accueil.wilaya'),
                  actif: _wilaya != null,
                  onTap: () => _ouvrirSelecteur(
                    titre: t(context, 'accueil.wilaya'),
                    options: _wilayasRef,
                    cleValeur: 'code',
                    valeur: _wilaya,
                    recherche: true,
                    onChoisir: (v) {
                      setState(() => _wilaya = v);
                      _rechercher();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pillFiltre(
                  icone: Icons.medical_services_outlined,
                  libelle: _nomSpecialite() ?? t(context, 'accueil.specialite'),
                  actif: _specialite != null,
                  onTap: () => _ouvrirSelecteur(
                    titre: t(context, 'accueil.specialite'),
                    options: _specialitesRef,
                    cleValeur: 'slug',
                    valeur: _specialite,
                    recherche: false,
                    onChoisir: (v) {
                      setState(() => _specialite = v);
                      _rechercher();
                    },
                  ),
                ),
              ),
            ],
          ),
          if (!_rechercheActive) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.credit_card, size: 16, color: Tabibi.or),
              const SizedBox(width: 8),
              Flexible(
                child: Text(t(context, 'accueil.paiement'),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Tabibi.texteDoux, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: _statTile(
                      _totalMedecins != null
                          ? _formatMilliers(_totalMedecins!)
                          : '…',
                      t(context, 'accueil.statMedecins'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _statTile(
                      _wilayasRef.isNotEmpty ? '${_wilayasRef.length}' : '69',
                      t(context, 'accueil.statWilayas'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _statTile('24/7', t(context, 'accueil.statReservation'))),
            ],
          ),
          ],
        ],
      ),
      ),
      ),
    );
  }

  /// Pastille de filtre (wilaya / specialite) ouvrant un selecteur en bas d'ecran.
  Widget _pillFiltre({
    required IconData icone,
    required String libelle,
    required bool actif,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(Tabibi.r16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: actif ? Tabibi.pastille : Colors.white,
          borderRadius: BorderRadius.circular(Tabibi.r16),
          border: Border.all(
              color: actif ? Tabibi.vert : Tabibi.bord, width: actif ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icone, size: 18, color: actif ? Tabibi.vert : Tabibi.texte3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(libelle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: actif ? Tabibi.vert : Tabibi.texteDoux)),
          ),
          Icon(Icons.expand_more,
              size: 18, color: actif ? Tabibi.vert : Tabibi.texte3),
        ]),
      ),
    );
  }

  String? _nomWilaya() {
    for (final w in _wilayasRef) {
      if (w['code']?.toString() == _wilaya) return w['nom']?.toString();
    }
    return null;
  }

  String? _nomSpecialite() {
    for (final s in _specialitesRef) {
      if (s['slug']?.toString() == _specialite) return s['nom']?.toString();
    }
    return null;
  }

  /// Selecteur en bas d'ecran (liste + recherche) pour une wilaya ou une specialite.
  Future<void> _ouvrirSelecteur({
    required String titre,
    required List<Map<String, dynamic>> options,
    required String cleValeur,
    required String? valeur,
    required bool recherche,
    required ValueChanged<String?> onChoisir,
  }) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final q = ctrl.text.trim().toLowerCase();
          final filtres = q.isEmpty
              ? options
              : options
                  .where((o) =>
                      (o['nom']?.toString().toLowerCase() ?? '').contains(q))
                  .toList();
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Tabibi.bord,
                          borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                    child: Row(children: [
                      Text(titre,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Tabibi.ink)),
                      const Spacer(),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Tabibi.texte3)),
                    ]),
                  ),
                  if (recherche)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: ctrl,
                        onChanged: (_) => setSheet(() {}),
                        decoration: InputDecoration(
                          hintText: t(context, 'accueil.rechercheWilaya'),
                          prefixIcon:
                              const Icon(Icons.search, color: Tabibi.texte3),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        _ligneSelecteur(
                            t(context, 'accueil.tout'), valeur == null, () {
                          Navigator.pop(ctx);
                          onChoisir(null);
                        }),
                        for (final o in filtres)
                          _ligneSelecteur(
                            o['nom']?.toString() ?? '',
                            valeur == o[cleValeur]?.toString(),
                            () {
                              Navigator.pop(ctx);
                              onChoisir(o[cleValeur]?.toString());
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _ligneSelecteur(String texte, bool choisi, VoidCallback onTap) {
    return ListTile(
      title: Text(texte,
          style: TextStyle(
              fontWeight: choisi ? FontWeight.w700 : FontWeight.w500,
              color: choisi ? Tabibi.vert : Tabibi.texte)),
      trailing: choisi ? const Icon(Icons.check, color: Tabibi.vert) : null,
      onTap: onTap,
    );
  }

  /// 75035 -> « 75K », 5 -> « 5 » : total lisible dans une petite tuile.
  String _formatMilliers(int n) => n >= 1000 ? '${n ~/ 1000}K' : '$n';

  /// Bloc recrutement medecin (comme le site).
  Widget _blocMedecin(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
          child: const Icon(Icons.medical_information_outlined,
              color: Tabibi.vert, size: 26),
        ),
        const SizedBox(height: 14),
        Text(t(context, 'accueil.medecinTitre'),
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: Tabibi.ink)),
        const SizedBox(height: 8),
        Text(
          t(context, 'accueil.medecinTexte'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Tabibi.texteDoux, height: 1.4),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _message(t(context, 'accueil.medecinBientot')),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(t(context, 'accueil.medecinBouton')),
          ),
        ),
      ]),
    );
  }

  /// Foire aux questions (accordeon).
  Widget _faq(BuildContext context) {
    final items = <List<String>>[
      [t(context, 'accueil.faqQ1'), t(context, 'accueil.faqR1')],
      [t(context, 'accueil.faqQ2'), t(context, 'accueil.faqR2')],
      [t(context, 'accueil.faqQ3'), t(context, 'accueil.faqR3')],
      [t(context, 'accueil.faqQ4'), t(context, 'accueil.faqR4')],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t(context, 'accueil.faqTitre'),
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.ink)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Tabibi.bord),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Tabibi.bord, splashColor: Colors.transparent),
          child: Column(children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Tabibi.bord),
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: Tabibi.vert,
                collapsedIconColor: Tabibi.texte3,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Text(items[i][0],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Tabibi.texte,
                        fontSize: 14)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(items[i][1],
                        style: const TextStyle(
                            color: Tabibi.texteDoux, height: 1.5, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  /// Mini pied de page.
  Widget _miniFooter(BuildContext context) {
    return Column(children: [
      const Divider(color: Tabibi.bord, height: 1),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SvgPicture.asset('assets/logo-mark-vert.svg', width: 22, height: 22),
        const SizedBox(width: 8),
        const Text('Tabibi',
            style: TextStyle(
                color: Tabibi.vert, fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      const SizedBox(height: 8),
      Text(
        t(context, 'accueil.footerTagline', params: {
          'n': _totalMedecins != null ? _formatMilliers(_totalMedecins!) : '75K',
          'w': _wilayasRef.isNotEmpty ? '${_wilayasRef.length}' : '69',
        }),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Tabibi.texte3, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.mail_outline, size: 14, color: Tabibi.texte3),
        SizedBox(width: 6),
        Text('contact@tabibi.doctor',
            style: TextStyle(
                color: Tabibi.texteDoux,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 6, children: [
        Text(t(context, 'accueil.footerApropos'), style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
        Text(t(context, 'accueil.footerCgu'), style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
        Text(t(context, 'accueil.footerConfid'), style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
        Text(t(context, 'accueil.footerMentions'), style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
      ]),
      const SizedBox(height: 12),
      Text(t(context, 'accueil.footerCopyright'),
          style: const TextStyle(color: Tabibi.texte4, fontSize: 11)),
    ]);
  }

  Widget _statTile(String valeur, String libelle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(
        children: [
          Text(valeur,
              style: const TextStyle(
                  color: Tabibi.vert,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(libelle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Tabibi.texte3,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }

  /// Carte medecin (resultat) facon Doctolib : avatar, nom, specialite/ville, chevron.
  Widget _carteMedecin(BuildContext context, Map<String, dynamic> m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: AvatarInitiales(m['nomComplet'] as String),
        title: Row(
          children: [
            Flexible(
              child: Text(m['nomComplet'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Tabibi.texte)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Tabibi.orClair,
                  borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified, size: 12, color: Tabibi.or),
                const SizedBox(width: 3),
                Text(t(context, 'accueil.verifie'),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Tabibi.orTexte)),
              ]),
            ),
          ],
        ),
        subtitle: Text(
          medecinSousTitre(m),
          style: const TextStyle(color: Tabibi.texteDoux),
        ),
        trailing: const Icon(Icons.chevron_right, color: Tabibi.bordFort),
        onTap: () => _ouvrirFiche(identifiant(m['id'])),
      ),
      ),
    );
  }

  /// Entrees de l'espace personnel sous la recherche : « Notifications (n) » avec le nombre
  /// de non lues (connu a l'ouverture et actualise au retour de chaque ecran),
  /// « Téléconsultations », « Messagerie », « Mes avis », « Dawini (pharmacies) »,
  /// « Liste d'attente », « Mon profil » et « Langue ».
  /// Squelette de chargement (placeholder gris) pour une carte medecin.
  Widget _squeletteMedecin() {
    Widget bloc(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: Tabibi.bg2, borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Row(
        children: [
          Container(
              width: 48,
              height: 48,
              decoration:
                  const BoxDecoration(color: Tabibi.bg2, shape: BoxShape.circle)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bloc(150, 12),
                const SizedBox(height: 8),
                bloc(90, 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tuile service (accueil) : icone pastille + libelle, facon Doctolib.
  Widget _tuileService(IconData icone, String libelle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tabibi.r16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: Tabibi.ombreDouce,
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration:
                  const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
              child: Icon(icone, color: Tabibi.vert, size: 22),
            ),
            const SizedBox(height: 8),
            Text(libelle,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Tabibi.texte)),
          ],
        ),
      ),
    );
  }

  /// Panneau « Compte » (feuille du bas) : profil, ordonnances, avis, liste d'attente,
  /// verification, langue — tout le secondaire, hors de l'accueil.
  void _ouvrirCompte() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Tabibi.bord, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(t(context, 'accueil.compte'),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Tabibi.ink)),
              ),
            ),
            _ligneMenu(Icons.badge_outlined, t(context, 'accueil.monProfil'),
                () { Navigator.pop(ctx); _ouvrirMonProfil(); }),
            _ligneMenu(Icons.description_outlined, t(context, 'accueil.mesOrdonnances'),
                () { Navigator.pop(ctx); _ouvrirMesOrdonnances(); }),
            _ligneMenu(Icons.star_outline, t(context, 'accueil.mesAvis'),
                () { Navigator.pop(ctx); _ouvrirMesAvis(); }),
            _ligneMenu(Icons.hourglass_top_outlined, t(context, 'accueil.listeAttente'),
                () { Navigator.pop(ctx); _ouvrirListesAttente(); }),
            _ligneMenu(Icons.verified_outlined, t(context, 'accueil.verifierOrdonnance'),
                () { Navigator.pop(ctx); _ouvrirVerification(); }),
            _ligneMenu(Icons.language_outlined, t(context, 'accueil.langue'),
                () { Navigator.pop(ctx); _ouvrirLangue(); }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Une ligne de menu : pastille verte + icone, libelle, chevron.
  Widget _ligneMenu(IconData icone, String libelle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: Tabibi.pastille, shape: BoxShape.circle),
              child: Icon(icone, size: 18, color: Tabibi.vert),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(libelle,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Tabibi.texte)),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Tabibi.bordFort),
          ],
        ),
      ),
    );
  }

}
