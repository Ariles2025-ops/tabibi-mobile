import 'package:flutter/material.dart';

import '../../config/referentiel.dart';
import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/libelles.dart';
import '../../widgets/champ_wilaya.dart';
import 'outils_espace.dart';

/// Corps de la candidature, comme le site : champs nettoyes, libelles francais de la specialite
/// et de la wilaya tires du referentiel. Null si un champ obligatoire manque (nom, specialite,
/// wilaya, numero d'inscription a l'ordre).
Map<String, dynamic>? corpsCandidature({
  required String nomComplet,
  required String? specialiteSlug,
  required String? wilayaCode,
  required String ville,
  required String numeroOrdre,
  required String telephone,
  String? ficheReclamee,
}) {
  final nom = nomComplet.trim();
  final ordre = numeroOrdre.trim();
  final sp = specialites.where((s) => s.slug == specialiteSlug).firstOrNull;
  final w = wilayaParCode(wilayaCode);
  if (nom.isEmpty || ordre.isEmpty || sp == null || w == null) return null;
  return {
    'nomComplet': nom,
    'specialiteSlug': sp.slug,
    'specialiteFr': sp.nom,
    'wilayaCode': w.code,
    'wilayaFr': w.nom,
    'ville': ville.trim(),
    'numeroOrdre': ordre,
    'telephone': telephone.trim(),
    if (ficheReclamee != null && ficheReclamee.isNotEmpty) 'ficheReclamee': ficheReclamee,
  };
}

/// « Ma candidature » du site : derniere candidature du compte (GET /api/medecin/candidature,
/// 404 = aucune) et formulaire de depot s'il n'en a jamais depose ou si la derniere a ete
/// refusee (POST). Une candidature est examinee par un administrateur.
class CandidaturePage extends StatefulWidget {
  const CandidaturePage({super.key, this.api = const ApiService(), this.auth, this.ficheReclamee});

  final ApiService api;
  final AuthService? auth;

  /// Identifiant d'une fiche importee que le praticien reclame (« C'est votre fiche ? »), comme
  /// `?fiche=` sur le site : nom, specialite et lieu sont preremplis. Null : candidature simple.
  final String? ficheReclamee;

  @override
  State<CandidaturePage> createState() => _CandidaturePageState();
}

