import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n/langue.dart';
import '../services/supabase_service.dart';
import '../theme/theme_tabibi.dart';

/// Connexion / creation de compte via Supabase Auth (e-mail + mot de passe).
/// Renvoie `true` (Navigator.pop) quand une session est ouverte.
class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  bool _inscription = false;
  bool _charge = false;
  bool _voirMdp = false;

  @override
  void dispose() {
    _email.dispose();
    _mdp.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final email = _email.text.trim();
    final mdp = _mdp.text;
    if (email.isEmpty || mdp.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _charge = true);
    try {
      if (_inscription) {
        await sb.auth.signUp(email: email, password: mdp);
      } else {
        await sb.auth.signInWithPassword(email: email, password: mdp);
      }
      if (!mounted) return;
      if (sb.auth.currentSession != null) {
        Navigator.of(context).pop(true);
      } else {
        _msg(t(context, 'connexion.verifEmail'));
      }
    } on AuthException catch (e) {
      if (mounted) _msg(e.message);
    } catch (_) {
      if (mounted) _msg(t(context, 'connexion.echec'));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, _inscription ? 'connexion.creer' : 'connexion.titre')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(child: SvgPicture.asset('assets/logo-mark-vert.svg', width: 56, height: 56)),
            const SizedBox(height: 16),
            Text(t(context, _inscription ? 'connexion.creer' : 'connexion.titre'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: Tabibi.ink)),
            const SizedBox(height: 8),
            Text(t(context, 'connexion.sousTitre'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Tabibi.texteDoux, height: 1.4)),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t(context, 'connexion.email'),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _mdp,
              obscureText: !_voirMdp,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _valider(),
              decoration: InputDecoration(
                labelText: t(context, 'connexion.motDePasse'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_voirMdp ? Icons.visibility_off : Icons.visibility,
                      color: Tabibi.texte3),
                  onPressed: () => setState(() => _voirMdp = !_voirMdp),
                ),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _charge ? null : _valider,
              child: _charge
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(t(context, _inscription ? 'connexion.creer' : 'connexion.titre')),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _charge
                  ? null
                  : () => setState(() => _inscription = !_inscription),
              child: Text(t(
                  context, _inscription ? 'connexion.dejaCompte' : 'connexion.pasDeCompte')),
            ),
          ],
        ),
      ),
    );
  }
}
