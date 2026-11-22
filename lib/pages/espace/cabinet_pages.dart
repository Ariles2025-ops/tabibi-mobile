import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/identifiants.dart';
import 'agenda_page.dart';
import 'cabinet.dart';
import 'creneaux_page.dart';
import 'outils_espace.dart';

/// Liste d'attente du medecin connecte : patients inscrits, les plus anciens d'abord.
class ListeAttenteMedecinPage extends StatefulWidget {
  const ListeAttenteMedecinPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<ListeAttenteMedecinPage> createState() => _ListeAttenteMedecinPageState();
}

class _ListeAttenteMedecinPageState extends State<ListeAttenteMedecinPage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  List<Map<String, dynamic>> _inscrits = [];
  final Map<String, Map<String, dynamic>> _patients = {};

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  Future<void> recharger() async {
    final l = await chargerAvec((j) => widget.api.listeAttenteMedecin(j));
    if (l == null || !mounted) return;
    try {
      for (final p in await widget.api.patientsMedecin(auth.accessToken ?? '')) {
        _patients[identifiant(p['patientId'])] = p;
      }
    } on Exception {
      // Noms indisponibles.
    }
    if (mounted) setState(() => _inscrits = l);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(t("Liste d'attente", 'قائمة الانتظار')), actions: actionsActualiser()),
      body: corps(
          t("Connectez-vous pour voir votre liste d'attente.", 'سجّل الدخول لعرض قائمة الانتظار.'),
          () {
        final intro = Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(t(
              "Patients qui attendent un créneau chez vous, du plus ancien au plus récent. Ils sont prévenus dès que vous ouvrez un créneau ou qu'un rendez-vous est annulé.",
              'المرضى الذين ينتظرون موعدًا عندك، من الأقدم إلى الأحدث. يتم إعلامهم فور فتحك موعدًا أو إلغاء موعد.')),
        );
        if (_inscrits.isEmpty) {
          return ListView(children: [
            intro,
            VueVide(t("Aucun patient en liste d'attente pour le moment.",
                'لا يوجد مرضى في قائمة الانتظار حاليًا.')),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CreneauxPage(api: widget.api, auth: auth))),
                child: Text(t('Ouvrir des créneaux', 'فتح مواعيد')),
              ),
            ),
          ]);
        }
        final tries = [..._inscrits]..sort((x, y) => _dateInscription(x).compareTo(_dateInscription(y)));
        return ListView.separated(
          itemCount: tries.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, k) {
            if (k == 0) return intro;
            final i = k - 1;
            final ins = tries[i];
            final id = identifiant(ins['patientId']);
            final p = _patients[id];
            final nom =
                (p?['nomComplet'] as String?) ?? t('Patient ${abreger(id)}', 'مريض ${abreger(id)}');
            final tel = p?['telephone'] as String?;
            final date = DateTime.tryParse('${ins['inscritLe']}');
            return ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(nom),
              subtitle: Text([
                if (tel != null && tel.isNotEmpty) tel,
                if (date != null)
                  t('Inscrit le ${formaterDateHeure(date)}', 'سُجّل في ${formaterDateHeure(date)}'),
              ].join(' · ')),
            );
          },
        );
      }),
    );
  }

  /// Date d'inscription ; une date absente ou illisible passe en fin de liste.
  static DateTime _dateInscription(Map<String, dynamic> ins) =>
      DateTime.tryParse('${ins['inscritLe']}') ?? DateTime.utc(9999);
}

/// Cabinets de la secretaire connectee : pour chacun, l'agenda et les creneaux du medecin.
class CabinetsPage extends StatefulWidget {
  const CabinetsPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<CabinetsPage> createState() => _CabinetsPageState();
}