class _CandidaturePageState extends State<CandidaturePage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  final _nom = TextEditingController();
  final _ordre = TextEditingController();
  final _ville = TextEditingController();
  final _telephone = TextEditingController();
  Map<String, dynamic>? _candidature;
  bool _formulaire = false;
  String? _specialite;
  String? _wilaya;
  String? _erreurFormulaire;
  bool _envoiEnCours = false;
  String? _ficheReclamee;

  @override
  void initState() {
    super.initState();
    _ficheReclamee = widget.ficheReclamee;
    if (_ficheReclamee != null) _preremplirDepuisFiche(_ficheReclamee!);
    if (auth.estConnecte) recharger();
  }

  /// Reprend nom, specialite et lieu de la fiche reclamee ; le medecin n'ajoute que son numero d'ordre.
  Future<void> _preremplirDepuisFiche(String id) async {
    try {
      final m = await widget.api.medecin(id);
      if (!mounted) return;
      final sp = m['specialiteSlug']?.toString();
      setState(() {
        _nom.text = m['nomComplet']?.toString() ?? '';
        _ville.text = m['ville']?.toString() ?? '';
        _specialite = specialites.any((s) => s.slug == sp) ? sp : null;
        _wilaya = wilayaParCode(m['wilayaCode']?.toString())?.code;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _ficheReclamee = null;
        _erreurFormulaire = t(
            'La fiche à réclamer est introuvable : vous pouvez déposer une candidature.',
            'الملف المطلوب غير موجود: يمكنك إيداع ترشح.');
      });
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _ordre.dispose();
    _ville.dispose();
    _telephone.dispose();
    super.dispose();
  }

  @override
  Future<void> recharger() async {
    final jeton = auth.accessToken;
    if (jeton == null) return;
    setState(() {
      charge = true;
      erreur = null;
    });
    try {
      _afficher(await widget.api.maCandidature(jeton));
    } on ApiException catch (e) {
      if (e.introuvable) {
        // Aucune candidature deposee : on propose le formulaire.
        if (mounted) {
          setState(() {
            _candidature = null;
            _formulaire = true;
          });
        }
      } else {
        if (e.nonAutorise) auth.seDeconnecter();
        if (mounted) setState(() => erreur = e.message);
      }
    } on Exception catch (e) {
      if (mounted) setState(() => erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => charge = false);
    }
  }

  /// Affiche la candidature ; le formulaire (prerempli) n'est propose que si elle est refusee.
  void _afficher(Map<String, dynamic> c) {
    if (!mounted) return;
    final refusee = c['statut']?.toString().toUpperCase() == 'REFUSEE';
    setState(() {
      _candidature = c;
      _formulaire = refusee;
      if (refusee && _ficheReclamee == null) {
        _nom.text = c['nomComplet']?.toString() ?? '';
        _ordre.text = c['numeroOrdre']?.toString() ?? '';
        _ville.text = c['ville']?.toString() ?? '';
        _telephone.text = c['telephone']?.toString() ?? '';
        final sp = c['specialiteSlug']?.toString();
        _specialite = specialites.any((s) => s.slug == sp) ? sp : null;
        _wilaya = wilayaParCode(c['wilayaCode']?.toString())?.code;
      }
    });
  }

  Future<void> _deposer() async {
    final corps = corpsCandidature(
      nomComplet: _nom.text,
      specialiteSlug: _specialite,
      wilayaCode: _wilaya,
      ville: _ville.text,
      numeroOrdre: _ordre.text,
      telephone: _telephone.text,
      ficheReclamee: _ficheReclamee,
    );
    if (corps == null) {
      setState(() => _erreurFormulaire = t(
          "Renseignez le nom complet, la spécialité, la wilaya et le numéro d'inscription à l'ordre.",
          'أدخل الاسم الكامل والتخصص والولاية ورقم التسجيل في الهيئة.'));
      return;
    }
    final jeton = auth.accessToken;
    if (jeton == null) return;
    setState(() {
      _erreurFormulaire = null;
      _envoiEnCours = true;
    });
    try {
      _afficher(await widget.api.deposerCandidature(corps, jeton));
      message(t('Candidature déposée : elle sera examinée par un administrateur.',
          'تم إيداع الترشح: سيفحصه مسؤول.'));
    } on ApiException catch (e) {
      if (e.nonAutorise) auth.seDeconnecter();
      if (mounted) setState(() => _erreurFormulaire = e.message);
      // Deja en attente ou validee : on affiche l'etat reel.
      if (e.conflit) await recharger();
    } on Exception catch (e) {
      if (mounted) setState(() => _erreurFormulaire = messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  Widget _carte(Map<String, dynamic> c) {
    final statut = c['statut']?.toString().toUpperCase() ?? '';
    final sp = specialites.where((s) => s.slug == c['specialiteSlug']).firstOrNull;
    final w = wilayaParCode(c['wilayaCode']?.toString());
    final ville = (c['ville']?.toString() ?? '').trim();
    final depose = c['deposeeLe']?.toString();
    final traite = c['traiteeLe']?.toString();
    final motif = (c['motifRefus']?.toString() ?? '').trim();
    final lieu = [if (ville.isNotEmpty) ville, if (w != null) nomWilaya(w)].join(' · ');
    final details = [
      if (sp != null) nomSpecialite(sp),
      if (lieu.isNotEmpty) lieu,
      "${t("N° d'ordre", 'رقم التسجيل')} ${c['numeroOrdre'] ?? ''}",
    ].join(' · ');
    final dates = [
      if (depose != null)
        t('Déposée le ${formaterDateIso(depose, avecAnnee: true)}',
            'أُودع في ${formaterDateIso(depose, avecAnnee: true)}'),
      if (traite != null)
        t('traitée le ${formaterDateIso(traite, avecAnnee: true)}',
            'عولج في ${formaterDateIso(traite, avecAnnee: true)}'),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${c['nomComplet'] ?? ''} · ${libelleStatut(statut)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(details),
            if (dates.isNotEmpty) Text(dates, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (statut == 'EN_ATTENTE')
              Text(t("Votre candidature est en cours d'examen.", 'ترشحك قيد الفحص.')),
            if (statut == 'VALIDEE')
              Text(t(
                  'Votre candidature a été validée : vous figurez sur Ndawik. Ouvrez « Mon espace » (reconnectez-vous si besoin) pour gérer votre agenda.',
                  'تم قبول ترشحك: أنت تظهر على نداويك. افتح «فضائي» (وأعد تسجيل الدخول عند الحاجة) لإدارة مواعيدك.')),
            if (statut == 'REFUSEE')
              Text(
                  '${t('Votre candidature a été refusée', 'تم رفض ترشحك')}'
                  '${motif.isEmpty ? '' : ' · ${t('Motif', 'السبب')} : $motif'}. '
                  '${t('Vous pouvez en déposer une nouvelle ci-dessous.', 'يمكنك إيداع ترشح جديد أدناه.')}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    );
  }

  Widget _champ(TextEditingController c, String libelle,
          {TextInputType? type, bool obligatoire = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: obligatoire ? '$libelle *' : libelle),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_ficheReclamee != null
              ? t('Réclamer ma fiche', 'المطالبة بملفي')
              : t('Ma candidature', 'ترشحي')),
          actions: actionsActualiser()),
      body: corps(t('Connectez-vous pour déposer votre candidature.', 'سجّل الدخول لإيداع ترشحك.'),
          () {
        final c = _candidature;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_ficheReclamee != null
                ? t("Vérifiez les informations de votre fiche et ajoutez votre numéro d'inscription à l'ordre : un administrateur confirme que c'est bien vous avant de vous la confier.",
                    'تحقّق من معلومات ملفك وأضف رقم تسجيلك في الهيئة: يتأكد مسؤول أنك أنت صاحبه قبل أن يسلّمه لك.')
                : t('Pour figurer sur Ndawik, déposez votre candidature : elle est examinée par un administrateur.',
                    'لتظهر على نداويك، أودع ترشحك: سيفحصه مسؤول.')),
            const SizedBox(height: 16),
            if (c != null) _carte(c),
            if (_formulaire) ...[
              if (c != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(t('Nouvelle candidature', 'ترشح جديد'),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              _champ(_nom, t('Nom complet', 'الاسم الكامل'), obligatoire: true),
              _champ(_ordre, t("Numéro d'inscription à l'ordre", 'رقم التسجيل في الهيئة'),
                  obligatoire: true),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('specialite-$_specialite'),
                  initialValue: _specialite,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: t('Spécialité *', 'التخصص *')),
                  items: [
                    for (final s in specialites)
                      DropdownMenuItem(value: s.slug, child: Text(nomSpecialite(s))),
                  ],
                  onChanged: (v) => setState(() => _specialite = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChampWilaya(
                    valeur: _wilaya, obligatoire: true, onChanged: (v) => setState(() => _wilaya = v)),
              ),
              _champ(_ville, t('Ville', 'المدينة')),
              _champ(_telephone, t('Téléphone', 'الهاتف'), type: TextInputType.phone),
              if (_erreurFormulaire != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_erreurFormulaire!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Text(t('* Champs obligatoires.', '* حقول إلزامية.'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _envoiEnCours ? null : _deposer,
                child: Text(_envoiEnCours
                    ? t('Envoi…', 'جارٍ الإرسال…')
                    : _ficheReclamee != null
                        ? t('Réclamer ma fiche', 'المطالبة بملفي')
                        : t('Déposer ma candidature', 'إيداع ترشحي')),
              ),
            ] else if (_erreurFormulaire != null)
              Text(_erreurFormulaire!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        );
      }),
    );
  }
}
