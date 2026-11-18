import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../i18n/langue.dart';
import '../utils/praticien.dart';
import '../models/avis.dart';
import '../models/conversation.dart';
import '../models/synthese_avis.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/avis.dart';
import '../utils/dates.dart';
import '../utils/fiche_semaine.dart';
import '../utils/identifiants.dart';
import '../widgets/composants.dart';
import '../widgets/vue_erreur.dart';
import 'conversation_page.dart';

/// Message affiche quand le patient n'a aucun rendez-vous avec le praticien (403).
String get messageConversationRefusee => t(
    'Vous devez avoir un rendez-vous avec ce médecin pour lui écrire.',
    'يجب أن يكون لديك موعد مع هذا الطبيب لمراسلته.');

/// Nombre de derniers avis affiches sur la fiche.
const int nombreAvisAffiches = 5;

/// Ce que promet la liste d'attente : une notification DANS L'APPLI (pas de push tant que
/// l'enregistrement d'appareil et FCM ne sont pas en place, ticket #90).
String get texteListeAttente => t("Vous verrez une notification dans l'appli dès qu'un créneau se libère.",
    'سيظهر لك إشعار داخل التطبيق فور توفر موعد.');

/// Message affiche quand le patient est deja inscrit sur la liste d'attente (409).
String get messageDejaInscrit =>
    t('Vous êtes déjà inscrit sur cette liste.', 'أنت مسجل بالفعل في هذه القائمة.');

/// Etat affiche a la place du bouton une fois le patient inscrit.
String get texteInscrit => t("Vous êtes inscrit sur la liste d'attente de ce médecin.",
    'أنت مسجل في قائمة انتظار هذا الطبيب.');

