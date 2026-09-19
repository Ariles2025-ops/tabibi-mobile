import 'package:flutter/material.dart';

import '../models/inscription_attente.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/identifiants.dart';
import '../utils/liste_attente.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Message affiche apres le retrait d'une liste d'attente.
const String messageRetrait = "Retrait de la liste d'attente effectué.";

/// Listes d'attente du patient connecte : une carte par inscription avec le praticien (nom
/// via `GET /api/medecins/{id}`, ou « Médecin » et l'identifiant abrege) et la date
/// d'inscription ; bouton « Me retirer » avec confirmation.
class MesListesAttentePage extends StatefulWidget {
  const MesListesAttentePage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<MesListesAttentePage> createState() => _MesListesAttentePageState();
}

class _MesListesAttentePageState extends State<MesListesAttentePage> {
  late final AuthService _auth = widget.auth ?? session;
  List<InscriptionAttente> _inscriptions = [];

  /// Noms des praticiens deja resolus, par identifiant (texte).
  final Map<String, String> _nomsMedecins = {};
  bool _charge = false;
  String? _erreur;

  /// Identifiant (texte) de l'inscription en cours de retrait (boutons desactives).
  String? _enCours;

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
      _message('Connexion annulée');
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
      final inscriptions = await widget.api.mesInscriptionsAttente(token);
      final triees = trierParInscription(inscriptions.map(InscriptionAttente.fromJson).toList());
      await _chargerNomsMedecins(triees);
      if (!mounted) return;
      setState(() => _inscriptions = triees);
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

  /// Noms des praticiens via la fiche publique (`GET /api/medecins/{id}`, identifiant UUID en
  /// texte) ; un echec n'empeche pas l'affichage, « Médecin » et l'identifiant abrege sont
  /// alors montres a la place.
  Future<void> _chargerNomsMedecins(List<InscriptionAttente> inscriptions) async {
    for (final medecinId in inscriptions.map((i) => i.medecinId).toSet()) {
      if (medecinId.isEmpty || _nomsMedecins.containsKey(medecinId)) continue;
      try {
        final Object? nom = (await widget.api.medecin(medecinId))['nomComplet'];
        if (nom is String && nom.isNotEmpty) _nomsMedecins[medecinId] = nom;
      } on Exception {
        // Fiche indisponible : libelle de repli ([libelleMedecin]).
      }
    }
  }

  String _nomMedecin(InscriptionAttente i) =>
      _nomsMedecins[i.medecinId] ?? libelleMedecin(i.medecinId);

  /// Retire l'inscription apres confirmation (POST /api/liste-attente/{id}/retirer) ; une
  /// inscription deja disparue cote serveur (404) est aussi retiree de la liste.
  Future<void> _retirer(InscriptionAttente i) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Vous retirer de cette liste d'attente ?"),
        content: Text('${_nomMedecin(i)}\nVous ne serez plus notifié des créneaux libérés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, me retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || _enCours != null) return;
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _enCours = i.id);
    var retiree = false;
    try {
      await widget.api.retirerListeAttente(i.id, token);
      retiree = true;
      _message(messageRetrait);
    } on ApiException catch (e) {
      if (e.introuvable) {
        retiree = true; // deja retiree cote serveur
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
      }
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) {
        setState(() {
          _enCours = null; // rebatit aussi si la session a expire
          if (retiree) _inscriptions = _inscriptions.where((a) => a.id != i.id).toList();
        });
      }
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes listes d'attente"),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              tooltip: 'Actualiser',
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
        message: _erreur ?? "Connectez-vous pour consulter vos listes d'attente.",
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_inscriptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Aucune inscription sur une liste d'attente. Inscrivez-vous depuis la fiche d'un "
            "médecin dont aucun créneau n'est disponible : vous serez notifié dès qu'un "
            'créneau se libère.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final i in _inscriptions) _carte(context, i)],
    );
  }

  /// Une carte par inscription : praticien, date d'inscription et bouton « Me retirer ».
  Widget _carte(BuildContext context, InscriptionAttente i) {
    final enCours = _enCours == i.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.hourglass_top_outlined),
        title: Text(_nomMedecin(i)),
        subtitle: Text(dateInscription(i)),
        trailing: enCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _enCours == null ? () => _retirer(i) : null,
                child: const Text('Me retirer'),
              ),
      ),
    );
  }
}
