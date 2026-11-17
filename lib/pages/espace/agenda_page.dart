import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/espace_pro.dart';
import '../../utils/identifiants.dart';
import '../../utils/libelles.dart';
import 'cabinet.dart';
import 'outils_espace.dart';

/// Actions du cabinet sur un rendez-vous confirme.
enum ActionRdv { honorer, absent, annuler }

/// Agenda du cabinet (medecin connecte, ou medecin choisi par une secretaire) : rendez-vous du
/// plus proche au plus lointain, nom du patient quand il est connu ; sur un rendez-vous confirme
/// (RESERVE compris) : « Patient venu », « Absent », « Annuler » (avec confirmation).
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
    if (mounted) setState(() => _rdvs = trierParDebut(rdvs));
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

  Future<void> _agir(Map<String, dynamic> rdv, ActionRdv action) async {
    final id = identifiant(rdv['id']);
    if (action == ActionRdv.annuler) {
      final ok = await confirmer(
        t('Annuler ce rendez-vous ?', 'إلغاء هذا الموعد؟'),
        t('${_patient(rdv)}\n${formaterDateIso('${rdv['debut']}')}\nLe patient sera prévenu.',
            '${_patient(rdv)}\n${formaterDateIso('${rdv['debut']}')}\nسيتم إعلام المريض.'),
        t('Oui, annuler', 'نعم، إلغاء'),
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
      }
      return true;
    });
    if (fait != true) return;
    message(switch (action) {
      ActionRdv.honorer => t('Rendez-vous honoré', 'تم تأكيد حضور المريض'),
      ActionRdv.absent => t('Patient marqué absent', 'تم تسجيل غياب المريض'),
      ActionRdv.annuler => t('Rendez-vous annulé', 'تم إلغاء الموعد'),
    });
    await recharger();
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.cabinet.nomMedecin;
    return Scaffold(
      appBar: AppBar(
        title: Text(nom == null ? t('Mon agenda', 'مواعيدي') : t('Agenda · $nom', 'مواعيد · $nom')),
        actions: actionsActualiser(),
      ),
      body: corps(
          t('Connectez-vous pour consulter l\'agenda.', 'سجّل الدخول لعرض المواعيد.'), _liste),
    );
  }

  Widget _liste() {
    if (_rdvs.isEmpty) return VueVide(t('Aucun rendez-vous.', 'لا توجد مواعيد.'));
    return RefreshIndicator(
      onRefresh: recharger,
      child: ListView.separated(
        itemCount: _rdvs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final rdv = _rdvs[i];
          return ListTile(
            leading: const Icon(Icons.event),
            title: Text(formaterDateIso('${rdv['debut']}')),
            subtitle: Text('${_patient(rdv)} · ${libelleStatut(statutAgenda(rdv['statut']))}'),
            trailing: actionsCabinetPossibles(rdv['statut'])
                ? PopupMenuButton<ActionRdv>(
                    tooltip: t('Actions', 'إجراءات'),
                    onSelected: (a) => _agir(rdv, a),
                    itemBuilder: (_) => [
                      // Seulement une fois l'heure du rendez-vous atteinte (comme le site).
                      if (rdvCommence(rdv['debut'], (widget.maintenant ?? DateTime.now)())) ...[
                        PopupMenuItem(
                            value: ActionRdv.honorer,
                            child: Text(t('Patient venu', 'حضر المريض'))),
                        PopupMenuItem(value: ActionRdv.absent, child: Text(t('Absent', 'غائب'))),
                      ],
                      PopupMenuItem(value: ActionRdv.annuler, child: Text(t('Annuler', 'إلغاء'))),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }
}
