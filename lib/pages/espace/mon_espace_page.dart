import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/espace_pro.dart';
import 'agenda_page.dart';
import 'avis_medecin_page.dart';
import 'cabinet_pages.dart';
import 'creneaux_page.dart';
import 'fiche_semaine_pages.dart';
import 'outils_espace.dart';
import 'pharmacie_pages.dart';

/// « Mon espace » : entrees selon les roles du compte (GET /api/moi) ; medecin (agenda,
/// creneaux, liste d'attente), secretaire (cabinets), pharmacie (besoins Dawini, delivrance) ;
/// les invitations de cabinet sont proposees a tout compte connecte.
class MonEspacePage extends StatefulWidget {
  const MonEspacePage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<MonEspacePage> createState() => _MonEspacePageState();
}

class _MonEspacePageState extends State<MonEspacePage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  List<Espace> _espaces = [];

  /// Faux quand GET /api/medecin/fiche repond 404 : « Ma fiche » est alors cachee.
  bool _ficheDispo = true;

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  Future<void> recharger() async {
    final moi = await chargerAvec((j) => widget.api.moi(j));
    if (moi == null || !mounted) return;
    final espaces = espacesPour(rolesDe(moi));
    setState(() => _espaces = espaces);
    if (espaces.contains(Espace.medecin)) await _sonderFiche();
  }

  /// La route « fiche » peut ne pas exister encore : un 404 cache l'entree, toute autre
  /// reponse (ou erreur reseau) la laisse visible.
  Future<void> _sonderFiche() async {
    final jeton = auth.accessToken;
    if (jeton == null) return;
    var dispo = true;
    try {
      await widget.api.ficheMedecin(jeton);
    } on ApiException catch (e) {
      dispo = !e.introuvable;
    } on Exception {
      // Reseau : on garde l'entree.
    }
    if (mounted) setState(() => _ficheDispo = dispo);
  }

  Future<void> _ouvrir(Widget page) async {
    final sortie = await Navigator.of(context).push<Object?>(MaterialPageRoute<Object?>(builder: (_) => page));
    if (!mounted) return;
    setState(() {
      if (sortie is SortieEcran && sortie.indisponible) _ficheDispo = false;
    });
  }

  Widget _entree(IconData icone, String titre, String sousTitre, Widget page) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icone, color: Theme.of(context).colorScheme.primary),
          title: Text(titre),
          subtitle: Text(sousTitre),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _ouvrir(page),
        ),
      );

  Widget _section(String titre) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(titre, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return Scaffold(
      appBar: AppBar(title: Text(t('Mon espace', 'فضائي')), actions: actionsActualiser()),
      body: corps(t('Connectez-vous pour ouvrir votre espace.', 'سجّل الدخول لفتح فضائك.'), () {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_espaces.contains(Espace.medecin)) ...[
              _section(t('Espace médecin', 'فضاء الطبيب')),
              _entree(
                  Icons.event_note,
                  t('Agenda', 'المواعيد'),
                  t('Rendez-vous de vos patients', 'مواعيد مرضاك'),
                  AgendaPage(api: api, auth: auth)),
              _entree(
                  Icons.schedule,
                  t('Disponibilités', 'الأوقات المتاحة'),
                  t('Ouvrir ou supprimer des créneaux', 'فتح أو حذف مواعيد متاحة'),
                  CreneauxPage(api: api, auth: auth)),
              _entree(
                  Icons.hourglass_top_outlined,
                  t("Liste d'attente", 'قائمة الانتظار'),
                  t('Patients en attente d\'un créneau', 'مرضى ينتظرون موعدًا'),
                  ListeAttenteMedecinPage(api: api, auth: auth)),
              _entree(
                  Icons.star_outline,
                  t('Avis des patients', 'آراء المرضى'),
                  t('Avis publiés sur votre fiche, signalement',
                      'الآراء المنشورة على بطاقتك والإبلاغ عنها'),
                  AvisMedecinPage(api: api, auth: auth)),
              if (_ficheDispo)
                _entree(
                    Icons.badge_outlined,
                    t('Ma fiche', 'بطاقتي'),
                    t('Adresse, téléphone, horaires, présentation et langues',
                        'العنوان والهاتف وأوقات العمل والتعريف واللغات'),
                    MaFichePage(api: api, auth: auth)),
            ],
            if (_espaces.contains(Espace.secretaire)) ...[
              _section(t('Espace secrétaire', 'فضاء السكرتارية')),
              _entree(
                  Icons.business_outlined,
                  t('Agenda du cabinet', 'مواعيد العيادة'),
                  t('Agenda et créneaux des médecins', 'مواعيد الأطباء وأوقاتهم المتاحة'),
                  CabinetsPage(api: api, auth: auth)),
            ],
            if (_espaces.contains(Espace.pharmacie)) ...[
              _section(t('Espace pharmacie', 'فضاء الصيدلية')),
              _entree(
                  Icons.local_pharmacy_outlined,
                  t('Besoins Dawini', 'طلبات دَويني'),
                  t('Demandes de médicaments dans votre wilaya', 'طلبات الأدوية في ولايتك'),
                  BesoinsPharmaciePage(api: api, auth: auth)),
              _entree(
                  Icons.qr_code_2,
                  t('Délivrer une ordonnance', 'صرف وصفة طبية'),
                  t('Vérifier un code et marquer délivrée', 'التحقق من رمز وتسجيل الصرف'),
                  DelivrerOrdonnancePage(api: api, auth: auth)),
            ],
            if (_espaces.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(t('Votre compte est un compte patient : tout se passe sur l\'accueil.',
                    'حسابك حساب مريض: كل شيء متاح في الصفحة الرئيسية.')),
              ),
            _section(t('Cabinet', 'العيادة')),
            _entree(
                Icons.mail_outline,
                t('Invitations de cabinet', 'دعوات العيادات'),
                t('Rejoindre le cabinet d\'un médecin comme secrétaire',
                    'الانضمام إلى عيادة طبيب كسكرتيرة'),
                InvitationsCabinetPage(api: api, auth: auth)),
          ],
        );
      }),
    );
  }
}
