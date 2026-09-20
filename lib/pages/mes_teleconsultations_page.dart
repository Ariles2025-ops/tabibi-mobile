import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/langue.dart';
import '../models/teleconsultation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/teleconsultations.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Ouverture d'un lien hors de l'application ; vrai si elle a ete acceptee.
typedef OuvrirLien = Future<bool> Function(Uri lien);

/// Teleconsultations du patient connecte : statut et date de chaque session ; consentement
/// explicite avant la remise du lien de salle, puis bouton « Rejoindre » (navigateur externe).
class MesTeleconsultationsPage extends StatefulWidget {
  const MesTeleconsultationsPage({
    super.key,
    this.api = const ApiService(),
    this.auth,
    this.ouvrirLien,
  });

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  /// Ouverture du lien de salle ; par defaut le navigateur externe (`url_launcher`).
  final OuvrirLien? ouvrirLien;

  @override
  State<MesTeleconsultationsPage> createState() => _MesTeleconsultationsPageState();
}

class _MesTeleconsultationsPageState extends State<MesTeleconsultationsPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Teleconsultation> _teleconsultations = [];
  bool _charge = false;
  String? _erreur;

  /// Identifiant de la teleconsultation dont le consentement est en cours d'envoi.
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
      final teleconsultations = await widget.api.mesTeleconsultations(token);
      if (!mounted) return;
      setState(() {
        _teleconsultations = teleconsultations.map(Teleconsultation.fromJson).toList();
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

  /// Consentement explicite (POST /api/teleconsultations/{id}/consentir) ; la vue renvoyee,
  /// qui porte desormais le lien de salle, remplace l'element.
  Future<void> _consentir(Teleconsultation tele) async {
    if (_enCours != null) return;
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _enCours = tele.id);
    try {
      final consentie = Teleconsultation.fromJson(await widget.api.consentir(tele.id, token));
      if (!mounted) return;
      setState(() {
        _teleconsultations = [
          for (final autre in _teleconsultations) autre.id == tele.id ? consentie : autre,
        ];
      });
      _message(t(context, 'tele.consentementEnregistre'));
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      if (mounted) _message(messageApi(context, e));
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
    } finally {
      if (mounted) setState(() => _enCours = null); // rebatit aussi si la session a expire
    }
  }

  /// Ouvre la salle video dans le navigateur externe ; seuls les liens http(s) sont acceptes.
  Future<void> _rejoindre(Teleconsultation tele) async {
    final lien = tele.lienSalle;
    final uri = lien == null ? null : Uri.tryParse(lien);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      _message(t(context, 'tele.lienInvalide'));
      return;
    }
    final ouvrir = widget.ouvrirLien ?? _ouvrirDansLeNavigateur;
    try {
      final ok = await ouvrir(uri);
      if (!ok && mounted) _message(t(context, 'tele.ouvertureImpossible'));
    } on Exception {
      if (mounted) _message(t(context, 'tele.ouvertureImpossible'));
    }
  }

  Future<bool> _ouvrirDansLeNavigateur(Uri lien) =>
      launchUrl(lien, mode: LaunchMode.externalApplication);

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'tele.titre')),
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
        icone: Icons.videocam_outlined,
        titre: t(context, 'connexion.titreTele'),
        message: _erreur ?? t(context, 'tele.connectezVous'),
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_teleconsultations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_outlined, size: 44, color: Tabibi.texte4),
            const SizedBox(height: 12),
            Text(t(context, 'tele.aucune'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Tabibi.texteDoux)),
          ]),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [for (final tele in _teleconsultations) _carte(context, tele)],
    );
  }

  /// Une carte par session : date et statut, puis consentement, bouton « Rejoindre »
  /// ou texte d'etat selon l'avancement.
  Widget _carte(BuildContext context, Teleconsultation tele) {
    final langue = langueDe(context);
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
                child:
                    const Icon(Icons.videocam_outlined, color: Tabibi.vert, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(dateTeleconsultation(langue, tele),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Tabibi.texte)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Tabibi.vertTresClair,
                    borderRadius: BorderRadius.circular(999)),
                child: Text(libelleStatutTeleconsultation(langue, tele.statut),
                    style: const TextStyle(
                        color: Tabibi.vert,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _zoneAction(context, tele),
        ],
      ),
    );
  }

  Widget _zoneAction(BuildContext context, Teleconsultation tele) {
    if (!tele.aConsenti && estActive(tele)) return _carteConsentement(context, tele);
    if (peutRejoindre(tele)) {
      return FilledButton.icon(
        onPressed: () => _rejoindre(tele),
        icon: const Icon(Icons.video_call_outlined),
        label: Text(t(context, 'tele.rejoindre')),
      );
    }
    return Text(_texteEtat(context, tele), style: Theme.of(context).textTheme.bodyMedium);
  }

  /// Consentement explicite : texte d'information et bouton « Je donne mon consentement ».
  Widget _carteConsentement(BuildContext context, Teleconsultation tele) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final enCours = _enCours == tele.id;
    return Card(
      color: couleurs.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'tele.consentementNecessaire'), style: texte.titleSmall),
            const SizedBox(height: 8),
            Text(t(context, 'tele.consentement'), style: texte.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _enCours == null ? () => _consentir(tele) : null,
              child: enCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t(context, 'tele.consentir')),
            ),
          ],
        ),
      ),
    );
  }

  /// Texte d'etat quand aucune action n'est possible (session terminee, annulee ou lien absent).
  String _texteEtat(BuildContext context, Teleconsultation tele) {
    return switch (tele.statut) {
      'TERMINEE' => t(context, 'tele.terminee'),
      'ANNULEE' => t(context, 'tele.annulee'),
      _ => t(context, 'tele.lienAVenir'),
    };
  }
}
