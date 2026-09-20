import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/avis.dart';
import '../models/conversation.dart';
import '../models/synthese_avis.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/praticiens_supabase.dart';
import '../services/session.dart';
import '../services/supabase_service.dart';
import '../theme/theme_tabibi.dart';
import '../utils/avis.dart';
import '../utils/dates.dart';
import '../utils/identifiants.dart';
import '../utils/libelles.dart';
import '../widgets/vue_erreur.dart';
import 'connexion_page.dart';
import 'conversation_page.dart';

/// Nombre de derniers avis affiches sur la fiche.
const int nombreAvisAffiches = 5;

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
  final PraticiensSupabase _prat = const PraticiensSupabase();
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
      final medecin = await _prat.parId(widget.medecinId);
      if (medecin == null) {
        if (mounted) setState(() => _erreur = 'Praticien introuvable.');
        return;
      }
      final creneaux = await _chargerCreneaux();
      final avis = await _chargerAvis();
      if (!mounted) return;
      setState(() {
        _medecin = medecin;
        _creneaux = creneaux;
        _avis = avis;
      });
    } catch (_) {
      if (mounted) setState(() => _erreur = 'Fiche momentanément indisponible.');
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Creneaux reservables du jour via Supabase (`get_available_slots`).
  /// Vide tant que le praticien n'a pas de planning : la fiche reste consultable.
  Future<List<Map<String, dynamic>>> _chargerCreneaux() async {
    try {
      final n = DateTime.now();
      final d = '${n.year.toString().padLeft(4, '0')}-'
          '${n.month.toString().padLeft(2, '0')}-'
          '${n.day.toString().padLeft(2, '0')}';
      final r = await sb.rpc('get_available_slots',
          params: {'p_doctor_id': widget.medecinId, 'p_date': d});
      final rows = (r as List?) ?? const [];
      return rows.map((e) {
        final m = e as Map;
        final debut = m['slot_start']?.toString() ?? '';
        final fin = m['slot_end']?.toString() ?? '';
        int duree = 30;
        try {
          duree = DateTime.parse(fin).difference(DateTime.parse(debut)).inMinutes;
        } catch (_) {}
        return <String, dynamic>{
          'id': debut,
          'debut': debut,
          'disponible': true,
          'dureeMinutes': duree,
        };
      }).toList();
    } catch (_) {
      return [];
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
    final debut = creneau['debut']?.toString();
    if (creneauId.isEmpty || debut == null || debut.isEmpty) return;
    // Connexion Supabase requise pour reserver.
    if (sb.auth.currentSession == null) {
      await Navigator.of(context).push(
          MaterialPageRoute<bool>(builder: (_) => const ConnexionPage()));
      if (!mounted) return;
      if (sb.auth.currentSession == null) {
        _message(t(context, 'fiche.connexionReserver'));
        return;
      }
    }
    setState(() => _enCours = creneauId);
    try {
      await sb.from('appointments').insert({
        'patient_id': sb.auth.currentUser!.id,
        'doctor_id': widget.medecinId,
        'scheduled_at': debut,
        'duration_minutes': creneau['dureeMinutes'] ?? 30,
      });
      if (!mounted) return;
      setState(() => _retirerCreneau(creneauId));
      _message(t(context, 'fiche.rdvConfirme'));
    } catch (_) {
      if (mounted) {
        // Le creneau vient d'etre pris, ou reservation refusee : on le retire.
        setState(() => _retirerCreneau(creneauId));
        _message('Réservation impossible (créneau déjà pris ou indisponible).');
      }
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
  /// n'a aucun rendez-vous avec lui (« fiche.conversationRefusee »).
  Future<void> _ouvrirConversation() async {
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message(t(context, 'fiche.connexionEcrire'));
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
      if (!mounted) return;
      if (e.interdit) {
        _message(t(context, 'fiche.conversationRefusee'));
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message(t(context, 'commun.sessionExpiree'));
      } else {
        _message(messageApi(context, e));
      }
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
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
  /// 409 (deja inscrit) -> « fiche.dejaInscrit », l'etat passe a inscrit dans les deux cas.
  Future<void> _inscrire() async {
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      if (!ok) {
        _message(t(context, 'fiche.connexionInscrire'));
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
      if (!mounted) return;
      _message(t(context, 'fiche.inscriptionEnregistree', params: {
        'texte': t(context, 'fiche.texteListeAttente'),
      }));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.conflit) {
        inscrit = true;
        _message(t(context, 'fiche.dejaInscrit'));
      } else if (e.nonAutorise) {
        _auth.seDeconnecter();
        _message(t(context, 'commun.sessionExpiree'));
      } else {
        _message(messageApi(context, e));
      }
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
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
      appBar: AppBar(title: Text(t(context, 'fiche.titre'))),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    final medecin = _medecin;
    if (erreur != null || medecin == null) {
      return VueErreur(
        message: erreur ?? t(context, 'fiche.introuvable'),
        onReessayer: _charger,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _enteteMedecin(context, medecin),
        const SizedBox(height: 16),
        _infosPratiques(context, medecin),
        _boutonConversation(context),
        const SizedBox(height: 24),
        _titreSection(t(context, 'fiche.creneaux')),
        const SizedBox(height: 10),
        if (_creneaux.isEmpty) _infoVide(t(context, 'fiche.aucunCreneau')),
        for (final c in _creneaux) _creneauTile(context, c),
        const SizedBox(height: 24),
        _listeAttente(context),
        const SizedBox(height: 24),
        _titreSection(t(context, 'fiche.avisPatients')),
        const SizedBox(height: 10),
        ..._derniersAvis(context),
      ],
    );
  }

  /// En-tete praticien facon Doctolib : avatar, nom, specialite/ville, note.
  Widget _enteteMedecin(BuildContext context, Map<String, dynamic> medecin) {
    final texte = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tabibi.surface,
        borderRadius: BorderRadius.circular(Tabibi.r16),
        border: Border.all(color: Tabibi.bord),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarInitiales(medecin['nomComplet'] as String, taille: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medecin['nomComplet'] as String,
                    style: texte.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: Tabibi.texte)),
                const SizedBox(height: 4),
                Text(
                  medecinSousTitre(medecin),
                  style: const TextStyle(color: Tabibi.texteDoux),
                ),
                const SizedBox(height: 8),
                _ligneMoyenne(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte « Infos pratiques » : note, type, langues, paiement, teleconsultation
  /// (masquee si rien a afficher). Alimentee par les vraies donnees Supabase.
  Widget _infosPratiques(BuildContext context, Map<String, dynamic> m) {
    final note = m['note'];
    final avis = (m['nombreAvis'] as num?)?.toInt() ?? 0;
    final langues = (m['langues'] as List?)
            ?.whereType<String>()
            .map(_labelLangue)
            .where((v) => v.isNotEmpty)
            .toList() ??
        const <String>[];
    final paiements = <String>[
      if (m['accepteChifa'] == true) t(context, 'fiche.chifa'),
      if (m['accepteCarte'] == true) t(context, 'fiche.carte'),
      if (m['accepteEspeces'] == true) t(context, 'fiche.especes'),
    ];
    final type = _labelType(context, m['typeEntite']?.toString());

    final lignes = <Widget>[];
    if (note is num) {
      final noteTxt = avis > 0
          ? '${note.toStringAsFixed(1)} · ${t(context, 'fiche.avisN', params: {'n': avis})}'
          : note.toStringAsFixed(1);
      lignes.add(_ligneInfo(Icons.star_rounded, Tabibi.or, noteTxt));
    }
    if (type != null) {
      lignes.add(_ligneInfo(Icons.local_hospital_outlined, Tabibi.vert, type));
    }
    if (langues.isNotEmpty) {
      lignes.add(_ligneChips(Icons.translate, langues));
    }
    if (paiements.isNotEmpty) {
      lignes.add(_ligneChips(Icons.payments_outlined, paiements));
    }
    if (m['teleconsultation'] == true) {
      lignes.add(_ligneInfo(
          Icons.videocam_outlined, Tabibi.vert, t(context, 'fiche.teleDispo')));
    }
    if (lignes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Tabibi.surface,
          borderRadius: BorderRadius.circular(Tabibi.r16),
          border: Border.all(color: Tabibi.bord),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < lignes.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              lignes[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _ligneInfo(IconData icone, Color couleur, String texte) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icone, size: 18, color: couleur),
      const SizedBox(width: 10),
      Expanded(
        child: Text(texte,
            style: const TextStyle(
                color: Tabibi.texte, fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _ligneChips(IconData icone, List<String> valeurs) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icone, size: 18, color: Tabibi.texte3),
      const SizedBox(width: 10),
      Expanded(
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final v in valeurs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Tabibi.pastille,
                  borderRadius: BorderRadius.circular(999)),
              child: Text(v,
                  style: const TextStyle(
                      color: Tabibi.vertFonce,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    ]);
  }

  /// Type d'etablissement en francais ; null pour un medecin ordinaire (deja implicite).
  String? _labelType(BuildContext context, String? brut) {
    if (brut == null || brut.trim().isEmpty) return null;
    const cles = {
      'dentist': 'fiche.typeDentiste',
      'clinic': 'fiche.typeClinique',
      'hospital': 'fiche.typeHopital',
      'optician': 'fiche.typeOpticien',
      'pharmacy': 'fiche.typePharmacie',
      'lab': 'fiche.typeLabo',
      'laboratory': 'fiche.typeLabo',
      'health_center': 'fiche.typeCentre',
      'midwife': 'fiche.typeSageFemme',
      'physiotherapist': 'fiche.typeKine',
    };
    final cle = cles[brut.toLowerCase()];
    return cle == null ? null : t(context, cle);
  }

  String _labelLangue(String code) {
    const map = {
      'fr': 'Français',
      'ar': 'العربية',
      'en': 'English',
      'ber': 'Tamazight',
      'kab': 'Tamazight',
      'es': 'Español',
    };
    return map[code.toLowerCase()] ?? code;
  }

  Widget _titreSection(String titre) {
    return Text(titre,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.ink));
  }

  Widget _infoVide(String texte) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tabibi.bg2,
        borderRadius: BorderRadius.circular(Tabibi.r12),
      ),
      child: Text(texte, style: const TextStyle(color: Tabibi.texteDoux)),
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
        Text(
          formaterMoyenne(langueDe(context), avis),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  /// Derniers avis anonymes (note, commentaire, date), ou un texte d'etat.
  List<Widget> _derniersAvis(BuildContext context) {
    final avis = _avis;
    if (avis == null) return [Text(t(context, 'fiche.avisIndisponibles'))];
    if (!avis.aDesAvis || avis.avis.isEmpty) return [Text(t(context, 'fiche.aucunAvis'))];
    return [for (final a in avis.avis.take(nombreAvisAffiches)) _carteAvis(context, a)];
  }

  /// Un avis anonyme : « 4 / 5 », commentaire s'il existe, date de depot.
  Widget _carteAvis(BuildContext context, Avis a) {
    final langue = langueDe(context);
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
                Text(formaterNote(langue, a.note), style: texte.titleSmall),
              ],
            ),
            if (commentaire != null) ...[
              const SizedBox(height: 4),
              Text(commentaire),
            ],
            const SizedBox(height: 4),
            Text(dateAvis(langue, a), style: texte.bodySmall),
          ],
        ),
      ),
    );
  }

  /// Liste d'attente, surtout utile quand aucun creneau n'est disponible : rappel de ce
  /// qu'elle promet, puis bouton « M'inscrire sur la liste d'attente » ou, une fois inscrit,
  /// texte d'etat.
  Widget _listeAttente(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, 'fiche.listeAttente'), style: texte.titleMedium),
        const SizedBox(height: 4),
        Text(t(context, 'fiche.texteListeAttente'), style: texte.bodySmall),
        const SizedBox(height: 8),
        if (_inscrit)
          Text(t(context, 'fiche.inscrit'))
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
              label: Text(t(context, 'fiche.inscrire')),
            ),
          ),
      ],
    );
  }

  /// « Ouvrir une conversation » (messagerie avec ce praticien), aligne du cote du debut.
  Widget _boutonConversation(BuildContext context) {
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
        label: Text(t(context, 'fiche.ouvrirConversation')),
      ),
    );
  }

  Widget _creneauTile(BuildContext context, Map<String, dynamic> creneau) {
    final enCours = _enCours == identifiant(creneau['id']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tabibi.surface,
        borderRadius: BorderRadius.circular(Tabibi.r12),
        border: Border.all(color: Tabibi.bord),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
            child: const Icon(Icons.schedule, size: 20, color: Tabibi.vert),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formaterDateIso(langueDe(context), creneau['debut'] as String),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Tabibi.texte)),
                Text(t(context, 'fiche.duree', params: {'n': creneau['dureeMinutes']}),
                    style: const TextStyle(color: Tabibi.texte3, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _enCours == null ? () => _reserver(creneau) : null,
            child: enCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t(context, 'fiche.reserver')),
          ),
        ],
      ),
    );
  }
}
