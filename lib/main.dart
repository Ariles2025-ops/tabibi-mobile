import 'package:flutter/material.dart';

import 'config/lancement.dart';
import 'config/referentiel.dart';
import 'config/theme.dart';

import 'pages/dawini_page.dart';
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
import 'utils/identifiants.dart';
import 'utils/notifications.dart';

void main() => runApp(const TabibiApp());

class TabibiApp extends StatelessWidget {
  const TabibiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tabibi',
      debugShowCheckedModeBanner: false,
      theme: Charte.theme(),
      home: const RecherchePage(),
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

  /// Nombre de notifications non lues ; null tant qu'il est inconnu (hors connexion, echec).
  int? _nonLues;

  Future<void> _rechercher() async {
    setState(() => _charge = true);
    try {
      final r = await widget.api.rechercherMedecins(specialite: _specialite, wilaya: _wilaya, q: _nom.text);
      if (mounted) setState(() => _resultats = r);
    } on Exception catch (e) {
      _message(messageErreur(e));
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
        _message('Connexion annulée');
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    var texte = 'Connecté';
    try {
      final moi = await widget.api.moi(token);
      texte = 'Connecté : ${moi['nom']}';
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
    if (!visioActive) {
      _message('La téléconsultation arrive bientôt sur Tabibi.');
      return;
    }
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
        title: const Text('Tabibi', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Vérifier une ordonnance',
            onPressed: _ouvrirVerification,
            icon: const Icon(Icons.verified_outlined),
          ),
          IconButton(
            tooltip: 'Mes ordonnances',
            onPressed: _ouvrirMesOrdonnances,
            icon: const Icon(Icons.description_outlined),
          ),
          IconButton(
            tooltip: 'Mes rendez-vous',
            onPressed: _ouvrirMesRendezVous,
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: connecte ? 'Connecté' : 'Se connecter',
            onPressed: _seConnecter,
            icon: Icon(connecte ? Icons.person : Icons.person_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (prelancement) const _BandeauLancement(),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _nom,
                  decoration: const InputDecoration(labelText: 'Nom du médecin'),
                  onSubmitted: (_) => _rechercher(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Rechercher',
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
                  decoration: const InputDecoration(labelText: 'Spécialité'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Toutes')),
                    for (final sp in specialites)
                      DropdownMenuItem(value: sp.slug, child: Text(sp.nom, overflow: TextOverflow.ellipsis)),
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
                  decoration: const InputDecoration(labelText: 'Wilaya'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Toutes')),
                    for (final w in wilayas)
                      DropdownMenuItem(value: w.code, child: Text('${w.code} - ${w.nom}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    setState(() => _wilaya = v);
                    _rechercher();
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _entrees(),
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
                    subtitle: Text(sousTitrePraticien(m)),
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
  /// « Teleconsultations », « Messagerie », « Mes avis », « Dawini (pharmacies) »,
  /// « Liste d'attente » et « Mon profil ».
  Widget _entrees() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ActionChip(
            avatar: const Icon(Icons.notifications_outlined, size: 18),
            label: Text(libelleNotifications(_nonLues)),
            onPressed: _ouvrirNotifications,
          ),
          ActionChip(
            avatar: const Icon(Icons.videocam_outlined, size: 18),
            label: Text(visioActive ? 'Téléconsultations' : 'Téléconsultation · Bientôt'),
            onPressed: _ouvrirTeleconsultations,
          ),
          ActionChip(
            avatar: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Messagerie'),
            onPressed: _ouvrirMessagerie,
          ),
          ActionChip(
            avatar: const Icon(Icons.star_outline, size: 18),
            label: const Text('Mes avis'),
            onPressed: _ouvrirMesAvis,
          ),
          ActionChip(
            avatar: const Icon(Icons.local_pharmacy_outlined, size: 18),
            label: const Text('Dawini (pharmacies)'),
            onPressed: _ouvrirDawini,
          ),
          ActionChip(
            avatar: const Icon(Icons.hourglass_top_outlined, size: 18),
            label: const Text("Liste d'attente"),
            onPressed: _ouvrirListesAttente,
          ),
          ActionChip(
            avatar: const Icon(Icons.badge_outlined, size: 18),
            label: const Text('Mon profil'),
            onPressed: _ouvrirMonProfil,
          ),
        ],
      ),
    );
  }
}

/// Ligne « spécialité · ville (wilaya) » d'un praticien, sans « null » quand une donnée manque.
String sousTitrePraticien(Map<String, dynamic> m) {
  final specialite = (m['specialiteFr'] as String?) ?? '';
  final ville = m['ville'] as String?;
  final wilaya = (m['wilayaFr'] as String?) ?? '';
  final lieu = (ville == null || ville.isEmpty) ? wilaya : '$ville ($wilaya)';
  return [specialite, lieu].where((x) => x.isNotEmpty).join(' · ');
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
        gradient: const LinearGradient(colors: [Charte.vert, Charte.vertFonce]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Lancement prochainement', style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: " — la prise de rendez-vous en ligne ouvre très bientôt. Parcourez déjà l'annuaire des médecins."),
            ]),
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
