import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../widgets/vue_erreur.dart';

/// Ordonnances emises par le praticien : liste + creation.
class MedecinOrdonnancesPage extends StatefulWidget {
  const MedecinOrdonnancesPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinOrdonnancesPage> createState() => _MedecinOrdonnancesPageState();
}

class _MedecinOrdonnancesPageState extends State<MedecinOrdonnancesPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _ordos = [];
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
      final o = await widget.medecin.mesOrdonnances();
      if (mounted) setState(() => _ordos = o);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _nouvelle() async {
    final cree = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => MedecinCreerOrdonnancePage(medecin: widget.medecin, auth: _auth)),
    );
    if (cree == true) _charger();
  }

  String _libelleStatut(String s) {
    switch (s) {
      case 'draft':
        return 'Brouillon';
      case 'pending_signature':
        return 'À signer';
      case 'signed':
        return 'Signée';
      case 'issued':
        return 'Émise';
      case 'cancelled':
        return 'Annulée';
      default:
        return s;
    }
  }

  Color _couleurStatut(String s) {
    switch (s) {
      case 'signed':
      case 'issued':
        return Tabibi.vert;
      case 'cancelled':
        return Tabibi.rouge;
      default:
        return Tabibi.orTexte;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ordonnances')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Tabibi.vert,
        onPressed: _nouvelle,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
      ),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? VueErreur(message: _erreur!, onReessayer: _charger)
              : _ordos.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aucune ordonnance émise.',
                            textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                      ),
                    )
                  : RefreshIndicator(
                      color: Tabibi.vert,
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        children: [for (final o in _ordos) _carte(o)],
                      ),
                    ),
    );
  }

  Widget _carte(Map<String, dynamic> o) {
    final statut = '${o['statut'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${o['patientNom'] ?? 'Patient'}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Tabibi.bg2, borderRadius: BorderRadius.circular(999)),
            child: Text(_libelleStatut(statut),
                style: TextStyle(color: _couleurStatut(statut), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        if ('${o['numero'] ?? ''}'.isNotEmpty)
          Text('N° ${o['numero']}', style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
        if ('${o['diagnostic'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('${o['diagnostic']}', style: const TextStyle(color: Tabibi.texteDoux, fontSize: 13)),
        ],
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.medication_outlined, size: 14, color: Tabibi.texte4),
          const SizedBox(width: 4),
          Text('${o['nbMedicaments'] ?? 0} médicament(s)', style: const TextStyle(color: Tabibi.texte4, fontSize: 12)),
          const Spacer(),
          Text(formaterDateIso(langueDe(context), '${o['emiseLe']}'),
              style: const TextStyle(color: Tabibi.texte4, fontSize: 11)),
        ]),
      ]),
    );
  }
}

/// Formulaire de creation d'une ordonnance : choix du patient + liste de medicaments.
class MedecinCreerOrdonnancePage extends StatefulWidget {
  const MedecinCreerOrdonnancePage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinCreerOrdonnancePage> createState() => _MedecinCreerOrdonnancePageState();
}

class _Medicament {
  final nom = TextEditingController();
  final dosage = TextEditingController();
  final duree = TextEditingController();
  void dispose() {
    nom.dispose();
    dosage.dispose();
    duree.dispose();
  }
}

class _MedecinCreerOrdonnancePageState extends State<MedecinCreerOrdonnancePage> {
  late final AuthService _auth = widget.auth ?? session;
  final _diagnostic = TextEditingController();
  final _notes = TextEditingController();
  final _validite = TextEditingController(text: '30');
  final List<_Medicament> _meds = [_Medicament()];

  List<Map<String, dynamic>> _patients = [];
  String? _patientId;
  bool _chargePatients = false;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _chargerPatients();
  }

  @override
  void dispose() {
    _diagnostic.dispose();
    _notes.dispose();
    _validite.dispose();
    for (final m in _meds) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerPatients() async {
    setState(() => _chargePatients = true);
    try {
      final p = await widget.medecin.mesPatients();
      if (mounted) setState(() => _patients = p);
    } on Exception {
      // liste vide : le medecin peut quand meme reessayer
    } finally {
      if (mounted) setState(() => _chargePatients = false);
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _enregistrer() async {
    if (_patientId == null) {
      _msg('Choisissez un patient.');
      return;
    }
    final medications = <Map<String, dynamic>>[];
    for (final m in _meds) {
      final nom = m.nom.text.trim();
      if (nom.isEmpty) continue;
      medications.add({
        'name': nom,
        if (m.dosage.text.trim().isNotEmpty) 'dosage': m.dosage.text.trim(),
        if (m.duree.text.trim().isNotEmpty) 'duration': m.duree.text.trim(),
      });
    }
    if (medications.isEmpty) {
      _msg('Ajoutez au moins un médicament.');
      return;
    }
    setState(() => _envoi = true);
    try {
      await widget.medecin.creerOrdonnance(
        patientId: _patientId!,
        medications: medications,
        diagnostic: _diagnostic.text.trim().isEmpty ? null : _diagnostic.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        validite: int.tryParse(_validite.text.trim()) ?? 30,
      );
      if (mounted) {
        _msg('Ordonnance créée');
        Navigator.of(context).pop(true);
      }
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.estConnecte) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle ordonnance')),
        body: const Center(child: Text('Connectez-vous.', style: TextStyle(color: Tabibi.texteDoux))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle ordonnance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const Text('Patient', style: TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
          const SizedBox(height: 6),
          if (_chargePatients)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())
          else if (_patients.isEmpty)
            const Text('Aucun patient (aucun rendez-vous enregistré).',
                style: TextStyle(color: Tabibi.texteDoux, fontSize: 13))
          else
            DropdownButtonFormField<String>(
              value: _patientId,
              isExpanded: true,
              decoration: const InputDecoration(hintText: 'Choisir un patient'),
              items: [
                for (final p in _patients)
                  DropdownMenuItem(value: '${p['patientId']}', child: Text('${p['nom'] ?? 'Patient'}')),
              ],
              onChanged: (v) => setState(() => _patientId = v),
            ),
          const SizedBox(height: 16),
          const Text('Médicaments', style: TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
          const SizedBox(height: 6),
          for (int i = 0; i < _meds.length; i++) _ligneMed(i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _meds.add(_Medicament())),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un médicament'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _diagnostic,
            decoration: const InputDecoration(labelText: 'Diagnostic (optionnel)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes cliniques (optionnel)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _validite,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Validité (jours)'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Tabibi.vert, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _envoi ? null : _enregistrer,
            icon: _envoi
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Créer l\'ordonnance'),
          ),
        ],
      ),
    );
  }

  Widget _ligneMed(int i) {
    final m = _meds[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: Tabibi.ombreDouce),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: m.nom,
              decoration: const InputDecoration(labelText: 'Médicament', isDense: true),
            ),
          ),
          if (_meds.length > 1)
            IconButton(
              onPressed: () => setState(() {
                _meds.removeAt(i).dispose();
              }),
              icon: const Icon(Icons.close, color: Tabibi.rouge, size: 20),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: m.dosage,
              decoration: const InputDecoration(labelText: 'Posologie', isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: m.duree,
              decoration: const InputDecoration(labelText: 'Durée', isDense: true),
            ),
          ),
        ]),
      ]),
    );
  }
}
