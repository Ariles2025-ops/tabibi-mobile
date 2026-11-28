import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/libelles.dart';
import '../utils/messagerie.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'fiche_medecin_page.dart';

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
  bool _fermeture = false;
  String? _erreur;

  /// Conversation courante : elle passe a « fermee » quand le medecin la ferme ou que l'envoi est refuse (409).
  late Conversation _conversation = widget.conversation;

  /// Vrai quand l'envoi a ete refuse (403) faute de rendez-vous recent : le champ de saisie est
  /// remplace par une invitation a reprendre rendez-vous (comme sur le site).
  bool _interdit = false;

  /// Mon identifiant : sujet du jeton, sinon le patient de la conversation (c'est moi).
  String get _moi => _auth.sujet ?? widget.conversation.patientId;

  bool get _moiPatient => _moi == _conversation.patientId;

  /// Le bouton « Fermer la conversation » n'est propose qu'au medecin, tant qu'elle est ouverte.
  bool get _peutFermer => !_conversation.fermee && _moi == _conversation.medecinId;

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
      _message(t('Connexion annulée', 'تم إلغاء تسجيل الدخول'));
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
      setState(() => _erreur = messageChargementRefuse(e.statusCode, e.message,
          refus: t('Cette conversation ne vous concerne pas.', 'هذه المحادثة لا تخصّك.'),
          introuvable: t('Conversation introuvable.', 'المحادثة غير موجودة.')));
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
      if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message(e.message);
      } else if (e.statusCode == 409 && mounted) {
        // Le medecin a ferme la conversation entre-temps.
        setState(() => _conversation = _conversation.enFermee());
      } else if (e.interdit && _moiPatient && mounted) {
        setState(() => _interdit = true);
      } else if (e.interdit) {
        _message(t("Vous n'avez pas le droit d'écrire dans cette conversation.",
            'ليس لديك صلاحية الكتابة في هذه المحادثة.'));
      } else {
        _message(e.message);
      }
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
    }
  }

  /// Ouvre la fiche du médecin de la conversation pour reprendre rendez-vous.
  void _ouvrirFiche() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          FicheMedecinPage(medecinId: _conversation.medecinId, api: widget.api, auth: _auth),
    ));
  }

  /// Ferme la conversation apres confirmation (POST .../fermer) ; le champ de saisie disparait ensuite.
  Future<void> _fermer() async {
    final token = _auth.accessToken;
    if (token == null || _fermeture) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t('Fermer cette conversation ? Le patient ne pourra plus vous écrire.',
            'إغلاق هذه المحادثة؟ لن يتمكن المريض من مراسلتك بعد الآن.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: Text(t('Annuler', 'إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t('Fermer la conversation', 'إغلاق المحادثة'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _fermeture = true);
    try {
      await widget.api.fermerConversation(_conversation.id, token);
      if (mounted) setState(() => _conversation = _conversation.enFermee());
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.nonAutorise
          ? e.message
          : t('La fermeture de la conversation a échoué, veuillez réessayer.',
              'فشل إغلاق المحادثة، يُرجى المحاولة مرة أخرى.'));
    } on Exception {
      _message(t('La fermeture de la conversation a échoué, veuillez réessayer.',
          'فشل إغلاق المحادثة، يُرجى المحاولة مرة أخرى.'));
    } finally {
      if (mounted) setState(() => _fermeture = false);
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
        title: Text(widget.nomMedecin ?? t('Conversation', 'محادثة')),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              tooltip: t('Actualiser', 'تحديث'),
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
        message: _erreur ??
            t('Connectez-vous pour consulter cette conversation.',
                'سجّل الدخول للاطلاع على هذه المحادثة.'),
        onSeConnecter: _seConnecter,
      );
    }
    return Column(
      children: [
        Expanded(child: _fil(context)),
        const Divider(height: 1),
        _pied(context),
      ],
    );
  }

  Widget _fil(BuildContext context) {
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t('Aucun message pour le moment. Écrivez le premier.',
                'لا توجد رسائل حاليًا. اكتب أول رسالة.'),
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
            // « · lu » sur mes messages lus par le destinataire, comme sur le site.
            Text(
              deMoi && m.estLu
                  ? '${dateMessage(m)} · ${t('lu', 'مقروءة')}'
                  : dateMessage(m),
              style: texte.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Bas de l'ecran : conversation fermee, envoi refuse (403) ou champ de saisie ; le medecin
  /// peut fermer une conversation ouverte.
  Widget _pied(BuildContext context) {
    final gris = Theme.of(context).colorScheme.onSurfaceVariant;
    if (_conversation.fermee) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _moiPatient
                ? t('Le médecin a fermé cette conversation.', 'أغلق الطبيب هذه المحادثة.')
                : t('Cette conversation est fermée.', 'هذه المحادثة مغلقة.'),
            key: const Key('conversation-fermee'),
            style: TextStyle(color: gris),
          ),
        ),
      );
    }
    if (_interdit) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('Vous ne pouvez plus écrire à ce médecin : prenez un nouveau rendez-vous.',
                    'لا يمكنك الكتابة إلى هذا الطبيب بعد الآن: احجز موعدًا جديدًا.'),
                key: const Key('envoi-interdit'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              // « Prendre rendez-vous » mène à la fiche du médecin, comme sur le site.
              TextButton(
                key: const Key('prendre-rendez-vous'),
                onPressed: _ouvrirFiche,
                child: Text(t('Prendre rendez-vous', 'حجز موعد')),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_peutFermer)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _fermeture ? null : _fermer,
              child: Text(t('Fermer la conversation', 'إغلاق المحادثة')),
            ),
          ),
        _zoneSaisie(context),
      ],
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
                decoration: InputDecoration(
                  hintText: t('Votre message', 'رسالتك'),
                  counterText: '',
                  border: const OutlineInputBorder(),
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
                      : Text(t('Envoyer', 'إرسال')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
