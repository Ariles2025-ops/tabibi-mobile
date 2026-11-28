import 'package:flutter/material.dart';

import '../config/lancement.dart';
import '../config/theme.dart';
import '../i18n/langue.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/espace_pro.dart';
import '../utils/notifications.dart';
import '../widgets/composants.dart';
import '../widgets/liens_legaux.dart';
import '../widgets/selecteur_langue.dart';
import 'dawini_page.dart';
import 'espace/cabinet_pages.dart';
import 'espace/mon_espace_page.dart';
import 'mes_avis_page.dart';
import 'mes_conversations_page.dart';
import 'mes_listes_attente_page.dart';
import 'mes_notifications_page.dart';
import 'mes_teleconsultations_page.dart';
import 'mon_profil_page.dart';
import 'verifier_ordonnance_page.dart';

/// Onglet « Compte » : connexion, puis toutes les entrees personnelles regroupees
/// (activite, services, reglages), comme dans les grandes applis de sante.
class ComptePage extends StatefulWidget {
  const ComptePage({super.key, this.api = const ApiService(), this.auth, this.onTrouverPraticien});

  final ApiService api;

  /// Ramene a la recherche (onglet Accueil) ; propose « Trouver un praticien » dans les pages vides.
  final VoidCallback? onTrouverPraticien;
  final AuthService? auth;

  @override
  State<ComptePage> createState() => _ComptePageState();
}

class _ComptePageState extends State<ComptePage> {
  late final AuthService _auth = widget.auth ?? session;
  Map<String, dynamic>? _moi;
  int? _nonLues;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final token = _auth.accessToken;
    if (token == null) {
      if (mounted) setState(() => _moi = null);
      return;
    }
    try {
      final moi = await widget.api.moi(token);
      int? nonLues;
      try {
        nonLues = await widget.api.nombreNonLues(token);
      } on Exception {
        nonLues = null;
      }
      if (mounted) {
        setState(() {
          _moi = moi;
          _nonLues = nonLues;
        });
      }
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      if (mounted) setState(() {});
    } on Exception {
      // Identite indisponible : l'en-tete reste generique.
    }
  }

  Future<void> _seConnecter() async {
    final ok = await _auth.seConnecter();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('Connexion annulée', 'تم إلغاء تسجيل الدخول'))));
    }
    await _charger();
  }

  Future<void> _seDeconnecter() async {
    await _auth.seDeconnecterCompletement();
    if (mounted) setState(() => _moi = null);
  }

  Future<void> _ouvrir(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final connecte = _auth.estConnecte;
    final roles = _moi == null ? <String>{} : rolesDe(_moi!);
    final api = widget.api;
    final pro = comptePro(roles);
    final espacePro = aUnEspacePro(roles);
    return Scaffold(
      appBar: AppBar(title: Text(t('Mon compte', 'حسابي'))),
      body: RefreshIndicator(
        color: Charte.vert,
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _EnTeteCompte(
              connecte: connecte,
              nom: (_moi?['nom']?.toString() ?? '').trim(),
              roles: libelleRoles(roles),
              onConnexion: _seConnecter,
            ),
            const SizedBox(height: 24),
            _Groupe(titre: t('Mon activité', 'نشاطي'), entrees: [
              if (aUnEspacePro(roles))
                _Entree(Icons.work_outline, t('Mon espace', 'فضائي'),
                    () => _ouvrir(MonEspacePage(api: api, auth: _auth))),
              _Entree(
                  Icons.notifications_outlined,
                  libelleNotifications(_nonLues),
                  () => _ouvrir(MesNotificationsPage(api: api, auth: _auth))),
              // Comme le site : la messagerie est reservee aux patients et aux medecins.
              if (peutUtiliserMessagerie(roles))
                _Entree(Icons.chat_bubble_outline, t('Messagerie', 'الرسائل'),
                    () => _ouvrir(MesConversationsPage(api: api, auth: _auth))),
              _Entree(
                Icons.videocam_outlined,
                visioActive
                    ? t('Téléconsultations', 'الاستشارات عن بُعد')
                    : t('Téléconsultation', 'الاستشارة عن بُعد'),
                visioActive
                    ? () =>
                        _ouvrir(MesTeleconsultationsPage(api: api, auth: _auth))
                    : null,
                badge: visioActive ? null : t('Bientôt', 'قريبًا'),
              ),
              // Comme le site : « Mes avis » et « Mes listes d'attente » sont des pages de patient,
              // pas proposées à un compte professionnel (elles lui répondraient « réservée aux patients »).
              if (!pro) ...[
                _Entree(Icons.star_outline, t('Mes avis', 'آرائي'),
                    () => _ouvrir(MesAvisPage(api: api, auth: _auth))),
                _Entree(
                    Icons.hourglass_top_outlined,
                    t("Mes listes d'attente", 'قوائم الانتظار'),
                    () => _ouvrir(MesListesAttentePage(
                          api: api,
                          auth: _auth,
                          onTrouverPraticien: widget.onTrouverPraticien == null
                              ? null
                              : () {
                                  Navigator.of(context).popUntil((r) => r.isFirst);
                                  widget.onTrouverPraticien!();
                                },
                        ))),
              ],
              // Comme le site : un patient peut recevoir une invitation de cabinet (secrétaire) ;
              // un compte professionnel la trouve dans « Mon espace ».
              if (!espacePro)
                _Entree(
                    Icons.mail_outline,
                    t('Invitations de cabinet', 'دعوات العيادات'),
                    () => _ouvrir(InvitationsCabinetPage(api: api, auth: _auth))),
            ]),
            const SizedBox(height: 20),
            _Groupe(titre: t('Services', 'الخدمات'), entrees: [
              if (!pro)
                _Entree(
                    Icons.local_pharmacy_outlined,
                    t('Dawini (pharmacies)', 'داويني (الصيدليات)'),
                    () => _ouvrir(DawiniPage(api: api, auth: _auth))),
              _Entree(
                  Icons.verified_outlined,
                  t('Vérifier une ordonnance', 'التحقق من وصفة طبية'),
                  () => _ouvrir(VerifierOrdonnancePage(api: api))),
            ]),
            const SizedBox(height: 20),
            _Groupe(titre: t('Réglages', 'الإعدادات'), entrees: [
              _Entree(Icons.badge_outlined, t('Mon profil', 'ملفي الشخصي'),
                  () => _ouvrir(MonProfilPage(api: api, auth: _auth))),
            ]),
            const SizedBox(height: 12),
            const ChampLangue(),
            if (connecte) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _seDeconnecter,
                icon: const Icon(Icons.logout),
                label: Text(t('Se déconnecter', 'تسجيل الخروج')),
              ),
            ],
            const SizedBox(height: 24),
            const LiensLegaux(),
          ],
        ),
      ),
    );
  }
}

