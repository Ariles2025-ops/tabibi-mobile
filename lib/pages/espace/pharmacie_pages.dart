import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/identifiants.dart';
import '../../utils/libelles.dart';
import '../../widgets/champ_wilaya.dart';
import 'outils_espace.dart';

/// Besoins Dawini ouverts d'une wilaya (par defaut celle du profil de la pharmacie) ; « Répondre »
/// indique la disponibilite, un prix et un commentaire facultatifs.
class BesoinsPharmaciePage extends StatefulWidget {
  const BesoinsPharmaciePage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<BesoinsPharmaciePage> createState() => _BesoinsPharmaciePageState();
}

class _BesoinsPharmaciePageState extends State<BesoinsPharmaciePage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  String? _wilaya;
  List<Map<String, dynamic>> _besoins = [];

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) _initialiser();
  }

  /// Wilaya du profil, puis besoins.
  Future<void> _initialiser() async {
    try {
      final profil = await widget.api.monProfil(auth.accessToken ?? '');
      _wilaya = wilayaParCode(profil['wilayaCode'] as String?)?.code;
    } on Exception {
      // Profil absent : la pharmacie choisit sa wilaya.
    }
    if (!mounted) return;
    setState(() {});
    await recharger();
  }

  @override
  Future<void> recharger() async {
    final w = _wilaya;
    if (w == null) return;
    final b = await chargerAvec((j) => widget.api.besoinsWilaya(w, j));
    if (b != null && mounted) setState(() => _besoins = b);
  }

  Future<void> _repondre(Map<String, dynamic> besoin) async {
    final reponse = await showDialog<_Reponse>(
      context: context,
      builder: (_) => _DialogueReponse(medicament: '${besoin['medicament']}'),
    );
    if (reponse == null) return;
    final fait = await appeler((j) async {
      await widget.api.repondreBesoin(identifiant(besoin['id']), reponse.disponible, j,
          prixDa: reponse.prixDa, commentaire: reponse.commentaire);
      return true;
    });
    if (fait != true) return;
    message(t('Réponse envoyée au patient', 'تم إرسال الرد إلى المريض'));
    await recharger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(t('Besoins Dawini', 'طلبات دَويني')), actions: actionsActualiser()),
      body: corps(
          t('Connectez-vous pour voir les besoins de votre wilaya.',
              'سجّل الدخول لعرض طلبات ولايتك.'), () {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ChampWilaya(
              valeur: _wilaya,
              obligatoire: true,
              onChanged: (w) {
                setState(() => _wilaya = w);
                recharger();
              },
            ),
            const SizedBox(height: 12),
            if (_wilaya == null)
              Text(
                  t('Choisissez votre wilaya pour voir les demandes.', 'اختر ولايتك لعرض الطلبات.'))
            else if (_besoins.isEmpty)
              Text(t('Aucune demande ouverte dans cette wilaya.',
                  'لا توجد طلبات مفتوحة في هذه الولاية.'))
            else
              for (final b in _besoins) _tuile(b),
          ],
        );
      }),
    );
  }

  Widget _tuile(Map<String, dynamic> b) {
    final repondu = b['dejaRepondu'] == true;
    final date = DateTime.tryParse('${b['publieLe']}');
    final details = [
      if ((b['commune'] as String?)?.isNotEmpty ?? false) b['commune'] as String,
      if ((b['precision'] as String?)?.isNotEmpty ?? false) b['precision'] as String,
      if (date != null) formaterDateHeure(date),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.medication_outlined),
        title: Text('${b['medicament']}'),
        subtitle: Text(details),
        trailing: repondu
            ? Text(t('Répondu', 'تم الرد'))
            : TextButton(onPressed: () => _repondre(b), child: Text(t('Répondre', 'رد'))),
      ),
    );
  }
}

class _Reponse {
  const _Reponse(this.disponible, this.prixDa, this.commentaire);
  final bool disponible;
  final int? prixDa;
  final String? commentaire;
}

class _DialogueReponse extends StatefulWidget {
  const _DialogueReponse({required this.medicament});
  final String medicament;

