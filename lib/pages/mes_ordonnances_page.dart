import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/identifiants.dart';
import '../utils/libelles.dart';
import '../utils/ordonnances.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'detail_ordonnance_page.dart';

/// Ordonnances du patient connecte : date d'emission, code et statut ; le detail au toucher.
class MesOrdonnancesPage extends StatefulWidget {
  const MesOrdonnancesPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<MesOrdonnancesPage> createState() => _MesOrdonnancesPageState();
}

class _MesOrdonnancesPageState extends State<MesOrdonnancesPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _ordonnances = [];
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
      final ordonnances = await widget.api.mesOrdonnances(token);
      if (!mounted) return;
      setState(() => _ordonnances = trierParEmission(ordonnances));
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

  /// Ouvre le detail de l'ordonnance (identifiant UUID en texte) ; rien sans identifiant.
  Future<void> _ouvrirDetail(Map<String, dynamic> ordonnance) async {
    final id = identifiant(ordonnance['id']);
    if (id.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailOrdonnancePage(ordonnanceId: id, api: widget.api, auth: _auth),
      ),
    );
    if (mounted) setState(() {}); // la session a pu expirer sur le detail
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes ordonnances'),
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
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ?? 'Connectez-vous pour consulter vos ordonnances.',
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_ordonnances.isEmpty) return const Center(child: Text('Aucune ordonnance.'));
    return ListView.separated(
      itemCount: _ordonnances.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final o = _ordonnances[i];
        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text('Emise le ${dateEmission(o)}'),
          subtitle: Text('Code ${o['codeVerification'] ?? '-'} · ${libelleStatut(o['statut'])}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _ouvrirDetail(o),
        );
      },
    );
  }
}
