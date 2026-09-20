import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../theme/theme_tabibi.dart';

/// Connexion / creation de compte PATIENT via Supabase Auth.
/// - Inscription par e-mail (confirmation e-mail) ou par telephone (SMS une fois).
/// - Identifiant (pseudo) choisi par l'utilisateur, unique, utilisable pour se connecter.
/// Renvoie `true` (Navigator.pop) quand une session est ouverte.
class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

enum _Mode { connexion, inscription }

enum _Methode { email, telephone }

class _ConnexionPageState extends State<ConnexionPage> {
  _Mode _mode = _Mode.connexion;
  _Methode _methode = _Methode.email;
  bool _charge = false;
  bool _voirMdp = false;

  // Connexion
  final _identifiant = TextEditingController(); // pseudo, e-mail ou telephone
  final _mdpConnexion = TextEditingController();

  // Inscription
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _pseudo = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _mdp = TextEditingController();
  int? _wilaya;
  List<Map<String, dynamic>> _wilayas = [];
  bool _cgu = false, _confid = false, _sante = false, _marketing = false;

  // Verif pseudo
  Timer? _debounce;
  bool? _pseudoLibre;
  bool _pseudoVerif = false;

  // Etape code SMS
  bool _etapeOtp = false;
  final _otp = TextEditingController();
  String _telNorm = '';
  String _contactOtp = '';

