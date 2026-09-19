import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/avis.dart';
import '../widgets/vue_connexion.dart';

/// Message affiche quand un avis existe deja pour le rendez-vous (409).
const String messageAvisDejaDonne = 'Vous avez déjà donné votre avis pour ce rendez-vous.';

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

  final int rendezVousId;

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
    if (!ok) _message('Connexion annulée');
    setState(() {});
  }

  /// Envoie la note et le commentaire (POST /api/avis) ; 409 -> [messageAvisDejaDonne],
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
      if (e.conflit) {
        _message(messageAvisDejaDonne);
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message('Session expirée : reconnectez-vous puis réessayez');
      } else {
        _message(e.message);
      }
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
    }
    if (!depose || !mounted) return;
    _message('Merci pour votre avis.');
    Navigator.of(context).pop(true);
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon avis')),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: 'Connectez-vous pour donner votre avis.',
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
            title: Text(nomMedecin ?? 'Rendez-vous honoré'),
            subtitle: dateRendezVous == null ? null : Text(dateRendezVous),
          ),
        const SizedBox(height: 8),
        Text('Votre note', style: texte.titleMedium),
        const SizedBox(height: 4),
        Text('1 = insatisfait, 5 = excellent', style: texte.bodySmall),
        const SizedBox(height: 8),
        _choixNote(),
        const SizedBox(height: 24),
        TextField(
          controller: _commentaire,
          minLines: 3,
          maxLines: 6,
          maxLength: longueurMaxCommentaire,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Commentaire (facultatif)',
            hintText: 'Accueil, écoute, explications...',
            border: OutlineInputBorder(),
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
              : const Text('Envoyer mon avis'),
        ),
        const SizedBox(height: 8),
        Text(
          'Votre avis est publié anonymement sur la fiche du praticien.',
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
