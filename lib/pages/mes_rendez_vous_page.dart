import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/dates.dart';
import '../widgets/vue_erreur.dart';

/// Rendez-vous du patient connecte, avec annulation.
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

  /// Noms des praticiens deja resolus, par identifiant.
  final Map<int, String> _nomsMedecins = {};
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
      if (!mounted) return;
      setState(() => _rdvs = rdvs);
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

  /// Noms des praticiens (endpoint public) ; un echec n'empeche pas l'affichage.
  Future<void> _chargerNomsMedecins(List<Map<String, dynamic>> rdvs) async {
    for (final id in rdvs.map((r) => r['medecinId'] as int).toSet()) {
      if (_nomsMedecins.containsKey(id)) continue;
      try {
        final m = await widget.api.medecin(id);
        _nomsMedecins[id] = m['nomComplet'] as String;
      } on Exception {
        // Nom indisponible : l'identifiant sera affiche a la place.
      }
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
      await widget.api.annuler(rdv['id'] as int, token);
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

  String _nomMedecin(Map<String, dynamic> rdv) {
    final id = rdv['medecinId'] as int;
    return _nomsMedecins[id] ?? 'Medecin n° $id';
  }

  String _statut(Map<String, dynamic> rdv) => '${rdv['statut'] ?? ''}';

  /// « CONFIRME » -> « Confirme », « EN_ATTENTE » -> « En attente ».
  String _libelleStatut(Map<String, dynamic> rdv) {
    final s = _statut(rdv).replaceAll('_', ' ').toLowerCase();
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  bool _annulable(Map<String, dynamic> rdv) => !_statut(rdv).toUpperCase().startsWith('ANNUL');

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
          trailing: _annulable(rdv)
              ? TextButton(onPressed: () => _annuler(rdv), child: const Text('Annuler'))
              : null,
        );
      },
    );
  }

  Widget _vueConnexion() {
    final erreur = _erreur;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              erreur ?? 'Connectez-vous pour consulter vos rendez-vous.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _seConnecter, child: const Text('Se connecter')),
          ],
        ),
      ),
    );
  }
}
