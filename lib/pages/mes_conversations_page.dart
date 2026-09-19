import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/messagerie.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'conversation_page.dart';

/// Conversations du patient connecte avec ses praticiens : nom du praticien (ou son
/// identifiant si sa fiche est indisponible), date du dernier message et pastille
/// « n non lus » ; un toucher ouvre le fil de messages.
class MesConversationsPage extends StatefulWidget {
  const MesConversationsPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<MesConversationsPage> createState() => _MesConversationsPageState();
}

class _MesConversationsPageState extends State<MesConversationsPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Conversation> _conversations = [];

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
      _message('Connexion annulée');
    }
  }

  /// Charge (ou recharge) les conversations ; [discret] evite l'indicateur plein ecran,
  /// « tirer pour rafraichir » affichant deja le sien.
  Future<void> _charger({bool discret = false}) async {
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() {
      _charge = !discret;
      _erreur = null;
    });
    try {
      final conversations = await widget.api.mesConversations(token);
      final triees = trierParActivite(conversations.map(Conversation.fromJson).toList());
      await _chargerNomsMedecins(triees);
      if (!mounted) return;
      setState(() => _conversations = triees);
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

  Future<void> _rafraichir() => _charger(discret: true);

  /// Noms des praticiens via la fiche publique de l'annuaire (identifiants numeriques) ;
  /// un echec n'empeche pas l'affichage, l'identifiant est alors montre a la place.
  Future<void> _chargerNomsMedecins(List<Conversation> conversations) async {
    for (final medecinId in conversations.map((c) => c.medecinId).toSet()) {
      if (_nomsMedecins.containsKey(medecinId)) continue;
      final id = int.tryParse(medecinId);
      if (id == null) continue;
      try {
        final Object? nom = (await widget.api.medecin(id))['nomComplet'];
        if (nom is String && nom.isNotEmpty) _nomsMedecins[medecinId] = nom;
      } on Exception {
        // Fiche indisponible : l'identifiant sera affiche a la place.
      }
    }
  }

  String _nomMedecin(Conversation c) => _nomsMedecins[c.medecinId] ?? 'Médecin n° ${c.medecinId}';

  /// Ouvre le fil ; au retour, les non lus ont pu changer (la lecture les marque lus).
  Future<void> _ouvrir(Conversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationPage(
          conversation: c,
          nomMedecin: _nomsMedecins[c.medecinId],
          api: widget.api,
          auth: _auth,
        ),
      ),
    );
    if (!mounted) return;
    if (_auth.estConnecte) {
      await _charger(discret: true);
    } else {
      setState(() {}); // la session a expire sur le fil
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
        title: const Text('Messagerie'),
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
        message: _erreur ?? 'Connectez-vous pour consulter vos conversations.',
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_conversations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune conversation pour le moment. Ouvrez-en une depuis la fiche de votre médecin.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _tuile(context, _conversations[i]),
      ),
    );
  }

  /// Praticien (en gras s'il reste des non lus), date du dernier message et pastille.
  Widget _tuile(BuildContext context, Conversation c) {
    final nonLus = c.nonLus > 0;
    return ListTile(
      leading: Icon(nonLus ? Icons.mark_chat_unread_outlined : Icons.chat_bubble_outline),
      title: Text(
        _nomMedecin(c),
        style: nonLus ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(libelleActivite(c)),
      trailing: nonLus
          ? _pastille(context, libelleNonLus(c.nonLus))
          : const Icon(Icons.chevron_right),
      onTap: () => _ouvrir(c),
    );
  }

  /// Pastille textuelle « n non lus ».
  Widget _pastille(BuildContext context, String texte) {
    final couleurs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleurs.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texte,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: couleurs.onPrimary),
      ),
    );
  }
}
