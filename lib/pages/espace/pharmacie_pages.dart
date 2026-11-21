import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../models/besoin_medicament.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/dawini.dart';
import '../../utils/espace_pro.dart';
import '../../utils/identifiants.dart';
import '../../utils/libelles.dart';
import '../../utils/ordonnances.dart';
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
  String _nomPharmacie = '';
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
      _nomPharmacie = '${profil['nomComplet'] ?? ''}'.trim();
    } on Exception {
      // Profil absent : la pharmacie choisit sa wilaya.
    }
    if (!mounted) return;
    setState(() {});
    await recharger();
  }

  /// 403 au chargement : page reservee aux pharmacies ; refus d'une reponse : messages du site.
  @override
  String libelleErreur(ApiException e) =>
      _repondant ? messageReponseBesoin(e) : messageChargement(e, PublicPage.pharmacies);
  bool _repondant = false;

  @override
  Future<void> recharger() async {
    final w = _wilaya;
    if (w == null) return;
    final b = await chargerAvec((j) => widget.api.besoinsWilaya(w, j));
    if (b != null && mounted) setState(() => _besoins = trierBesoinsBrutsParPublication(b));
  }

  Future<void> _repondre(Map<String, dynamic> besoin) async {
    // Comme le site : la reponse porte le nom de la pharmacie, pris dans son profil.
    if (_nomPharmacie.isEmpty) {
      message(t("Renseignez d'abord le nom de votre pharmacie dans « Mon profil ».",
          'أدخل أولًا اسم صيدليتك في «ملفي الشخصي».'));
      return;
    }
    final reponse = await showDialog<_Reponse>(
      context: context,
      builder: (_) => _DialogueReponse(medicament: '${besoin['medicament']}'),
    );
    if (reponse == null) return;
    _repondant = true;
    final fait = await appeler((j) async {
      await widget.api.repondreBesoin(identifiant(besoin['id']), reponse.disponible, j,
          prixDa: reponse.prixDa, commentaire: reponse.commentaire, nomPharmacie: _nomPharmacie);
      return true;
    });
    _repondant = false;
    if (fait != true) return;
    message(t('Réponse envoyée pour « ${besoin['medicament']} » : le patient est prévenu.',
        'تم إرسال الرد بخصوص «${besoin['medicament']}»: المريض مُبلَّغ.'));
    await recharger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(t('Demandes de médicaments', 'طلبات الأدوية')), actions: actionsActualiser()),
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
    final besoin = BesoinMedicament.fromJson(b);
    final precision = besoin.precision;
    final details = [
      detailBesoinPharmacie(besoin),
      if (precision != null && precision.isNotEmpty) precision,
    ].join('\n');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.medication_outlined),
        title: Text('${b['medicament']}'),
        subtitle: Text(details),
        trailing: repondu
            ? Text(t('Déjà répondu', 'تم الرد مسبقًا'))
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
  String? _erreurPrix;

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
            decoration: InputDecoration(
              labelText: t('Prix (DA)', 'السعر (دج)'),
              errorText: _erreurPrix,
            ),
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
            final texte = _prix.text.trim();
            // Un prix vide est ignore ; un prix non vide mais invalide bloque l'envoi.
            final prix = texte.isEmpty ? null : int.tryParse(texte);
            if (texte.isNotEmpty && (prix == null || prix < 0)) {
              setState(() => _erreurPrix = t('Indiquez un prix en dinars valide (nombre entier positif ou nul).',
                  'أدخل سعرًا صحيحًا بالدينار (عدد صحيح موجب أو صفر).'));
              return;
            }
            Navigator.pop(
              context,
              _Reponse(_disponible, prix,
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

  /// Vrai juste après « Marquer comme délivrée » : le statut DELIVREE est alors un succès, pas un refus.
  bool _vientDeDelivrer = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Future<void> recharger() async => setState(() {});

  /// Code qui a été vérifié : c'est le seul sur lequel « Marquer comme délivrée » peut agir.
  String? _codeVerifie;

  String get _codeSaisi => _code.text.trim().toUpperCase();

  void _codeModifie(String _) {
    if (_resultat != null && _codeSaisi != _codeVerifie) {
      setState(() {
        _resultat = null;
        _codeVerifie = null;
        _vientDeDelivrer = false;
      });
    }
  }

  Future<void> _verifier() async {
    final code = _codeSaisi;
    if (code.isEmpty) {
      message(t('Saisissez le code de vérification', 'أدخل رمز التحقق'));
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      final r = await widget.api.verifierOrdonnance(code);
      // Ignore la réponse si le champ a changé pendant l'appel.
      if (mounted && code == _codeSaisi) {
        setState(() {
          _resultat = r;
          _codeVerifie = code;
          _vientDeDelivrer = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.introuvable && code == _codeSaisi) {
        // Comme le site : un code inconnu (404) affiche « Code inconnu. », pas une erreur generique.
        setState(() {
          _resultat = const <String, dynamic>{'valide': false};
          _codeVerifie = code;
          _vientDeDelivrer = false;
        });
      } else {
        message(messageErreur(e));
      }
    } on Exception catch (e) {
      message(messageErreur(e));
    }
  }

  Future<void> _delivrer() async {
    final code = _codeVerifie;
    if (code == null) return;
    final r = await appeler((j) => widget.api.delivrerOrdonnance(code, j));
    if (r == null || !mounted) return;
    setState(() {
      _resultat = r;
      _vientDeDelivrer = true;
    });
    message(t('Ordonnance marquée comme délivrée.', 'تم تسجيل صرف الوصفة.'));
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultat;
    final valide = r?['valide'] == true;
    final statut = '${r?['statut'] ?? ''}'.toUpperCase();
    final refus = r == null || _vientDeDelivrer ? null : avertissementVerification(r);
    return Scaffold(
      appBar: AppBar(title: Text(t('Vérifier / délivrer une ordonnance', 'التحقق من وصفة وصرفها'))),
      body: corps(
          t('Connectez-vous avec le compte de la pharmacie.', 'سجّل الدخول بحساب الصيدلية.'), () {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: t('Code de vérification', 'رمز التحقق'),
                helperText: t("Saisissez le code de 8 caractères imprimé sur l'ordonnance.",
                    'أدخل الرمز المكوَّن من 8 أحرف المطبوع على الوصفة.'),
                helperMaxLines: 2,
                counterText: '',
                prefixIcon: const Icon(Icons.qr_code_2),
              ),
              onChanged: _codeModifie,
              onSubmitted: (_) => _verifier(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _verifier, child: Text(t('Vérifier', 'تحقق'))),
            const SizedBox(height: 16),
            // Après « Marquer comme délivrée » le serveur renvoie valide=false, statut=DELIVREE : c'est un succès.
            // Un code inconnu passe par une erreur 404 affichée en message, pas par ici.
            if (r != null && _vientDeDelivrer) ...[
              Text(
                  DateTime.tryParse('${r['delivreeLe']}') != null
                      ? t('Ordonnance délivrée le ${formaterDateIso('${r['delivreeLe']}')}',
                          'تم صرف الوصفة في ${formaterDateIso('${r['delivreeLe']}')}')
                      : t('Ordonnance délivrée', 'تم صرف الوصفة'),
                  style: Theme.of(context).textTheme.titleMedium),
            ],
            // Comme le site : annulée, expirée ou déjà délivrée = refus net, jamais « valide ».
            if (r != null && refus != null)
              Text(refus,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
            if (r != null && !valide && refus == null && !_vientDeDelivrer)
              Text(t('Code inconnu : aucune ordonnance ne correspond à ce code.',
                  'رمز غير معروف: لا توجد أي وصفة تطابق هذا الرمز.'),
                  key: const ValueKey('code-inconnu'),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
            if (r != null && valide && refus == null && !_vientDeDelivrer) ...[
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
                  label: Text(t('Marquer comme délivrée', 'تسجيل الصرف')),
                ),
            ],
          ],
        );
      }),
    );
  }
}
