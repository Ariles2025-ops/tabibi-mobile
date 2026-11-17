import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/identifiants.dart';
import '../../utils/ordonnances.dart';
import 'outils_espace.dart';

/// « Nouvelle ordonnance » du site : le medecin choisit un de ses patients (GET /api/medecin/patients),
/// facultativement un rendez-vous confirme ou honore, puis saisit les lignes (seul le medicament est
/// obligatoire) et emet l'ordonnance (POST /api/ordonnances). Se ferme avec `true` une fois emise.
class NouvelleOrdonnancePage extends StatefulWidget {
  const NouvelleOrdonnancePage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<NouvelleOrdonnancePage> createState() => _NouvelleOrdonnancePageState();
}

class _Ligne {
  final medicament = TextEditingController();
  final posologie = TextEditingController();
  final duree = TextEditingController();

  void dispose() {
    medicament.dispose();
    posologie.dispose();
    duree.dispose();
  }
}

class _NouvelleOrdonnancePageState extends State<NouvelleOrdonnancePage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _rendezVous = [];
  String _patientId = '';
  String _rendezVousId = '';
  final List<_Ligne> _lignes = [_Ligne()];
  String? _erreurFormulaire;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  void dispose() {
    for (final l in _lignes) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Future<void> recharger() async {
    final patients = await chargerAvec((j) => widget.api.patientsMedecin(j));
    if (patients == null || !mounted) return;
    final jeton = auth.accessToken;
    var rdv = <Map<String, dynamic>>[];
    if (jeton != null) {
      try {
        rdv = await widget.api.agendaMedecin(jeton);
      } on Exception {
        // Le rendez-vous lie est facultatif : on continue sans.
      }
    }
    if (!mounted) return;
    final tries = List<Map<String, dynamic>>.of(patients)
      ..sort((a, b) => '${a['nomComplet']}'.compareTo('${b['nomComplet']}'));
    setState(() {
      _patients = tries;
      _rendezVous = rdv;
    });
  }

  String _libelle(Map<String, dynamic> p) {
    final nom = '${p['nomComplet'] ?? ''}'.trim();
    final tel = '${p['telephone'] ?? ''}'.trim();
    final base = nom.isEmpty ? t('Patient', 'مريض') : nom;
    return tel.isEmpty ? base : '$base · $tel';
  }

  Future<void> _emettre() async {
    final corps = corpsOrdonnance(_patientId, _rendezVousId, [
      for (final l in _lignes)
        {'medicament': l.medicament.text, 'posologie': l.posologie.text, 'duree': l.duree.text},
    ]);
    if (corps == null) {
      setState(() => _erreurFormulaire = t(
          'Choisissez le patient et indiquez le médicament de chaque ligne.',
          'اختر المريض وأدخل الدواء في كل سطر.'));
      return;
    }
    final jeton = auth.accessToken;
    if (jeton == null) return;
    setState(() {
      _erreurFormulaire = null;
      _envoiEnCours = true;
    });
    try {
      await widget.api.emettreOrdonnance(corps, jeton);
      if (!mounted) return;
      message(t('Ordonnance émise.', 'تم إصدار الوصفة.'));
      Navigator.of(context).pop(true);
      return;
    } on ApiException catch (e) {
      if (e.nonAutorise) auth.seDeconnecter();
      final texte = switch (e.statusCode) {
        403 || 409 => e.message.isNotEmpty
            ? e.message
            : t('Le patient doit avoir un rendez-vous confirmé ou honoré avec vous pour recevoir une ordonnance.',
                'يجب أن يكون للمريض موعد مؤكد أو منجز معك ليتلقى وصفة.'),
        404 => t('Patient ou rendez-vous introuvable.', 'المريض أو الموعد غير موجود.'),
        _ => e.message,
      };
      if (mounted) setState(() => _erreurFormulaire = texte);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreurFormulaire = messageErreur(e));
    }
    if (mounted) setState(() => _envoiEnCours = false);
  }

  @override
  Widget build(BuildContext context) {
    final liables = rendezVousLiables(_rendezVous, _patientId);
    return Scaffold(
      appBar: AppBar(title: Text(t('Nouvelle ordonnance', 'وصفة جديدة'))),
      body: corps(t('Connectez-vous pour rédiger une ordonnance.', 'سجّل الدخول لتحرير وصفة.'), () {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InputDecorator(
              decoration: InputDecoration(labelText: t('Patient', 'المريض')),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('champ-patient'),
                  value: _patientId.isEmpty ? null : _patientId,
                  isExpanded: true,
                  isDense: true,
                  hint: Text(t('Choisir un patient', 'اختر مريضًا')),
                  items: [
                    for (final p in _patients)
                      DropdownMenuItem(value: identifiant(p['patientId']), child: Text(_libelle(p))),
                  ],
                  onChanged: (v) => setState(() {
                    _patientId = v ?? '';
                    _rendezVousId = '';
                  }),
                ),
              ),
            ),
            if (_patients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(t(
                    "Aucun patient pour le moment : un patient apparaît ici dès qu'il a un rendez-vous confirmé chez vous.",
                    'لا يوجد مرضى حاليًا: يظهر المريض هنا بمجرد أن يكون له موعد مؤكد عندك.')),
              ),
            if (_patientId.isNotEmpty) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                    labelText: t('Rendez-vous lié (facultatif)', 'الموعد المرتبط (اختياري)')),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey('champ-rdv-$_patientId'),
                    value: _rendezVousId.isEmpty ? null : _rendezVousId,
                    isExpanded: true,
                    isDense: true,
                    hint: Text(t('Aucun', 'لا شيء')),
                    items: [
                      for (final r in liables)
                        DropdownMenuItem(
                            value: identifiant(r['id']), child: Text(formaterDateIso('${r['debut']}'))),
                    ],
                    onChanged: (v) => setState(() => _rendezVousId = v ?? ''),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(t('Prescription', 'الوصفة'), style: Theme.of(context).textTheme.titleMedium),
            for (var i = 0; i < _lignes.length; i++)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _lignes[i].medicament,
                        decoration: InputDecoration(
                            labelText: t('Médicament', 'الدواء'),
                            hintText: t('Ex. Paracétamol 1 g', 'مثال: باراسيتامول 1 غ')),
                      ),
                      TextField(
                        controller: _lignes[i].posologie,
                        decoration: InputDecoration(
                            labelText: t('Posologie (facultatif)', 'الجرعة (اختياري)'),
                            hintText: t('Ex. 1 comprimé matin et soir', 'مثال: قرص صباحًا ومساءً')),
                      ),
                      TextField(
                        controller: _lignes[i].duree,
                        decoration: InputDecoration(
                            labelText: t('Durée (facultatif)', 'المدة (اختياري)'),
                            hintText: t('Ex. 7 jours', 'مثال: 7 أيام')),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: _lignes.length == 1
                              ? null
                              : () => setState(() => _lignes.removeAt(i).dispose()),
                          child: Text(t('Supprimer', 'حذف')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _lignes.add(_Ligne())),
                icon: const Icon(Icons.add),
                label: Text(t('Ajouter une ligne', 'إضافة سطر')),
              ),
            ),
            if (_erreurFormulaire != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erreurFormulaire!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _envoiEnCours ? null : _emettre,
              child: Text(_envoiEnCours
                  ? t('Émission…', 'جارٍ الإصدار…')
                  : t("Émettre l'ordonnance", 'إصدار الوصفة')),
            ),
          ],
        );
      }),
    );
  }
}
