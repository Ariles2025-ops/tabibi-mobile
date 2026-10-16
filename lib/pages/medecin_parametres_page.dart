import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/supabase_service.dart';
import '../theme/theme_tabibi.dart';

/// Paramètres du compte : sécurité (mot de passe, e-mail), préférences de
/// notification, et suppression du compte (RGPD).
class MedecinParametresPage extends StatefulWidget {
  const MedecinParametresPage({super.key, this.auth, this.medecin = const MedecinSupabase()});

  final AuthService? auth;
  final MedecinSupabase medecin;

  @override
  State<MedecinParametresPage> createState() => _MedecinParametresPageState();
}

class _MedecinParametresPageState extends State<MedecinParametresPage> {
  bool _chargement = true;
  bool _rdv = true, _messages = true, _avis = true, _rappels = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final p = await widget.medecin.mesPreferencesNotifs();
      if (!mounted) return;
      setState(() {
        _rdv = p['notif_rdv'] as bool? ?? true;
        _messages = p['notif_messages'] as bool? ?? true;
        _avis = p['notif_avis'] as bool? ?? true;
        _rappels = p['notif_rappels'] as bool? ?? true;
        _chargement = false;
      });
    } on Object {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _majNotifs() async {
    try {
      await widget.medecin.majPreferencesNotifs(
          rdv: _rdv, messages: _messages, avis: _avis, rappels: _rappels);
    } on Object {
      _msg('Impossible d\'enregistrer la préférence');
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    final email = sb.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _titre('Sécurité'),
                _carte(Column(children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Tabibi.vert),
                    title: const Text('Changer le mot de passe'),
                    trailing: const Icon(Icons.chevron_right, color: Tabibi.texte4),
                    onTap: _dialogueMotDePasse,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.alternate_email, color: Tabibi.vert),
                    title: const Text('Changer l\'e-mail'),
                    subtitle: email.isEmpty ? null : Text(email, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Tabibi.texte4),
                    onTap: _dialogueEmail,
                  ),
                ])),
                const SizedBox(height: 18),
                _titre('Notifications'),
                _carte(Column(children: [
                  _switch('Rendez-vous', 'Nouvelles réservations et changements', _rdv,
                      (v) => setState(() { _rdv = v; _majNotifs(); })),
                  const Divider(height: 1),
                  _switch('Messages', 'Nouveaux messages des patients', _messages,
                      (v) => setState(() { _messages = v; _majNotifs(); })),
                  const Divider(height: 1),
                  _switch('Avis', 'Nouveaux avis reçus', _avis,
                      (v) => setState(() { _avis = v; _majNotifs(); })),
                  const Divider(height: 1),
                  _switch('Rappels', 'Rappels avant les rendez-vous', _rappels,
                      (v) => setState(() { _rappels = v; _majNotifs(); })),
                ])),
                const SizedBox(height: 18),
                _titre('Compte'),
                _carte(ListTile(
                  leading: const Icon(Icons.delete_outline, color: Tabibi.rouge),
                  title: const Text('Supprimer mon compte',
                      style: TextStyle(color: Tabibi.rouge, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Action définitive', style: TextStyle(fontSize: 12)),
                  onTap: _dialogueSuppression,
                )),
              ],
            ),
    );
  }

  Widget _titre(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: Tabibi.texte, fontSize: 15)),
      );

  Widget _carte(Widget child) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: Tabibi.ombreDouce),
        child: child,
      );

  Widget _switch(String titre, String sous, bool valeur, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        value: valeur,
        onChanged: onChanged,
        activeColor: Tabibi.vert,
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sous, style: const TextStyle(fontSize: 12, color: Tabibi.texteDoux)),
      );

  Future<void> _dialogueMotDePasse() async {
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nouveau mot de passe'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: ctrl1,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
          TextField(
              controller: ctrl2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmer')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    final p1 = ctrl1.text, p2 = ctrl2.text;
    if (p1.length < 6) { _msg('6 caractères minimum'); return; }
    if (p1 != p2) { _msg('Les mots de passe ne correspondent pas'); return; }
    try {
      await widget.medecin.changerMotDePasse(p1);
      _msg('Mot de passe mis à jour');
    } on Object {
      _msg('Échec de la mise à jour');
    }
  }

  Future<void> _dialogueEmail() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nouvel e-mail'),
        content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Nouvel e-mail')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (ok != true) return;
    final e = ctrl.text.trim();
    if (!e.contains('@')) { _msg('E-mail invalide'); return; }
    try {
      await widget.medecin.changerEmail(e);
      _msg('E-mail de confirmation envoyé à $e');
    } on Object {
      _msg('Échec de la demande');
    }
  }

  Future<void> _dialogueSuppression() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text(
            'Votre compte sera désactivé et vos données ne seront plus accessibles. '
            'Cette action est définitive.'),
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
      await widget.medecin.supprimerMonCompte();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on Object {
      _msg('Échec de la suppression');
    }
  }
}
