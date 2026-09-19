import 'package:flutter/material.dart';

import '../models/avis.dart';
import '../models/conversation.dart';
import '../models/synthese_avis.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/avis.dart';
import '../utils/dates.dart';
import '../utils/identifiants.dart';
import '../widgets/vue_erreur.dart';
import 'conversation_page.dart';

/// Message affiche quand le patient n'a aucun rendez-vous avec le praticien (403).
const String messageConversationRefusee =
    'Vous devez avoir un rendez-vous avec ce médecin pour lui écrire.';

/// Nombre de derniers avis affiches sur la fiche.
const int nombreAvisAffiches = 5;

/// Fiche d'un praticien : informations, moyenne des avis, ouverture d'une conversation,
/// creneaux reservables et derniers avis anonymes.
class FicheMedecinPage extends StatefulWidget {
  const FicheMedecinPage({
    super.key,
    required this.medecinId,
    this.api = const ApiService(),
    this.auth,
  });

  /// Identifiant du praticien (UUID en texte, tel que renvoye par l'annuaire).
  final String medecinId;
  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<FicheMedecinPage> createState() => _FicheMedecinPageState();
}

class _FicheMedecinPageState extends State<FicheMedecinPage> {
  late final AuthService _auth = widget.auth ?? session;
  Map<String, dynamic>? _medecin;
  List<Map<String, dynamic>> _creneaux = [];

  /// Synthese publique des avis ; null tant qu'elle est indisponible.
  SyntheseAvis? _avis;
  bool _charge = true;
  String? _erreur;

  /// Identifiant (texte) du creneau en cours de reservation (boutons desactives).
  String? _enCours;

  /// Vrai pendant l'ouverture de la conversation (bouton desactive).
  bool _conversationEnCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final medecin = await widget.api.medecin(widget.medecinId);
      final creneaux = await widget.api.creneaux(widget.medecinId);
      final avis = await _chargerAvis();
      if (!mounted) return;
      setState(() {
        _medecin = medecin;
        _creneaux = creneaux.where((c) => c['disponible'] != false).toList();
        _avis = avis;
      });
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Synthese publique des avis (GET /api/medecins/{id}/avis) ; un echec n'empeche pas
  /// l'affichage de la fiche, la section indique alors que les avis sont indisponibles.
  Future<SyntheseAvis?> _chargerAvis() async {
    try {
      return SyntheseAvis.fromJson(await widget.api.avisDuMedecin(widget.medecinId));
    } on Exception {
      return null;
    }
  }

  Future<void> _reserver(Map<String, dynamic> creneau) async {
    final creneauId = identifiant(creneau['id']);
    if (creneauId.isEmpty) return;
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message('Connexion necessaire pour reserver');
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _enCours = creneauId);
    try {
      await widget.api.reserverCreneau(creneauId, token);
      if (!mounted) return;
      setState(() => _retirerCreneau(creneauId));
      _message('Rendez-vous confirme');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.conflit) {
        // Pris entre-temps par un autre patient : il n'est plus reservable.
        setState(() => _retirerCreneau(creneauId));
        _message("Ce creneau vient d'etre pris");
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message('Session expiree : reconnectez-vous puis reessayez');
      } else {
        _message(e.message);
      }
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  /// Retire de la liste le creneau d'identifiant [creneauId] (compare en texte).
  void _retirerCreneau(String creneauId) {
    _creneaux.removeWhere((c) => identifiant(c['id']) == creneauId);
  }