  @override
  State<_DialogueReponse> createState() => _DialogueReponseState();
}

class _DialogueReponseState extends State<_DialogueReponse> {
  bool _disponible = true;
  final _prix = TextEditingController();
  final _commentaire = TextEditingController();

  @override
  void dispose() {
    _prix.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.medicament),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('Disponible', 'متوفر')),
            value: _disponible,
            onChanged: (v) => setState(() => _disponible = v),
          ),
          TextField(
            controller: _prix,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: t('Prix (DA)', 'السعر (دج)')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentaire,
            decoration: InputDecoration(labelText: t('Commentaire', 'تعليق')),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('Annuler', 'إلغاء'))),
        FilledButton(
          onPressed: () {
            final commentaire = _commentaire.text.trim();
            Navigator.pop(
              context,
              _Reponse(_disponible, int.tryParse(_prix.text.trim()),
                  commentaire.isEmpty ? null : commentaire),
            );
          },
          child: Text(t('Envoyer', 'إرسال')),
        ),
      ],
    );
  }
}

/// Pharmacie : verifier un code d'ordonnance puis la marquer delivree.
class DelivrerOrdonnancePage extends StatefulWidget {
  const DelivrerOrdonnancePage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<DelivrerOrdonnancePage> createState() => _DelivrerOrdonnancePageState();
}

class _DelivrerOrdonnancePageState extends State<DelivrerOrdonnancePage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  final _code = TextEditingController();
  Map<String, dynamic>? _resultat;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Future<void> recharger() async => setState(() {});

  String get _codeSaisi => _code.text.trim().toUpperCase();

  Future<void> _verifier() async {
    if (_codeSaisi.isEmpty) {
      message(t('Saisissez le code de vérification', 'أدخل رمز التحقق'));
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      final r = await widget.api.verifierOrdonnance(_codeSaisi);
      if (mounted) setState(() => _resultat = r);
    } on Exception catch (e) {
      message(messageErreur(e));
    }
  }

  Future<void> _delivrer() async {
    final r = await appeler((j) => widget.api.delivrerOrdonnance(_codeSaisi, j));
    if (r == null || !mounted) return;
    setState(() => _resultat = r);
    message(t('Ordonnance marquée délivrée', 'تم تسجيل صرف الوصفة'));
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultat;
    final valide = r?['valide'] == true;
    final statut = '${r?['statut'] ?? ''}'.toUpperCase();
    return Scaffold(
      appBar: AppBar(title: Text(t('Délivrer une ordonnance', 'صرف وصفة طبية'))),
      body: corps(
          t('Connectez-vous avec le compte de la pharmacie.', 'سجّل الدخول بحساب الصيدلية.'), () {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: t('Code de vérification', 'رمز التحقق'),
                prefixIcon: const Icon(Icons.qr_code_2),
              ),
              onSubmitted: (_) => _verifier(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _verifier, child: Text(t('Vérifier', 'تحقّق'))),
            const SizedBox(height: 16),
            if (r != null && !valide)
              Text(t('Aucune ordonnance ne correspond à ce code.', 'لا توجد وصفة بهذا الرمز.')),
            if (r != null && valide) ...[
              Text(
                t('Ordonnance valide · ${libelleStatut(statut)}',
                    'وصفة صالحة · ${libelleStatut(statut)}'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (DateTime.tryParse('${r['emiseLe']}') != null)
                Text(t('Émise le ${formaterDateIso('${r['emiseLe']}')}',
                    'صدرت في ${formaterDateIso('${r['emiseLe']}')}')),
              if (DateTime.tryParse('${r['delivreeLe']}') != null)
                Text(t('Délivrée le ${formaterDateIso('${r['delivreeLe']}')}',
                    'صُرفت في ${formaterDateIso('${r['delivreeLe']}')}')),
              const SizedBox(height: 12),
              if (statut == 'EMISE')
                FilledButton.icon(
                  onPressed: _delivrer,
                  icon: const Icon(Icons.check),
                  label: Text(t('Marquer délivrée', 'تسجيل الصرف')),
                ),
            ],
          ],
        );
      }),
    );
  }
}
