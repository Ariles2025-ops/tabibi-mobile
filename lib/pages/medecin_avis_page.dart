import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../widgets/vue_erreur.dart';

/// Avis reçus par le praticien.
class MedecinAvisPage extends StatefulWidget {
  const MedecinAvisPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinAvisPage> createState() => _MedecinAvisPageState();
}

class _MedecinAvisPageState extends State<MedecinAvisPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _avis = [];
  bool _charge = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final a = await widget.medecin.avisRecus();
      if (mounted) setState(() => _avis = a);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  double? get _moyenne {
    final notes = _avis
        .where((a) => '${a['statut']}' == 'published')
        .map((a) => a['note'])
        .whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    if (notes.isEmpty) return null;
    return notes.reduce((x, y) => x + y) / notes.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avis reçus')),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? VueErreur(message: _erreur!, onReessayer: _charger)
              : _avis.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aucun avis pour le moment.',
                            textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                      ),
                    )
                  : RefreshIndicator(
                      color: Tabibi.vert,
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          if (_moyenne != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Tabibi.vertTresClair, borderRadius: BorderRadius.circular(16)),
                              child: Row(children: [
                                const Icon(Icons.star, color: Tabibi.or),
                                const SizedBox(width: 8),
                                Text('${_moyenne!.toStringAsFixed(1)} / 5',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Tabibi.texte)),
                                const SizedBox(width: 8),
                                Text('(${_avis.length} avis)', style: const TextStyle(color: Tabibi.texteDoux)),
                              ]),
                            ),
                          for (final a in _avis) _carte(a),
                        ],
                      ),
                    ),
    );
  }

  Widget _carte(Map<String, dynamic> a) {
    final publie = '${a['statut']}' == 'published';
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
          if (!publie)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Tabibi.bg2, borderRadius: BorderRadius.circular(999)),
              child: Text('${a['statut']}', style: const TextStyle(color: Tabibi.texte3, fontSize: 11)),
            ),
        ]),
        if ('${a['commentaire'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${a['commentaire']}', style: const TextStyle(color: Tabibi.texteDoux)),
        ],
        const SizedBox(height: 4),
        Text(formaterDateIso(langueDe(context), '${a['creeLe']}'),
            style: const TextStyle(color: Tabibi.texte4, fontSize: 11)),
        if ('${a['reponse'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Tabibi.vertTresClair, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Votre réponse',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Tabibi.vert, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${a['reponse']}', style: const TextStyle(color: Tabibi.texte)),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _repondre(a),
            icon: Icon('${a['reponse'] ?? ''}'.isEmpty ? Icons.reply : Icons.edit, size: 16, color: Tabibi.vert),
            label: Text('${a['reponse'] ?? ''}'.isEmpty ? 'Répondre' : 'Modifier la réponse',
                style: const TextStyle(color: Tabibi.vert)),
          ),
        ),
      ]),
    );
  }

  Future<void> _repondre(Map<String, dynamic> a) async {
    final ctrl = TextEditingController(text: '${a['reponse'] ?? ''}');
    final valider = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Répondre à l\'avis'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Votre réponse publique…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Publier')),
        ],
      ),
    );
    if (valider != true) return;
    try {
      await widget.medecin.repondreAvis('${a['id']}', ctrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réponse enregistrée')));
      await _charger();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'enregistrer la réponse')));
      }
    }
  }
}
