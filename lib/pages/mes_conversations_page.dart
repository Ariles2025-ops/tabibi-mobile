import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/identifiants.dart';
import '../utils/messagerie.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'conversation_page.dart';

/// Conversations du patient connecte avec ses praticiens : nom du praticien (ou « Médecin »
/// et son identifiant abrege si sa fiche est indisponible), date du dernier message et
/// pastille « n non lus » ; un toucher ouvre le fil de messages.
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
      _message(t(context, 'commun.connexionAnnulee'));
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
      setState(() => _erreur = messageApi(context, e));
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageApi(context, e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _rafraichir() => _charger(discret: true);

  /// Noms des praticiens via la fiche publique de l'annuaire (`GET /api/medecins/{id}`,
  /// identifiant UUID en texte, toujours tente) ; un echec n'empeche pas l'affichage,
  /// « Médecin » et l'identifiant abrege sont alors montres a la place.
  Future<void> _chargerNomsMedecins(List<Conversation> conversations) async {
    for (final medecinId in conversations.map((c) => c.medecinId).toSet()) {
      if (medecinId.isEmpty || _nomsMedecins.containsKey(medecinId)) continue;
      try {
        final Object? nom = (await widget.api.medecin(medecinId))['nomComplet'];
        if (nom is String && nom.isNotEmpty) _nomsMedecins[medecinId] = nom;
      } on Exception {
        // Fiche indisponible : libelle de repli ([libelleMedecin]).
      }
    }
  }

  String _nomMedecin(BuildContext context, Conversation c) =>
      _nomsMedecins[c.medecinId] ?? libelleMedecin(langueDe(context), c.medecinId);

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
        title: Text(t(context, 'messagerie.titre')),
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
        icone: Icons.mail_outline,
        titre: 'Vos messages',
        message: _erreur ?? t(context, 'messagerie.connectezVous'),
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t(context, 'messagerie.aucune'), textAlign: TextAlign.center),
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
    final langue = langueDe(context);
    final nonLus = c.nonLus > 0;
    return ListTile(
      leading: Icon(nonLus ? Icons.mark_chat_unread_outlined : Icons.chat_bubble_outline),
      title: Text(
        _nomMedecin(context, c),
        style: nonLus ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(libelleActivite(langue, c)),
      trailing: nonLus
          ? _pastille(context, libelleNonLus(langue, c.nonLus))
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
