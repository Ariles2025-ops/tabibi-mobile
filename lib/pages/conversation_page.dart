import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/messagerie.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Longueur maximale d'un message acceptee par l'API.
const int longueurMaxMessage = 2000;

/// Fil d'une conversation avec un praticien : bulles alignees a droite pour mes messages,
/// a gauche pour ceux du praticien, avec leur date ; champ de saisie et bouton « Envoyer »
/// (desactive tant que le message est vide), fil rafraichi apres chaque envoi.
class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversation,
    this.nomMedecin,
    this.api = const ApiService(),
    this.auth,
  });

  final Conversation conversation;

  /// Nom du praticien (titre de l'ecran) ; « Conversation » s'il est inconnu.
  final String? nomMedecin;
  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _saisie = TextEditingController();
  List<Message> _messages = [];
  bool _charge = false;
  bool _envoi = false;
  String? _erreur;

  /// Mon identifiant : sujet du jeton, sinon le patient de la conversation (c'est moi).
  String get _moi => _auth.sujet ?? widget.conversation.patientId;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
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

  /// Charge (ou recharge) le fil ; l'appel marque lus les messages recus.
  /// [discret] evite l'indicateur plein ecran (rafraichissement apres un envoi).
  Future<void> _charger({bool discret = false}) async {
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() {
      _charge = !discret;
      _erreur = null;
    });
    try {
      final messages = await widget.api.messages(widget.conversation.id, token);
      if (!mounted) return;
      setState(() => _messages = messages.map(Message.fromJson).toList());
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

  /// Envoie le message saisi (POST /api/conversations/{id}/messages) puis recharge le fil ;
  /// un 400 (contenu vide ou trop long) est affiche tel quel.
  Future<void> _envoyer() async {
    final contenu = _saisie.text.trim();
    if (contenu.isEmpty || _envoi) return;
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _envoi = true);
    try {
      await widget.api.envoyerMessage(widget.conversation.id, contenu, token);
      if (!mounted) return;
      _saisie.clear();
      await _charger(discret: true);
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
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
        title: Text(widget.nomMedecin ?? 'Conversation'),
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
        message: _erreur ?? 'Connectez-vous pour consulter cette conversation.',
        onSeConnecter: _seConnecter,
      );
    }
    return Column(
      children: [
        Expanded(child: _fil(context)),
        const Divider(height: 1),
        _zoneSaisie(context),
      ],
    );
  }

  Widget _fil(BuildContext context) {
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun message pour le moment. Écrivez le premier.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Liste inversee : le message le plus recent reste visible en bas du fil.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _bulle(context, _messages[_messages.length - 1 - i]),
    );
  }

  /// Bulle d'un message : a droite (couleur primaire) pour les miens, a gauche pour ceux
  /// du praticien ; contenu puis date d'envoi.
  Widget _bulle(BuildContext context, Message m) {
    final deMoi = estDeMoi(m, _moi);
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Align(
      alignment: alignementMessage(m, _moi),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: deMoi ? couleurs.primaryContainer : couleurs.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.contenu),
            const SizedBox(height: 4),
            Text(dateMessage(m), style: texte.bodySmall),
          ],
        ),
      ),
    );
  }

  /// Champ de saisie et bouton « Envoyer », desactive tant que le texte est vide
  /// ou qu'un envoi est en cours.
  Widget _zoneSaisie(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _saisie,
                minLines: 1,
                maxLines: 4,
                maxLength: longueurMaxMessage,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Votre message',
                  counterText: '',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _saisie,
              builder: (_, valeur, __) {
                final vide = valeur.text.trim().isEmpty;
                return FilledButton(
                  onPressed: vide || _envoi ? null : _envoyer,
                  child: _envoi
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Envoyer'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
