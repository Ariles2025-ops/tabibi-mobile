import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/espace_pro.dart';
import '../../utils/identifiants.dart';
import '../../utils/libelles.dart';
import '../../utils/rendez_vous.dart' show estAnnule;
import 'cabinet.dart';
import 'outils_espace.dart';

/// Actions du cabinet sur un rendez-vous confirme.
enum ActionRdv { honorer, absent, annuler, deplacer }

/// Agenda du cabinet (medecin connecte, ou medecin choisi par une secretaire) : rendez-vous en
/// sections Aujourd'hui / À venir / Passés, nom du patient quand il est connu ; sur un rendez-vous confirme
/// (RESERVE compris) : « Marquer honoré », « Absent », « Annuler » (avec confirmation) et, tant qu'il n'a pas
/// commence, « Déplacer » vers un autre créneau libre (comme sur le site).
class AgendaPage extends StatefulWidget {
  const AgendaPage({
    super.key,
    this.cabinet = const Cabinet.duMedecin(),
    this.api = const ApiService(),
    this.auth,
    this.maintenant,
  });

  final Cabinet cabinet;
  final ApiService api;
  final AuthService? auth;

  /// Horloge (tests) ; par defaut l'heure du telephone.
  final DateTime Function()? maintenant;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;

  List<Map<String, dynamic>> _rdvs = [];
  final Map<String, String> _patients = {};

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  Future<void> recharger() async {
    final rdvs = await chargerAvec((j) => widget.cabinet.agenda(widget.api, j));
    if (rdvs == null || !mounted) return;
    await _chargerPatients();
    if (mounted) setState(() => _rdvs = rdvs);
  }

  /// Noms des patients du cabinet ; un echec laisse « Patient » et l'identifiant abrege.
  Future<void> _chargerPatients() async {
    final jeton = auth.accessToken;
    if (jeton == null) return;
    try {
      for (final p in await widget.cabinet.patients(widget.api, jeton)) {
        final Object? nom = p['nomComplet'];
        if (nom is String && nom.isNotEmpty) _patients[identifiant(p['patientId'])] = nom;
      }
    } on Exception {
      // Noms indisponibles.
    }
  }

  String _patient(Map<String, dynamic> rdv) {
    final saisi = rdv['nomPatient'];
    if (saisi is String && saisi.trim().isNotEmpty) return saisi.trim();
    final id = identifiant(rdv['patientId']);
    return _patients[id] ?? t('Patient ${abreger(id)}', 'مريض ${abreger(id)}');
  }