/// Carte d'en-tete : identite si connecte, sinon invitation a se connecter.
class _EnTeteCompte extends StatelessWidget {
  const _EnTeteCompte(
      {required this.connecte,
      required this.nom,
      required this.onConnexion,
      this.roles = ''});

  final bool connecte;
  final String nom;

  /// Roles metier deja formates (« Rôle : Médecin ») ; vide tant qu'ils sont inconnus.
  final String roles;
  final VoidCallback onConnexion;

  @override
  Widget build(BuildContext context) {
    final clair = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Charte.degrade,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Charte.ombreCarte,
      ),
      child: connecte
          ? Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: clair.withValues(alpha: 0.18),
                child: Text(AvatarInitiales.initiales(nom.isEmpty ? '?' : nom),
                    style: TextStyle(
                        color: clair,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom.isEmpty ? t('Bienvenue', 'مرحبًا') : nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: clair,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(t('Compte connecté', 'الحساب متصل'),
                          style: TextStyle(
                              color: clair.withValues(alpha: 0.85),
                              fontSize: 14)),
                      if (roles.isNotEmpty)
                        Text(roles,
                            style: TextStyle(
                                color: clair.withValues(alpha: 0.85),
                                fontSize: 14)),
                    ]),
              ),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Bienvenue sur Ndawik', 'مرحبًا بك في نداويك'),
                  style: TextStyle(
                      color: clair, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  t('Connectez-vous pour retrouver vos rendez-vous, ordonnances et messages.',
                      'سجّل الدخول لتجد مواعيدك ووصفاتك ورسائلك.'),
                  style: TextStyle(
                      color: clair.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.4)),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Charte.vertFonce),
                onPressed: onConnexion,
                child: Text(t('Se connecter', 'تسجيل الدخول')),
              ),
            ]),
    );
  }
}

class _Entree {
  const _Entree(this.icone, this.libelle, this.action, {this.badge});
  final IconData icone;
  final String libelle;
  final VoidCallback? action;
  final String? badge;
}

/// Groupe d'entrees dans une carte, separees par un trait fin.
class _Groupe extends StatelessWidget {
  const _Groupe({required this.titre, required this.entrees});

  final String titre;
  final List<_Entree> entrees;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Text(titre.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Charte.meta,
                letterSpacing: 0.6)),
      ),
      Container(
        decoration: Charte.carte(),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < entrees.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 64),
              ListTile(
                enabled: entrees[i].action != null,
                onTap: entrees[i].action,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: Charte.pastille,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(entrees[i].icone, size: 20, color: Charte.vert),
                ),
                title: Text(entrees[i].libelle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                trailing: entrees[i].badge != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Charte.orClair,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(entrees[i].badge!,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Charte.orTexte)),
                      )
                    : const Icon(Icons.chevron_right,
                        color: Charte.placeholder),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}
