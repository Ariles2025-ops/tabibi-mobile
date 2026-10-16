import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/medecin_supabase.dart';
import '../theme/theme_tabibi.dart';

/// Statistiques du praticien : KPIs + graphiques (revenus & RDV sur 6 mois),
/// taux de presence, repartition des statuts. Graphiques en Flutter pur.
class MedecinStatsPage extends StatefulWidget {
  final MedecinSupabase medecin;
  const MedecinStatsPage({super.key, this.medecin = const MedecinSupabase()});

  @override
  State<MedecinStatsPage> createState() => _MedecinStatsPageState();
}

class _MedecinStatsPageState extends State<MedecinStatsPage> {
  Map<String, dynamic>? _s;
  bool _charge = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final s = await widget.medecin.statsDetaillees();
      if (!mounted) return;
      setState(() { _s = s; _charge = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _charge = false; });
    }
  }

  static const _moisCourt = ['', 'janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
  String _labelMois(String ym) {
    final p = ym.split('-');
    if (p.length != 2) return ym;
    final m = int.tryParse(p[1]) ?? 0;
    return (m >= 1 && m <= 12) ? _moisCourt[m] : ym;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          if (!_charge && _err == null)
            IconButton(
              tooltip: 'Exporter en CSV',
              icon: const Icon(Icons.download_outlined),
              onPressed: _exporterCsv,
            ),
        ],
      ),
      body: _charge
          ? const Center(child: CircularProgressIndicator(color: Tabibi.vert))
          : _err != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Indisponible : $_err', textAlign: TextAlign.center)))
              : _corps(),
    );
  }

  Widget _corps() {
    final s = _s ?? const {};
    final parMois = (s['par_mois'] as List?) ?? const [];
    final taux = s['taux_presence'];
    final patients = s['patients_total'] ?? 0;
    final nouveaux = s['nouveaux_ce_mois'] ?? 0;
    final rdvTotal = s['rdv_total'] ?? 0;
    final repartition = (s['repartition'] as Map?) ?? const {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _kpi('Présence', taux == null ? '—' : '$taux %', Icons.check_circle_outline),
          const SizedBox(width: 10),
          _kpi('Patients', '$patients', Icons.people_outline),
          const SizedBox(width: 10),
          _kpi('Nouveaux', '$nouveaux', Icons.person_add_alt),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _kpi('RDV total', '$rdvTotal', Icons.event_available_outlined),
          const SizedBox(width: 10),
          const Expanded(child: SizedBox()),
          const SizedBox(width: 10),
          const Expanded(child: SizedBox()),
        ]),
        const SizedBox(height: 20),
        _titre('Revenus (6 mois)'),
        const SizedBox(height: 8),
        _graphBarres(parMois, (m) => (m['revenus'] as num?)?.toDouble() ?? 0, suffixe: ' DA'),
        const SizedBox(height: 24),
        _titre('Rendez-vous (6 mois)'),
        const SizedBox(height: 8),
        _graphBarres(parMois, (m) => (m['rdv'] as num?)?.toDouble() ?? 0),
        const SizedBox(height: 24),
        _titre('Répartition des rendez-vous'),
        const SizedBox(height: 8),
        _repartition(repartition),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _kpi(String libelle, String valeur, IconData icone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Tabibi.bord)),
        child: Column(children: [
          Icon(icone, color: Tabibi.vert, size: 20),
          const SizedBox(height: 6),
          Text(valeur, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Tabibi.ink)),
          const SizedBox(height: 2),
          Text(libelle, style: const TextStyle(fontSize: 11, color: Tabibi.texteDoux), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _titre(String t) => Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.ink));

  Widget _graphBarres(List<dynamic> parMois, double Function(Map) valeur, {String suffixe = ''}) {
    if (parMois.isEmpty) {
      return const Text('Aucune donnée.', style: TextStyle(color: Tabibi.texteDoux));
    }
    double maxV = 0;
    for (final m in parMois) {
      final v = valeur(m as Map);
      if (v > maxV) maxV = v;
    }
    if (maxV <= 0) maxV = 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Tabibi.bord)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final m in parMois)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    valeur(m as Map) >= 1000
                        ? '${(valeur(m) / 1000).toStringAsFixed(1)}k'
                        : valeur(m).toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Tabibi.vert),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 110 * (valeur(m) / maxV).clamp(0.02, 1.0),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Tabibi.vert,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_labelMois('${m['mois']}'), style: const TextStyle(fontSize: 10, color: Tabibi.texteDoux)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exporterCsv() async {
    final parMois = (_s?['par_mois'] as List?) ?? const [];
    final lignes = <String>['Mois;RDV;Honorés;Absents;Revenus (DZD)'];
    for (final m in parMois) {
      final mm = m as Map;
      lignes.add([
        '${mm['mois'] ?? ''}',
        '${mm['rdv'] ?? 0}',
        '${mm['honores'] ?? 0}',
        '${mm['absents'] ?? 0}',
        '${(mm['revenus'] as num?)?.toStringAsFixed(0) ?? '0'}',
      ].join(';'));
    }
    final csv = lignes.join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Revenus copiés au format CSV (collez dans Excel / Sheets)')),
    );
  }

  Widget _repartition(Map rep) {
    const libelles = {
      'pending': 'En attente',
      'confirmed': 'Confirmés',
      'completed': 'Honorés',
      'cancelled': 'Annulés',
      'no_show': 'Absents',
    };
    final entries = rep.entries.toList();
    if (entries.isEmpty) {
      return const Text('Aucun rendez-vous pour le moment.', style: TextStyle(color: Tabibi.texteDoux));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Tabibi.bord)),
      child: Column(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(libelles[e.key] ?? '${e.key}', style: const TextStyle(color: Tabibi.texte)),
                  Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800, color: Tabibi.ink)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
