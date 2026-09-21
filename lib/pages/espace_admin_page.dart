import 'package:flutter/material.dart';

import '../services/admin_supabase.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Espace administrateur : validation des medecins en attente et gestion des comptes
/// (recherche, activation, suppression) par e-mail.
class EspaceAdminPage extends StatefulWidget {
  const EspaceAdminPage({super.key, this.admin = const AdminSupabase(), this.auth});

  final AdminSupabase admin;
  final AuthService? auth;

  @override
  State<EspaceAdminPage> createState() => _EspaceAdminPageState();
}

class _EspaceAdminPageState extends State<EspaceAdminPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _email = TextEditingController();

  List<Map<String, dynamic>> _attente = [];
  Map<String, dynamic>? _compte;
  bool _charge = false;
  String? _enCours;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final att = await widget.admin.medecinsEnAttente();
      if (mounted) setState(() => _attente = att);
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

  Future<void> _valider(String email) async {
    if (_enCours != null) return;
    setState(() => _enCours = email);
    try {
      await widget.admin.validerMedecin(email);
      if (mounted) _msg('Médecin validé : $email');
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
    if (mounted) await _charger();
  }

  Future<void> _rechercher() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _msg('Entrez un e-mail valide.');
      return;
    }
    setState(() => _enCours = 'search');
    try {
      final c = await widget.admin.rechercherCompte(email);
      if (mounted) {
        setState(() => _compte = c);
        if (c == null) _msg('Aucun compte pour $email.');
      }
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  Future<void> _activer() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return;
    setState(() => _enCours = 'activer');
    try {
      await widget.admin.activerCompte(email);
      if (mounted) _msg('Compte activé : $email');
      await _rechercher();
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  Future<void> _supprimer() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text('Le compte $email sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tabibi.rouge),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _enCours = 'supprimer');
    try {
      await widget.admin.supprimerCompte(email);
      if (mounted) {
        _msg('Compte supprimé : $email');
        setState(() => _compte = null);
      }
      await _charger();
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace admin'),
        actions: [
          if (_auth.estConnecte)
            IconButton(onPressed: _charge ? null : _charger, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (!_auth.estConnecte) {
      return VueConnexion(
        icone: Icons.admin_panel_settings_outlined,
        titre: 'Espace admin',
        message: 'Connectez-vous avec le compte administrateur.',
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _titre('Médecins en attente (${_attente.length})'),
        if (_attente.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucun médecin en attente.',
                style: TextStyle(color: Tabibi.texteDoux)),
          )
        else
          for (final m in _attente) _carteAttente(m),
        const SizedBox(height: 20),
        _titre('Gérer un compte'),
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'E-mail du compte',
            prefixIcon: Icon(Icons.mail_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(
            onPressed: _enCours != null ? null : _rechercher,
            child: const Text('Rechercher'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tabibi.vert),
            onPressed: _enCours != null ? null : _activer,
            child: const Text('Activer'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tabibi.rouge),
            onPressed: _enCours != null ? null : _supprimer,
            child: const Text('Supprimer'),
          ),
        ]),
        if (_compte != null) ...[
          const SizedBox(height: 12),
          _carteCompte(_compte!),
        ],
      ],
    );
  }

  Widget _titre(String t) => Text(t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.texte));

  Widget _carteAttente(Map<String, dynamic> m) {
    final email = '${m['email'] ?? ''}';
    final sous = [
      if ((m['specialite'] ?? '').toString().isNotEmpty) '${m['specialite']}',
      if ((m['wilaya'] ?? '').toString().isNotEmpty) '${m['wilaya']}',
      if ((m['telephone'] ?? '').toString().isNotEmpty) '${m['telephone']}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['nom'] ?? email}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
            const SizedBox(height: 2),
            Text(email, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
            if (sous.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sous, style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Tabibi.vert, visualDensity: VisualDensity.compact),
          onPressed: _enCours != null ? null : () => _valider(email),
          child: const Text('Valider'),
        ),
      ]),
    );
  }

  Widget _carteCompte(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Tabibi.bg2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c['nom'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
        const SizedBox(height: 4),
        Text('E-mail : ${c['email'] ?? ''}', style: const TextStyle(color: Tabibi.texteDoux)),
        Text('Rôle : ${c['role'] ?? ''}', style: const TextStyle(color: Tabibi.texteDoux)),
        Text('Statut : ${c['statut'] ?? ''} · ${c['actif'] == true ? 'actif' : 'inactif'}',
            style: const TextStyle(color: Tabibi.texteDoux)),
        Text('Fiche médecin : ${c['estMedecin'] == true ? 'oui' : 'non'}',
            style: const TextStyle(color: Tabibi.texteDoux)),
      ]),
    );
  }
}