  /// Ouvre (ou retrouve) la conversation avec ce praticien (POST /api/conversations),
  /// connexion Keycloak a la volee si necessaire, puis affiche le fil ; 403 si le patient
  /// n'a aucun rendez-vous avec lui ([messageConversationRefusee]).
  Future<void> _ouvrirConversation() async {
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message('Connexion nécessaire pour écrire au médecin');
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _conversationEnCours = true);
    Conversation? conversation;
    try {
      conversation = Conversation.fromJson(
        await widget.api.ouvrirConversation(widget.medecinId, token),
      );
    } on ApiException catch (e) {
      if (e.interdit) {
        _message(messageConversationRefusee);
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message('Session expiree : reconnectez-vous puis reessayez');
      } else {
        _message(e.message);
      }
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _conversationEnCours = false);
    }
    final ouverte = conversation;
    if (ouverte == null || !mounted) return;
    final Object? nom = _medecin?['nomComplet'];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationPage(
          conversation: ouverte,
          nomMedecin: nom is String && nom.isNotEmpty ? nom : null,
          api: widget.api,
          auth: _auth,
        ),
      ),
    );
    if (mounted) setState(() {}); // la session a pu expirer sur le fil
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche medecin')),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    final medecin = _medecin;
    if (erreur != null || medecin == null) {
      return VueErreur(message: erreur ?? 'Medecin introuvable', onReessayer: _charger);
    }
    final texte = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(medecin['nomComplet'] as String, style: texte.titleLarge),
        const SizedBox(height: 4),
        Text('${medecin['specialiteFr']} · ${medecin['ville']} (${medecin['wilayaFr']})'),
        const SizedBox(height: 8),
        _ligneMoyenne(context),
        const SizedBox(height: 16),
        _boutonConversation(),
        const SizedBox(height: 24),
        Text('Creneaux disponibles', style: texte.titleMedium),
        const SizedBox(height: 8),
        if (_creneaux.isEmpty) const Text('Aucun creneau disponible pour le moment.'),
        for (final c in _creneaux) _creneauTile(c),
        const SizedBox(height: 24),
        Text('Avis des patients', style: texte.titleMedium),
        const SizedBox(height: 8),
        ..._derniersAvis(context),
      ],
    );
  }

  /// « 4,5 / 5 (12 avis) » (ou « Aucun avis »), precede d'une etoile ; masquee si la
  /// synthese est indisponible.
  Widget _ligneMoyenne(BuildContext context) {
    final avis = _avis;
    if (avis == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.star, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(formaterMoyenne(avis), style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  /// Derniers avis anonymes (note, commentaire, date), ou un texte d'etat.
  List<Widget> _derniersAvis(BuildContext context) {
    final avis = _avis;
    if (avis == null) return const [Text('Avis indisponibles pour le moment.')];
    if (!avis.aDesAvis || avis.avis.isEmpty) return const [Text('Aucun avis pour le moment.')];
    return [for (final a in avis.avis.take(nombreAvisAffiches)) _carteAvis(context, a)];
  }

  /// Un avis anonyme : « 4 / 5 », commentaire s'il existe, date de depot.
  Widget _carteAvis(BuildContext context, Avis a) {
    final texte = Theme.of(context).textTheme;
    final commentaire = a.commentaire;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_outline, size: 18),
                const SizedBox(width: 4),
                Text(formaterNote(a.note), style: texte.titleSmall),
              ],
            ),
            if (commentaire != null) ...[
              const SizedBox(height: 4),
              Text(commentaire),
            ],
            const SizedBox(height: 4),
            Text(dateAvis(a), style: texte.bodySmall),
          ],
        ),
      ),
    );
  }

  /// « Ouvrir une conversation » (messagerie avec ce praticien), aligne a gauche.
  Widget _boutonConversation() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _conversationEnCours ? null : _ouvrirConversation,
        icon: _conversationEnCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chat_bubble_outline),
        label: const Text('Ouvrir une conversation'),
      ),
    );
  }

  Widget _creneauTile(Map<String, dynamic> creneau) {
    final enCours = _enCours == identifiant(creneau['id']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(formaterDateIso(creneau['debut'] as String)),
      subtitle: Text('${creneau['dureeMinutes']} min'),
      trailing: FilledButton(
        onPressed: _enCours == null ? () => _reserver(creneau) : null,
        child: enCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Reserver'),
      ),
    );
  }
}
