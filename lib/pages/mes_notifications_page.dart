import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/besoin_medicament.dart';
import '../models/conversation.dart';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../config/lancement.dart';
import '../utils/notifications.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'conversation_page.dart';
import 'dawini_page.dart';
import 'detail_ordonnance_page.dart';
import 'espace/agenda_page.dart';
import 'espace/avis_medecin_page.dart';
import 'espace/cabinet_pages.dart';
import 'espace/candidature_page.dart';
import 'espace/secretaires_page.dart';
import 'fiche_medecin_page.dart';
import 'mes_avis_page.dart';
import 'mes_conversations_page.dart';
import 'mes_listes_attente_page.dart';
import 'mes_ordonnances_page.dart';
import 'mes_rendez_vous_page.dart';
import 'reponses_besoin_page.dart';
import 'mes_teleconsultations_page.dart';

/// Notifications de l'utilisateur connecte : sujet (en gras tant qu'elle n'est pas lue),
/// message et date ; un toucher marque la notification lue (si besoin) puis ouvre la page de son lien, l'AppBar permet de tout marquer lu.
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
      _message(t('Connexion annulée', 'تم إلغاء تسجيل الدخول'));
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

  /// Toucher : marque lue si besoin, puis ouvre l'ecran du lien (meme si deja lue).
  Future<void> _ouvrir(NotificationUtilisateur n) async {
    await _marquerLue(n);
    final cible = cibleDuLien(n.lien);
    if (cible == null || !mounted) return;
    final ecran = await _ecran(cible);
    if (ecran == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));
  }

  Future<Widget?> _ecran(CibleNotification cible) async {
    final id = cible.id ?? '';
    switch (cible.type) {
      case TypeCible.rendezVous:
        return MesRendezVousPage(api: widget.api, auth: _auth);
      case TypeCible.ordonnances:
        return MesOrdonnancesPage(api: widget.api, auth: _auth);
      case TypeCible.ordonnance:
        return DetailOrdonnancePage(ordonnanceId: id, api: widget.api, auth: _auth);
      case TypeCible.medecin:
        return FicheMedecinPage(medecinId: id, api: widget.api, auth: _auth);
      case TypeCible.dawini:
        return DawiniPage(api: widget.api, auth: _auth);
      case TypeCible.besoin:
        final besoin = await _besoin(id);
        return besoin == null
            ? DawiniPage(api: widget.api, auth: _auth)
            : ReponsesBesoinPage(besoin: besoin, api: widget.api, auth: _auth);
      case TypeCible.avis:
        return MesAvisPage(api: widget.api, auth: _auth);
      case TypeCible.listeAttente:
        return MesListesAttentePage(api: widget.api, auth: _auth);
      case TypeCible.agenda:
        return AgendaPage(api: widget.api, auth: _auth);
      case TypeCible.avisMedecin:
        return AvisMedecinPage(api: widget.api, auth: _auth);
      case TypeCible.secretaires:
        return SecretairesPage(api: widget.api, auth: _auth);
      case TypeCible.candidature:
        return CandidaturePage(api: widget.api, auth: _auth);
      case TypeCible.cabinets:
        return CabinetsPage(api: widget.api, auth: _auth);
      case TypeCible.invitations:
        return InvitationsCabinetPage(api: widget.api, auth: _auth);
      case TypeCible.teleconsultations:
        // Visio « Bientôt » : rien a ouvrir tant qu'elle est fermee.
        return visioActive ? MesTeleconsultationsPage(api: widget.api, auth: _auth) : null;
      case TypeCible.conversations:
        return MesConversationsPage(api: widget.api, auth: _auth);
      case TypeCible.conversation:
        final conversation = await _conversation(id);
        return conversation == null
            ? MesConversationsPage(api: widget.api, auth: _auth)
            : ConversationPage(
                conversation: conversation,
                nomMedecin: await titrePourMedecin(widget.api, _auth, conversation),
                api: widget.api,
                auth: _auth,
              );
    }
  }

  /// Retrouve une demande de medicament du patient par identifiant ; null si introuvable
  /// ou en cas d'echec (repli sur la liste des demandes).
  Future<BesoinMedicament?> _besoin(String id) async {
    final token = _auth.accessToken;
    if (token == null) return null;
    try {
      for (final b in await widget.api.mesBesoins(token)) {
        final besoin = BesoinMedicament.fromJson(b);
        if (besoin.id == id) return besoin;
      }
    } on Exception {
      // Repli sur la liste des demandes.
    }
    return null;
  }

  /// Retrouve une conversation par identifiant ; null si introuvable ou en cas d'echec.
  Future<Conversation?> _conversation(String id) async {
    final token = _auth.accessToken;
    if (token == null) return null;
    try {
      for (final c in await widget.api.mesConversations(token)) {
        final conversation = Conversation.fromJson(c);
        if (conversation.id == id) return conversation;
      }
    } on Exception {
      // Repli sur la liste des conversations.
    }
    return null;
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
          ? t('$nombre notification(s) marquée(s) lue(s)', 'تم تعليم $nombre إشعار(ات) كمقروءة')
          : t('Aucune notification à marquer', 'لا توجد إشعارات لتعليمها'));
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
        title: Text(t('Mes notifications', 'إشعاراتي')),
        actions: [
          if (_auth.estConnecte) ...[
            IconButton(
              tooltip: t('Tout marquer comme lu', 'تعليم الكل كمقروء'),
              onPressed: _charge || nonLues == 0 ? null : _toutMarquerLu,
              icon: const Icon(Icons.done_all),
            ),
            IconButton(
              tooltip: t('Actualiser', 'تحديث'),
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
        message: _erreur ??
            t('Connectez-vous pour consulter vos notifications.',
                'سجّل الدخول للاطلاع على إشعاراتك.'),
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_notifications.isEmpty) {
      return Center(
          child: Text(t('Aucune notification pour le moment.', 'لا توجد إشعارات حاليًا.')));
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
      trailing: _suffixe(n),
      onTap: () => _ouvrir(n),
    );
  }

  /// « Voir → » quand la notification ouvre un ecran (comme sur le site), puis le bouton de lecture.
  Widget? _suffixe(NotificationUtilisateur n) {
    final action = _actionLecture(n);
    if (!ouvreUnEcran(n.lien, visioActive: visioActive)) return action;
    final voir = Text(
      t('Voir →', 'عرض ←'),
      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
    );
    if (action == null) return voir;
    return Row(mainAxisSize: MainAxisSize.min, children: [voir, action]);
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
      tooltip: t('Marquer comme lue', 'تعليم كمقروء'),
      onPressed: () => _marquerLue(n),
      icon: const Icon(Icons.mark_email_read_outlined),
    );
  }
}
