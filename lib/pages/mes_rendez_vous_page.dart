import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/avis.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/avis.dart';
import '../utils/dates.dart';
import '../utils/identifiants.dart';
import '../utils/libelles.dart';
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
      _message(t(context, 'commun.connexionAnnulee'));
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
      setState(() => _erreur = messageApi(context, e));
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageApi(context, e));
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
        builder: (ctx) => DeposerAvisPage(
          rendezVousId: id,
          nomMedecin: _nomMedecin(ctx, rdv),
          dateRendezVous: _dateRdv(ctx, rdv),
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
        title: Text(t(ctx, 'rdv.annulerQuestion')),
        content: Text('${_nomMedecin(ctx, rdv)}\n${_dateRdv(ctx, rdv)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t(ctx, 'commun.non')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t(ctx, 'rdv.ouiAnnuler')),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    final token = _auth.accessToken;
    if (token == null) return;
    try {
      await widget.api.annuler(identifiant(rdv['id']), token);
      if (mounted) _message(t(context, 'rdv.annule'));
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      if (mounted) _message(messageApi(context, e));
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
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

  String _dateRdv(BuildContext context, Map<String, dynamic> rdv) =>
      formaterDateIso(langueDe(context), rdv['debut'] as String);

  /// Nom du praticien ; « Médecin » suivi de l'identifiant abrege s'il n'a pu etre resolu.
  String _nomMedecin(BuildContext context, Map<String, dynamic> rdv) {
    final id = identifiant(rdv['medecinId']);
    return _nomsMedecins[id] ?? libelleMedecin(langueDe(context), id);
  }

  String _statut(Map<String, dynamic> rdv) => '${rdv['statut'] ?? ''}';

  /// Annulable tant qu'il n'est ni annule ni honore (un rendez-vous honore est passe).
  bool _annulable(Map<String, dynamic> rdv) =>
      !_statut(rdv).toUpperCase().startsWith('ANNUL') && !estHonore(rdv['statut']);

  /// Action d'un rendez-vous : « Donner mon avis » (ou « Avis donné ») s'il est honore,
  /// « Annuler » s'il est encore annulable, rien sinon.
  Widget? _action(BuildContext context, Map<String, dynamic> rdv) {
    if (estHonore(rdv['statut'])) {
      if (_aDonneSonAvis(rdv)) return Text(t(context, 'rdv.avisDonne'));
      return TextButton(
        onPressed: () => _donnerAvis(rdv),
        child: Text(t(context, 'rdv.donnerAvis')),
      );
    }
    if (_annulable(rdv)) {
      return TextButton(
        onPressed: () => _annuler(rdv),
        child: Text(t(context, 'rdv.annuler')),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'rdv.titre')),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              tooltip: t(context, 'commun.actualiser'),
              onPressed: _charge ? null : _charger,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) return _vueConnexion(context);
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_rdvs.isEmpty) {
      return _vueVide(Icons.event_busy_outlined, t(context, 'rdv.aucun'));
    }
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [for (final rdv in _rdvs) _carteRdv(context, rdv)],
      ),
    );
  }

  /// Une carte de rendez-vous : pastille, medecin, date, pilule de statut, action.
  Widget _carteRdv(BuildContext context, Map<String, dynamic> rdv) {
    final langue = langueDe(context);
    final action = _action(context, rdv);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Tabibi.pastille, shape: BoxShape.circle),
                child: const Icon(Icons.event, color: Tabibi.vert, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nomMedecin(context, rdv),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Tabibi.texte,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(_dateRdv(context, rdv),
                        style: const TextStyle(
                            color: Tabibi.texteDoux, fontSize: 13)),
                  ],
                ),
              ),
              _pileStatut(langue, rdv),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        ],
      ),
    );
  }

  /// Pilule de statut coloree (vert = confirme, ambre = en attente, rouge = annule,
  /// gris = honore/passe).
  Widget _pileStatut(String langue, Map<String, dynamic> rdv) {
    final st = _statut(rdv).toUpperCase();
    Color bg;
    Color fg;
    if (st.startsWith('ANNUL')) {
      bg = Tabibi.rougeClair;
      fg = Tabibi.rouge;
    } else if (estHonore(rdv['statut'])) {
      bg = Tabibi.bg2;
      fg = Tabibi.texte3;
    } else if (st.contains('ATTENTE') || st.contains('PENDING')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else {
      bg = Tabibi.vertTresClair;
      fg = Tabibi.vert;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(libelleStatut(langue, rdv['statut']),
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  /// Etat vide soigne (icone + message centres).
  Widget _vueVide(IconData icone, String texte) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 44, color: Tabibi.texte4),
            const SizedBox(height: 12),
            Text(texte,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Tabibi.texteDoux)),
          ],
        ),
      ),
    );
  }

  Widget _vueConnexion(BuildContext context) {
    return VueConnexion(
      message: _erreur ?? t(context, 'rdv.connectezVous'),
      onSeConnecter: _seConnecter,
    );
  }
}
