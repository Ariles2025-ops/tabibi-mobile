import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/profil.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/profil.dart';
import '../widgets/champ_wilaya.dart';
import '../widgets/liens_legaux.dart';
import '../widgets/selecteur_langue.dart';
import 'espace/cabinet_pages.dart';
import 'espace/candidature_page.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Message affiche quand le nom complet est vide (seul champ obligatoire).
String get messageNomRequis => t('Indiquez votre nom complet.', 'أدخل اسمك الكامل.');

/// Longueur maximale du nom complet acceptee par l'API.
const int longueurMaxNom = 120;

/// Annee de naissance la plus ancienne proposee (l'API exige une annee posterieure a 1900).
const int anneeNaissanceMin = 1901;

/// Mon profil : langue de l'appli (memorisee sur le telephone) ; formulaire prerempli si un
/// profil existe (`GET /api/moi/profil`), vide sinon (404) ; nom complet obligatoire, telephone
/// algerien, date de naissance facultative, wilaya (liste des 69) et langue preferee ;
/// « Enregistrer » (`PUT /api/moi/profil`, 400 affiche). Puis invitations de cabinet,
/// « Se déconnecter » (jetons effaces et session Keycloak fermee) et « Supprimer mon compte »
/// (confirmation, `DELETE /api/moi`, deconnexion et retour a l'accueil).
class MonProfilPage extends StatefulWidget {
  const MonProfilPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<MonProfilPage> createState() => _MonProfilPageState();
}

