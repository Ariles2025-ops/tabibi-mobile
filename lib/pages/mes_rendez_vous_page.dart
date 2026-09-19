import 'package:flutter/material.dart';

import '../models/avis.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
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
      _message('Connexion annulee');
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
        title: const Text('Annuler ce rendez-vous ?'),
        content: Text('${_nomMedecin(rdv)}\n${_dateRdv(rdv)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    final token = _auth.accessToken;
    if (token == null) return;
    try {
      await widget.api.annuler(identifiant(rdv['id']), token);
      _message('Rendez-vous annule');
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

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  String _dateRdv(Map<String, dynamic> rdv) => formaterDateIso(rdv['debut'] as String);

  /// Nom du praticien ; « Médecin » suivi de l'identifiant abrege s'il n'a pu etre resolu.
  String _nomMedecin(Map<String, dynamic> rdv) {
    final id = identifiant(rdv['medecinId']);
    return _nomsMedecins[id] ?? libelleMedecin(id);
  }

  String _statut(Map<String, dynamic> rdv) => '${rdv['statut'] ?? ''}';

  /// « CONFIRME » -> « Confirme », « EN_ATTENTE » -> « En attente ».
  String _libelleStatut(Map<String, dynamic> rdv) => libelleStatut(rdv['statut']);

  /// Annulable tant qu'il n'est ni annule ni honore (un rendez-vous honore est passe).
  bool _annulable(Map<String, dynamic> rdv) =>
      !_statut(rdv).toUpperCase().startsWith('ANNUL') && !estHonore(rdv['statut']);

  /// Action d'un rendez-vous : « Donner mon avis » (ou « Avis donné ») s'il est honore,
  /// « Annuler » s'il est encore annulable, rien sinon.
  Widget? _action(Map<String, dynamic> rdv) {
    if (estHonore(rdv['statut'])) {
      if (_aDonneSonAvis(rdv)) return const Text('Avis donné');
      return TextButton(onPressed: () => _donnerAvis(rdv), child: const Text('Donner mon avis'));
    }
    if (_annulable(rdv)) {
      return TextButton(onPressed: () => _annuler(rdv), child: const Text('Annuler'));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              tooltip: 'Actualiser',
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
    if (_rdvs.isEmpty) return const Center(child: Text('Aucun rendez-vous.'));
    return ListView.separated(
      itemCount: _rdvs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final rdv = _rdvs[i];
        return ListTile(
          leading: const Icon(Icons.event),
          title: Text(_dateRdv(rdv)),
          subtitle: Text('${_nomMedecin(rdv)} · ${_libelleStatut(rdv)}'),
          trailing: _action(rdv),
        );
      },
    );
  }

  Widget _vueConnexion() {
    return VueConnexion(
      message: _erreur ?? 'Connectez-vous pour consulter vos rendez-vous.',
      onSeConnecter: _seConnecter,
    );
  }
}
