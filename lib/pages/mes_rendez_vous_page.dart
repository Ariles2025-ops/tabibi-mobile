import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../i18n/langue.dart';
import '../models/avis.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/avis.dart';
import '../utils/dates.dart';
import '../utils/identifiants.dart';
import '../widgets/composants.dart';
import '../utils/rendez_vous.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'deposer_avis_page.dart';

/// Rendez-vous du patient connecte, avec annulation ; « Donner mon avis » sur les
/// rendez-vous honores (ou « Avis donné » si l'avis existe deja).
class MesRendezVousPage extends StatefulWidget {
  const MesRendezVousPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<MesRendezVousPage> createState() => _MesRendezVousPageState();
}

class _MesRendezVousPageState extends State<MesRendezVousPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _rdvs = [];

  /// Noms des praticiens deja resolus, par identifiant (UUID en texte).
  final Map<String, String> _nomsMedecins = {};

  /// Identifiants (texte) des rendez-vous pour lesquels un avis a deja ete depose.
  Set<String> _rendezVousEvalues = {};
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
      final rdvs = await widget.api.mesRendezVous(token);
      await _chargerNomsMedecins(rdvs);
      final evalues = await _chargerRendezVousEvalues(token);
      if (!mounted) return;
      setState(() {
        _rdvs = rdvs;
        _rendezVousEvalues = evalues;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Jeton expire : retour au bouton « Se connecter ».
      if (e.nonAutorise) _auth.seDeconnecter();
      setState(() => _erreur = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Noms des praticiens (endpoint public, identifiant UUID en texte) ; un echec n'empeche
  /// pas l'affichage.
  Future<void> _chargerNomsMedecins(List<Map<String, dynamic>> rdvs) async {
    for (final id in rdvs.map((r) => identifiant(r['medecinId'])).toSet()) {
      if (id.isEmpty || _nomsMedecins.containsKey(id)) continue;
      try {
        final Object? nom = (await widget.api.medecin(id))['nomComplet'];
        if (nom is String && nom.isNotEmpty) _nomsMedecins[id] = nom;
      } on Exception {
        // Nom indisponible : « Médecin » et l'identifiant abrege seront affiches a la place.
      }
    }
  }

  /// Rendez-vous deja evalues (GET /api/avis/mes) ; en cas d'echec, le bouton « Donner mon
  /// avis » reste propose et un eventuel 409 sera explique au depot.
  Future<Set<String>> _chargerRendezVousEvalues(String token) async {
    try {
      final avis = await widget.api.mesAvis(token);
      return avis.map(Avis.fromJson).map((a) => a.rendezVousId).toSet();
    } on Exception {
      return _rendezVousEvalues;
    }
  }

  bool _aDonneSonAvis(Map<String, dynamic> rdv) =>
      _rendezVousEvalues.contains(identifiant(rdv['id']));

  /// Ouvre le formulaire d'avis ; au retour, la liste est rechargee si un avis a ete depose.
  Future<void> _donnerAvis(Map<String, dynamic> rdv) async {
    final id = identifiant(rdv['id']);
    if (id.isEmpty) return;
    final depose = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DeposerAvisPage(
          rendezVousId: id,
          nomMedecin: _nomMedecin(rdv),
          dateRendezVous: _dateRdv(rdv),
          api: widget.api,
          auth: _auth,
        ),
      ),
    );
    if (!mounted) return;
    if (depose == true && _auth.estConnecte) {
      await _charger();
    } else {
      setState(() {}); // la session a pu expirer sur le formulaire
    }
  }

  Future<void> _annuler(Map<String, dynamic> rdv) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Annuler ce rendez-vous ?', 'إلغاء هذا الموعد؟')),
        content: Text('${_nomMedecin(rdv)}\n${_dateRdv(rdv)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Non', 'لا')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Oui, annuler', 'نعم، إلغاء')),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    final token = _auth.accessToken;
    if (token == null) return;
    try {
      await widget.api.annuler(identifiant(rdv['id']), token);
      _message(t('Rendez-vous annulé', 'تم إلغاء الموعد'));
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    }
    if (!mounted) return;
    if (_auth.estConnecte) {
      await _charger();
    } else {
      setState(() {});
    }
  }

  /// Deplacer : choix d'un autre creneau libre du meme praticien, confirmation, puis
  /// POST .../deplacer. Si le creneau est pris (409), rien ne change et on le dit.
  Future<void> _deplacer(Map<String, dynamic> rdv) async {
    final token = _auth.accessToken;
    if (token == null) return;
    final List<Map<String, dynamic>> libres;
    try {
      final tous = await widget.api.creneaux(identifiant(rdv['medecinId']));
      final maintenant = DateTime.now();
      libres = tous
          .where((c) =>
              c['disponible'] != false &&
              identifiant(c['id']) != identifiant(rdv['creneauId']) &&
              (DateTime.tryParse(identifiant(c['debut']))?.isAfter(maintenant) ?? false))
          .toList()
        ..sort((a, b) => identifiant(a['debut']).compareTo(identifiant(b['debut'])));
    } on Exception catch (e) {
      _message(messageErreur(e));
      return;
    }
    if (!mounted) return;
    final choisi = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('Choisir un nouveau créneau', 'اختر موعدًا جديدًا')),
        children: libres.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(t('Aucun autre créneau disponible pour le moment.',
                      'لا توجد مواعيد أخرى متاحة حاليًا.')),
                ),
              ]
            : [
                for (final c in libres)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, c),
                    child: Text(formaterDateIso(identifiant(c['debut']))),
                  ),
              ],
      ),
    );
    if (choisi == null || !mounted) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Déplacer ce rendez-vous ?', 'نقل هذا الموعد؟')),
        content: Text('${_nomMedecin(rdv)}\n${_dateRdv(rdv)} → '
            '${formaterDateIso(identifiant(choisi['debut']))}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Non', 'لا')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Oui, déplacer', 'نعم، انقل')),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await widget.api.deplacer(identifiant(rdv['id']), identifiant(choisi['id']), token);
      _message(t('Rendez-vous déplacé', 'تم نقل الموعد'));
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.conflit
          ? t("Ce créneau vient d'être pris. Votre rendez-vous n'a pas changé : choisissez un autre créneau.",
              'تم حجز هذا الموعد للتو. موعدك لم يتغيّر، اختر موعدًا آخر.')
          : e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    }
    if (!mounted) return;
    if (_auth.estConnecte) {
      await _charger();
    } else {
      setState(() {});
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  String _dateRdv(Map<String, dynamic> rdv) => formaterDateIso(identifiant(rdv['debut']));

  /// Nom du praticien ; « Médecin » suivi de l'identifiant abrege s'il n'a pu etre resolu.
  String _nomMedecin(Map<String, dynamic> rdv) {
    final id = identifiant(rdv['medecinId']);
    return _nomsMedecins[id] ?? libelleMedecin(id);
  }

  /// « CONFIRME » -> « Confirmé » (« Terminé » une fois l'heure passée, comme sur le site).
  String _libelleStatut(Map<String, dynamic> rdv) => libelleStatutRendezVous(rdv);

  /// Annulable tant qu'il est a venir (ni annule, ni honore, ni absent, ni passe).
  bool _annulable(Map<String, dynamic> rdv) => estAnnulable(rdv);

  /// Action d'un rendez-vous : « Donner mon avis » (ou « Avis donné ») s'il est honore,
  /// « Annuler » s'il est encore annulable, rien sinon.
  Widget? _action(Map<String, dynamic> rdv) {
    if (estHonore(rdv['statut'])) {
      if (_aDonneSonAvis(rdv)) return Text(t('Avis donné', 'تم تقديم الرأي'));
      return TextButton(
          onPressed: () => _donnerAvis(rdv), child: Text(t('Donner mon avis', 'أبدِ رأيك')));
    }
    if (_annulable(rdv)) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        TextButton(onPressed: () => _deplacer(rdv), child: Text(t('Déplacer', 'نقل'))),
        TextButton(onPressed: () => _annuler(rdv), child: Text(t('Annuler', 'إلغاء'))),
      ]);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Mes rendez-vous', 'مواعيدي')),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              tooltip: t('Actualiser', 'تحديث'),
              onPressed: _charge ? null : _charger,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (!_auth.estConnecte) return _vueConnexion();
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_rdvs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t("Aucun rendez-vous pour le moment. Trouvez un praticien depuis l'accueil et réservez en quelques secondes.",
                'لا توجد مواعيد حاليًا. ابحث عن ممارس من الصفحة الرئيسية واحجز في ثوانٍ.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final classes = classerRendezVous(_rdvs);
    final lignes = <Widget>[
      _enTete(t('À venir', 'القادمة')),
      if (classes.aVenir.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(t('Aucun rendez-vous à venir.', 'لا توجد مواعيد قادمة.')),
        ),
      for (final rdv in classes.aVenir) _ligne(rdv, avecAnnee: false),
      if (classes.passes.isNotEmpty) ...[
        _enTete(t('Passés', 'السابقة')),
        for (final rdv in classes.passes) _ligne(rdv, avecAnnee: true),
      ],
    ];
    return ListView(padding: const EdgeInsets.all(16), children: lignes);
  }

  Widget _enTete(String titre) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Text(titre, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _ligne(Map<String, dynamic> rdv, {required bool avecAnnee}) {
    final texte = Theme.of(context).textTheme;
    final action = _action(rdv);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CarteTabibi(
        child: Row(children: [
          AvatarInitiales(nom: _nomMedecin(rdv)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formaterDateIso(identifiant(rdv['debut']), avecAnnee: avecAnnee),
                    style: texte.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_nomMedecin(rdv),
                    style: texte.bodyMedium?.copyWith(color: Charte.doux)),
                const SizedBox(height: 6),
                PastilleStatut(libelle: _libelleStatut(rdv), statut: rdv['statut']),
              ],
            ),
          ),
          if (action != null) action,
        ]),
      ),
    );
  }

  Widget _vueConnexion() {
    return VueConnexion(
      message: _erreur ??
          t('Connectez-vous pour consulter vos rendez-vous.', 'سجّل الدخول للاطلاع على مواعيدك.'),
      onSeConnecter: _seConnecter,
    );
  }
}
