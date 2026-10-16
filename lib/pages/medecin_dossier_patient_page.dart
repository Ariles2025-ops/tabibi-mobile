import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../widgets/vue_erreur.dart';

/// Dossier médical d'un patient, vu par son médecin (RDV requis côté base).
class MedecinDossierPatientPage extends StatefulWidget {
  const MedecinDossierPatientPage({
    super.key,
    required this.patientId,
    required this.patientNom,
    this.medecin = const MedecinSupabase(),
    this.auth,
  });

  final String patientId;
  final String patientNom;
  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinDossierPatientPage> createState() => _MedecinDossierPatientPageState();
}

class _MedecinDossierPatientPageState extends State<MedecinDossierPatientPage> {
  late final AuthService _auth = widget.auth ?? session;
  Map<String, dynamic>? _dossier;
  bool _charge = false;
  bool _vide = false;
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
      _vide = false;
    });
    try {
      final d = await widget.medecin.dossierPatient(widget.patientId);
      if (mounted) {
        setState(() {
          _dossier = d;
          _vide = d == null;
        });
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patientNom)),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? VueErreur(message: _erreur!, onReessayer: _charger)
              : _vide
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Ce patient n\'a pas encore renseigné son dossier médical.',
                            textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        _section('Constantes', [
                          _ligne('Groupe sanguin', _txt(_dossier!['groupeSanguin'])),
                          _ligne('Taille', _dossier!['tailleCm'] == null ? '—' : '${_dossier!['tailleCm']} cm'),
                          _ligne('Poids', _dossier!['poidsKg'] == null ? '—' : '${_dossier!['poidsKg']} kg'),
                          _ligne('Fumeur', _bool(_dossier!['fumeur'])),
                          _ligne('Consommation d\'alcool', _bool(_dossier!['buveur'])),
                        ]),
                        _sectionTexte('Allergies', _dossier!['allergies']),
                        _sectionTexte('Antécédents médicaux', _dossier!['antecedents']),
                        _sectionTexte('Traitements en cours', _dossier!['traitements']),
                        _sectionTexte('Antécédents familiaux', _dossier!['antecedentsFamiliaux']),
                        _sectionTexte('Vaccinations', _dossier!['vaccinations']),
                        _section('Assurance', [
                          _ligne('Assurance', _txt(_dossier!['assurance'])),
                          _ligne('Mutuelle', _txt(_dossier!['mutuelle'])),
                        ]),
                        _section('Contact d\'urgence', [
                          _ligne('Nom', _txt(_dossier!['urgenceNom'])),
                          _ligne('Lien', _txt(_dossier!['urgenceLien'])),
                          _ligne('Téléphone', _txt(_dossier!['urgenceTel'])),
                        ]),
                      ],
                    ),
    );
  }

  String _txt(dynamic v) => (v == null || '$v'.trim().isEmpty) ? '—' : '$v';
  String _bool(dynamic v) => v == true ? 'Oui' : (v == false ? 'Non' : '—');

  Widget _section(String titre, List<Widget> lignes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, color: Tabibi.texte)),
        const SizedBox(height: 8),
        ...lignes,
      ]),
    );
  }

  Widget _sectionTexte(String titre, dynamic valeur) {
    final v = (valeur == null || '$valeur'.trim().isEmpty) ? null : '$valeur';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, color: Tabibi.texte)),
        const SizedBox(height: 6),
        Text(v ?? '—', style: TextStyle(color: v == null ? Tabibi.texte4 : Tabibi.texteDoux)),
      ]),
    );
  }

  Widget _ligne(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 13))),
        Expanded(child: Text(valeur, style: const TextStyle(color: Tabibi.texte, fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
}
