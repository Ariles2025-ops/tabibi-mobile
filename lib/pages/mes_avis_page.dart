import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/avis.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/avis.dart';
import '../utils/identifiants.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Avis deposes par le patient connecte : praticien, note, statut, commentaire et date.
class MesAvisPage extends StatefulWidget {
  const MesAvisPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<MesAvisPage> createState() => _MesAvisPageState();
}

class _MesAvisPageState extends State<MesAvisPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Avis> _avis = [];

  /// Noms des praticiens deja resolus, par identifiant (texte).
  final Map<String, String> _nomsMedecins = {};
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
      final avis = (await widget.api.mesAvis(token)).map(Avis.fromJson).toList();
      await _chargerNomsMedecins(avis);
      if (!mounted) return;
      setState(() => _avis = avis);
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

  /// Noms des praticiens via la fiche publique (`GET /api/medecins/{id}`, identifiant UUID en
  /// texte) ; un echec n'empeche pas l'affichage, « Médecin » et l'identifiant abrege sont
  /// alors montres a la place.
  Future<void> _chargerNomsMedecins(List<Avis> avis) async {
    for (final medecinId in avis.map((a) => a.medecinId).toSet()) {
      if (medecinId.isEmpty || _nomsMedecins.containsKey(medecinId)) continue;
      try {
        final Object? nom = (await widget.api.medecin(medecinId))['nomComplet'];
        if (nom is String && nom.isNotEmpty) _nomsMedecins[medecinId] = nom;
      } on Exception {
        // Fiche indisponible : libelle de repli ([libelleMedecin]).
      }
    }
  }

  String _nomMedecin(BuildContext context, Avis a) =>
      _nomsMedecins[a.medecinId] ?? libelleMedecin(langueDe(context), a.medecinId);

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'mesAvis.titre')),
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
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ?? t(context, 'mesAvis.connectezVous'),
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_avis.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t(context, 'mesAvis.aucun'), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final a in _avis) _carte(context, a)],
    );
  }

  /// Une carte par avis : praticien, « 4 / 5 · Publié », commentaire puis date de depot.
  Widget _carte(BuildContext context, Avis a) {
    final langue = langueDe(context);
    final texte = Theme.of(context).textTheme;
    final commentaire = a.commentaire;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline),
              title: Text(_nomMedecin(context, a)),
              subtitle: Text(t(context, 'mesAvis.noteStatut', params: {
                'note': formaterNote(langue, a.note),
                'statut': libelleStatutAvis(langue, a.statut),
              })),
            ),
            if (commentaire != null) ...[
              const SizedBox(height: 4),
              Text(commentaire),
            ],
            const SizedBox(height: 8),
            Text(
              t(context, 'mesAvis.deposeLe', params: {'date': dateAvis(langue, a)}),
              style: texte.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
