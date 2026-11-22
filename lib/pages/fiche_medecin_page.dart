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
import 'espace/candidature_page.dart';
import 'mes_listes_attente_page.dart';
import 'mes_rendez_vous_page.dart';

/// Message affiche quand le patient n'a aucun rendez-vous avec le praticien (403).
String get messageConversationRefusee => t(
    'Vous devez avoir un rendez-vous avec ce médecin pour lui écrire.',
    'يجب أن يكون لديك موعد مع هذا الطبيب لمراسلته.');

/// Nombre de derniers avis affiches sur la fiche.
const int nombreAvisAffiches = 5;

/// Ce que promet la liste d'attente : une notification DANS L'APPLI (pas de push tant que
/// l'enregistrement d'appareil et FCM ne sont pas en place, ticket #90).
String get texteListeAttente => t(
    "Vous verrez une notification dans l'appli dès qu'un créneau se libère.",
    'سيظهر لك إشعار داخل التطبيق فور توفر موعد.');

/// Titre et texte de l'encart d'une fiche importee sans compte (memes textes que le site).
String get titreFicheSansCompte =>
    t("Ce praticien n'est pas encore sur Ndawik", 'هذا الممارس ليس بعد على نداويك');

String get texteFicheSansCompte => t(
    'Sa fiche provient de sources publiques : il ne reçoit pas encore de messages ni de demandes de rendez-vous en ligne.',
    'ملفّه مأخوذ من مصادر عامة: لا يستقبل بعدُ رسائل ولا طلبات مواعيد عبر الإنترنت.');

/// Message affiche quand le patient est deja inscrit sur la liste d'attente (409).
String get messageDejaInscrit =>
    t('Vous êtes déjà inscrit sur cette liste.', 'أنت مسجّل بالفعل في هذه القائمة.');

/// Titre de l'encart de liste d'attente, comme le site : la question change selon qu'aucun
/// creneau n'est propose ou que ceux proposes ne conviennent pas.
String titreListeAttente({required bool aucunCreneau}) => aucunCreneau
    ? t('Aucun créneau ne vous est proposé ?', 'لا توجد مواعيد مقترحة لك؟')
    : t('Aucun créneau ne vous convient ?', 'لا يناسبك أي موعد؟');

/// Lien affiche une fois inscrit, vers « Mes listes d'attente » (comme le site).
String get texteVoirMesListesAttente =>
    t("Voir mes listes d'attente", 'عرض قوائم انتظاري');

/// Lien proposé après une réservation, vers « Mes rendez-vous » (comme le site).
String get texteVoirMesRendezVous => t('Voir mes rendez-vous', 'عرض مواعيدي');

/// Confirmation d'une réservation : le texte du site « Rendez-vous confirmé » avec la date du
/// rendez-vous quand l'API la renvoie.
String messageRendezVousConfirme(Object? debut) {
  final base = t('Rendez-vous confirmé', 'تم تأكيد الموعد');
  final date = debut is String && debut.isNotEmpty ? formaterDateIso(debut) : '';
  return date.isEmpty ? base : '$base : $date';
}

