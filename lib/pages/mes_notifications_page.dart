import 'package:flutter/material.dart';

import '../models/notification.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/notifications.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Notifications de l'utilisateur connecte : sujet (en gras tant qu'elle n'est pas lue),
/// message et date ; un toucher marque la notification lue, l'AppBar permet de tout marquer lu.
class MesNotificationsPage extends StatefulWidget {
  const MesNotificationsPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<MesNotificationsPage> createState() => _MesNotificationsPageState();
}

class _MesNotificationsPageState extends State<MesNotificationsPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<NotificationUtilisateur> _notifications = [];
  bool _charge = false;
  String? _erreur;

  /// Identifiant de la notification en cours de marquage (evite un double envoi).
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

  /// Charge (ou recharge) les notifications ; [discret] evite l'indicateur plein ecran,
  /// « tirer pour rafraichir » affichant deja le sien.
  Future<void> _charger({bool discret = false}) async {
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() {
      _charge = !discret;
      _erreur = null;
    });
    try {
      final notifications = await widget.api.mesNotifications(token);
      if (!mounted) return;
      setState(() {
        _notifications = trierParCreation(
          notifications.map(NotificationUtilisateur.fromJson).toList(),
        );
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

  Future<void> _rafraichir() => _charger(discret: true);

  /// Marque une notification lue (POST /api/notifications/{id}/lue) et remplace l'element
  /// par la notification renvoyee.
  Future<void> _marquerLue(NotificationUtilisateur notification) async {
    if (notification.lue || _enCours != null) return;
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _enCours = notification.id);
    try {
      final lue = NotificationUtilisateur.fromJson(
        await widget.api.marquerLue(notification.id, token),
      );
      if (!mounted) return;
      setState(() {
        _notifications = [
          for (final n in _notifications) n.id == notification.id ? lue : n,
        ];
      });
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = null); // rebatit aussi si la session a expire
    }
  }

  /// Marque lues toutes les notifications (POST /api/notifications/toutes-lues).
  Future<void> _toutMarquerLu() async {
    final token = _auth.accessToken;
    if (token == null) return;
    try {
      final nombre = await widget.api.toutMarquerLu(token);
      if (!mounted) return;
      setState(() {
        _notifications = [for (final n in _notifications) n.marquerLue()];
      });
      _message(nombre > 0
          ? '$nombre notification(s) marquee(s) lue(s)'
          : 'Aucune notification a marquer');
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    }
    if (mounted) setState(() {}); // la session a pu expirer
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    final nonLues = compterNonLues(_notifications);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes notifications'),
        actions: [
          if (_auth.estConnecte) ...[
            IconButton(
              tooltip: 'Tout marquer comme lu',
              onPressed: _charge || nonLues == 0 ? null : _toutMarquerLu,
              icon: const Icon(Icons.done_all),
            ),
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _charge ? null : _charger,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ],
      ),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ?? 'Connectez-vous pour consulter vos notifications.',
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_notifications.isEmpty) {
      return const Center(child: Text('Aucune notification pour le moment.'));
    }
    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _tuile(context, _notifications[i]),
      ),
    );
  }

  /// Sujet en gras tant que la notification n'est pas lue ; message puis date en dessous.
  Widget _tuile(BuildContext context, NotificationUtilisateur n) {
    final texte = Theme.of(context).textTheme;
    return ListTile(
      leading: Icon(n.lue ? Icons.notifications_none : Icons.notifications_active_outlined),
      title: Text(
        n.sujet,
        style: n.lue ? null : const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.message),
          const SizedBox(height: 4),
          Text(dateNotification(n), style: texte.bodySmall),
        ],
      ),
      isThreeLine: true,
      trailing: _actionLecture(n),
      onTap: n.lue ? null : () => _marquerLue(n),
    );
  }

  /// Bouton « Marquer comme lue » d'une notification non lue (indicateur pendant l'envoi).
  Widget? _actionLecture(NotificationUtilisateur n) {
    if (n.lue) return null;
    if (_enCours == n.id) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return IconButton(
      tooltip: 'Marquer comme lue',
      onPressed: () => _marquerLue(n),
      icon: const Icon(Icons.mark_email_read_outlined),
    );
  }
}
