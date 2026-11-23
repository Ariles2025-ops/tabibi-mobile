import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/besoin_medicament.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/espace_pro.dart';
import '../utils/dawini.dart';
import '../widgets/champ_wilaya.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'reponses_besoin_page.dart';

/// Messages de validation du formulaire.
String get messageMedicamentRequis =>
    t('Indiquez le médicament recherché.', 'أدخل اسم الدواء المطلوب.');
String get messageWilayaRequise => t('Choisissez votre wilaya.', 'اختر ولايتك.');

/// Dawini : demander un medicament aux pharmacies. Formulaire (medicament et wilaya
/// obligatoires, commune et precision facultatives) puis liste de mes demandes avec leur
/// statut et le nombre de reponses ; un toucher ouvre les reponses.
class DawiniPage extends StatefulWidget {
  const DawiniPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<DawiniPage> createState() => _DawiniPageState();
}

class _DawiniPageState extends State<DawiniPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _medicament = TextEditingController();

  /// Code de la wilaya choisie (liste des 69) ; prerempli avec celle du profil.
  String? _wilaya;
  final _commune = TextEditingController();
  final _precision = TextEditingController();
  List<BesoinMedicament> _besoins = [];
  bool _charge = false;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) {
      _charger();
      _wilayaDuProfil();
    }
  }

  /// Wilaya du profil comme valeur par defaut ; sans profil, l'utilisateur la choisit.
  Future<void> _wilayaDuProfil() async {
    final token = _auth.accessToken;
    if (token == null) return;
    try {
      final profil = await widget.api.monProfil(token);
      final code = wilayaParCode(profil['wilayaCode'] as String?)?.code;
      if (mounted && _wilaya == null && code != null) setState(() => _wilaya = code);
    } on Exception {
      // Profil absent ou indisponible.
    }
  }

  @override
  void dispose() {
    _medicament.dispose();
    _commune.dispose();
    _precision.dispose();
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

  /// Charge (ou recharge) mes demandes ; [discret] evite l'indicateur plein ecran.
  Future<void> _charger({bool discret = false}) async {
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() {
      _charge = !discret;
      _erreur = null;
    });
    try {
      final besoins = await widget.api.mesBesoins(token);
      if (!mounted) return;
      setState(() {
        _besoins = trierParPublication(besoins.map(BesoinMedicament.fromJson).toList());
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Jeton expire : retour au bouton « Se connecter ».
      if (e.nonAutorise) _auth.seDeconnecter();
      setState(() => _erreur = messageChargement(e, PublicPage.patients));
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Publie la demande (POST /api/dawini/besoins) apres validation locale du medicament et
  /// du code de wilaya ; succes -> formulaire vide et liste rechargee ; 400 affiche tel quel.
  Future<void> _publier() async {
    final medicament = _medicament.text.trim();
    if (medicament.isEmpty) {
      _message(messageMedicamentRequis);
      return;
    }
    final wilayaCode = _wilaya ?? '';
    if (wilayaCode.isEmpty) {
      _message(messageWilayaRequise);
      return;
    }
    if (_envoi) return;
    final token = _auth.accessToken;
    if (token == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoi = true);
    var publie = false;
    try {
      final commune = _commune.text.trim();
      final precision = _precision.text.trim();
      await widget.api.publierBesoin(
        medicament,
        wilayaCode,
        token,
        commune: commune.isEmpty ? null : commune,
        precision: precision.isEmpty ? null : precision,
      );
      publie = true;
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(messagePublicationBesoin(e));
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
    }
    if (!publie || !mounted) return;
    _medicament.clear();
    _commune.clear();
    _precision.clear();
    _message(t('Demande publiée : les pharmacies de votre wilaya peuvent y répondre.',
        'تم نشر الطلب: يمكن لصيدليات ولايتك الرد عليه.'));
    await _charger(discret: true);
  }

  /// Ouvre les reponses ; au retour, la demande a pu etre cloturee.
  Future<void> _ouvrirReponses(BesoinMedicament besoin) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReponsesBesoinPage(besoin: besoin, api: widget.api, auth: _auth),
      ),
    );
    if (!mounted) return;
    if (_auth.estConnecte) {
      await _charger(discret: true);
    } else {
      setState(() {}); // la session a expire sur les reponses
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Dawini', 'داويني')),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              tooltip: t('Actualiser', 'تحديث'),
              onPressed: _charge ? null : _charger,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ??
            t('Connectez-vous pour demander un médicament aux pharmacies.',
                'سجّل الدخول لطلب دواء من الصيدليات.'),
        onSeConnecter: _seConnecter,
      );
    }
    final texte = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _formulaire(context),
        const SizedBox(height: 24),
        Text(t('Mes demandes', 'طلباتي'), style: texte.titleMedium),
        const SizedBox(height: 8),
        ..._listeDemandes(context),
      ],
    );
  }

  /// Formulaire de demande : medicament et wilaya obligatoires, commune et precision libres.
  Widget _formulaire(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Demander un médicament', 'طلب دواء'), style: texte.titleMedium),
            const SizedBox(height: 4),
            Text(
              t('Les pharmacies de votre wilaya répondent avec leur disponibilité et leur prix, sans connaître votre identité.',
                  'تردّ صيدليات ولايتك بتوفّر الدواء وسعره، دون معرفة هويتك.'),
              style: texte.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _medicament,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t('Médicament recherché *', 'الدواء المطلوب *'),
                prefixIcon: const Icon(Icons.medication_outlined),
              ),
            ),
            const SizedBox(height: 8),
            ChampWilaya(
              valeur: _wilaya,
              obligatoire: true,
              actif: !_envoi,
              onChanged: (code) => setState(() => _wilaya = code),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commune,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t('Commune', 'البلدية'),
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _precision,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t('Précision (dosage, forme, urgence)',
                    'تفاصيل (الجرعة، الشكل، الاستعجال)'),
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _envoi ? null : _publier,
              child: _envoi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t('Publier ma demande', 'نشر طلبي')),
            ),
          ],
        ),
      ),
    );
  }

  /// Mes demandes : medicament, lieu et statut, date, « n réponses » ; ou un texte d'etat.
  List<Widget> _listeDemandes(BuildContext context) {
    if (_charge) {
      return const [
        Center(
          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
        ),
      ];
    }
    final erreur = _erreur;
    if (erreur != null) return [VueErreur(message: erreur, onReessayer: _charger)];
    if (_besoins.isEmpty) {
      return [Text(t('Aucune demande pour le moment.', 'لا توجد طلبات حاليًا.'))];
    }
    return [for (final b in _besoins) _tuile(context, b)];
  }

  Widget _tuile(BuildContext context, BesoinMedicament b) {
    final texte = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(estOuvert(b) ? Icons.local_pharmacy_outlined : Icons.check_circle_outline),
        title: Text(b.medicament),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${lieuBesoin(b)} · ${libelleStatutBesoin(b.statut)}'),
            const SizedBox(height: 2),
            Text(dateBesoin(b), style: texte.bodySmall),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(libelleReponses(b.nombreReponses), style: texte.labelLarge),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _ouvrirReponses(b),
      ),
    );
  }
}
