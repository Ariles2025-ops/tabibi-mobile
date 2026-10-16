import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../theme/theme_tabibi.dart';

/// Verification du profil praticien : numero d'Ordre, upload de documents
/// (carte d'Ordre / diplome), statut de validation et indicateur de completude.
class MedecinVerificationPage extends StatefulWidget {
  final AuthService? auth;
  final MedecinSupabase medecin;
  const MedecinVerificationPage({super.key, this.auth, this.medecin = const MedecinSupabase()});

  @override
  State<MedecinVerificationPage> createState() => _MedecinVerificationPageState();
}

class _MedecinVerificationPageState extends State<MedecinVerificationPage> {
  final _ordre = TextEditingController();
  Map<String, dynamic>? _p;
  bool _charge = true;
  bool _envoi = false;
  bool _docEnvoye = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _ordre.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final p = await widget.medecin.profilVerification();
      if (!mounted) return;
      setState(() {
        _p = p;
        _ordre.text = '${p?['ordre_number'] ?? ''}';
        _charge = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _charge = false);
      _msg('Chargement impossible : $e');
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  int _completude() {
    final p = _p ?? const {};
    int ok = 0;
    const total = 6;
    if ('${p['ordre_number'] ?? ''}'.trim().isNotEmpty) ok++;
    if ('${p['bio'] ?? ''}'.trim().isNotEmpty) ok++;
    if ('${p['photo_url'] ?? ''}'.trim().isNotEmpty) ok++;
    if ((p['consultation_fee_dzd'] as num?) != null && (p['consultation_fee_dzd'] as num) > 0) ok++;
    final wh = p['working_hours'];
    if (wh is Map && wh.isNotEmpty) ok++;
    if (_docEnvoye || '${p['ordre_card_path'] ?? ''}'.trim().isNotEmpty) ok++;
    return ((ok / total) * 100).round();
  }

  Future<void> _enregistrerOrdre() async {
    final v = _ordre.text.trim();
    if (v.length < 3) { _msg('Numéro d\'Ordre trop court.'); return; }
    setState(() => _envoi = true);
    try {
      final r = await widget.medecin.setNumeroOrdre(v);
      if (r == 'ok') {
        _msg('Numéro d\'Ordre enregistré.');
        await _charger();
      } else if (r == 'invalid_format') {
        _msg('Format du numéro invalide.');
      } else if (r == 'locked_approved') {
        _msg('Profil déjà validé — modification verrouillée.');
      } else {
        _msg('Aucune fiche praticien à mettre à jour.');
      }
    } catch (e) {
      _msg('Erreur : $e');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _uploader() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) { _msg('Fichier illisible.'); return; }
      final ext = (f.extension ?? 'jpg').toLowerCase();
      setState(() => _envoi = true);
      await widget.medecin.uploaderDocOrdre(bytes, ext);
      if (!mounted) return;
      setState(() => _docEnvoye = true);
      _msg('Document téléversé.');
    } catch (e) {
      _msg('Upload impossible : $e');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _demander() async {
    setState(() => _envoi = true);
    try {
      final r = await widget.medecin.demanderVerification();
      if (r == 'ok') {
        _msg('Demande envoyée. Un administrateur va vérifier votre profil.');
        await _charger();
      } else if (r == 'already_approved') {
        _msg('Votre profil est déjà vérifié.');
      } else {
        _msg('Aucune fiche praticien trouvée.');
      }
    } catch (e) {
      _msg('Erreur : $e');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification du profil')),
      body: _charge
          ? const Center(child: CircularProgressIndicator(color: Tabibi.vert))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statut(),
                const SizedBox(height: 16),
                _completudeCarte(),
                const SizedBox(height: 20),
                const Text('Numéro d\'Ordre', style: TextStyle(fontWeight: FontWeight.w700, color: Tabibi.ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ordre,
                  decoration: InputDecoration(
                    hintText: 'Ex. 16/12345',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _envoi ? null : _enregistrerOrdre,
                  child: const Text('Enregistrer le numéro'),
                ),
                const SizedBox(height: 20),
                const Text('Documents (carte d\'Ordre, diplôme)', style: TextStyle(fontWeight: FontWeight.w700, color: Tabibi.ink)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _envoi ? null : _uploader,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_docEnvoye ? 'Document envoyé ✓ — en ajouter un autre' : 'Téléverser un document'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _envoi ? null : _demander,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Demander la vérification'),
                  style: FilledButton.styleFrom(backgroundColor: Tabibi.vert, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Après votre demande, un administrateur Tabibi vérifie vos documents et active le badge « Vérifié » sur votre fiche.',
                  style: TextStyle(fontSize: 12, color: Tabibi.texteDoux),
                ),
              ],
            ),
    );
  }

  Widget _statut() {
    final p = _p ?? const {};
    final verifie = p['is_verified'] == true;
    final st = '${p['validation_status'] ?? ''}';
    late Color c; late String txt; late IconData ic;
    if (verifie || st == 'approved') { c = Tabibi.vert; txt = 'Profil vérifié'; ic = Icons.verified; }
    else if (st == 'pending') { c = Tabibi.or; txt = 'Vérification en cours'; ic = Icons.hourglass_top; }
    else if (st == 'rejected') { c = Tabibi.rouge; txt = 'Vérification refusée — corrigez et redemandez'; ic = Icons.error_outline; }
    else { c = Tabibi.texte4; txt = 'Non vérifié'; ic = Icons.info_outline; }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.5))),
      child: Row(children: [
        Icon(ic, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(txt, style: TextStyle(fontWeight: FontWeight.w700, color: c))),
      ]),
    );
  }

  Widget _completudeCarte() {
    final pct = _completude();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Tabibi.bord)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Complétude du profil', style: TextStyle(fontWeight: FontWeight.w700, color: Tabibi.ink)),
          Text('$pct %', style: const TextStyle(fontWeight: FontWeight.w800, color: Tabibi.vert)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: Tabibi.bord,
            color: Tabibi.vert,
          ),
        ),
      ]),
    );
  }
}