/// Etat affiche a la place du bouton une fois le patient inscrit.
String get texteInscrit => t(
    "Vous êtes inscrit sur la liste d'attente de ce médecin.",
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

  /// Jour choisi (« jeu. 3 déc. ») et creneau choisi (identifiant) dans le selecteur.
  String? _jourChoisi;
  String? _creneauChoisi;

  /// « jeu. 3 déc. 09:00 » -> (« jeu. 3 déc. », « 09:00 »).
  static (String, String) _jourEtHeure(Map<String, dynamic> c) {
    final texte = formaterDateIso(identifiant(c['debut']));
    final i = texte.lastIndexOf(' ');
    return i < 0
        ? (texte, '')
        : (texte.substring(0, i), texte.substring(i + 1));
  }

  /// Jours ayant au moins un creneau, dans l'ordre des creneaux.
  List<String> get _jours => [
        for (final c in _creneaux) _jourEtHeure(c).$1,
      ].fold<List<String>>([], (l, j) => l.contains(j) ? l : (l..add(j)));

  Map<String, dynamic>? get _creneauSelectionne {
    if (_creneaux.isEmpty) return null;
    final jour = _jours.contains(_jourChoisi) ? _jourChoisi! : _jours.first;
    final duJour = _creneaux.where((c) => _jourEtHeure(c).$1 == jour).toList();
    return duJour.firstWhere((c) => identifiant(c['id']) == _creneauChoisi,
        orElse: () => duJour.first);
  }

  /// Vrai pendant l'ouverture de la conversation (bouton desactive).
  bool _conversationEnCours = false;

  /// Vrai une fois le patient inscrit sur la liste d'attente (201, ou 409 deja inscrit).
  bool _inscrit = false;

  /// Vrai pour une fiche importee sans compte : ni messagerie, ni creneaux, ni liste d'attente.
  bool _reclamable = false;

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
      final reclamable = await widget.api.reclamable(widget.medecinId);
      final dejaInscrit = await _dejaInscrit();
      if (!mounted) return;
      setState(() {
        _reclamable = reclamable;
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
      return SyntheseAvis.fromJson(
          await widget.api.avisDuMedecin(widget.medecinId));
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
      return inscriptions
          .any((i) => identifiant(i['medecinId']) == widget.medecinId);
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      return false;
    } on Exception {
      return false;
    }
  }

  /// Fenetre de recapitulatif (medecin, jour et heure d'Alger, duree, adresse si connue) ;
  /// vrai uniquement si le patient appuie sur « Confirmer ».
  Future<bool> _confirmerReservation(Map<String, dynamic> creneau) async {
    final nom = _champTexte(_medecin ?? const {}, 'nomComplet');
    final adresse = _champTexte(_medecin ?? const {}, 'adresse');
    final duree = formaterDuree(creneau['dureeMinutes']);
    final debut = creneau['debut'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Confirmer le rendez-vous', 'تأكيد الموعد')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nom != null)
              Text(nom, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (debut is String) Text(formaterDateIso(debut, avecAnnee: true)),
            if (duree.isNotEmpty) Text('${t('Durée', 'المدة')} : $duree'),
            if (adresse != null) Text('${t('Adresse', 'العنوان')} : $adresse'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t('Annuler', 'إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t('Confirmer', 'تأكيد'))),
        ],
      ),
    );
    return ok == true;
  }

  /// « C'est votre fiche ? » : candidature preremplie avec cette fiche (connexion d'abord si besoin).
  Future<void> _reclamer() async {
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message(t('Connexion nécessaire pour réclamer une fiche',
            'يجب تسجيل الدخول للمطالبة بملف'));
        return;
      }
    }
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => CandidaturePage(
            api: widget.api, auth: _auth, ficheReclamee: widget.medecinId)));
  }

  Future<void> _reserver(Map<String, dynamic> creneau) async {
    final creneauId = identifiant(creneau['id']);
    if (creneauId.isEmpty) return;
    if (!await _confirmerReservation(creneau) || !mounted) return;
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message(
            t('Connexion nécessaire pour réserver', 'يجب تسجيل الدخول للحجز'));
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() => _enCours = creneauId);
    try {
      final reservation = await widget.api.reserverCreneau(creneauId, token);
      if (!mounted) return;
      setState(() => _retirerCreneau(creneauId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageRendezVousConfirme(reservation['debut'])),
        action: SnackBarAction(
          label: texteVoirMesRendezVous,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MesRendezVousPage(api: widget.api, auth: _auth))),
        ),
      ));
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
      setState(() =>
          _creneaux = creneaux.where((c) => c['disponible'] != false).toList());
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
        _message(t('Connexion nécessaire pour écrire au médecin',
            'يجب تسجيل الدخول لمراسلة الطبيب'));
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
        _message(t(
            "Connexion nécessaire pour s'inscrire sur la liste d'attente",
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
      _message(
          '${t('Inscription enregistrée.', 'تم التسجيل.')} $texteListeAttente');
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
          message: erreur ?? t('Médecin introuvable', 'الطبيب غير موجود'),
          onReessayer: _charger);
    }
    final texte = Theme.of(context).textTheme;
    final nom = identifiant(medecin['nomComplet']);
    final telephone = _champTexte(medecin, 'telephoneCabinet');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: Charte.degrade,
            borderRadius: BorderRadius.circular(20),
            boxShadow: Charte.ombreCarte,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: AvatarInitiales(nom: nom, rayon: 36),
            ),
            const SizedBox(height: 12),
            Text(nom,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text(sousTitrePraticien(medecin),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
            const SizedBox(height: 12),
            _ligneMoyenne(context),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          if (!_reclamable) Expanded(child: _boutonConversation()),
          if (telephone != null) ...[
            if (!_reclamable) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri(
                    scheme: 'tel',
                    path: telephone.replaceAll(RegExp(r'[\s.\-()]'), ''))),
                icon: const Icon(Icons.phone_outlined),
                label: Text(t('Appeler', 'اتصال')),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 24),
        if (_reclamable)
          CarteTabibi(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: Charte.meta),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titreFicheSansCompte, style: texte.titleSmall),
                      const SizedBox(height: 4),
                      Text(texteFicheSansCompte),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: _reclamer,
                          child: Text(t("C'est votre fiche ?", 'هل هذا ملفّك؟')),
                        ),
                      ),
                    ]),
              ),
            ]),
          )
        else ...[
        Text(t('Créneaux disponibles', 'المواعيد المتاحة'),
            style: texte.titleMedium),
        if (texteProchaineDisponibilite(_creneaux) case final prochaine?) ...[
          const SizedBox(height: 4),
          Text(prochaine, style: texte.bodyMedium?.copyWith(color: Charte.meta)),
        ],
        const SizedBox(height: 12),
        if (_creneaux.isEmpty)
          CarteTabibi(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.event_busy_outlined, color: Charte.meta),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t('Aucun créneau disponible pour le moment.',
                    'لا توجد مواعيد متاحة حاليًا.')),
              ),
            ]),
          )
        else
          _selecteurCreneaux(context),
        ],
        ..._informationsPratiques(context, medecin),
        if (!_reclamable) ...[
          const SizedBox(height: 24),
          _listeAttente(context),
        ],
        const SizedBox(height: 24),
        Text(t('Avis des patients', 'آراء المرضى'), style: texte.titleMedium),
        const SizedBox(height: 8),
        ..._derniersAvis(context),
      ],
    );
  }

  /// Choix du jour (pastilles defilantes), puis de l'heure (grille), puis un seul bouton
  /// « Réserver » qui rappelle le creneau choisi.
  Widget _selecteurCreneaux(BuildContext context) {
    final choisi = _creneauSelectionne!;
    final jourCourant = _jourEtHeure(choisi).$1;
    final duJour =
        _creneaux.where((c) => _jourEtHeure(c).$1 == jourCourant).toList();
    final enCours = _enCours == identifiant(choisi['id']);
    return CarteTabibi(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _jours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final jour = _jours[i];
              final actif = jour == jourCourant;
              final morceaux = jour.split(' ');
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  _jourChoisi = jour;
                  _creneauChoisi = null;
                }),
                child: Container(
                  width: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: actif ? Charte.vert : Charte.fond,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: actif ? Charte.vert : Charte.bordure),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(morceaux.first,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: actif ? Colors.white : Charte.meta,
                                fontWeight: FontWeight.w600)),
                        Text(morceaux.skip(1).join(' '),
                            style: TextStyle(
                                fontSize: 14,
                                color: actif ? Colors.white : Charte.texte,
                                fontWeight: FontWeight.w800)),
                      ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in duJour)
            ChoiceChip(
              label: Text(_jourEtHeure(c).$2),
              selected: identifiant(c['id']) == identifiant(choisi['id']),
              showCheckmark: false,
              selectedColor: Charte.vert,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: identifiant(c['id']) == identifiant(choisi['id'])
                    ? Colors.white
                    : Charte.vertFonce,
              ),
              backgroundColor: Charte.pastille,
              side: BorderSide.none,
              onSelected: (_) =>
                  setState(() => _creneauChoisi = identifiant(c['id'])),
            ),
        ]),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.event_available_outlined, color: Charte.vert),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formaterDateIso(identifiant(choisi['debut'])),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Charte.texte,
                      fontSize: 15)),
              Text(formaterDuree(choisi['dureeMinutes']),
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _enCours == null ? () => _reserver(choisi) : null,
          child: enCours
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t('Réserver', 'احجز')),
        ),
      ]),
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
  List<Widget> _informationsPratiques(
      BuildContext context, Map<String, dynamic> medecin) {
    final adresse = _champTexte(medecin, 'adresse');
    final telephone = _champTexte(medecin, 'telephoneCabinet');
    final horaires = _champTexte(medecin, 'horaires');
    final presentation = _champTexte(medecin, 'presentation');
    final langues = [
      for (final l in languesFiche)
        if (languesDe(medecin['langues']).contains(l.$1)) t(l.$2, l.$3),
    ];
    // Comme sur le site : paiement, confirmation et annulation, pour une fiche reservable.
    final reservable = !_reclamable;
    if ([adresse, telephone, horaires, presentation].every((v) => v == null) &&
        langues.isEmpty &&
        !reservable) {
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
                    Text(libelle,
                        style: texte.bodySmall?.copyWith(color: Charte.doux)),
                    contenu,
                  ],
                ),
              ),
            ],
          ),
        );
    return [
      const SizedBox(height: 24),
      Text(t('Informations pratiques', 'معلومات عملية'),
          style: texte.titleMedium),
      const SizedBox(height: 8),
      CarteTabibi(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (adresse != null)
              ligne(
                  Icons.place_outlined, t('Adresse', 'العنوان'), Text(adresse)),
            if (telephone != null)
              ligne(
                Icons.phone_outlined,
                t('Téléphone', 'الهاتف'),
                InkWell(
                  onTap: () => launchUrl(
                    Uri(
                        scheme: 'tel',
                        path: telephone.replaceAll(RegExp(r'[\s.\-()]'), '')),
                  ),
                  child: Text(telephone,
                      style: const TextStyle(
                          color: Charte.vertFonce,
                          decoration: TextDecoration.underline)),
                ),
              ),
            if (horaires != null)
              ligne(Icons.access_time, t('Horaires', 'أوقات العمل'),
                  Text(horaires)),
            if (presentation != null)
              ligne(
                  Icons.notes, t('Présentation', 'تقديم'), Text(presentation)),
            if (langues.isNotEmpty)
              ligne(Icons.translate, t('Langues parlées', 'اللغات المتحدَّث بها'),
                  Text(langues.join(' · '))),
            if (reservable) ...[
              ligne(
                  Icons.account_balance_wallet_outlined,
                  t('Paiement au cabinet', 'الدفع في العيادة'),
                  Text(t('Vous réglez la consultation directement sur place.',
                      'تدفع ثمن الاستشارة مباشرة في العيادة.'))),
              ligne(
                  Icons.bolt_outlined,
                  t('Confirmation immédiate', 'تأكيد فوري'),
                  Text(t('Votre rendez-vous est enregistré dès la réservation.',
                      'يُسجَّل موعدك فور الحجز.'))),
              ligne(
                  Icons.event_busy_outlined,
                  t('Un empêchement ?', 'هل طرأ ما يمنعك؟'),
                  Text(t(
                      'Annulez depuis « Mes rendez-vous » pour libérer la place.',
                      'ألغِ الموعد من «مواعيدي» لإتاحة المكان لغيرك.'))),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: Charte.or),
          const SizedBox(width: 4),
          Text(formaterMoyenne(avis),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }

  /// Derniers avis anonymes (note, commentaire, date), ou un texte d'etat.
  List<Widget> _derniersAvis(BuildContext context) {
    final avis = _avis;
    if (avis == null) {
      return [
        Text(
            t('Avis indisponibles pour le moment.', 'الآراء غير متاحة حاليًا.'))
      ];
    }
    if (!avis.aDesAvis || avis.avis.isEmpty) {
      return [Text(t('Aucun avis pour le moment.', 'لا توجد آراء حاليًا.'))];
    }
    return [
      for (final a in trierParDateRecente(avis.avis, (a) => a.deposeLe).take(nombreAvisAffiches))
        _carteAvis(context, a)
    ];
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
        Text(titreListeAttente(aucunCreneau: _creneaux.isEmpty),
            style: texte.titleMedium),
        const SizedBox(height: 4),
        Text(texteListeAttente, style: texte.bodySmall),
        const SizedBox(height: 8),
        if (_inscrit) ...[
          Text(texteInscrit),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('voir-mes-listes-attente'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => MesListesAttentePage(api: widget.api, auth: _auth))),
              child: Text(texteVoirMesListesAttente),
            ),
          ),
        ] else
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
              label: Text(t("M'inscrire sur la liste d'attente",
                  'التسجيل في قائمة الانتظار')),
            ),
          ),
      ],
    );
  }

  /// « Ouvrir une conversation » (messagerie avec ce praticien), aligne a gauche.
  Widget _boutonConversation() {
    return SizedBox(
      width: double.infinity,
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
}