  /// Déplacer : choix d'un autre créneau libre du cabinet, confirmation, puis POST .../deplacer.
  /// Si le créneau vient d'être pris (409), rien ne change et on le dit.
  Future<void> _deplacer(Map<String, dynamic> rdv) async {
    final id = identifiant(rdv['id']);
    final maintenant = (widget.maintenant ?? DateTime.now)();
    final creneaux = await appeler((j) => widget.cabinet.creneaux(widget.api, j));
    if (creneaux == null || !mounted) return;
    final libres = creneauxPourDeplacer(creneaux, rdv, maintenant);
    final choisi = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('Choisir un nouveau créneau', 'اختر موعدًا جديدًا')),
        children: libres.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(t('Aucun autre créneau disponible pour le moment.',
                      'لا توجد مواعيد أخرى متاحة حاليًا.')),
                ),
              ]
            : [
                for (final c in libres)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, c),
                    child: Text(formaterDateIso('${c['debut']}')),
                  ),
              ],
      ),
    );
    if (choisi == null || !mounted) return;
    final nouvelleDate = formaterDateIso('${choisi['debut']}');
    // Rendez-vous pris par téléphone : le patient n'a pas de compte, personne ne le prévient.
    final telephone = '${rdv['source']}'.trim().toUpperCase() == 'TELEPHONE';
    final ok = await confirmer(
      t('Déplacer ce rendez-vous ?', 'نقل هذا الموعد؟'),
      '${_patient(rdv)}\n${formaterDateIso('${rdv['debut']}')} → $nouvelleDate\n'
      '${telephone ? t('Pensez à prévenir le patient par téléphone.', 'يرجى إبلاغ المريض هاتفيًا.') : t('Le patient sera prévenu.', 'سيتم إعلام المريض.')}',
      t('Oui, déplacer', 'نعم، انقل'),
    );
    if (!ok) return;
    final fait = await appeler<bool>((j) async {
      try {
        await widget.cabinet.deplacer(widget.api, id, identifiant(choisi['id']), j);
        return true;
      } on ApiException catch (e) {
        if (!e.conflit) rethrow;
        message(t("Ce créneau vient d'être pris. Le rendez-vous n'a pas changé : choisissez un autre créneau.",
            'تم حجز هذا الموعد للتو. لم يتغيّر الموعد: اختر موعدًا آخر.'));
        return false;
      }
    });
    if (fait == true) {
      message(t('Rendez-vous déplacé au $nouvelleDate', 'تم نقل الموعد إلى $nouvelleDate'));
    }
    if (fait != null) await recharger();
  }

  Future<void> _agir(Map<String, dynamic> rdv, ActionRdv action) async {
    if (action == ActionRdv.deplacer) return _deplacer(rdv);
    final id = identifiant(rdv['id']);
    if (action == ActionRdv.annuler) {
      // Rendez-vous pris par téléphone : le patient n'a pas de compte et l'API ne lui envoie
      // aucun message ; comme sur le site, on ne prétend donc pas qu'il sera prévenu.
      final telephone = '${rdv['source']}'.trim().toUpperCase() == 'TELEPHONE';
      final date = formaterDateIso('${rdv['debut']}');
      final ok = await confirmer(
        t('Annuler ce rendez-vous ?', 'إلغاء هذا الموعد؟'),
        telephone
            ? t('${_patient(rdv)}\n$date\nPensez à prévenir le patient par téléphone.',
                '${_patient(rdv)}\n$date\nيرجى إبلاغ المريض هاتفيًا.')
            : t('${_patient(rdv)}\n$date\nLe patient sera prévenu.',
                '${_patient(rdv)}\n$date\nسيتم إعلام المريض.'),
        t('Oui, annuler', 'نعم، إلغاء'),
      );
      if (!ok) return;
    }
    if (action == ActionRdv.absent) {
      // Irréversible : confirmation, comme sur le site.
      final ok = await confirmer(
        t('Signaler le patient absent à ce rendez-vous ?', 'تسجيل غياب المريض عن هذا الموعد؟'),
        '${_patient(rdv)}\n${formaterDateIso('${rdv['debut']}')}',
        t('Oui', 'نعم'),
      );
      if (!ok) return;
    }
    final c = widget.cabinet;
    final fait = await appeler<bool>((j) async {
      switch (action) {
        case ActionRdv.honorer:
          await c.honorer(widget.api, id, j);
        case ActionRdv.absent:
          await c.absent(widget.api, id, j);
        case ActionRdv.annuler:
          await c.annuler(widget.api, id, j);
        case ActionRdv.deplacer:
          break; // traité plus haut par _deplacer
      }
      return true;
    });
    if (fait != true) return;
    final date = formaterDateIso('${rdv['debut']}');
    message(switch (action) {
      ActionRdv.honorer => t('Rendez-vous du $date marqué honoré.', 'تم تسجيل حضور المريض للموعد في $date.'),
      ActionRdv.absent => t('Patient signalé absent au rendez-vous du $date.', 'تم تسجيل غياب المريض عن الموعد في $date.'),
      ActionRdv.annuler => t('Rendez-vous annulé', 'تم إلغاء الموعد'),
      ActionRdv.deplacer => '',
    });
    await recharger();
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.cabinet.nomMedecin;
    return Scaffold(
      appBar: AppBar(
        title: Text(nom == null ? t('Agenda', 'المواعيد') : t('Agenda · $nom', 'مواعيد · $nom')),
        actions: actionsActualiser(),
      ),
      body: corps(
          t('Connectez-vous pour consulter l\'agenda.', 'سجّل الدخول لعرض المواعيد.'), _liste),
    );
  }

  Widget _liste() {
    if (_rdvs.isEmpty) return VueVide(t('Aucun rendez-vous.', 'لا توجد مواعيد.'));
    final c = classerAgenda(_rdvs, (widget.maintenant ?? DateTime.now)());
    // Entrees : un titre de section (String) ou un rendez-vous.
    final entrees = <Object>[
      if (c.aujourdhui.isNotEmpty) ...[t("Aujourd'hui", 'اليوم'), ...c.aujourdhui],
      if (c.aVenir.isNotEmpty) ...[t('À venir', 'القادمة'), ...c.aVenir],
      if (c.passes.isNotEmpty) ...[t('Passés', 'السابقة'), ...c.passes],
    ];
    return RefreshIndicator(
      onRefresh: recharger,
      child: ListView.builder(
        itemCount: entrees.length,
        itemBuilder: (_, i) {
          final e = entrees[i];
          if (e is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(e, style: Theme.of(context).textTheme.titleSmall),
            );
          }
          return _ligne(e as Map<String, dynamic>);
        },
      ),
    );
  }

  Widget _ligne(Map<String, dynamic> rdv) {
    final grise = estAnnule(rdv['statut']) ? Theme.of(context).disabledColor : null;
    return ListTile(
      leading: Icon(Icons.event, color: grise),
      title: Text(formaterDateIso('${rdv['debut']}'), style: TextStyle(color: grise)),
      subtitle: Text('${_patient(rdv)} · ${libelleStatut(statutAgenda(rdv['statut']))}',
          style: TextStyle(color: grise)),
      trailing: actionsCabinetPossibles(rdv['statut'])
          ? PopupMenuButton<ActionRdv>(
              tooltip: t('Actions', 'إجراءات'),
              onSelected: (a) => _agir(rdv, a),
              itemBuilder: (_) => [
                // Seulement une fois l'heure du rendez-vous atteinte (comme le site).
                if (rdvCommence(rdv['debut'], (widget.maintenant ?? DateTime.now)())) ...[
                  PopupMenuItem(value: ActionRdv.honorer, child: Text(t('Marquer honoré', 'تسجيل الحضور'))),
                  PopupMenuItem(value: ActionRdv.absent, child: Text(t('Patient absent', 'المريض غائب'))),
                ],
                if (peutDeplacerCabinet(rdv['statut'], rdv['debut'], (widget.maintenant ?? DateTime.now)()))
                  PopupMenuItem(value: ActionRdv.deplacer, child: Text(t('Déplacer', 'نقل'))),
                PopupMenuItem(value: ActionRdv.annuler, child: Text(t('Annuler', 'إلغاء'))),
              ],
            )
          : null,
    );
  }
}
