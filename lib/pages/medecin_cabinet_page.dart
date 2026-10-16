import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../theme/theme_tabibi.dart';

/// Gestion des cabinets du praticien : liste, création, et accès aux membres
/// (médecins & secrétariat).
class MedecinCabinetPage extends StatefulWidget {
  const MedecinCabinetPage({super.key, this.auth, this.medecin = const MedecinSupabase()});

  final AuthService? auth;
  final MedecinSupabase medecin;

  @override
  State<MedecinCabinetPage> createState() => _MedecinCabinetPageState();
}

class _MedecinCabinetPageState extends State<MedecinCabinetPage> {
  bool _charge = true;
  String? _erreur;
  List<Map<String, dynamic>> _cabinets = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _charge = true; _erreur = null; });
    try {
      final c = await widget.medecin.mesCabinets();
      if (mounted) setState(() { _cabinets = c; _charge = false; });
    } on Object catch (e) {
      if (mounted) setState(() { _erreur = e.toString(); _charge = false; });
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon cabinet')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Tabibi.vert,
        onPressed: _creer,
        icon: const Icon(Icons.add),
        label: const Text('Créer un cabinet'),
      ),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Erreur : $_erreur')))
              : _cabinets.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                            'Aucun cabinet.\nCréez-en un pour gérer votre équipe (médecins, secrétariat).',
                            textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                      ),
                    )
                  : RefreshIndicator(
                      color: Tabibi.vert,
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        children: [for (final c in _cabinets) _carteCabinet(c)],
                      ),
                    ),
    );
  }

  Widget _carteCabinet(Map<String, dynamic> c) {
    final role = '${c['role'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42, height: 42, alignment: Alignment.center,
          decoration: const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
          child: const Icon(Icons.business_outlined, color: Tabibi.vert, size: 20),
        ),
        title: Text('${c['name'] ?? 'Cabinet'}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$role · ${c['member_count'] ?? 0} membre(s)',
            style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Tabibi.texte4),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CabinetMembresPage(
            medecin: widget.medecin,
            cabinetId: '${c['cabinet_id']}',
            cabinetNom: '${c['name'] ?? 'Cabinet'}',
            monRole: role,
          ),
        )),
      ),
    );
  }

  Future<void> _creer() async {
    final nom = TextEditingController();
    final wilaya = TextEditingController();
    final commune = TextEditingController();
    final adresse = TextEditingController();
    final tel = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nouveau cabinet'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom du cabinet *')),
            TextField(controller: wilaya, decoration: const InputDecoration(labelText: 'Wilaya')),
            TextField(controller: commune, decoration: const InputDecoration(labelText: 'Commune')),
            TextField(controller: adresse, decoration: const InputDecoration(labelText: 'Adresse')),
            TextField(controller: tel, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true) return;
    if (nom.text.trim().isEmpty) { _msg('Le nom est obligatoire'); return; }
    try {
      await widget.medecin.creerCabinet(
        nom: nom.text.trim(),
        wilaya: _vide(wilaya.text),
        commune: _vide(commune.text),
        adresse: _vide(adresse.text),
        telephone: _vide(tel.text),
      );
      _msg('Cabinet créé');
      await _charger();
    } on Object {
      _msg('Impossible de créer le cabinet');
    }
  }

  String? _vide(String s) => s.trim().isEmpty ? null : s.trim();
}

/// Membres d'un cabinet : liste, invitation par e-mail, retrait.
class CabinetMembresPage extends StatefulWidget {
  const CabinetMembresPage({
    super.key,
    required this.medecin,
    required this.cabinetId,
    required this.cabinetNom,
    required this.monRole,
  });

  final MedecinSupabase medecin;
  final String cabinetId;
  final String cabinetNom;
  final String monRole;

  @override
  State<CabinetMembresPage> createState() => _CabinetMembresPageState();
}

class _CabinetMembresPageState extends State<CabinetMembresPage> {
  bool _charge = true;
  List<Map<String, dynamic>> _membres = [];

  bool get _peutGerer => widget.monRole == 'owner' || widget.monRole == 'admin';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _charge = true);
    try {
      final m = await widget.medecin.membresCabinet(widget.cabinetId);
      if (mounted) setState(() { _membres = m; _charge = false; });
    } on Object {
      if (mounted) setState(() => _charge = false);
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cabinetNom)),
      floatingActionButton: _peutGerer
          ? FloatingActionButton.extended(
              backgroundColor: Tabibi.vert,
              onPressed: _inviter,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Inviter'),
            )
          : null,
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: Tabibi.vert,
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  for (final m in _membres) _carteMembre(m),
                  if (_membres.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aucun membre.', textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _carteMembre(Map<String, dynamic> m) {
    final role = '${m['role'] ?? ''}';
    final accepte = m['accepted'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Tabibi.pastille, child: Icon(Icons.person, color: Tabibi.vert)),
        title: Text('${m['full_name'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            [_libelleRole(role), if (m['specialty_fr'] != null) '${m['specialty_fr']}', if (!accepte) 'invitation en attente']
                .join(' · '),
            style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
        trailing: (_peutGerer && role != 'owner')
            ? IconButton(
                icon: const Icon(Icons.person_remove_outlined, color: Tabibi.rouge),
                onPressed: () => _retirer(m),
              )
            : null,
      ),
    );
  }

  String _libelleRole(String r) => switch (r) {
        'owner' => 'Propriétaire',
        'admin' => 'Administrateur',
        'doctor' => 'Médecin',
        'secretaire' => 'Secrétariat',
        _ => r,
      };

  Future<void> _inviter() async {
    final email = TextEditingController();
    String role = 'secretaire';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Inviter un membre'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail (compte existant)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: const [
                DropdownMenuItem(value: 'secretaire', child: Text('Secrétariat')),
                DropdownMenuItem(value: 'doctor', child: Text('Médecin')),
                DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
              ],
              onChanged: (v) => setLocal(() => role = v ?? 'secretaire'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Inviter')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final e = email.text.trim();
    if (!e.contains('@')) { _msg('E-mail invalide'); return; }
    try {
      final u = await widget.medecin.chercherUtilisateurParEmail(e);
      if (u == null) { _msg('Aucun compte trouvé pour cet e-mail'); return; }
      await widget.medecin.inviterMembre(widget.cabinetId, '${u['user_id']}', role);
      _msg('${u['full_name'] ?? e} invité(e)');
      await _charger();
    } on Object {
      _msg('Impossible d\'inviter ce membre');
    }
  }

  Future<void> _retirer(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retirer ce membre ?'),
        content: Text('${m['full_name'] ?? ''} sera retiré(e) du cabinet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tabibi.rouge),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.medecin.retirerMembre(widget.cabinetId, '${m['user_id']}');
      _msg('Membre retiré');
      await _charger();
    } on Object {
      _msg('Impossible de retirer ce membre');
    }
  }
}
