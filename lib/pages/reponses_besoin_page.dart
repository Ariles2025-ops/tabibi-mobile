import 'package:flutter/material.dart';

import '../models/besoin_medicament.dart';
import '../models/reponse_pharmacie.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/dawini.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Message affiche quand la demande est deja cloturee cote serveur (409).
const String messageDemandeDejaCloturee = 'Cette demande est déjà clôturée.';

/// Reponses des pharmacies a une demande de medicament : nom de la pharmacie,
/// « Disponible » / « Indisponible », prix (« 850 DA ») s'il est indique, commentaire et
/// date ; bouton « Clôturer la demande » tant qu'elle est ouverte.
class ReponsesBesoinPage extends StatefulWidget {
  const ReponsesBesoinPage({
    super.key,
    required this.besoin,
    this.api = const ApiService(),
    this.auth,
  });

  final BesoinMedicament besoin;
  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<ReponsesBesoinPage> createState() => _ReponsesBesoinPageState();
}

class _ReponsesBesoinPageState extends State<ReponsesBesoinPage> {
  late final AuthService _auth = widget.auth ?? session;

  /// Demande affichee ; remplacee par sa copie cloturee apres la cloture.
  late BesoinMedicament _besoin = widget.besoin;
  List<ReponsePharmacie> _reponses = [];
  bool _charge = false;
  bool _cloture = false;
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
      final reponses = await widget.api.reponsesBesoin(_besoin.id, token);
      if (!mounted) return;
      setState(() => _reponses = reponses.map(ReponsePharmacie.fromJson).toList());
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

  /// Cloture la demande apres confirmation (POST /api/dawini/besoins/{id}/cloturer) ;
  /// 409 (deja cloturee) -> [messageDemandeDejaCloturee], la demande est alors marquee
  /// cloturee localement aussi.
  Future<void> _cloturer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer cette demande ?'),
        content: Text('${_besoin.medicament}\nLes pharmacies ne pourront plus y répondre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, clôturer'),
          ),
        ],
      ),
    );
    if (confirme != true || _cloture) return;
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _cloture = true);
    var cloturee = false;
    try {
      await widget.api.cloturerBesoin(_besoin.id, token);
      cloturee = true;
      _message('Demande clôturée.');
    } on ApiException catch (e) {
      if (e.conflit) {
        cloturee = true;
        _message(messageDemandeDejaCloturee);
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message('Session expirée : reconnectez-vous puis réessayez');
      } else {
        _message(e.message);
      }
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) {
        setState(() {
          _cloture = false; // rebatit aussi si la session a expire
          if (cloturee) _besoin = _besoin.cloturer(DateTime.now());
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
        title: const Text('Réponses des pharmacies'),
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
        message: _erreur ?? 'Connectez-vous pour consulter les réponses à votre demande.',
        onSeConnecter: _seConnecter,
      );
    }
    final texte = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _enTete(context),
        const SizedBox(height: 12),
        if (estOuvert(_besoin)) ...[
          _boutonCloture(),
          const SizedBox(height: 12),
        ],
        Text('Réponses', style: texte.titleMedium),
        const SizedBox(height: 8),
        ..._listeReponses(context),
      ],
    );
  }

  /// Rappel de la demande : medicament, lieu et statut, precision, date.
  Widget _enTete(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final precision = _besoin.precision;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_besoin.medicament, style: texte.titleMedium),
            const SizedBox(height: 4),
            Text('${lieuBesoin(_besoin)} · ${libelleStatutBesoin(_besoin.statut)}'),
            if (precision != null) ...[
              const SizedBox(height: 4),
              Text(precision),
            ],
            const SizedBox(height: 4),
            Text(dateBesoin(_besoin), style: texte.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _boutonCloture() {
    return OutlinedButton.icon(
      onPressed: _cloture ? null : _cloturer,
      icon: _cloture
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check_circle_outline),
      label: const Text('Clôturer la demande'),
    );
  }

  List<Widget> _listeReponses(BuildContext context) {
    if (_charge) {
      return const [
        Center(
          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
        ),
      ];
    }
    final erreur = _erreur;
    if (erreur != null) return [VueErreur(message: erreur, onReessayer: _charger)];
    if (_reponses.isEmpty) return const [Text('Aucune réponse pour le moment.')];
    return [for (final r in _reponses) _carte(context, r)];
  }

  /// Une carte par reponse : pharmacie, disponibilite (et prix), commentaire, date.
  Widget _carte(BuildContext context, ReponsePharmacie r) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final prix = formaterPrix(r.prixDa);
    final commentaire = r.commentaire;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                r.disponible ? Icons.check_circle : Icons.cancel_outlined,
                color: r.disponible ? couleurs.primary : couleurs.error,
              ),
              title: Text(r.nomPharmacie),
              subtitle: Text(libelleDisponibilite(r.disponible)),
              trailing: prix == null ? null : Text(prix, style: texte.titleMedium),
            ),
            if (commentaire != null) ...[
              const SizedBox(height: 4),
              Text(commentaire),
            ],
            const SizedBox(height: 8),
            Text(dateReponse(r), style: texte.bodySmall),
          ],
        ),
      ),
    );
  }
}
