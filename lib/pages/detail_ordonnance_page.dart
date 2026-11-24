import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/langue.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/identifiants.dart';
import '../utils/libelles.dart';
import '../utils/ordonnances.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Detail d'une ordonnance du patient connecte : praticien, code de verification
/// et une carte par ligne (medicament, posologie, duree).
class DetailOrdonnancePage extends StatefulWidget {
  const DetailOrdonnancePage({
    super.key,
    required this.ordonnanceId,
    this.api = const ApiService(),
    this.auth,
  });

  /// Identifiant de l'ordonnance (UUID en texte).
  final String ordonnanceId;
  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<DetailOrdonnancePage> createState() => _DetailOrdonnancePageState();
}

class _DetailOrdonnancePageState extends State<DetailOrdonnancePage> {
  late final AuthService _auth = widget.auth ?? session;
  Map<String, dynamic>? _ordonnance;

  /// Nom du praticien resolu via la fiche publique ; « Médecin » et l'identifiant abrege a defaut.
  String _nomMedecin = '';
  bool _charge = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
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

  Future<void> _charger() async {
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final ordonnance = await widget.api.ordonnance(widget.ordonnanceId, token);
      final nomMedecin = await _resoudreNomMedecin(ordonnance);
      if (!mounted) return;
      setState(() {
        _ordonnance = ordonnance;
        _nomMedecin = nomMedecin;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Jeton expire : retour au bouton « Se connecter ».
      if (e.nonAutorise) _auth.seDeconnecter();
      setState(() => _erreur = messageChargementRefuse(e.statusCode, e.message,
          refus: t('Vous n\'avez pas accès à cette ordonnance.', 'ليس لديك صلاحية الاطلاع على هذه الوصفة.'),
          introuvable: t('Ordonnance introuvable.', 'الوصفة غير موجودة.')));
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Nom du praticien (endpoint public, identifiant UUID en texte) ; un echec n'empeche pas
  /// l'affichage : « Votre médecin » est montre a la place, comme le site (jamais l'identifiant).
  Future<String> _resoudreNomMedecin(Map<String, dynamic> ordonnance) async {
    final id = identifiant(ordonnance['medecinId']);
    if (id.isEmpty) return nomMedecinOrdonnance(null);
    try {
      final Object? nom = (await widget.api.medecin(id))['nomComplet'];
      if (nom is String && nom.trim().isNotEmpty) return nomMedecinOrdonnance(nom);
    } on Exception {
      // Fiche indisponible : libelle de repli ci-dessous.
    }
    return nomMedecinOrdonnance(null);
  }

  Future<void> _copier(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _message(t('Code copié', 'تم نسخ الرمز'));
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Ordonnance', 'الوصفة الطبية'))),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ??
            t('Connectez-vous pour consulter cette ordonnance.',
                'سجّل الدخول للاطلاع على هذه الوصفة.'),
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    final ordonnance = _ordonnance;
    if (erreur != null || ordonnance == null) {
      return VueErreur(
          message: erreur ?? t('Ordonnance introuvable', 'الوصفة غير موجودة'),
          onReessayer: _charger);
    }
    final texte = Theme.of(context).textTheme;
    final lignes = lignesOrdonnance(ordonnance);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(_nomMedecin),
          subtitle: Text(_sousTitre(ordonnance)),
        ),
        if (infoStatutOrdonnance(ordonnance) != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(infoStatutOrdonnance(ordonnance)!,
                key: const ValueKey('info-statut-ordonnance'),
                style: TextStyle(
                    color: '${ordonnance['statut']}'.toUpperCase() == 'ANNULEE'
                        ? Theme.of(context).colorScheme.error
                        : null)),
          ),
        const SizedBox(height: 8),
        _carteCode(context, '${ordonnance['codeVerification'] ?? ''}',
            aPresenter: !['ANNULEE', 'DELIVREE']
                .contains('${ordonnance['statut'] ?? ''}'.trim().toUpperCase())),
        const SizedBox(height: 24),
        Text(t('Médicaments', 'الأدوية'), style: texte.titleMedium),
        const SizedBox(height: 8),
        if (lignes.isEmpty)
          Text(t('Aucun médicament sur cette ordonnance.', 'لا يوجد أي دواء في هذه الوصفة.')),
        for (final ligne in lignes) _carteLigne(context, ligne),
      ],
    );
  }

  /// « Emise le jeu. 4 dec. 09:00 · Emise » (statut omis s'il est absent).
  String _sousTitre(Map<String, dynamic> ordonnance) {
    final date = '${t('Émise le', 'صدرت في')} ${dateEmission(ordonnance)}';
    final statut = libelleStatut(ordonnance['statut']);
    return statut.isEmpty ? date : '$date · $statut';
  }

  /// Code de verification en grand, selectionnable, avec bouton de copie.
  Widget _carteCode(BuildContext context, String code, {bool aPresenter = true}) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Card(
      color: couleurs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Code de vérification', 'رمز التحقق'), style: texte.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: texte.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: couleurs.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('Copier le code', 'نسخ الرمز'),
                  onPressed: code.isEmpty ? null : () => _copier(code),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            if (aPresenter) ...[
            const SizedBox(height: 4),
            Text(
              t('À présenter en pharmacie ; vérifiable sans compte via « Vérifier une ordonnance ».',
                  'يُقدَّم في الصيدلية؛ ويمكن التحقق منه دون حساب عبر « التحقق من وصفة ».'),
              key: const ValueKey('a-presenter-pharmacie'),
              style: texte.bodySmall,
            ),
            ],
          ],
        ),
      ),
    );
  }

  /// Une carte par ligne : medicament, posologie, duree.
  Widget _carteLigne(BuildContext context, Map<String, dynamic> ligne) {
    final texte = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${ligne['medicament'] ?? ''}', style: texte.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${t('Posologie', 'الجرعة')} : ${ligne['posologie'] ?? '-'}'),
            const SizedBox(height: 4),
            Text('${t('Durée', 'المدة')} : ${ligne['duree'] ?? '-'}'),
          ],
        ),
      ),
    );
  }
}
