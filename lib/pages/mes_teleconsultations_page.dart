import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/teleconsultation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/teleconsultations.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Ouverture d'un lien hors de l'application ; vrai si elle a ete acceptee.
typedef OuvrirLien = Future<bool> Function(Uri lien);

/// Texte du consentement explicite demande avant de remettre le lien de salle.
const String texteConsentement =
    "En rejoignant cette teleconsultation, vous acceptez qu'elle se deroule en video via un "
    "service tiers (Jitsi Meet). Aucun enregistrement n'est realise par Tabibi.";

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
      final teleconsultations = await widget.api.mesTeleconsultations(token);
      if (!mounted) return;
      setState(() {
        _teleconsultations = teleconsultations.map(Teleconsultation.fromJson).toList();
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

  /// Consentement explicite (POST /api/teleconsultations/{id}/consentir) ; la vue renvoyee,
  /// qui porte desormais le lien de salle, remplace l'element.
  Future<void> _consentir(Teleconsultation t) async {
    if (_enCours != null) return;
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _enCours = t.id);
    try {
      final consentie = Teleconsultation.fromJson(await widget.api.consentir(t.id, token));
      if (!mounted) return;
      setState(() {
        _teleconsultations = [
          for (final autre in _teleconsultations) autre.id == t.id ? consentie : autre,
        ];
      });
      _message('Consentement enregistre');
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = null); // rebatit aussi si la session a expire
    }
  }

  /// Ouvre la salle video dans le navigateur externe ; seuls les liens http(s) sont acceptes.
  Future<void> _rejoindre(Teleconsultation t) async {
    final lien = t.lienSalle;
    final uri = lien == null ? null : Uri.tryParse(lien);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      _message('Lien de salle invalide');
      return;
    }
    final ouvrir = widget.ouvrirLien ?? _ouvrirDansLeNavigateur;
    try {
      final ok = await ouvrir(uri);
      if (!ok) _message("Impossible d'ouvrir le lien de la salle");
    } on Exception {
      _message("Impossible d'ouvrir le lien de la salle");
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
        title: const Text('Mes teleconsultations'),
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
        message: _erreur ?? 'Connectez-vous pour consulter vos teleconsultations.',
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_teleconsultations.isEmpty) {
      return const Center(child: Text('Aucune teleconsultation pour le moment.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final t in _teleconsultations) _carte(context, t)],
    );
  }

  /// Une carte par session : date et statut, puis consentement, bouton « Rejoindre »
  /// ou texte d'etat selon l'avancement.
  Widget _carte(BuildContext context, Teleconsultation t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.videocam_outlined),
              title: Text(dateTeleconsultation(t)),
              subtitle: Text(libelleStatutTeleconsultation(t.statut)),
            ),
            const SizedBox(height: 8),
            _zoneAction(context, t),
          ],
        ),
      ),
    );
  }

  Widget _zoneAction(BuildContext context, Teleconsultation t) {
    if (!t.aConsenti && estActive(t)) return _carteConsentement(context, t);
    if (peutRejoindre(t)) {
      return FilledButton.icon(
        onPressed: () => _rejoindre(t),
        icon: const Icon(Icons.video_call_outlined),
        label: const Text('Rejoindre la teleconsultation'),
      );
    }
    return Text(_texteEtat(t), style: Theme.of(context).textTheme.bodyMedium);
  }

  /// Consentement explicite : texte d'information et bouton « Je donne mon consentement ».
  Widget _carteConsentement(BuildContext context, Teleconsultation t) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final enCours = _enCours == t.id;
    return Card(
      color: couleurs.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Votre consentement est necessaire', style: texte.titleSmall),
            const SizedBox(height: 8),
            Text(texteConsentement, style: texte.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _enCours == null ? () => _consentir(t) : null,
              child: enCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Je donne mon consentement'),
            ),
          ],
        ),
      ),
    );
  }

  /// Texte d'etat quand aucune action n'est possible (session terminee, annulee ou lien absent).
  String _texteEtat(Teleconsultation t) {
    return switch (t.statut) {
      'TERMINEE' => 'Cette teleconsultation est terminee.',
      'ANNULEE' => 'Cette teleconsultation a ete annulee.',
      _ => 'Le lien de la salle sera disponible prochainement.',
    };
  }
}
