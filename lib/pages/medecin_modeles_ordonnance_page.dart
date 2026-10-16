import 'package:flutter/material.dart';

import '../services/medecin_supabase.dart';
import '../theme/theme_tabibi.dart';

/// Modèles d'ordonnances réutilisables : le médecin enregistre des listes de
/// médicaments fréquentes pour les réutiliser rapidement.
class MedecinModelesOrdonnancePage extends StatefulWidget {
  const MedecinModelesOrdonnancePage({super.key, this.medecin = const MedecinSupabase()});

  final MedecinSupabase medecin;

  @override
  State<MedecinModelesOrdonnancePage> createState() => _MedecinModelesOrdonnancePageState();
}

class _MedecinModelesOrdonnancePageState extends State<MedecinModelesOrdonnancePage> {
  bool _charge = true;
  List<Map<String, dynamic>> _modeles = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _charge = true);
    try {
      final m = await widget.medecin.mesModelesOrdonnance();
      if (mounted) setState(() { _modeles = m; _charge = false; });
    } on Object {
      if (mounted) setState(() => _charge = false);
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  List<String> _nomsMedicaments(dynamic meds) {
    if (meds is! List) return const [];
    return meds
        .map((e) => e is Map ? '${e['nom'] ?? e['name'] ?? ''}' : '$e')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modèles d\'ordonnances')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Tabibi.vert,
        onPressed: _creer,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau modèle'),
      ),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _modeles.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Aucun modèle.\nCréez-en un pour gagner du temps lors de vos ordonnances.',
                        textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                  ),
                )
              : RefreshIndicator(
                  color: Tabibi.vert,
                  onRefresh: _charger,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: [for (final m in _modeles) _carte(m)],
                  ),
                ),
    );
  }

  Widget _carte(Map<String, dynamic> m) {
    final noms = _nomsMedicaments(m['medications']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${m['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Tabibi.texte, fontSize: 15))),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Tabibi.rouge),
            onPressed: () => _supprimer(m),
          ),
        ]),
        if (('${m['diagnostic'] ?? ''}').isNotEmpty) ...[
          Text('Diagnostic : ${m['diagnostic']}', style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
          const SizedBox(height: 6),
        ],
        for (final n in noms)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  ', style: TextStyle(color: Tabibi.vert)),
              Expanded(child: Text(n, style: const TextStyle(color: Tabibi.texte))),
            ]),
          ),
        if (noms.isEmpty)
          const Text('Aucun médicament', style: TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
      ]),
    );
  }

  Future<void> _creer() async {
    final nom = TextEditingController();
    final meds = TextEditingController();
    final diag = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nouveau modèle'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom du modèle *')),
            const SizedBox(height: 8),
            TextField(
                controller: meds,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Médicaments (un par ligne)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                )),
            const SizedBox(height: 8),
            TextField(controller: diag, decoration: const InputDecoration(labelText: 'Diagnostic (optionnel)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    if (nom.text.trim().isEmpty) { _msg('Le nom est obligatoire'); return; }
    final lignes = meds.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => <String, dynamic>{'nom': l})
        .toList();
    try {
      await widget.medecin.creerModeleOrdonnance(
        nom: nom.text.trim(),
        medications: lignes,
        diagnostic: diag.text.trim().isEmpty ? null : diag.text.trim(),
      );
      _msg('Modèle enregistré');
      await _charger();
    } on Object {
      _msg('Impossible d\'enregistrer le modèle');
    }
  }

  Future<void> _supprimer(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce modèle ?'),
        content: Text('« ${m['name'] ?? ''} » sera supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tabibi.rouge),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.medecin.supprimerModeleOrdonnance('${m['id']}');
      _msg('Modèle supprimé');
      await _charger();
    } on Object {
      _msg('Impossible de supprimer le modèle');
    }
  }
}