  @override
  void initState() {
    super.initState();
    _chargerWilayas();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_identifiant, _mdpConnexion, _prenom, _nom, _pseudo, _email, _tel, _mdp, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerWilayas() async {
    try {
      final r = await sb.from('wilayas').select('code,name_fr').eq('is_active', true).order('name_fr');
      if (mounted) setState(() => _wilayas = List<Map<String, dynamic>>.from(r as List));
    } catch (_) {}
  }

  String _normTel(String v) {
    var t = v.replaceAll(RegExp(r'[^0-9+]'), '');
    if (t.startsWith('00')) t = '+${t.substring(2)}';
    if (t.startsWith('0')) t = '+213${t.substring(1)}';
    if (!t.startsWith('+')) t = '+213$t';
    return t;
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _onPseudoChange(String v) {
    _pseudoLibre = null;
    _debounce?.cancel();
    final u = v.trim();
    setState(() {});
    if (u.length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _pseudoVerif = true);
      try {
        final r = await sb.rpc('identifiant_disponible', params: {'p_username': u});
        if (mounted) setState(() => _pseudoLibre = r == true);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _pseudoVerif = false);
      }
    });
  }

  // ---------- CONNEXION ----------
  Future<void> _connexion() async {
    final id = _identifiant.text.trim();
    final mdp = _mdpConnexion.text;
    if (id.isEmpty || mdp.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _charge = true);
    try {
      String? email;
      String? phone;
      if (id.contains('@')) {
        email = id;
      } else if (RegExp(r'^[+0-9 ]{6,}$').hasMatch(id)) {
        phone = _normTel(id);
      } else {
        final r = await sb.rpc('identifiant_vers_contact', params: {'p_username': id});
        if (r is Map) {
          email = r['email'] as String?;
          phone = r['phone'] as String?;
        }
      }
      if (email != null && email.isNotEmpty) {
        await sb.auth.signInWithPassword(email: email, password: mdp);
      } else if (phone != null && phone.isNotEmpty) {
        await sb.auth.signInWithPassword(phone: phone, password: mdp);
      } else {
        _msg('Identifiant introuvable.');
        return;
      }
      if (mounted && sb.auth.currentSession != null) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) _msg(e.message);
    } catch (_) {
      if (mounted) _msg('Connexion impossible. Vérifiez vos identifiants.');
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  // ---------- INSCRIPTION ----------
  bool get _consentsOk => _cgu && _confid && _sante;

  Future<void> _inscription() async {
    final prenom = _prenom.text.trim();
    final nom = _nom.text.trim();
    final pseudo = _pseudo.text.trim();
    final mdp = _mdp.text;
    if (prenom.isEmpty || nom.isEmpty) {
      _msg('Indiquez votre prénom et votre nom.');
      return;
    }
    if (pseudo.length < 3) {
      _msg('Choisissez un identifiant (3 caractères min.).');
      return;
    }
    if (_pseudoLibre == false) {
      _msg('Cet identifiant est déjà pris.');
      return;
    }
    if (mdp.length < 6) {
      _msg('Mot de passe : 6 caractères minimum.');
      return;
    }
    if (!_consentsOk) {
      _msg('Merci d\'accepter les conditions et consentements requis.');
      return;
    }
    final data = <String, dynamic>{
      'role': 'patient',
      'first_name': prenom,
      'last_name': nom,
      'username': pseudo,
      if (_wilaya != null) 'wilaya_code': _wilaya,
      'consent_terms': _cgu,
      'consent_privacy': _confid,
      'consent_health': _sante,
      'consent_marketing': _marketing,
    };
    FocusScope.of(context).unfocus();
    setState(() => _charge = true);
    try {
      // securite : pseudo encore libre ?
      final libre = await sb.rpc('identifiant_disponible', params: {'p_username': pseudo});
      if (libre != true) {
        _msg('Cet identifiant est déjà pris.');
        return;
      }
      if (_methode == _Methode.email) {
        final email = _email.text.trim();
        if (!email.contains('@')) {
          _msg('E-mail invalide.');
          return;
        }
        await sb.auth.signUp(email: email, password: mdp, data: data);
        if (!mounted) return;
        if (sb.auth.currentSession != null) {
          Navigator.of(context).pop(true);
        } else {
          _contactOtp = email;
          setState(() => _etapeOtp = true);
        }
      } else {
        _telNorm = _normTel(_tel.text);
        if (_telNorm.length < 8) {
          _msg('Numéro invalide.');
          return;
        }
        await sb.auth.signUp(phone: _telNorm, password: mdp, data: data);
        _contactOtp = _telNorm;
        if (mounted) setState(() => _etapeOtp = true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        final m = e.message.toLowerCase();
        if (m.contains('already') || m.contains('registered') || m.contains('exist')) {
          _identifiant.text =
              _methode == _Methode.email ? _email.text.trim() : _normTel(_tel.text);
          setState(() => _mode = _Mode.connexion);
          _msg('Ce compte existe déjà. Connectez-vous avec votre mot de passe.');
        } else {
          _msg(e.message);
        }
      }
    } catch (_) {
      if (mounted) _msg('Création impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _verifierOtp() async {
    final code = _otp.text.trim();
    if (code.isEmpty) return;
    setState(() => _charge = true);
    try {
      if (_methode == _Methode.telephone) {
        await sb.auth.verifyOTP(type: OtpType.sms, phone: _contactOtp, token: code);
      } else {
        await sb.auth.verifyOTP(type: OtpType.signup, email: _contactOtp, token: code);
      }
      if (mounted && sb.auth.currentSession != null) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) _msg(e.message);
    } catch (_) {
      if (mounted) _msg('Code incorrect ou expiré.');
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _renvoyerCode() async {
    try {
      if (_methode == _Methode.telephone) {
        await sb.auth.resend(type: OtpType.sms, phone: _contactOtp);
      } else {
        await sb.auth.resend(type: OtpType.signup, email: _contactOtp);
      }
      if (mounted) _msg('Code renvoyé.');
    } on AuthException catch (e) {
      if (mounted) _msg(e.message);
    } catch (_) {
      if (mounted) _msg('Impossible de renvoyer le code.');
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final titre = _etapeOtp
        ? 'Vérification'
        : (_mode == _Mode.connexion ? 'Connexion' : 'Créer un compte');
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: _etapeOtp ? _vueOtp() : _vueFormulaire(),
        ),
      ),
    );
  }

  Widget _entete() => Column(children: [
        const SizedBox(height: 8),
        SvgPicture.asset('assets/logo-mark-vert.svg', width: 52, height: 52),
        const SizedBox(height: 14),
        Text(_mode == _Mode.connexion ? 'Connexion' : 'Créer un compte',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Tabibi.ink)),
        const SizedBox(height: 6),
        const Text('Accédez à vos rendez-vous, messages et ordonnances.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tabibi.texteDoux, height: 1.4)),
        const SizedBox(height: 22),
      ]);

  Widget _vueFormulaire() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _entete(),
      if (_mode == _Mode.connexion) ..._champsConnexion() else ..._champsInscription(),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _charge ? null : (_mode == _Mode.connexion ? _connexion : _inscription),
        child: _charge
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(_mode == _Mode.connexion
                ? 'Se connecter'
                : (_methode == _Methode.telephone ? 'Recevoir le code' : 'Créer un compte')),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _charge
            ? null
            : () => setState(() => _mode = _mode == _Mode.connexion ? _Mode.inscription : _Mode.connexion),
        child: Text(_mode == _Mode.connexion
            ? 'Pas encore de compte ? Créer un compte'
            : 'Déjà un compte ? Se connecter'),
      ),
    ]);
  }

  List<Widget> _champsConnexion() => [
        TextField(
          controller: _identifiant,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Identifiant, e-mail ou téléphone',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),
        _champMdp(_mdpConnexion, onSubmit: _connexion),
      ];

  List<Widget> _champsInscription() => [
        Row(children: [
          Expanded(child: _champ(_prenom, 'Prénom', Icons.badge_outlined)),
          const SizedBox(width: 12),
          Expanded(child: _champ(_nom, 'Nom', Icons.badge_outlined)),
        ]),
        const SizedBox(height: 14),
        _champPseudo(),
        const SizedBox(height: 18),
        _choixMethode(),
        const SizedBox(height: 14),
        if (_methode == _Methode.email)
          _champ(_email, 'E-mail', Icons.mail_outline,
              clavier: TextInputType.emailAddress)
        else
          _champ(_tel, 'Téléphone (ex. 0555 12 34 56)', Icons.phone_outlined,
              clavier: TextInputType.phone),
        const SizedBox(height: 14),
        _champMdp(_mdp),
        const SizedBox(height: 14),
        _champWilaya(),
        const SizedBox(height: 18),
        _consentements(),
      ];

  Widget _champ(TextEditingController c, String label, IconData icone,
      {TextInputType? clavier}) {
    return TextField(
      controller: c,
      keyboardType: clavier,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icone)),
    );
  }

  Widget _champMdp(TextEditingController c, {VoidCallback? onSubmit}) {
    return TextField(
      controller: c,
      obscureText: !_voirMdp,
      textInputAction: onSubmit != null ? TextInputAction.done : TextInputAction.next,
      onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: 'Mot de passe',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_voirMdp ? Icons.visibility_off : Icons.visibility, color: Tabibi.texte3),
          onPressed: () => setState(() => _voirMdp = !_voirMdp),
        ),
      ),
    );
  }

  Widget _champPseudo() {
    Widget? suffixe;
    if (_pseudoVerif) {
      suffixe = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_pseudoLibre == true) {
      suffixe = const Icon(Icons.check_circle, color: Tabibi.vert);
    } else if (_pseudoLibre == false) {
      suffixe = const Icon(Icons.cancel, color: Tabibi.rouge);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _pseudo,
        autocorrect: false,
        onChanged: _onPseudoChange,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
        ],
        decoration: InputDecoration(
          labelText: 'Identifiant (ex. @amine.dz)',
          prefixIcon: const Icon(Icons.alternate_email),
          suffixIcon: suffixe,
        ),
      ),
      if (_pseudoLibre == false)
        const Padding(
          padding: EdgeInsets.only(top: 6, left: 4),
          child: Text('Cet identifiant est déjà pris.',
              style: TextStyle(color: Tabibi.rouge, fontSize: 12)),
        )
      else
        const Padding(
          padding: EdgeInsets.only(top: 6, left: 4),
          child: Text('Servira à te connecter. Lettres, chiffres, . et _',
              style: TextStyle(color: Tabibi.texte3, fontSize: 12)),
        ),
    ]);
  }

  Widget _choixMethode() {
    Widget seg(String label, IconData ic, _Methode m) {
      final actif = _methode == m;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(Tabibi.r12),
          onTap: () => setState(() => _methode = m),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: actif ? Tabibi.pastille : Colors.white,
              borderRadius: BorderRadius.circular(Tabibi.r12),
              border: Border.all(color: actif ? Tabibi.vert : Tabibi.bord, width: actif ? 1.5 : 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ic, size: 18, color: actif ? Tabibi.vert : Tabibi.texte3),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: actif ? Tabibi.vert : Tabibi.texteDoux)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      seg('E-mail', Icons.mail_outline, _Methode.email),
      const SizedBox(width: 10),
      seg('Téléphone', Icons.phone_outlined, _Methode.telephone),
    ]);
  }

  Widget _champWilaya() {
    return DropdownButtonFormField<int?>(
      value: _wilaya,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Wilaya (facultatif)',
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('— Sélectionnez —')),
        for (final w in _wilayas)
          DropdownMenuItem<int?>(
            value: (w['code'] as num).toInt(),
            child: Text(w['name_fr']?.toString() ?? '', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => _wilaya = v),
    );
  }

  Widget _consentements() {
    Widget c(bool v, ValueChanged<bool?> on, String texte, {bool gras = false}) {
      return InkWell(
        onTap: () => on(!v),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: v,
                onChanged: on,
                activeColor: Tabibi.vert,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texte,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Tabibi.texteDoux,
                      fontWeight: gras ? FontWeight.w700 : FontWeight.w400)),
            ),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Tabibi.bg2,
        borderRadius: BorderRadius.circular(Tabibi.r12),
      ),
      child: Column(children: [
        c(_cgu, (x) => setState(() => _cgu = x ?? false),
            "J'accepte les Conditions Générales d'Utilisation de Tabibi."),
        c(_confid, (x) => setState(() => _confid = x ?? false),
            'Je consens au traitement de mes données personnelles (loi 18-07).'),
        c(_sante, (x) => setState(() => _sante = x ?? false),
            'Consentement données de santé : j\'autorise le traitement de mes données médicales pour la prise de rendez-vous (art. 18, loi 18-07).',
            gras: true),
        c(_marketing, (x) => setState(() => _marketing = x ?? false),
            '(Optionnel) J\'accepte de recevoir des conseils santé et offres Tabibi.'),
      ]),
    );
  }

  Widget _vueOtp() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      const Icon(Icons.sms_outlined, size: 48, color: Tabibi.vert),
      const SizedBox(height: 16),
      const Text('Entrez le code',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Tabibi.ink)),
      const SizedBox(height: 8),
      Text(
          _methode == _Methode.telephone
              ? 'Un code à 6 chiffres vous a été envoyé par SMS au $_contactOtp.'
              : 'Un code à 6 chiffres vous a été envoyé par e-mail à $_contactOtp.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Tabibi.texteDoux, height: 1.4)),
      const SizedBox(height: 22),
      TextField(
        controller: _otp,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6),
        decoration: const InputDecoration(hintText: '••••••'),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _charge ? null : _verifierOtp,
        child: _charge
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Vérifier'),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _charge ? null : _renvoyerCode,
        child: const Text('Renvoyer le code'),
      ),
      TextButton(
        onPressed: _charge ? null : () => setState(() => _etapeOtp = false),
        child: const Text('Retour'),
      ),
    ]);
  }
}
