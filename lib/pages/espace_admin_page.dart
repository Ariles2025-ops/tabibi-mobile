import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/admin_supabase.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../utils/libelles.dart';
import '../widgets/vue_connexion.dart';

/// Console d'administration : supervision globale de Tabibi.
/// Tableau de bord, validation des medecins, gestion des utilisateurs, suivi des rendez-vous.
class EspaceAdminPage extends StatefulWidget {
  const EspaceAdminPage({super.key, this.admin = const AdminSupabase(), this.auth});

  final AdminSupabase admin;
  final AuthService? auth;

  @override
  State<EspaceAdminPage> createState() => _EspaceAdminPageState();
}

class _EspaceAdminPageState extends State<EspaceAdminPage> {
  late final AuthService _auth = widget.auth ?? session;

  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _attente = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _rdv = [];
  final _recherche = TextEditingController();
  String? _roleFiltre; // null = tous
  bool _charge = false;
  String? _enCours;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _tout();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _tout() async {
    setState(() => _charge = true);
    await Future.wait([_chargerStats(), _chargerAttente(), _chargerUsers(), _chargerRdv()]);
    if (mounted) setState(() => _charge = false);
  }

  Future<void> _chargerStats() async {
    try {
      final s = await widget.admin.stats();
      if (mounted) setState(() => _stats = s);
    } on Exception {/* ignore */}
  }

  Future<void> _chargerAttente() async {
    try {
      final a = await widget.admin.medecinsEnAttente();
      if (mounted) setState(() => _attente = a);
    } on Exception {/* ignore */}
  }

  Future<void> _chargerUsers() async {
    try {
      final u = await widget.admin
          .listerUtilisateurs(role: _roleFiltre, q: _recherche.text.trim());
      if (mounted) setState(() => _users = u);
    } on Exception {/* ignore */}
  }

  Future<void> _chargerRdv() async {
    try {
      final r = await widget.admin.listerRdv();
      if (mounted) setState(() => _rdv = r);
    } on Exception {/* ignore */}
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _action(String cle, Future<void> Function() op, String ok) async {
    if (_enCours != null) return;
    setState(() => _enCours = cle);
    try {
      await op();
      if (mounted) _msg(ok);
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
    await _chargerStats();
    await _chargerAttente();
    await _chargerUsers();
  }

  Future<void> _valider(String email) =>
      _action('val:$email', () => widget.admin.validerMedecin(email), 'Médecin validé : $email');

  Future<void> _activer(String email) =>
      _action('act:$email', () => widget.admin.activerCompte(email), 'Compte activé : $email');

  Future<void> _supprimer(String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text('$email sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tabibi.rouge),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _action('del:$email', () => widget.admin.supprimerCompte(email), 'Compte supprimé : $email');
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.estConnecte) {
      return Scaffold(
        appBar: AppBar(title: const Text('Console admin')),
        body: VueConnexion(
          icone: Icons.admin_panel_settings_outlined,
          titre: 'Console admin',
          message: 'Connectez-vous avec le compte administrateur.',
          onSeConnecter: () async {
            await _auth.seConnecter();
            if (mounted) setState(() {});
            if (_auth.estConnecte) _tout();
          },
        ),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Console admin'),
          actions: [
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _charge ? null : _tout,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Déconnexion',
              onPressed: () {
                _auth.seDeconnecter();
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Tabibi.vert,
            indicatorColor: Tabibi.vert,
            unselectedLabelColor: Tabibi.texteDoux,
            tabs: [
              Tab(text: 'Tableau de bord'),
              Tab(text: 'Médecins'),
              Tab(text: 'Utilisateurs'),
              Tab(text: 'Rendez-vous'),
            ],
          ),
        ),
        body: _charge
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _ongletDashboard(),
                  _ongletMedecins(),
                  _ongletUtilisateurs(),
                  _ongletRdv(),
                ],
              ),
      ),
    );
  }

