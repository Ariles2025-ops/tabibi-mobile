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
  Map<String, dynamic> _dawiniStats = const {};
  List<Map<String, dynamic>> _attente = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _rdv = [];
  List<Map<String, dynamic>> _avis = [];
  List<Map<String, dynamic>> _dawini = [];
  List<Map<String, dynamic>> _cabinets = [];
  final _recherche = TextEditingController();
  String? _roleFiltre;
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
    await Future.wait([
      _chargerStats(),
      _chargerAttente(),
      _chargerUsers(),
      _chargerRdv(),
      _chargerAvis(),
      _chargerDawini(),
      _chargerCabinets(),
    ]);
    if (mounted) setState(() => _charge = false);
  }

  Future<void> _chargerStats() async {
    try {
      final s = await widget.admin.stats();
      final d = await widget.admin.dawiniStats();
      if (mounted) setState(() {
        _stats = s;
        _dawiniStats = d;
      });
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
      final u = await widget.admin.listerUtilisateurs(role: _roleFiltre, q: _recherche.text.trim());
      if (mounted) setState(() => _users = u);
    } on Exception {/* ignore */}
  }

  Future<void> _chargerRdv() async {
    try {
      final r = await widget.admin.listerRdv();
      if (mounted) setState(() => _rdv = r);
    } on Exception {/* ignore */}
  }

  Future<void> _chargerAvis() async {
    try {
      final a = await widget.admin.avisAModerer();
      if (mounted) setState(() => _avis = a);
    } on Exception {/* ignore */}
  }

  Future<void> _chargerDawini() async {
    try {
      final d = await widget.admin.listerDawini();
      if (mounted) setState(() => _dawini = d);
    } on Exception {/* ignore */}
  }

  Future<void> _chargerCabinets() async {
    try {
      final c = await widget.admin.listerCabinets();
      if (mounted) setState(() => _cabinets = c);
    } on Exception {/* ignore */}
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _run(String cle, Future<void> Function() op, String ok, {Future<void> Function()? apres}) async {
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
    if (apres != null) await apres();
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
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Console admin'),
          actions: [
            IconButton(onPressed: _charge ? null : _tout, icon: const Icon(Icons.refresh)),
            IconButton(onPressed: () => _auth.seDeconnecter(), icon: const Icon(Icons.logout)),
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
              Tab(text: 'Avis'),
              Tab(text: 'Dawini'),
              Tab(text: 'Cabinets'),
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
                  _ongletAvis(),
                  _ongletDawini(),
                  _ongletCabinets(),
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
            childAspectRatio: 1.15,
            children: [
              _kpi('Patients', _stats['patients'], Icons.people_outline),
              _kpi('Médecins actifs', _stats['medecinsActifs'], Icons.medical_services_outlined),
              _kpi('Médecins en attente', _stats['medecinsAttente'], Icons.hourglass_top_outlined, accent: true),
              _kpi('Rendez-vous', _stats['rdv'], Icons.event_outlined),
              _kpi('Candidatures', _stats['candidatures'], Icons.assignment_outlined),
              _kpi('Demandes Dawini', _dawiniStats['demandes'], Icons.local_pharmacy_outlined),
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
      padding: const EdgeInsets.all(12),
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
                  fontSize: 22, fontWeight: FontWeight.w800, color: accent ? Tabibi.orTexte : Tabibi.texte)),
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
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['nom'] ?? email}', style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
            const SizedBox(height: 2),
            Text(email, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
            if (sous.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(sous, style: const TextStyle(color: Tabibi.texte3, fontSize: 12))),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Tabibi.vert, visualDensity: VisualDensity.compact),
          onPressed: _enCours != null ? null : () => _run('val:$email', () => widget.admin.validerMedecin(email), 'Médecin validé', apres: () async { await _chargerStats(); await _chargerAttente(); await _chargerUsers(); }),
          child: const Text('Valider'),
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
              ? const Center(child: Text('Aucun utilisateur.', style: TextStyle(color: Tabibi.texteDoux)))
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _roleFiltre == role,
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${u['nom'] ?? email}', style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
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
          if (actif)
            TextButton(
              onPressed: _enCours != null ? null : () => _run('des:$email', () => widget.admin.desactiverCompte(email), 'Compte désactivé', apres: _chargerUsers),
              child: const Text('Désactiver'),
            )
          else
            TextButton(
              onPressed: _enCours != null ? null : () => _run('act:$email', () => widget.admin.activerCompte(email), 'Compte activé', apres: _chargerUsers),
              child: const Text('Activer'),
            ),
          TextButton(
            onPressed: _enCours != null ? null : () => _confirmerSuppression(email),
            style: TextButton.styleFrom(foregroundColor: Tabibi.rouge),
            child: const Text('Supprimer'),
          ),
        ]),
      ]),
    );
  }

  Future<void> _confirmerSuppression(String email) async {
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
    await _run('del:$email', () => widget.admin.supprimerCompte(email), 'Compte supprimé',
        apres: () async { await _chargerStats(); await _chargerUsers(); });
  }

  Widget _badgeRole(String role) {
    Color bg = Tabibi.bg2, fg = Tabibi.texte3;
    String txt = role.isEmpty ? '—' : role;
    if (role == 'admin') { bg = Tabibi.orClair; fg = Tabibi.orTexte; txt = 'Admin'; }
    else if (role == 'medecin') { bg = Tabibi.vertTresClair; fg = Tabibi.vert; txt = 'Médecin'; }
    else if (role == 'patient') { txt = 'Patient'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(txt, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _pastilleEtat(bool actif) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(actif ? Icons.check_circle : Icons.cancel, size: 14, color: actif ? Tabibi.vert : Tabibi.rouge),
      const SizedBox(width: 4),
      Text(actif ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 12, color: actif ? Tabibi.vert : Tabibi.rouge)),
    ]);
  }

  // ---------- Rendez-vous ----------
  Widget _ongletRdv() {
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _chargerRdv,
      child: _rdv.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Aucun rendez-vous.', style: TextStyle(color: Tabibi.texteDoux)))])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: _rdv.length,
              itemBuilder: (_, i) {
                final r = _rdv[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['patientNom']} → ${r['medecinNom']}', style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
                        const SizedBox(height: 2),
                        Text(formaterDateIso(langueDe(context), '${r['debut']}'), style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
                      ]),
                    ),
                    Text(libelleStatut(langueDe(context), r['statut']), style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
                  ]),
                );
              },
            ),
    );
  }

  // ---------- Avis (moderation) ----------
  Widget _ongletAvis() {
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _chargerAvis,
      child: _avis.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Aucun avis à modérer.', style: TextStyle(color: Tabibi.texteDoux)))])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: _avis.length,
              itemBuilder: (_, i) {
                final a = _avis[i];
                final id = '${a['id']}';
                final signal = a['signalements'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.star, size: 16, color: Tabibi.or),
                      const SizedBox(width: 4),
                      Text('${a['note'] ?? '-'} / 5', style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
                      const Spacer(),
                      if ((signal as num) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Tabibi.rougeClair, borderRadius: BorderRadius.circular(999)),
                          child: Text('$signal signalement(s)', style: const TextStyle(color: Tabibi.rouge, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Dr ${a['medecinNom'] ?? ''} · ${a['statut'] ?? ''}', style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
                    if ('${a['commentaire'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('${a['commentaire']}', style: const TextStyle(color: Tabibi.texteDoux)),
                    ],
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                        onPressed: _enCours != null ? null : () => _run('rej:$id', () => widget.admin.rejeterAvis(id), 'Avis masqué', apres: _chargerAvis),
                        style: TextButton.styleFrom(foregroundColor: Tabibi.rouge),
                        child: const Text('Masquer'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Tabibi.vert, visualDensity: VisualDensity.compact),
                        onPressed: _enCours != null ? null : () => _run('pub:$id', () => widget.admin.publierAvis(id), 'Avis publié', apres: _chargerAvis),
                        child: const Text('Publier'),
                      ),
                    ]),
                  ]),
                );
              },
            ),
    );
  }

  // ---------- Dawini ----------
  Widget _ongletDawini() {
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _chargerDawini,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(children: [
            Expanded(child: _miniStat('Demandes', _dawiniStats['demandes'])),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('Pharmacies', _dawiniStats['pharmacies'])),
          ]),
          const SizedBox(height: 16),
          const Text('Demandes récentes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.texte)),
          const SizedBox(height: 8),
          if (_dawini.isEmpty)
            const Text('Aucune demande.', style: TextStyle(color: Tabibi.texteDoux))
          else
            for (final d in _dawini)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['medicaments'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
                  const SizedBox(height: 2),
                  Text('Wilaya ${d['wilaya'] ?? '?'} · ${d['statut'] ?? ''} · ${d['nbReponses'] ?? 0} réponse(s)',
                      style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
                ]),
              ),
        ],
      ),
    );
  }

  Widget _miniStat(String libelle, Object? valeur) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${valeur ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Tabibi.texte)),
        Text(libelle, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
      ]),
    );
  }

  // ---------- Cabinets ----------
  Widget _ongletCabinets() {
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _chargerCabinets,
      child: _cabinets.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Aucun cabinet.', style: TextStyle(color: Tabibi.texteDoux)))])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: _cabinets.length,
              itemBuilder: (_, i) {
                final c = _cabinets[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
                  child: ListTile(
                    title: Text('${c['nom'] ?? 'Cabinet'}', style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
                    subtitle: Text([
                      if ('${c['commune'] ?? ''}'.isNotEmpty) '${c['commune']}',
                      if ('${c['wilaya'] ?? ''}'.isNotEmpty) '${c['wilaya']}',
                      '${c['nbMembres'] ?? 0} membre(s)',
                    ].join(' · '), style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Tabibi.texte4),
                    onTap: () => _ouvrirMembres('${c['id']}', '${c['nom'] ?? 'Cabinet'}'),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _ouvrirMembres(String cabinetId, String nom) async {
    List<Map<String, dynamic>> membres = [];
    try {
      membres = await widget.admin.membresCabinet(cabinetId);
    } on Exception catch (e) {
      _msg(e.toString());
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Tabibi.ink)),
              const SizedBox(height: 4),
              const Text('Membres', style: TextStyle(color: Tabibi.texteDoux)),
              const SizedBox(height: 12),
              if (membres.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucun membre.', style: TextStyle(color: Tabibi.texteDoux)))
              else
                for (final mem in membres)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${mem['nom'] ?? mem['email'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
                          Text('${mem['role'] ?? ''} · ${mem['email'] ?? ''}', style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
                        ]),
                      ),
                      if (mem['actif'] == true)
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Tabibi.rouge),
                          onPressed: () async {
                            try {
                              await widget.admin.retirerMembreCabinet('${mem['id']}');
                              setSheet(() => mem['actif'] = false);
                              _msg('Membre retiré');
                              _chargerCabinets();
                            } on Exception catch (e) {
                              _msg(e.toString());
                            }
                          },
                          child: const Text('Retirer'),
                        )
                      else
                        const Text('Retiré', style: TextStyle(color: Tabibi.texte4, fontSize: 12)),
                    ]),
                  ),
            ]),
          ),
        ),
      ),
    );
  }
}
