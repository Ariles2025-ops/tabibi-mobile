import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../utils/libelles.dart';
import 'espace_medecin_page.dart';
import 'medecin_disponibilites_page.dart';
import 'medecin_profil_page.dart';

/// Application du praticien (facon Doctolib Pro) : un medecin valide arrive ici.
/// Navigation basse : Accueil (tableau de bord), Agenda (RDV), Disponibilités, Profil.
class AccueilMedecinPage extends StatefulWidget {
  const AccueilMedecinPage({super.key, this.auth});

  final AuthService? auth;

  @override
  State<AccueilMedecinPage> createState() => _AccueilMedecinPageState();
}

class _AccueilMedecinPageState extends State<AccueilMedecinPage> {
  late final AuthService _auth = widget.auth ?? session;
  int _index = 0;

  void _allerAgenda() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    final pages = [
      MedecinDashboardPage(auth: _auth, onVoirAgenda: _allerAgenda),
      MedecinRendezVousPage(auth: _auth),
      MedecinDisponibilitesPage(auth: _auth),
      MedecinProfilPage(auth: _auth),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: Tabibi.pastille,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Dispo'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: 'Profil'),
        ],
      ),
    );
  }
}

/// Tableau de bord du praticien : salutation, rendez-vous du jour, prochains RDV.
class MedecinDashboardPage extends StatefulWidget {
  const MedecinDashboardPage({super.key, this.medecin = const MedecinSupabase(), this.auth, this.onVoirAgenda});

  final MedecinSupabase medecin;
  final AuthService? auth;
  final VoidCallback? onVoirAgenda;

  @override
  State<MedecinDashboardPage> createState() => _MedecinDashboardPageState();
}

class _MedecinDashboardPageState extends State<MedecinDashboardPage> {
  late final AuthService _auth = widget.auth ?? session;
  String? _nom;
  List<Map<String, dynamic>> _rdvs = [];
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  Future<void> _charger() async {
    setState(() => _charge = true);
    try {
      final p = await widget.medecin.monProfil();
      final rdvs = await widget.medecin.rdvRecus();
      if (mounted) {
        setState(() {
          _nom = p?['nomComplet'] as String?;
          _rdvs = rdvs;
        });
      }
    } on Exception {
      // silencieux : le tableau de bord reste affichable
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  bool _memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<Map<String, dynamic>> get _aujourdhui {
    final now = DateTime.now();
    return _rdvs.where((r) {
      final d = DateTime.tryParse('${r['debut']}')?.toLocal();
      return d != null && _memeJour(d, now);
    }).toList()
      ..sort((x, y) => '${x['debut']}'.compareTo('${y['debut']}'));
  }

  int get _aVenir {
    final now = DateTime.now();
    return _rdvs.where((r) {
      final d = DateTime.tryParse('${r['debut']}')?.toLocal();
      final st = '${r['statut']}'.toUpperCase();
      return d != null && d.isAfter(now) && !st.startsWith('ANNUL') && st != 'HONORE';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(onPressed: _charge ? null : _charger, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => _auth.seDeconnecter(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: Tabibi.vert,
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Text('Bonjour${_nom != null && _nom!.isNotEmpty ? ' Dr $_nom' : ''}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Tabibi.ink)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _stat('Aujourd\'hui', _aujourdhui.length, Icons.today_outlined, accent: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _stat('À venir', _aVenir, Icons.event_available_outlined)),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Text('Rendez-vous du jour',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.texte)),
                    const Spacer(),
                    TextButton(onPressed: widget.onVoirAgenda, child: const Text('Voir l\'agenda')),
                  ]),
                  const SizedBox(height: 4),
                  if (_aujourdhui.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aucun rendez-vous aujourd\'hui.', style: TextStyle(color: Tabibi.texteDoux)),
                    )
                  else
                    for (final r in _aujourdhui) _carteRdv(r),
                ],
              ),
            ),
    );
  }

  Widget _stat(String libelle, int valeur, IconData icone, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent ? Tabibi.vert : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, color: accent ? Colors.white : Tabibi.vert, size: 22),
        const SizedBox(height: 8),
        Text('$valeur',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent ? Colors.white : Tabibi.texte)),
        Text(libelle, style: TextStyle(color: accent ? Colors.white70 : Tabibi.texteDoux, fontSize: 12)),
      ]),
    );
  }

  Widget _carteRdv(Map<String, dynamic> r) {
    final heure = DateTime.tryParse('${r['debut']}')?.toLocal();
    final hh = heure == null ? '' : '${heure.hour.toString().padLeft(2, '0')}:${heure.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Tabibi.pastille, borderRadius: BorderRadius.circular(10)),
          child: Text(hh, style: const TextStyle(color: Tabibi.vert, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['patientNom'] ?? 'Patient'}', style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
            if ('${r['motif'] ?? ''}'.isNotEmpty)
              Text('${r['motif']}', style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
          ]),
        ),
        Text(libelleStatut(langueDe(context), r['statut']), style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
      ]),
    );
  }
}
