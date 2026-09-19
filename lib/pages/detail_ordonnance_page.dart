import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/identifiants.dart';
import '../utils/libelles.dart';
import '../utils/ordonnances.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Enregistrement d'un document sous [nomFichier] puis ouverture hors de l'application ;
/// vrai si une application l'a pris en charge.
typedef EnregistrerEtOuvrir = Future<bool> Function(String nomFichier, Uint8List octets);

/// Message affiche quand le PDF n'a pu etre ecrit ou qu'aucune application ne l'ouvre.
const String messagePdfImpossible =
    "Impossible d'ouvrir le PDF : aucune application ne prend en charge ce document.";

/// Implementation reelle d'[EnregistrerEtOuvrir] : le fichier est ecrit dans le dossier
/// temporaire de l'application (`getTemporaryDirectory`) puis confie a l'application du
/// telephone qui lit les PDF (`OpenFilex.open`).
Future<bool> enregistrerEtOuvrirFichier(String nomFichier, Uint8List octets) async {
  final dossier = await getTemporaryDirectory();
  final fichier = File('${dossier.path}${Platform.pathSeparator}$nomFichier');
  await fichier.writeAsBytes(octets, flush: true);
  final resultat = await OpenFilex.open(fichier.path, type: typePdf);
  return resultat.type == ResultType.done;
}

/// Detail d'une ordonnance du patient connecte : praticien, code de verification, bouton
/// « Ouvrir le PDF » (version imprimable) et une carte par ligne (medicament, posologie, duree).
class DetailOrdonnancePage extends StatefulWidget {
  const DetailOrdonnancePage({
    super.key,
    required this.ordonnanceId,
    this.api = const ApiService(),
    this.auth,
    this.enregistrerEtOuvrir,
  });

  /// Identifiant de l'ordonnance (UUID en texte).
  final String ordonnanceId;
  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  /// Enregistrement et ouverture du PDF ; par defaut [enregistrerEtOuvrirFichier]
  /// (dossier temporaire puis application du telephone), injectable dans les tests.
  final EnregistrerEtOuvrir? enregistrerEtOuvrir;

  @override
  State<DetailOrdonnancePage> createState() => _DetailOrdonnancePageState();
}

class _DetailOrdonnancePageState extends State<DetailOrdonnancePage> {
  late final AuthService _auth = widget.auth ?? session;
  Map<String, dynamic>? _ordonnance;

  /// Nom du praticien resolu via la fiche publique ; « Médecin » et l'identifiant abrege a defaut.
  String _nomMedecin = '';
  bool _charge = false;
  String? _erreur;

  /// Vrai pendant le telechargement et l'ouverture du PDF (bouton desactive).
  bool _pdfEnCours = false;

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
      final ordonnance = await widget.api.ordonnance(widget.ordonnanceId, token);
      final nomMedecin = await _resoudreNomMedecin(ordonnance);
      if (!mounted) return;
      setState(() {
        _ordonnance = ordonnance;
        _nomMedecin = nomMedecin;
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

  /// Nom du praticien (endpoint public, identifiant UUID en texte) ; un echec n'empeche pas
  /// l'affichage : « Médecin » et l'identifiant abrege sont montres a la place.
  Future<String> _resoudreNomMedecin(Map<String, dynamic> ordonnance) async {
    final id = identifiant(ordonnance['medecinId']);
    if (id.isEmpty) return libelleMedecin(id);
    try {
      final Object? nom = (await widget.api.medecin(id))['nomComplet'];
      if (nom is String && nom.isNotEmpty) return nom;
    } on Exception {
      // Fiche indisponible : libelle de repli ci-dessous.
    }
    return libelleMedecin(id);
  }

  Future<void> _copier(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _message('Code copie');
  }

  /// Telecharge la version imprimable (GET /api/ordonnances/{id}/pdf), l'ecrit sous
  /// « ordonnance-<code>.pdf » et l'ouvre avec l'application du telephone ; un echec
  /// d'ecriture ou d'ouverture est signale ([messagePdfImpossible]), une erreur de l'API
  /// affichee telle quelle.
  Future<void> _ouvrirPdf() async {
    final ordonnance = _ordonnance;
    final token = _auth.accessToken;
    if (ordonnance == null || token == null || _pdfEnCours) return;
    setState(() => _pdfEnCours = true);
    try {
      final octets = await widget.api.ordonnancePdf(widget.ordonnanceId, token);
      final ouvrir = widget.enregistrerEtOuvrir ?? enregistrerEtOuvrirFichier;
      var ouvert = false;
      try {
        ouvert = await ouvrir(nomFichierPdf(ordonnance), octets);
      } on Exception {
        ouvert = false; // ecriture impossible ou plateforme sans lecteur
      }
      if (!ouvert) _message(messagePdfImpossible);
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _pdfEnCours = false); // rebatit aussi si la session a expire
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ordonnance')),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ?? 'Connectez-vous pour consulter cette ordonnance.',
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    final ordonnance = _ordonnance;
    if (erreur != null || ordonnance == null) {
      return VueErreur(message: erreur ?? 'Ordonnance introuvable', onReessayer: _charger);
    }
    final texte = Theme.of(context).textTheme;
    final lignes = lignesOrdonnance(ordonnance);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(_nomMedecin),
          subtitle: Text(_sousTitre(ordonnance)),
        ),
        const SizedBox(height: 8),
        _carteCode(context, '${ordonnance['codeVerification'] ?? ''}'),
        const SizedBox(height: 12),
        _boutonPdf(),
        const SizedBox(height: 24),
        Text('Medicaments', style: texte.titleMedium),
        const SizedBox(height: 8),
        if (lignes.isEmpty) const Text('Aucun medicament sur cette ordonnance.'),
        for (final ligne in lignes) _carteLigne(context, ligne),
      ],
    );
  }

  /// « Emise le jeu. 4 dec. 09:00 · Emise » (statut omis s'il est absent).
  String _sousTitre(Map<String, dynamic> ordonnance) {
    final date = 'Emise le ${dateEmission(ordonnance)}';
    final statut = libelleStatut(ordonnance['statut']);
    return statut.isEmpty ? date : '$date · $statut';
  }

  /// Code de verification en grand, selectionnable, avec bouton de copie.
  Widget _carteCode(BuildContext context, String code) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Card(
      color: couleurs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code de verification', style: texte.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: texte.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: couleurs.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copier le code',
                  onPressed: code.isEmpty ? null : () => _copier(code),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'A presenter en pharmacie ; verifiable sans compte via « Verifier une ordonnance ».',
              style: texte.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// « Ouvrir le PDF » : version imprimable (avec QR code) ouverte hors de l'application ;
  /// indicateur pendant le telechargement.
  Widget _boutonPdf() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _pdfEnCours ? null : _ouvrirPdf,
        icon: _pdfEnCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Ouvrir le PDF'),
      ),
    );
  }

  /// Une carte par ligne : medicament, posologie, duree.
  Widget _carteLigne(BuildContext context, Map<String, dynamic> ligne) {
    final texte = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${ligne['medicament'] ?? ''}', style: texte.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Posologie : ${ligne['posologie'] ?? '-'}'),
            const SizedBox(height: 4),
            Text('Duree : ${ligne['duree'] ?? '-'}'),
          ],
        ),
      ),
    );
  }
}
