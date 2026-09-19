import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
  await langues.initialiser(locale: localeDuTelephone());
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
          theme: ThemeData(colorSchemeSeed: const Color(0xFF0F7560), useMaterial3: true),
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
  bool _charge = false;

  /// Nombre de notifications non lues ; null tant qu'il est inconnu (hors connexion, echec).
  int? _nonLues;

  Future<void> _rechercher() async {
    setState(() => _charge = true);
    try {
      final r = await widget.api.rechercherMedecins(specialite: _specialite, q: _nom.text);
      if (mounted) setState(() => _resultats = r);
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
    } finally {
      if (mounted) setState(() => _charge = false);
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
    _chargerNonLues();
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
        title: Text(t(context, 'accueil.titre')),
        actions: [
          IconButton(
            tooltip: t(context, 'accueil.verifierOrdonnance'),
            onPressed: _ouvrirVerification,
            icon: const Icon(Icons.verified_outlined),
          ),
          IconButton(
            tooltip: t(context, 'accueil.mesOrdonnances'),
            onPressed: _ouvrirMesOrdonnances,
            icon: const Icon(Icons.description_outlined),
          ),
          IconButton(
            tooltip: t(context, 'accueil.mesRendezVous'),
            onPressed: _ouvrirMesRendezVous,
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: t(context, connecte ? 'commun.connecte' : 'commun.seConnecter'),
            onPressed: _seConnecter,
            icon: Icon(connecte ? Icons.person : Icons.person_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _nom,
                  decoration: InputDecoration(labelText: t(context, 'accueil.nomMedecin')),
                  onSubmitted: (_) => _rechercher(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _specialite,
                hint: Text(t(context, 'accueil.specialite')),
                items: [
                  for (final slug in specialites)
                    DropdownMenuItem(
                      value: slug,
                      child: Text(t(context, 'specialite.$slug')),
                    ),
                ],
                onChanged: (v) => setState(() => _specialite = v),
              ),
              IconButton(onPressed: _rechercher, icon: const Icon(Icons.search)),
            ]),
            const SizedBox(height: 12),
            _entrees(context),
            const SizedBox(height: 12),
            if (_charge) const CircularProgressIndicator(),
            Expanded(
              child: ListView.separated(
                itemCount: _resultats.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final m = _resultats[i];
                  return ListTile(
                    title: Text(m['nomComplet'] as String),
                    subtitle: Text(t(context, 'accueil.sousTitreMedecin', params: {
                      'specialite': m['specialiteFr'],
                      'ville': m['ville'],
                      'wilaya': m['wilayaFr'],
                    })),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _ouvrirFiche(identifiant(m['id'])),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Entrees de l'espace personnel sous la recherche : « Notifications (n) » avec le nombre
  /// de non lues (connu a l'ouverture et actualise au retour de chaque ecran),
  /// « Téléconsultations », « Messagerie », « Mes avis », « Dawini (pharmacies) »,
  /// « Liste d'attente », « Mon profil » et « Langue ».
  Widget _entrees(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ActionChip(
            avatar: const Icon(Icons.notifications_outlined, size: 18),
            label: Text(libelleNotifications(langueDe(context), _nonLues)),
            onPressed: _ouvrirNotifications,
          ),
          ActionChip(
            avatar: const Icon(Icons.videocam_outlined, size: 18),
            label: Text(t(context, 'accueil.teleconsultations')),
            onPressed: _ouvrirTeleconsultations,
          ),
          ActionChip(
            avatar: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(t(context, 'accueil.messagerie')),
            onPressed: _ouvrirMessagerie,
          ),
          ActionChip(
            avatar: const Icon(Icons.star_outline, size: 18),
            label: Text(t(context, 'accueil.mesAvis')),
            onPressed: _ouvrirMesAvis,
          ),
          ActionChip(
            avatar: const Icon(Icons.local_pharmacy_outlined, size: 18),
            label: Text(t(context, 'accueil.dawini')),
            onPressed: _ouvrirDawini,
          ),
          ActionChip(
            avatar: const Icon(Icons.hourglass_top_outlined, size: 18),
            label: Text(t(context, 'accueil.listeAttente')),
            onPressed: _ouvrirListesAttente,
          ),
          ActionChip(
            avatar: const Icon(Icons.badge_outlined, size: 18),
            label: Text(t(context, 'accueil.monProfil')),
            onPressed: _ouvrirMonProfil,
          ),
          ActionChip(
            avatar: const Icon(Icons.language_outlined, size: 18),
            label: Text(t(context, 'accueil.langue')),
            onPressed: _ouvrirLangue,
          ),
        ],
      ),
    );
  }
}