/// Fiche d'un praticien : informations, moyenne des avis, ouverture d'une conversation,
/// creneaux reservables, inscription sur la liste d'attente et derniers avis anonymes.
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

  /// Vrai une fois le patient inscrit sur la liste d'attente (201, ou 409 deja inscrit).
  bool _inscrit = false;

  /// Vrai pendant l'inscription sur la liste d'attente (bouton desactive).
  bool _inscriptionEnCours = false;

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
      final dejaInscrit = await _dejaInscrit();
      if (!mounted) return;
      setState(() {
        if (dejaInscrit) _inscrit = true;
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

  /// Vrai si le patient connecte est deja sur la liste d'attente de ce praticien
  /// (GET /api/liste-attente/mes, comme le site) ; faux sans session ou en cas d'echec : la
  /// fiche reste utilisable et un 409 a l'inscription sera traite comme « deja inscrit ».
  Future<bool> _dejaInscrit() async {
    final token = _auth.accessToken;
    if (!_auth.estConnecte || token == null) return false;
    try {
      final inscriptions = await widget.api.mesInscriptionsAttente(token);
      return inscriptions.any((i) => identifiant(i['medecinId']) == widget.medecinId);
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      return false;
    } on Exception {
      return false;
    }
  }

  Future<void> _reserver(Map<String, dynamic> creneau) async {
    final creneauId = identifiant(creneau['id']);
    if (creneauId.isEmpty) return;
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message(t('Connexion nécessaire pour réserver', 'يجب تسجيل الدخول للحجز'));
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
      _message(t('Rendez-vous confirmé', 'تم تأكيد الموعد'));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.conflit) {
        // Le 409 peut venir d'un creneau pris, mais aussi de la regle « un seul rendez-vous
        // a venir par medecin » (creneau encore libre) : on affiche le message de l'API et
        // on recharge les creneaux, seul un creneau reellement pris disparait de la liste.
        _message(e.message);
        await _rechargerCreneaux();
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message(t('Session expirée : reconnectez-vous puis réessayez',
            'انتهت الجلسة: سجّل الدخول من جديد ثم أعد المحاولة'));
      } else {
        _message(e.message);
      }
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  /// Recharge les creneaux depuis l'API ; en cas d'echec, la liste affichee est conservee.
  Future<void> _rechargerCreneaux() async {
    try {
      final creneaux = await widget.api.creneaux(widget.medecinId);
      if (!mounted) return;
      setState(() => _creneaux = creneaux.where((c) => c['disponible'] != false).toList());
    } on Exception {
      // Liste inchangee : le message de l'API a deja ete affiche.
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
        _message(
            t('Connexion nécessaire pour écrire au médecin', 'يجب تسجيل الدخول لمراسلة الطبيب'));
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
        _message(t('Session expirée : reconnectez-vous puis réessayez',
            'انتهت الجلسة: سجّل الدخول من جديد ثم أعد المحاولة'));
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

  /// Inscrit le patient sur la liste d'attente du praticien
  /// (POST /api/medecins/{id}/liste-attente), connexion Keycloak a la volee si necessaire ;
  /// 409 (deja inscrit) -> [messageDejaInscrit], l'etat passe a inscrit dans les deux cas.
  Future<void> _inscrire() async {
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message(t("Connexion nécessaire pour s'inscrire sur la liste d'attente",
            'يجب تسجيل الدخول للتسجيل في قائمة الانتظار'));
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _inscriptionEnCours = true);
    var inscrit = false;
    try {
      await widget.api.inscrireListeAttente(widget.medecinId, token);
      inscrit = true;
      _message('${t('Inscription enregistrée.', 'تم التسجيل.')} $texteListeAttente');
    } on ApiException catch (e) {
      if (e.conflit) {
        inscrit = true;
        _message(messageDejaInscrit);
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message(t('Session expirée : reconnectez-vous puis réessayez',
            'انتهت الجلسة: سجّل الدخول من جديد ثم أعد المحاولة'));
      } else {
        _message(e.message);
      }
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) {
        setState(() {
          _inscriptionEnCours = false; // rebatit aussi si la session a expire
          if (inscrit) _inscrit = true;
        });
      }
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Fiche médecin', 'ملف الطبيب'))),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    final medecin = _medecin;
    if (erreur != null || medecin == null) {
      return VueErreur(
          message: erreur ?? t('Médecin introuvable', 'الطبيب غير موجود'), onReessayer: _charger);
    }
    final texte = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CarteTabibi(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                AvatarInitiales(nom: medecin['nomComplet'] as String, rayon: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medecin['nomComplet'] as String,
                          style: texte.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(sousTitrePraticien(medecin),
                          style: texte.bodyMedium?.copyWith(color: Charte.doux)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              _ligneMoyenne(context),
              const SizedBox(height: 12),
              _boutonConversation(),
            ],
          ),
        ),
        ..._informationsPratiques(context, medecin),
        const SizedBox(height: 24),
        Text(t('Créneaux disponibles', 'المواعيد المتاحة'), style: texte.titleMedium),
        const SizedBox(height: 8),
        if (_creneaux.isEmpty)
          Text(t('Aucun créneau disponible pour le moment.', 'لا توجد مواعيد متاحة حاليًا.')),
        Wrap(spacing: 10, runSpacing: 10, children: [for (final c in _creneaux) _creneauTile(c)]),
        const SizedBox(height: 24),
        _listeAttente(context),
        const SizedBox(height: 24),
        Text(t('Avis des patients', 'آراء المرضى'), style: texte.titleMedium),
        const SizedBox(height: 8),
        ..._derniersAvis(context),
      ],
    );
  }

  /// Texte non vide (espaces retires) d'un champ de la fiche, sinon null.
  String? _champTexte(Map<String, dynamic> medecin, String cle) {
    final v = medecin[cle];
    if (v is! String || v.trim().isEmpty) return null;
    return v.trim();
  }

  /// « Informations pratiques » : adresse, telephone (lien tel:), horaires, presentation et
  /// langues ; chaque ligne vide est masquee, la section aussi si tout est vide.
  List<Widget> _informationsPratiques(BuildContext context, Map<String, dynamic> medecin) {
    final adresse = _champTexte(medecin, 'adresse');
    final telephone = _champTexte(medecin, 'telephoneCabinet');
    final horaires = _champTexte(medecin, 'horaires');
    final presentation = _champTexte(medecin, 'presentation');
    final langues = [
      for (final l in languesFiche)
        if (languesDe(medecin['langues']).contains(l.$1)) t(l.$2, l.$3),
    ];
    if ([adresse, telephone, horaires, presentation].every((v) => v == null) &&
        langues.isEmpty) {
      return const [];
    }
    final texte = Theme.of(context).textTheme;
    Widget ligne(IconData icone, String libelle, Widget contenu) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, size: 20, color: Charte.vertFonce),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(libelle, style: texte.bodySmall?.copyWith(color: Charte.doux)),
                    contenu,
                  ],
                ),
              ),
            ],
          ),
        );
    return [
      const SizedBox(height: 24),
      Text(t('Informations pratiques', 'معلومات عملية'), style: texte.titleMedium),
      const SizedBox(height: 8),
      CarteTabibi(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (adresse != null) ligne(Icons.place_outlined, t('Adresse', 'العنوان'), Text(adresse)),
            if (telephone != null)
              ligne(
                Icons.phone_outlined,
                t('Téléphone', 'الهاتف'),
                InkWell(
                  onTap: () => launchUrl(
                    Uri(scheme: 'tel', path: telephone.replaceAll(RegExp(r'[\s.\-()]'), '')),
                  ),
                  child: Text(telephone,
                      style: const TextStyle(
                          color: Charte.vertFonce, decoration: TextDecoration.underline)),
                ),
              ),
            if (horaires != null)
              ligne(Icons.access_time, t('Horaires', 'أوقات العمل'), Text(horaires)),
            if (presentation != null)
              ligne(Icons.notes, t('Présentation', 'تقديم'), Text(presentation)),
            if (langues.isNotEmpty)
              ligne(Icons.translate, t('Langues parlées', 'اللغات المتحدث بها'),
                  Text(langues.join(' · '))),
          ],
        ),
      ),
    ];
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
    if (avis == null) {
      return [Text(t('Avis indisponibles pour le moment.', 'الآراء غير متاحة حاليًا.'))];
    }
    if (!avis.aDesAvis || avis.avis.isEmpty) {
      return [Text(t('Aucun avis pour le moment.', 'لا توجد آراء حاليًا.'))];
    }
    return [for (final a in avis.avis.take(nombreAvisAffiches)) _carteAvis(context, a)];
  }

  /// Un avis anonyme : « 4 / 5 », commentaire s'il existe, date de depot.
  Widget _carteAvis(BuildContext context, Avis a) {
    final texte = Theme.of(context).textTheme;
    final commentaire = a.commentaire;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarteTabibi(
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

  /// Liste d'attente, surtout utile quand aucun creneau n'est disponible : rappel de ce
  /// qu'elle promet, puis bouton « M'inscrire sur la liste d'attente » ou, une fois inscrit,
  /// texte d'etat ([texteInscrit]).
  Widget _listeAttente(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t("Liste d'attente", 'قائمة الانتظار'), style: texte.titleMedium),
        const SizedBox(height: 4),
        Text(texteListeAttente, style: texte.bodySmall),
        const SizedBox(height: 8),
        if (_inscrit)
          Text(texteInscrit)
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _inscriptionEnCours ? null : _inscrire,
              icon: _inscriptionEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.hourglass_top_outlined),
              label: Text(t("M'inscrire sur la liste d'attente", 'التسجيل في قائمة الانتظار')),
            ),
          ),
      ],
    );
  }

  /// « Ouvrir une conversation » (messagerie avec ce praticien), aligne a gauche.
  Widget _boutonConversation() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        onPressed: _conversationEnCours ? null : _ouvrirConversation,
        icon: _conversationEnCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chat_bubble_outline),
        label: Text(t('Ouvrir une conversation', 'بدء محادثة')),
      ),
    );
  }

  /// Creneau en pastille : date, duree et bouton « Réserver ».
  Widget _creneauTile(Map<String, dynamic> creneau) {
    final enCours = _enCours == identifiant(creneau['id']);
    final texte = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: Charte.pastille,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 18, color: Charte.vertFonce),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formaterDateIso(creneau['debut'] as String),
                  style: texte.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(formaterDuree(creneau['dureeMinutes']),
                  style: texte.bodySmall?.copyWith(color: Charte.doux)),
            ],
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _enCours == null ? () => _reserver(creneau) : null,
            child: enCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t('Réserver', 'احجز')),
          ),
        ],
      ),
    );
  }
}