class _CabinetsPageState extends State<CabinetsPage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  List<Map<String, dynamic>> _cabinets = [];
  Map<String, String> _noms = {};

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  Future<void> recharger() async {
    final c = await chargerAvec((j) => widget.api.cabinetsSecretaire(j));
    if (c == null || !mounted) return;
    final noms = await nomsMedecins(widget.api, c.map((r) => identifiant(r['medecinId'])));
    if (mounted) {
      setState(() {
        _cabinets = c;
        _noms = noms;
      });
    }
  }

  Future<void> _ouvrir(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Agenda du cabinet', 'مواعيد العيادة')), actions: actionsActualiser()),
      body: corps(t('Connectez-vous pour gérer vos cabinets.', 'سجّل الدخول لإدارة العيادات.'), () {
        if (_cabinets.isEmpty) {
          return VueVide(t('Aucun médecin ne vous a encore rattachée à son cabinet. Communiquez-lui l\'adresse e-mail de votre compte Ndawik.',
              'لم يربطك أي طبيب بعيادته بعد. أعطيه عنوان البريد الإلكتروني لحسابك في نداويك.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final r in _cabinets) _carte(identifiant(r['medecinId'])),
          ],
        );
      }),
    );
  }

  Widget _carte(String medecinId) {
    final nom = _noms[medecinId] ?? libelleMedecin(medecinId);
    final cabinet = Cabinet.pourSecretaire(medecinId, nomMedecin: nom);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nom, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: () => _ouvrir(AgendaPage(cabinet: cabinet, api: widget.api, auth: auth)),
                icon: const Icon(Icons.event_note),
                label: Text(t('Agenda', 'المواعيد')),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _ouvrir(CreneauxPage(cabinet: cabinet, api: widget.api, auth: auth)),
                icon: const Icon(Icons.schedule),
                label: Text(t('Créneaux', 'المواعيد المتاحة')),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Invitations a rejoindre le cabinet d'un medecin (tout compte connecte) : accepter donne
/// l'espace secretaire (jeton renouvele aussitot ; repli : a la prochaine connexion), refuser fait disparaitre l'invitation.
class InvitationsCabinetPage extends StatefulWidget {
  const InvitationsCabinetPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<InvitationsCabinetPage> createState() => _InvitationsCabinetPageState();
}

class _InvitationsCabinetPageState extends State<InvitationsCabinetPage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  List<Map<String, dynamic>> _invitations = [];
  Map<String, String> _noms = {};

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  Future<void> recharger() async {
    final l = await chargerAvec((j) => widget.api.invitationsCabinet(j));
    if (l == null || !mounted) return;
    final noms = await nomsMedecins(widget.api, l.map((r) => identifiant(r['medecinId'])));
    if (mounted) {
      setState(() {
        _invitations = l;
        _noms = noms;
      });
    }
  }

  Future<void> _repondre(Map<String, dynamic> inv, {required bool accepter}) async {
    final id = identifiant(inv['id']);
    final fait = await appeler((j) async {
      accepter
          ? await widget.api.accepterInvitation(id, j)
          : await widget.api.refuserInvitation(id, j);
      return true;
    });
    if (fait != true) return;
    if (accepter && await auth.rafraichir()) {
      // Comme le site : le jeton renouvelé porte déjà le rôle SECRETAIRE, l'espace s'ouvre seul.
      message(t('Invitation acceptée : votre espace secrétaire est ouvert.',
          'تم قبول الدعوة: تم فتح فضاء السكرتارية.'));
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    message(accepter
        ? t('Invitation acceptée : reconnectez-vous pour ouvrir l\'espace secrétaire.',
            'تم قبول الدعوة: أعد تسجيل الدخول لفتح فضاء السكرتارية.')
        : t('Invitation refusée : le médecin est prévenu.', 'تم رفض الدعوة وتم إعلام الطبيب.'));
    await recharger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(t('Invitations de cabinet', 'دعوات العيادات')), actions: actionsActualiser()),
      body: corps(t('Connectez-vous pour voir vos invitations.', 'سجّل الدخول لعرض دعواتك.'), () {
        if (_invitations.isEmpty) {
          return VueVide(t('Aucune invitation en attente.', 'لا توجد دعوات في الانتظار.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final inv in _invitations)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('${_nom(inv)} vous invite à gérer l\'agenda de son cabinet.',
                            '${_nom(inv)} يدعوك لإدارة عيادته.'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        FilledButton(
                          onPressed: () => _repondre(inv, accepter: true),
                          child: Text(t('Accepter', 'قبول')),
                        ),
                        OutlinedButton(
                          onPressed: () => _repondre(inv, accepter: false),
                          child: Text(t('Refuser', 'رفض')),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  String _nom(Map<String, dynamic> inv) {
    final id = identifiant(inv['medecinId']);
    return _noms[id] ?? libelleMedecin(id);
  }
}
