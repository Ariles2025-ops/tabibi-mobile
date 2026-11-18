import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/configuration.dart';
import '../config/theme.dart';
import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../widgets/liens_legaux.dart';

/// Connexion dans l'appli, sans page web : e-mail et mot de passe envoyes au serveur de
/// connexion. Renvoie true (Navigator.pop) une fois connecte, false si l'on revient en arriere.
class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _masque = true;
  bool _enCours = false;
  String? _erreur;

  /// Compte a finaliser (mot de passe a definir) : seul cas ou l'on propose la page web.
  bool _aFinaliser = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  static String messageErreurConnexion(String code) => switch (code) {
        'reseau' => t('Connexion au serveur impossible. Vérifiez votre réseau.',
            'تعذّر الاتصال بالخادم. تحقق من الشبكة.'),
        'account_incomplete' => t(
            'Votre compte doit être finalisé : définissez votre mot de passe une première fois.',
            'يجب إكمال حسابك: حدّد كلمة المرور لأول مرة.'),
        'account_disabled' =>
          t('Ce compte est désactivé.', 'هذا الحساب معطّل.'),
        'unauthorized_client' => t(
            'La connexion est momentanément indisponible.',
            'تسجيل الدخول غير متاح مؤقتًا.'),
        _ => t('E-mail ou mot de passe incorrect.',
            'البريد الإلكتروني أو كلمة المرور غير صحيحة.'),
      };

  Future<void> _valider() async {
    final email = _email.text.trim();
    if (email.isEmpty || _motDePasse.text.isEmpty) {
      setState(() => _erreur = t(
          'Saisissez votre e-mail et votre mot de passe.',
          'أدخل بريدك الإلكتروني وكلمة المرور.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final code = await widget.auth.connexionDirecte(email, _motDePasse.text);
    if (!mounted) return;
    if (code == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (code == 'unauthorized_client') {
      // Le serveur n'autorise pas (encore) la connexion directe : parcours habituel par le navigateur.
      final ok = await widget.auth.seConnecterParNavigateur();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
    }
    setState(() {
      _enCours = false;
      _erreur = messageErreurConnexion(code);
      _aFinaliser = code == 'account_incomplete';
    });
  }

  Future<void> _finaliser() async {
    final ok = await widget.auth.seConnecterParNavigateur();
    if (mounted && ok) Navigator.of(context).pop(true);
  }

  void _motDePasseOublie() {
    launchUrl(
      Uri.parse('${Configuration.issuer}/login-actions/reset-credentials'
          '?client_id=${Configuration.clientId}'),
      mode: LaunchMode.inAppBrowserView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/img/logo-ndawik.png',
                    width: 44, height: 44, excludeFromSemantics: true),
              ),
              const SizedBox(width: 12),
              const Text('Ndawik',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Charte.vert,
                      letterSpacing: -0.4)),
            ]),
            const SizedBox(height: 32),
            Text(t('Connexion', 'تسجيل الدخول'), style: tt.headlineSmall),
            const SizedBox(height: 8),
            Text(
                t('Retrouvez vos rendez-vous, ordonnances et messages.',
                    'تجد مواعيدك ووصفاتك ورسائلك.'),
                style: tt.bodyMedium),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('connexion-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t('Adresse e-mail', 'البريد الإلكتروني'),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('connexion-mot-de-passe'),
              controller: _motDePasse,
              obscureText: _masque,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _valider(),
              decoration: InputDecoration(
                labelText: t('Mot de passe', 'كلمة المرور'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _masque
                      ? t('Afficher le mot de passe', 'إظهار كلمة المرور')
                      : t('Masquer le mot de passe', 'إخفاء كلمة المرور'),
                  icon: Icon(_masque
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _masque = !_masque),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _motDePasseOublie,
                child: Text(t('Mot de passe oublié ?', 'نسيت كلمة المرور؟')),
              ),
            ),
            if (_erreur != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Charte.statutNegatif.$1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_erreur!,
                    style: TextStyle(
                        color: Charte.statutNegatif.$2,
                        fontWeight: FontWeight.w600)),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _enCours ? null : _valider,
              child: _enCours
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t('Se connecter', 'تسجيل الدخول')),
            ),
            if (_aFinaliser) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _finaliser,
                child: Text(t('Définir mon mot de passe', 'تحديد كلمة المرور')),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Charte.pastille,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                t(
                    'Ndawik est en phase de test : les comptes sont créés sur demande. '
                        'Médecin ? Faites votre demande sur ndawik.com/praticien.',
                    'نداويك في مرحلة التجربة: تُنشأ الحسابات عند الطلب. '
                        'طبيب؟ قدّم طلبك على ndawik.com/praticien.'),
                style: const TextStyle(
                    color: Charte.vertFonce, fontSize: 13.5, height: 1.45),
              ),
            ),
            const SizedBox(height: 24),
            const LiensLegaux(),
          ],
        ),
      ),
    );
  }
}
