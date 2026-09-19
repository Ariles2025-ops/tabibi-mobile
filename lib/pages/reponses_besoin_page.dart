import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/besoin_medicament.dart';
import '../models/reponse_pharmacie.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/dawini.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

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
      final reponses = await widget.api.reponsesBesoin(_besoin.id, token);
      if (!mounted) return;
      setState(() => _reponses = reponses.map(ReponsePharmacie.fromJson).toList());
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

  /// Cloture la demande apres confirmation (POST /api/dawini/besoins/{id}/cloturer) ;
  /// 409 (deja cloturee) -> « reponses.dejaCloturee », la demande est alors marquee
  /// cloturee localement aussi.
  Future<void> _cloturer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(ctx, 'reponses.cloturerQuestion')),
        content: Text(t(ctx, 'reponses.cloturerDetail', params: {
          'medicament': _besoin.medicament,
        })),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t(ctx, 'commun.non')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t(ctx, 'reponses.ouiCloturer')),
          ),
        ],
      ),
    );
    if (confirme != true || _cloture || !mounted) return;
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _cloture = true);
    var cloturee = false;
    try {
      await widget.api.cloturerBesoin(_besoin.id, token);
      cloturee = true;
      if (mounted) _message(t(context, 'reponses.cloturee'));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.conflit) {
        cloturee = true;
        _message(t(context, 'reponses.dejaCloturee'));
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message(t(context, 'commun.sessionExpiree'));
      } else {
        _message(messageApi(context, e));
      }
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
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
        title: Text(t(context, 'reponses.titre')),
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
        message: _erreur ?? t(context, 'reponses.connectezVous'),
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
          _boutonCloture(context),
          const SizedBox(height: 12),
        ],
        Text(t(context, 'reponses.section'), style: texte.titleMedium),
        const SizedBox(height: 8),
        ..._listeReponses(context),
      ],
    );
  }

  /// Rappel de la demande : medicament, lieu et statut, precision, date.
  Widget _enTete(BuildContext context) {
    final langue = langueDe(context);
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
            Text(t(context, 'dawini.lieuStatut', params: {
              'lieu': lieuBesoin(langue, _besoin),
              'statut': libelleStatutBesoin(langue, _besoin.statut),
            })),
            if (precision != null) ...[
              const SizedBox(height: 4),
              Text(precision),
            ],
            const SizedBox(height: 4),
            Text(dateBesoin(langue, _besoin), style: texte.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _boutonCloture(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _cloture ? null : _cloturer,
      icon: _cloture
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check_circle_outline),
      label: Text(t(context, 'reponses.cloturer')),
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
    if (_reponses.isEmpty) return [Text(t(context, 'reponses.aucune'))];
    return [for (final r in _reponses) _carte(context, r)];
  }

  /// Une carte par reponse : pharmacie, disponibilite (et prix), commentaire, date.
  Widget _carte(BuildContext context, ReponsePharmacie r) {
    final langue = langueDe(context);
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final prix = formaterPrix(langue, r.prixDa);
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
              subtitle: Text(libelleDisponibilite(langue, r.disponible)),
              trailing: prix == null ? null : Text(prix, style: texte.titleMedium),
            ),
            if (commentaire != null) ...[
              const SizedBox(height: 4),
              Text(commentaire),
            ],
            const SizedBox(height: 8),
            Text(dateReponse(langue, r), style: texte.bodySmall),
          ],
        ),
      ),
    );
  }
}