class _MonProfilPageState extends State<MonProfilPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _nomComplet = TextEditingController();
  final _telephone = TextEditingController();

  /// Code de la wilaya choisie (« 16 ») ; null si aucune.
  String? _wilaya;

  /// Date de naissance choisie ; null tant qu'elle n'est pas renseignee.
  DateTime? _dateNaissance;
  String _langue = Profil.langueParDefaut;

  /// Profil connu du serveur ; null tant qu'il n'a jamais ete renseigne (404).
  Profil? _profil;
  bool _charge = false;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  @override
  void dispose() {
    _nomComplet.dispose();
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final ok = await _auth.seConnecter();
    if (!mounted) return;
    if (ok) {
      await _charger();
    } else {
      _message(t('Connexion annulée', 'تم إلغاء تسجيل الدخول'));
    }
  }

  /// Charge le profil (GET /api/moi/profil) et preremplit le formulaire ; un 404 (profil
  /// jamais renseigne) laisse simplement le formulaire vide.
  Future<void> _charger() async {
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final profil = Profil.fromJson(await widget.api.monProfil(token));
      if (!mounted) return;
      setState(() => _remplir(profil));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.introuvable) {
        setState(() => _remplir(null));
        return;
      }
      // Jeton expire : retour au bouton « Se connecter ».
      if (e.nonAutorise) _auth.seDeconnecter();
      setState(() => _erreur = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Reporte le profil dans les champs ; formulaire vide (langue par defaut) sans profil.
  void _remplir(Profil? profil) {
    _profil = profil;
    _nomComplet.text = profil?.nomComplet ?? '';
    _telephone.text = profil?.telephone ?? '';
    _wilaya = wilayaParCode(profil?.wilayaCode)?.code;
    _dateNaissance = profil?.dateNaissance;
    final langue = profil?.langue ?? Profil.langueParDefaut;
    _langue = Profil.langues.contains(langue) ? langue : Profil.langueParDefaut;
  }

  /// Choix de la date de naissance : dans le passe, apres 1900 (regles de l'API).
  Future<void> _choisirDate() async {
    final aujourdHui = DateTime.now();
    final hier = DateTime(aujourdHui.year, aujourdHui.month, aujourdHui.day - 1);
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(aujourdHui.year - 30, aujourdHui.month, 1),
      firstDate: DateTime(anneeNaissanceMin),
      lastDate: hier,
      helpText: t('Date de naissance', 'تاريخ الميلاد'),
    );
    if (choisie == null || !mounted) return;
    setState(() => _dateNaissance = DateTime(choisie.year, choisie.month, choisie.day));
  }

  /// Enregistre le profil (PUT /api/moi/profil) apres validation locale du nom (obligatoire)
  /// et du telephone (numero algerien) ; succes -> « Profil enregistré. » et formulaire
  /// realigne sur la vue renvoyee ; 400 (regle de l'API) affiche tel quel.
  Future<void> _enregistrer() async {
    final nomComplet = _nomComplet.text.trim();
    if (nomComplet.isEmpty) {
      _message(messageNomRequis);
      return;
    }
    if (!telephoneValide(_telephone.text)) {
      _message(messageTelephoneInvalide);
      return;
    }
    if (_envoi) return;
    final token = _auth.accessToken;
    if (token == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoi = true);
    Profil? enregistre;
    try {
      final wilayaCode = _wilaya ?? '';
      final profil = Profil(
        nomComplet: nomComplet,
        telephone: normaliserTelephone(_telephone.text),
        dateNaissance: _dateNaissance,
        wilayaCode: wilayaCode.isEmpty ? null : wilayaCode,
        langue: _langue,
      );
      enregistre = Profil.fromJson(await widget.api.enregistrerProfil(profil.toJson(), token));
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
    }
    if (enregistre == null || !mounted) return;
    setState(() => _remplir(enregistre));
    _message(t('Profil enregistré.', 'تم حفظ الملف الشخصي.'));
  }

  /// Retour a l'accueil (premier ecran) apres deconnexion ou suppression du compte.
  void _retourAccueil() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// « Se déconnecter » : jetons effaces et session Keycloak fermee, puis accueil.
  Future<void> _seDeconnecter() async {
    await _auth.seDeconnecterCompletement();
    _message(t('Vous êtes déconnecté.', 'تم تسجيل خروجك.'));
    _retourAccueil();
  }

  /// « Supprimer mon compte » : confirmation, `DELETE /api/moi`, deconnexion et accueil.
  Future<void> _supprimerCompte() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Supprimer mon compte ?', 'حذف حسابي؟')),
        content: Text(t(
            'Votre compte et vos données personnelles (profil, rendez-vous, messages, listes '
                "d'attente) sont effacés définitivement. Seules les ordonnances et le journal "
                'de sécurité sont conservés le temps exigé par la loi. Cette action est définitive.',
            'يُحذف حسابك وبياناتك الشخصية (الملف الشخصي والمواعيد والرسائل وقوائم الانتظار) '
                'نهائيًا. لا يُحتفظ إلا بالوصفات الطبية وسجل الأمان للمدة التي يفرضها القانون. '
                'هذا الإجراء نهائي.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Annuler', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Oui, supprimer définitivement', 'نعم، احذف نهائيًا')),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _envoi = true);
    try {
      await widget.api.supprimerMonCompte(token);
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(messageEchecSuppressionCompte(e));
      if (mounted) setState(() => _envoi = false);
      return;
    } on Exception catch (e) {
      _message(messageEchecSuppressionCompte(e));
      if (mounted) setState(() => _envoi = false);
      return;
    }
    await _auth.seDeconnecterCompletement();
    _message(t('Votre compte a été supprimé.', 'تم حذف حسابك.'));
    _retourAccueil();
  }

  Future<void> _ouvrirInvitations() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvitationsCabinetPage(api: widget.api, auth: _auth),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _ouvrirCandidature() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CandidaturePage(api: widget.api, auth: _auth),
      ),
    );
    if (mounted) setState(() {});
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Mon profil', 'ملفي الشخصي')),
        actions: const [SelecteurLangue()],
      ),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ??
            t('Connectez-vous pour renseigner votre profil.', 'سجّل الدخول لملء ملفك الشخصي.'),
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    final texte = Theme.of(context).textTheme;
    final profil = _profil;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ChampLangue(),
        const SizedBox(height: 16),
        Text(
          t('Ces informations servent aux praticiens et aux rappels de rendez-vous. Seul le nom complet est obligatoire.',
              'تُستعمل هذه المعلومات من طرف الأطباء ولتذكيرات المواعيد. الاسم الكامل وحده إجباري.'),
          style: texte.bodySmall,
        ),
        if (profil != null) ...[
          const SizedBox(height: 4),
          Text(libelleMiseAJour(profil), style: texte.bodySmall),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _nomComplet,
          textCapitalization: TextCapitalization.words,
          maxLength: longueurMaxNom,
          decoration: InputDecoration(
            labelText: t('Nom complet *', 'الاسم الكامل *'),
            counterText: '',
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _telephone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: t('Téléphone', 'الهاتف'),
            hintText: '0550123456',
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 8),
        _champDateNaissance(),
        const SizedBox(height: 8),
        ChampWilaya(
          valeur: _wilaya,
          actif: !_envoi,
          onChanged: (code) => setState(() => _wilaya = code),
        ),
        const SizedBox(height: 8),
        _champLangue(),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _envoi ? null : _enregistrer,
          child: _envoi
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t('Enregistrer', 'حفظ')),
        ),
        const SizedBox(height: 8),
        Text(
          t('Ces informations ne sont visibles que de vous et des praticiens que vous consultez.',
              'هذه المعلومات لا يراها إلا أنت والأطباء الذين تستشيرهم.'),
          style: texte.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mail_outline),
          title: Text(t('Invitations de cabinet', 'دعوات العيادات')),
          trailing: const Icon(Icons.chevron_right),
          onTap: _ouvrirInvitations,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.medical_services_outlined),
          title: Text(t('Ma candidature de médecin', 'ترشحي كطبيب')),
          subtitle: Text(t('Figurer sur Ndawik : déposer ou suivre ma candidature',
              'الظهور على نداويك: إيداع ترشحي أو متابعته')),
          trailing: const Icon(Icons.chevron_right),
          onTap: _ouvrirCandidature,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _envoi ? null : _seDeconnecter,
          icon: const Icon(Icons.logout),
          label: Text(t('Se déconnecter', 'تسجيل الخروج')),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: _envoi ? null : _supprimerCompte,
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(t('Supprimer mon compte', 'حذف حسابي')),
        ),
        const SizedBox(height: 16),
        const LiensLegaux(),
      ],
    );
  }

  /// Date de naissance (facultative) : champ en lecture seule ouvrant le selecteur de date,
  /// avec une icone pour effacer la date choisie.
  Widget _champDateNaissance() {
    final date = _dateNaissance;
    return InkWell(
      onTap: _choisirDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: t('Date de naissance', 'تاريخ الميلاد'),
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: date == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: t('Effacer la date', 'مسح التاريخ'),
                  onPressed: () => setState(() => _dateNaissance = null),
                  icon: const Icon(Icons.clear),
                ),
        ),
        child: Text(libelleDateNaissance(date)),
      ),
    );
  }

  /// Langue de l'interface : menu deroulant parmi les langues acceptees par l'API.
  Widget _champLangue() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: t('Langue préférée', 'اللغة المفضلة'),
        prefixIcon: const Icon(Icons.language_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _langue,
          isExpanded: true,
          isDense: true,
          items: [
            for (final code in Profil.langues)
              DropdownMenuItem(value: code, child: Text(libelleLangue(code))),
          ],
          onChanged: _envoi
              ? null
              : (code) {
                  if (code != null) setState(() => _langue = code);
                },
        ),
      ),
    );
  }
}
