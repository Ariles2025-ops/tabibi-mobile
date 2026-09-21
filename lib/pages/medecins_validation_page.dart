import 'package:flutter/material.dart';

import '../services/admin_supabase.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../widgets/vue_erreur.dart';

/// Validation avancee des fiches medecins (les fiches importees, reclamees par un praticien) :
/// onglets A valider / Validees / Rejetees, recherche, et validation / rejet avec motif.
class MedecinsValidationPage extends StatefulWidget {
  const MedecinsValidationPage({super.key, this.admin = const AdminSupabase(), this.auth});

  final AdminSupabase admin;
  final AuthService? auth;

  @override
  State<MedecinsValidationPage> createState() => _MedecinsValidationPageState();
}

class _MedecinsValidationPageState extends State<MedecinsValidationPage>
    with SingleTickerProviderStateMixin {
  late final AuthService _auth = widget.auth ?? session;
  late final TabController _tc = TabController(length: 3, vsync: this)
    ..addListener(_onTab);
  final _recherche = TextEditingController();

  static const _tabs = ['pending', 'approved', 'rejected'];
  List<Map<String, dynamic>> _fiches = [];
  bool _charge = false;
  String? _enCours;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _tc.removeListener(_onTab);
    _tc.dispose();
    _recherche.dispose();
    super.dispose();
  }

  void _onTab() {
    if (!_tc.indexIsChanging) _charger();
  }

  String get _tab => _tabs[_tc.index];

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final f = await widget.admin.fichesAValider(tab: _tab, q: _recherche.text.trim());
      if (mounted) setState(() => _fiches = f);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _valider(String id) async {
    if (_enCours != null) return;
    setState(() => _enCours = id);
    try {
      await widget.admin.validerFiche(id);
      if (mounted) _msg('Fiche validée');
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
    await _charger();
  }

  Future<void> _rejeter(String id) async {
    final motif = await _demanderMotif();
    if (motif == null) return;
    setState(() => _enCours = id);
    try {
      await widget.admin.rejeterFiche(id, motif);
      if (mounted) _msg('Fiche rejetée');
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
    await _charger();
  }

  Future<String?> _demanderMotif() async {
    final c = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motif du rejet'),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Ex. document illisible, n° d\'ordre invalide…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tabibi.rouge),
            onPressed: () {
              final t = c.text.trim();
              if (t.length < 3) return;
              Navigator.pop(ctx, t);
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    c.dispose();
    return motif;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation des fiches'),
        actions: [
          IconButton(onPressed: _charge ? null : _charger, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tc,
          labelColor: Tabibi.vert,
          indicatorColor: Tabibi.vert,
          unselectedLabelColor: Tabibi.texteDoux,
          tabs: const [
            Tab(text: 'À valider'),
            Tab(text: 'Validées'),
            Tab(text: 'Rejetées'),
          ],
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _recherche,
            onSubmitted: (_) => _charger(),
            decoration: InputDecoration(
              hintText: 'Rechercher (nom ou email)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _charger),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(child: _corps()),
      ]),
    );
  }

  Widget _corps() {
    if (_charge) return const Center(child: CircularProgressIndicator());
    if (_erreur != null) return VueErreur(message: _erreur!, onReessayer: _charger);
    if (_fiches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Aucune fiche dans cet onglet.',
              textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
        ),
      );
    }
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: _fiches.length,
        itemBuilder: (_, i) => _carte(_fiches[i]),
      ),
    );
  }

  Widget _carte(Map<String, dynamic> f) {
    final id = '${f['id']}';
    final sous = [
      if ('${f['specialite'] ?? ''}'.isNotEmpty) '${f['specialite']}',
      if ('${f['wilayaCode'] ?? ''}'.isNotEmpty) 'Wilaya ${f['wilayaCode']}',
      if ('${f['ordre'] ?? ''}'.isNotEmpty) 'Ordre ${f['ordre']}',
    ].join(' · ');
    final estAValider = _tab == 'pending';
    final estRejetee = _tab == 'rejected';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${f['nom'] ?? 'Médecin'}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
        if (sous.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(sous, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
          ),
        if ('${f['email'] ?? ''}'.isNotEmpty)
          Text('${f['email']}', style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (!estRejetee)
            TextButton(
              onPressed: _enCours != null ? null : () => _rejeter(id),
              style: TextButton.styleFrom(foregroundColor: Tabibi.rouge),
              child: const Text('Rejeter'),
            ),
          if (!estAValider) const SizedBox(width: 6),
          if (_tab != 'approved')
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Tabibi.vert, visualDensity: VisualDensity.compact),
              onPressed: _enCours != null ? null : () => _valider(id),
              child: const Text('Valider'),
            ),
        ]),
      ]),
    );
  }
}
