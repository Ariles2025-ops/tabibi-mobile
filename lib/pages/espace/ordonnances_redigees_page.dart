import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../utils/espace_pro.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/identifiants.dart';
import '../../utils/libelles.dart';
import '../../utils/ordonnances.dart';
import 'nouvelle_ordonnance_page.dart';
import 'outils_espace.dart';

/// « Mes ordonnances rédigées » du site : ordonnances emises par le medecin connecte
/// (GET /api/medecin/ordonnances, les plus recentes d'abord), avec le nom du patient et
/// l'annulation (motif facultatif) tant que l'ordonnance est « Émise ».
class OrdonnancesRedigeesPage extends StatefulWidget {
  const OrdonnancesRedigeesPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<OrdonnancesRedigeesPage> createState() => _OrdonnancesRedigeesPageState();
}

class _OrdonnancesRedigeesPageState extends State<OrdonnancesRedigeesPage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  List<Map<String, dynamic>> _ordonnances = [];
  final Map<String, String> _patients = {};

  @override
  String libelleChargement(ApiException e) => messageChargement(e, PublicPage.medecins);

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  Future<void> recharger() async {
    final liste = await chargerAvec((j) => widget.api.ordonnancesRedigees(j));
    if (liste == null || !mounted) return;
    await _chargerPatients();
    if (mounted) setState(() => _ordonnances = trierParEmission(liste));
  }

  /// Noms des patients ; un echec laisse « Patient » et l'identifiant abrege.
  Future<void> _chargerPatients() async {
    final jeton = auth.accessToken;
    if (jeton == null) return;
    try {
      for (final p in await widget.api.patientsMedecin(jeton)) {
        final Object? nom = p['nomComplet'];
        if (nom is String && nom.isNotEmpty) _patients[identifiant(p['patientId'])] = nom;
      }
    } on Exception {
      // Noms indisponibles.
    }
  }

  String _patient(Map<String, dynamic> o) {
    final id = identifiant(o['patientId']);
    return _patients[id] ?? libellePatientParDefaut(id);
  }

  /// Comme le site : « Motif : ... » d'une ordonnance annulee, « le ... » d'une delivree.
  String _precision(Map<String, dynamic> o) {
    final statut = '${o['statut'] ?? ''}'.trim().toUpperCase();
    final motif = '${o['motifAnnulation'] ?? ''}'.trim();
    if (statut == 'ANNULEE' && motif.isNotEmpty) return t('Motif : $motif', 'السبب: $motif');
    final iso = o['delivreeLe'];
    if (statut == 'DELIVREE' && iso is String && DateTime.tryParse(iso) != null) {
      return t('le ${formaterDateIso(iso)}', 'في ${formaterDateIso(iso)}');
    }
    return '';
  }

  /// Confirmation avec motif facultatif ; null si le medecin renonce.
  Future<String?> _demanderMotif() {
    final champ = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Annuler cette ordonnance ?', 'إلغاء هذه الوصفة؟')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Le patient en sera informé et elle ne pourra plus être délivrée.',
                'سيتم إعلام المريض ولن يمكن صرفها بعد الآن.')),
            const SizedBox(height: 12),
            TextField(
              controller: champ,
              maxLength: longueurMaxMotifAnnulation,
              maxLines: 2,
              decoration: InputDecoration(labelText: t('Motif (facultatif)', 'السبب (اختياري)')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Non', 'لا'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, champ.text.trim()),
              child: Text(t('Oui, annuler', 'نعم، إلغاء'))),
        ],
      ),
    );
  }

  Future<void> _annuler(Map<String, dynamic> o) async {
    final motif = await _demanderMotif();
    if (motif == null) return;
    final maj = await appeler<Map<String, dynamic>>(
        (j) => widget.api.annulerOrdonnance(identifiant(o['id']), motif, j));
    if (maj == null || !mounted) return;
    setState(() {
      final i = _ordonnances.indexWhere((x) => identifiant(x['id']) == identifiant(o['id']));
      if (i >= 0) _ordonnances[i] = maj.isEmpty ? {...o, 'statut': 'ANNULEE'} : maj;
    });
    message(t('Ordonnance annulée.', 'تم إلغاء الوصفة.'));
  }

  Future<void> _nouvelle() async {
    final emise = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => NouvelleOrdonnancePage(api: widget.api, auth: widget.auth)));
    if (emise == true && mounted) await recharger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(t('Mes ordonnances rédigées', 'وصفاتي التي حررتها')),
          actions: actionsActualiser()),
      floatingActionButton: auth.estConnecte
          ? FloatingActionButton.extended(
              onPressed: _nouvelle,
              icon: const Icon(Icons.add),
              label: Text(t('Rédiger une ordonnance', 'تحرير وصفة')))
          : null,
      body: corps(t('Connectez-vous pour voir vos ordonnances.', 'سجّل الدخول لعرض وصفاتك.'), () {
        if (_ordonnances.isEmpty) {
          return VueVide(
              t('Aucune ordonnance rédigée pour le moment.', 'لا توجد وصفات محرَّرة حاليًا.'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            for (final o in _ordonnances)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(_patient(o)),
                  subtitle: Text([
                    dateEmission(o),
                    libelleStatut(o['statut']),
                    if (_precision(o).isNotEmpty) _precision(o),
                    if ('${o['codeVerification'] ?? ''}'.isNotEmpty)
                      '${o['codeVerification']}',
                  ].join(' · ')),
                  trailing: '${o['statut']}'.trim().toUpperCase() == 'EMISE'
                      ? TextButton(
                          onPressed: () => _annuler(o), child: Text(t('Annuler', 'إلغاء')))
                      : null,
                ),
              ),
          ],
        );
      }),
    );
  }
}
