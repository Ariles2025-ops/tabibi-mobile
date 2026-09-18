import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/dates.dart';
import '../widgets/vue_erreur.dart';

/// Fiche d'un praticien : informations et creneaux reservables.
class FicheMedecinPage extends StatefulWidget {
  const FicheMedecinPage({
    super.key,
    required this.medecinId,
    this.api = const ApiService(),
    this.auth,
  });

  final int medecinId;
  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<FicheMedecinPage> createState() => _FicheMedecinPageState();
}

class _FicheMedecinPageState extends State<FicheMedecinPage> {
  late final AuthService _auth = widget.auth ?? session;
  Map<String, dynamic>? _medecin;
  List<Map<String, dynamic>> _creneaux = [];
  bool _charge = true;
  String? _erreur;

  /// Identifiant du creneau en cours de reservation (boutons desactives).
  int? _enCours;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final medecin = await widget.api.medecin(widget.medecinId);
      final creneaux = await widget.api.creneaux(widget.medecinId);
      if (!mounted) return;
      setState(() {
        _medecin = medecin;
        _creneaux = creneaux.where((c) => c['disponible'] != false).toList();
      });
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _reserver(Map<String, dynamic> creneau) async {
    final creneauId = creneau['id'] as int;
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message('Connexion necessaire pour reserver');
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _enCours = creneauId);
    try {
      await widget.api.reserverCreneau(creneauId, token);
      if (!mounted) return;
      setState(() => _creneaux.removeWhere((c) => c['id'] == creneauId));
      _message('Rendez-vous confirme');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.conflit) {
        // Pris entre-temps par un autre patient : il n'est plus reservable.
        setState(() => _creneaux.removeWhere((c) => c['id'] == creneauId));
        _message("Ce creneau vient d'etre pris");
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message('Session expiree : reconnectez-vous puis reessayez');
      } else {
        _message(e.message);
      }
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche medecin')),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    final medecin = _medecin;
    if (erreur != null || medecin == null) {
      return VueErreur(message: erreur ?? 'Medecin introuvable', onReessayer: _charger);
    }
    final texte = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(medecin['nomComplet'] as String, style: texte.titleLarge),
        const SizedBox(height: 4),
        Text('${medecin['specialiteFr']} · ${medecin['ville']} (${medecin['wilayaFr']})'),
        const SizedBox(height: 24),
        Text('Creneaux disponibles', style: texte.titleMedium),
        const SizedBox(height: 8),
        if (_creneaux.isEmpty) const Text('Aucun creneau disponible pour le moment.'),
        for (final c in _creneaux) _creneauTile(c),
      ],
    );
  }

  Widget _creneauTile(Map<String, dynamic> creneau) {
    final enCours = _enCours == creneau['id'];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(formaterDateIso(creneau['debut'] as String)),
      subtitle: Text('${creneau['dureeMinutes']} min'),
      trailing: FilledButton(
        onPressed: _enCours == null ? () => _reserver(creneau) : null,
        child: enCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Reserver'),
      ),
    );
  }
}
