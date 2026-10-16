import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../widgets/vue_erreur.dart';

/// Congés / absences : le praticien bloque des plages où il n'est pas disponible.
/// Les créneaux bloqués n'apparaissent plus à la réservation (get_available_slots).
class MedecinAbsencesPage extends StatefulWidget {
  const MedecinAbsencesPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinAbsencesPage> createState() => _MedecinAbsencesPageState();
}

class _MedecinAbsencesPageState extends State<MedecinAbsencesPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _absences = [];
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
      final a = await widget.medecin.mesAbsences();
      if (mounted) setState(() => _absences = a);
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

  Future<void> _ajouter() async {
    final cree = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormAbsence(medecin: widget.medecin),
    );
    if (cree == true) {
      _msg('Absence enregistrée');
      _charger();
    }
  }

  Future<void> _supprimer(Map<String, dynamic> a) async {
    try {
      await widget.medecin.supprimerAbsence('${a['id']}');
      if (mounted) setState(() => _absences.remove(a));
    } on Exception catch (e) {
      _msg(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Congés / absences')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Tabibi.vert,
        onPressed: _ajouter,
        icon: const Icon(Icons.add),
        label: const Text('Bloquer'),
      ),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? VueErreur(message: _erreur!, onReessayer: _charger)
              : _absences.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aucune absence programmée.\nBloquez une plage pour ne pas recevoir de rendez-vous.',
                            textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                      ),
                    )
                  : RefreshIndicator(
                      color: Tabibi.vert,
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        children: [for (final a in _absences) _carte(a)],
                      ),
                    ),
    );
  }

  Widget _carte(Map<String, dynamic> a) {
    final lang = langueDe(context);
    final journee = a['journeeEntiere'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Tabibi.orClair, shape: BoxShape.circle),
          child: const Icon(Icons.event_busy, color: Tabibi.orTexte, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${formaterDateIso(lang, '${a['debut']}')} → ${formaterDateIso(lang, '${a['fin']}')}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte, fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              journee
                  ? 'Journée(s) entière(s)${'${a['motif'] ?? ''}'.isNotEmpty ? ' · ${a['motif']}' : ''}'
                  : ('${a['motif'] ?? ''}'.isEmpty ? 'Plage bloquée' : '${a['motif']}'),
              style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12),
            ),
          ]),
        ),
        IconButton(
          onPressed: () => _supprimer(a),
          icon: const Icon(Icons.delete_outline, color: Tabibi.rouge),
        ),
      ]),
    );
  }
}

class _FormAbsence extends StatefulWidget {
  const _FormAbsence({required this.medecin});
  final MedecinSupabase medecin;

  @override
  State<_FormAbsence> createState() => _FormAbsenceState();
}

class _FormAbsenceState extends State<_FormAbsence> {
  final _motif = TextEditingController();
  DateTime _debut = DateTime.now().add(const Duration(days: 1));
  DateTime _fin = DateTime.now().add(const Duration(days: 1));
  bool _journee = true;
  bool _envoi = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _choisirDate(bool debut) async {
    final init = debut ? _debut : _fin;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null) return;
    TimeOfDay? t;
    if (!_journee) {
      t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(init),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
    }
    final res = DateTime(d.year, d.month, d.day, t?.hour ?? (debut ? 0 : 23), t?.minute ?? (debut ? 0 : 59));
    setState(() {
      if (debut) {
        _debut = res;
        if (_fin.isBefore(_debut)) _fin = _debut;
      } else {
        _fin = res;
      }
    });
  }

  Future<void> _enregistrer() async {
    if (_fin.isBefore(_debut)) {
      _msg('La fin doit être après le début.');
      return;
    }
    setState(() => _envoi = true);
    try {
      DateTime debut = _debut;
      DateTime fin = _fin;
      if (_journee) {
        debut = DateTime(_debut.year, _debut.month, _debut.day, 0, 0);
        fin = DateTime(_fin.year, _fin.month, _fin.day, 23, 59);
      }
      await widget.medecin.ajouterAbsence(
        debut: debut,
        fin: fin,
        motif: _motif.text,
        journeeEntiere: _journee,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  String _fmt(DateTime d) {
    final j = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (_journee) return j;
    return '$j ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bloquer une période', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Tabibi.ink)),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: Tabibi.vert,
          title: const Text('Journée(s) entière(s)'),
          value: _journee,
          onChanged: (v) => setState(() => _journee = v),
        ),
        Row(children: [
          Expanded(child: _champDate('Début', _fmt(_debut), () => _choisirDate(true))),
          const SizedBox(width: 12),
          Expanded(child: _champDate('Fin', _fmt(_fin), () => _choisirDate(false))),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _motif,
          decoration: const InputDecoration(labelText: 'Motif (optionnel)', hintText: 'Congés, formation…'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Tabibi.vert, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _envoi ? null : _enregistrer,
          icon: _envoi
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.block),
          label: const Text('Bloquer cette période'),
        ),
      ]),
    );
  }

  Widget _champDate(String label, String valeur, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Tabibi.bg2, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 11)),
          const SizedBox(height: 2),
          Text(valeur, style: const TextStyle(color: Tabibi.texte, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      ),
    );
  }
}
