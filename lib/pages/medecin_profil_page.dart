import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Edition de la fiche du praticien : tarifs, moyens de paiement, teleconsultation, bio.
class MedecinProfilPage extends StatefulWidget {
  const MedecinProfilPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinProfilPage> createState() => _MedecinProfilPageState();
}

class _MedecinProfilPageState extends State<MedecinProfilPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _bio = TextEditingController();
  final _tarif = TextEditingController();
  final _teleTarif = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _langues = TextEditingController();

  bool _chifa = false;
  bool _carte = false;
  bool _especes = true;
  bool _tele = false;

  bool _charge = false;
  bool _envoi = false;
  String? _erreur;
  String? _entete; // nom + specialite (lecture seule)

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  @override
  void dispose() {
    _bio.dispose();
    _tarif.dispose();
    _teleTarif.dispose();
    _phone.dispose();
    _address.dispose();
    _langues.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final p = await widget.medecin.monProfil();
      if (!mounted) return;
      setState(() {
        if (p != null) _remplir(p);
      });
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  void _remplir(Map<String, dynamic> p) {
    _bio.text = '${p['bio'] ?? ''}';
    _tarif.text = p['tarif'] == null ? '' : '${p['tarif']}';
    _teleTarif.text = p['teleTarif'] == null ? '' : '${p['teleTarif']}';
    _phone.text = '${p['phone'] ?? ''}';
    _address.text = '${p['address'] ?? ''}';
    final langues = (p['langues'] as List?)?.map((e) => '$e').join(', ') ?? '';
    _langues.text = langues;
    _chifa = p['accepteChifa'] == true;
    _carte = p['accepteCarte'] == true;
    _especes = p['accepteEspeces'] != false;
    _tele = p['teleconsultation'] == true;
    final nom = '${p['nomComplet'] ?? ''}'.trim();
    final spe = '${p['specialiteFr'] ?? ''}'.trim();
    _entete = [if (nom.isNotEmpty) 'Dr $nom', if (spe.isNotEmpty) spe].join(' · ');
  }

  Future<void> _enregistrer() async {
    if (_envoi) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoi = true);
    var ok = false;
    try {
      final langues = _langues.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await widget.medecin.enregistrerProfil(
        bio: _bio.text.trim(),
        langues: langues,
        tarif: int.tryParse(_tarif.text.trim()),
        teleTarif: int.tryParse(_teleTarif.text.trim()),
        accepteChifa: _chifa,
        accepteCarte: _carte,
        accepteEspeces: _especes,
        teleconsultation: _tele,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
      );
      ok = true;
    } on Exception catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
    if (ok && mounted) _message('Profil enregistré');
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (!_auth.estConnecte) {
      return VueConnexion(
        icone: Icons.badge_outlined,
        titre: 'Mon profil',
        message: 'Connectez-vous avec votre compte praticien.',
        onSeConnecter: () async {
          await _auth.seConnecter();
          if (mounted) setState(() {});
          if (_auth.estConnecte) _charger();
        },
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    if (_erreur != null) return VueErreur(message: _erreur!, onReessayer: _charger);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_entete != null && _entete!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_entete!,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.texte)),
          ),
        _champ(_tarif, 'Tarif consultation (DA)', clavier: TextInputType.number),
        _champ(_phone, 'Téléphone'),
        _champ(_address, 'Adresse du cabinet'),
        _champ(_langues, 'Langues (séparées par des virgules)'),
        _champ(_bio, 'Présentation (bio)', lignes: 4),
        const SizedBox(height: 8),
        _titre('Moyens de paiement'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: Tabibi.vert,
          value: _especes,
          onChanged: (v) => setState(() => _especes = v),
          title: const Text('Espèces'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: Tabibi.vert,
          value: _carte,
          onChanged: (v) => setState(() => _carte = v),
          title: const Text('Carte'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: Tabibi.vert,
          value: _chifa,
          onChanged: (v) => setState(() => _chifa = v),
          title: const Text('Chifa'),
        ),
        const SizedBox(height: 8),
        _titre('Téléconsultation'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: Tabibi.vert,
          value: _tele,
          onChanged: (v) => setState(() => _tele = v),
          title: const Text('Proposer la téléconsultation'),
        ),
        if (_tele)
          _champ(_teleTarif, 'Tarif téléconsultation (DA)', clavier: TextInputType.number),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Tabibi.vert),
          onPressed: _envoi ? null : _enregistrer,
          child: _envoi
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _titre(String texte) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(texte,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Tabibi.texte)),
      );

  Widget _champ(TextEditingController c, String libelle,
      {int lignes = 1, TextInputType? clavier}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        minLines: lignes,
        maxLines: lignes,
        keyboardType: clavier,
        decoration: InputDecoration(
          labelText: libelle,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
