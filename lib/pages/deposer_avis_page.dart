import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/avis.dart';
import '../widgets/vue_connexion.dart';

/// Longueur maximale du commentaire acceptee par l'API.
const int longueurMaxCommentaire = 500;

/// Depot d'un avis apres un rendez-vous honore : note obligatoire de 1 a 5 (cinq boutons),
/// commentaire facultatif, puis « Envoyer mon avis » (POST /api/avis). L'ecran se ferme en
/// renvoyant `true` une fois l'avis depose.
class DeposerAvisPage extends StatefulWidget {
  const DeposerAvisPage({
    super.key,
    required this.rendezVousId,
    this.nomMedecin,
    this.dateRendezVous,
    this.api = const ApiService(),
    this.auth,
  });

  /// Identifiant du rendez-vous honore (UUID en texte), envoye tel quel dans le corps JSON.
  final String rendezVousId;

  /// Praticien et date du rendez-vous, rappeles en tete de l'ecran s'ils sont connus.
  final String? nomMedecin;
  final String? dateRendezVous;
  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<DeposerAvisPage> createState() => _DeposerAvisPageState();
}

class _DeposerAvisPageState extends State<DeposerAvisPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _commentaire = TextEditingController();

  /// Note choisie ; null tant que le patient n'a rien selectionne.
  int? _note;
  bool _envoi = false;

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final ok = await _auth.seConnecter();
    if (!mounted) return;
    if (!ok) _message(t(context, 'commun.connexionAnnulee'));
    setState(() {});
  }

  /// Envoie la note et le commentaire (POST /api/avis) ; 409 -> « avis.dejaDonne »,
  /// autres erreurs affichees telles quelles ; succes -> message puis fermeture.
  Future<void> _envoyer() async {
    final note = _note;
    if (!noteValide(note) || _envoi) return;
    final token = _auth.accessToken;
    if (token == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoi = true);
    var depose = false;
    try {
      final commentaire = _commentaire.text.trim();
      await widget.api.deposerAvis(
        widget.rendezVousId,
        note!,
        commentaire.isEmpty ? null : commentaire,
        token,
      );
      depose = true;
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.conflit) {
        _message(t(context, 'avis.dejaDonne'));
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message(t(context, 'commun.sessionExpiree'));
      } else {
        _message(messageApi(context, e));
      }
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
    }
    if (!depose || !mounted) return;
    _message(t(context, 'avis.merci'));
    Navigator.of(context).pop(true);
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'avis.titre'))),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: t(context, 'avis.connectezVous'),
        onSeConnecter: _seConnecter,
      );
    }
    final texte = Theme.of(context).textTheme;
    final nomMedecin = widget.nomMedecin;
    final dateRendezVous = widget.dateRendezVous;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (nomMedecin != null || dateRendezVous != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available_outlined),
            title: Text(nomMedecin ?? t(context, 'avis.rdvHonore')),
            subtitle: dateRendezVous == null ? null : Text(dateRendezVous),
          ),
        const SizedBox(height: 8),
        Text(t(context, 'avis.votreNote'), style: texte.titleMedium),
        const SizedBox(height: 4),
        Text(t(context, 'avis.echelle'), style: texte.bodySmall),
        const SizedBox(height: 8),
        _choixNote(),
        const SizedBox(height: 24),
        TextField(
          controller: _commentaire,
          minLines: 3,
          maxLines: 6,
          maxLength: longueurMaxCommentaire,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: t(context, 'avis.commentaire'),
            hintText: t(context, 'avis.commentaireIndice'),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: noteValide(_note) && !_envoi ? _envoyer : null,
          child: _envoi
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t(context, 'avis.envoyer')),
        ),
        const SizedBox(height: 8),
        Text(
          t(context, 'avis.anonyme'),
          style: texte.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Cinq boutons « 1 » a « 5 » ; un seul est selectionne.
  Widget _choixNote() {
    return Wrap(
      spacing: 8,
      children: [
        for (var note = noteMinimale; note <= noteMaximale; note++)
          ChoiceChip(
            label: Text('$note'),
            selected: _note == note,
            onSelected: _envoi ? null : (_) => setState(() => _note = note),
          ),
      ],
    );
  }
}
