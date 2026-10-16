import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../widgets/vue_erreur.dart';
import 'medecin_dossier_patient_page.dart';

/// Liste des patients suivis par le praticien (agreges depuis les rendez-vous).
class MedecinPatientsPage extends StatefulWidget {
  const MedecinPatientsPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinPatientsPage> createState() => _MedecinPatientsPageState();
}

class _MedecinPatientsPageState extends State<MedecinPatientsPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _patients = [];
  bool _charge = false;
  String? _erreur;
  String _recherche = '';

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
      final p = await widget.medecin.mesPatients();
      if (mounted) setState(() => _patients = p);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  List<Map<String, dynamic>> get _filtres {
    if (_recherche.trim().isEmpty) return _patients;
    final q = _recherche.toLowerCase();
    return _patients.where((p) => '${p['nom'] ?? ''}'.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes patients')),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? VueErreur(message: _erreur!, onReessayer: _charger)
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Rechercher un patient',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _recherche = v),
                    ),
                  ),
                  Expanded(
                    child: _filtres.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('Aucun patient pour le moment.',
                                  textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                            ),
                          )
                        : RefreshIndicator(
                            color: Tabibi.vert,
                            onRefresh: _charger,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                              children: [for (final p in _filtres) _carte(p)],
                            ),
                          ),
                  ),
                ]),
    );
  }

  void _ouvrirDossier(Map<String, dynamic> p) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MedecinDossierPatientPage(
        patientId: '${p['patientId']}',
        patientNom: '${p['nom'] ?? 'Patient'}',
        medecin: widget.medecin,
        auth: _auth,
      ),
    ));
  }

  Widget _carte(Map<String, dynamic> p) {
    final nom = '${p['nom'] ?? 'Patient'}';
    final initiale = nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase();
    return InkWell(
      onTap: () => _ouvrirDossier(p),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
        child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
          child: Text(initiale, style: const TextStyle(color: Tabibi.vert, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nom, style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
            const SizedBox(height: 2),
            Text('${p['nbRdv'] ?? 0} rendez-vous', style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
          ]),
        ),
        if ('${p['dernierRdv'] ?? ''}'.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Dernier', style: TextStyle(color: Tabibi.texte4, fontSize: 10)),
            Text(formaterDateIso(langueDe(context), '${p['dernierRdv']}'),
                style: const TextStyle(color: Tabibi.texte3, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}