  // ---------- Tableau de bord ----------
  Widget _ongletDashboard() {
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _tout,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _kpi('Patients', _stats['patients'], Icons.people_outline),
              _kpi('Médecins actifs', _stats['medecinsActifs'], Icons.medical_services_outlined),
              _kpi('Médecins en attente', _stats['medecinsAttente'], Icons.hourglass_top_outlined,
                  accent: true),
              _kpi('Rendez-vous', _stats['rdv'], Icons.event_outlined),
              _kpi('Candidatures', _stats['candidatures'], Icons.assignment_outlined),
            ],
          ),
          const SizedBox(height: 20),
          const Text('À valider',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.texte)),
          const SizedBox(height: 8),
          if (_attente.isEmpty)
            const Text('Aucun médecin en attente.', style: TextStyle(color: Tabibi.texteDoux))
          else
            for (final m in _attente.take(5)) _carteAttente(m),
        ],
      ),
    );
  }

  Widget _kpi(String libelle, Object? valeur, IconData icone, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? Tabibi.orClair : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icone, color: accent ? Tabibi.orTexte : Tabibi.vert, size: 20),
          Text('${valeur ?? 0}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: accent ? Tabibi.orTexte : Tabibi.texte)),
          Text(libelle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
        ],
      ),
    );
  }

  // ---------- Medecins ----------
  Widget _ongletMedecins() {
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _chargerAttente,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text('En attente de validation (${_attente.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.texte)),
          const SizedBox(height: 8),
          if (_attente.isEmpty)
            const Text('Aucun médecin en attente.', style: TextStyle(color: Tabibi.texteDoux))
          else
            for (final m in _attente) _carteAttente(m),
        ],
      ),
    );
  }

  Widget _carteAttente(Map<String, dynamic> m) {
    final email = '${m['email'] ?? ''}';
    final sous = [
      if ('${m['specialite'] ?? ''}'.isNotEmpty) '${m['specialite']}',
      if ('${m['wilaya'] ?? ''}'.isNotEmpty) '${m['wilaya']}',
      if ('${m['telephone'] ?? ''}'.isNotEmpty) '${m['telephone']}',
    ].join(' · ');
    final occupe = _enCours == 'val:$email';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['nom'] ?? email}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
            const SizedBox(height: 2),
            Text(email, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
            if (sous.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sous, style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Tabibi.vert, visualDensity: VisualDensity.compact),
          onPressed: _enCours != null ? null : () => _valider(email),
          child: occupe
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Valider'),
        ),
      ]),
    );
  }

  // ---------- Utilisateurs ----------
  Widget _ongletUtilisateurs() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _recherche,
            onSubmitted: (_) => _chargerUsers(),
            decoration: InputDecoration(
              hintText: 'Rechercher (email ou nom)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _chargerUsers),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _puceRole('Tous', null),
            _puceRole('Patients', 'patient'),
            _puceRole('Médecins', 'medecin'),
            _puceRole('Admins', 'admin'),
          ]),
        ),
        Expanded(
          child: _users.isEmpty
              ? const Center(
                  child: Text('Aucun utilisateur.', style: TextStyle(color: Tabibi.texteDoux)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: _users.length,
                  itemBuilder: (_, i) => _carteUser(_users[i]),
                ),
        ),
      ],
    );
  }

  Widget _puceRole(String label, String? role) {
    final actif = _roleFiltre == role;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: actif,
        selectedColor: Tabibi.pastille,
        onSelected: (_) {
          setState(() => _roleFiltre = role);
          _chargerUsers();
        },
      ),
    );
  }

  Widget _carteUser(Map<String, dynamic> u) {
    final email = '${u['email'] ?? ''}';
    final role = '${u['role'] ?? ''}';
    final actif = u['actif'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${u['nom'] ?? email}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
              ]),
            ),
            _badgeRole(role),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _pastilleEtat(actif),
            const Spacer(),
            if (!actif)
              TextButton(
                onPressed: _enCours != null ? null : () => _activer(email),
                child: const Text('Activer'),
              ),
            TextButton(
              onPressed: _enCours != null ? null : () => _supprimer(email),
              style: TextButton.styleFrom(foregroundColor: Tabibi.rouge),
              child: const Text('Supprimer'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _badgeRole(String role) {
    Color bg = Tabibi.bg2;
    Color fg = Tabibi.texte3;
    String txt = role;
    if (role == 'admin') {
      bg = Tabibi.orClair;
      fg = Tabibi.orTexte;
      txt = 'Admin';
    } else if (role == 'medecin') {
      bg = Tabibi.vertTresClair;
      fg = Tabibi.vert;
      txt = 'Médecin';
    } else if (role == 'patient') {
      txt = 'Patient';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(txt, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _pastilleEtat(bool actif) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(actif ? Icons.check_circle : Icons.cancel,
          size: 14, color: actif ? Tabibi.vert : Tabibi.rouge),
      const SizedBox(width: 4),
      Text(actif ? 'Actif' : 'Inactif',
          style: TextStyle(fontSize: 12, color: actif ? Tabibi.vert : Tabibi.rouge)),
    ]);
  }

  // ---------- Rendez-vous ----------
  Widget _ongletRdv() {
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _chargerRdv,
      child: _rdv.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('Aucun rendez-vous.', style: TextStyle(color: Tabibi.texteDoux))),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: _rdv.length,
              itemBuilder: (_, i) {
                final r = _rdv[i];
                final date = formaterDateIso(langueDe(context), '${r['debut']}');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: Tabibi.ombreDouce,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['patientNom']} → ${r['medecinNom']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, color: Tabibi.texte)),
                        const SizedBox(height: 2),
                        Text(date,
                            style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
                      ]),
                    ),
                    Text(libelleStatut(langueDe(context), r['statut']),
                        style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
                  ]),
                );
              },
            ),
    );
  }
}
