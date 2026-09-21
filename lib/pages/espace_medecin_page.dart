import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../utils/identifiants.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'medecin_profil_page.dart';

/// Tableau de bord du praticien : acces a ses rendez-vous recus et a sa fiche.
class EspaceMedecinPage extends StatefulWidget {
  const EspaceMedecinPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<EspaceMedecinPage> createState() => _EspaceMedecinPageState();
}

class _EspaceMedecinPageState extends State<EspaceMedecinPage> {
  late final AuthService _auth = widget.auth ?? session;
  String? _nom;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  Future<void> _charger() async {
    try {
      final p = await widget.medecin.monProfil();
      if (mounted) setState(() => _nom = p?['nomComplet'] as String?);
    } on Exception {
      // Nom indisponible : le tableau de bord reste accessible.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Espace médecin')),
      body: !_auth.estConnecte
          ? VueConnexion(
              icone: Icons.medical_services_outlined,
              titre: 'Espace médecin',
              message: 'Connectez-vous avec votre compte praticien.',
              onSeConnecter: () async {
                await _auth.seConnecter();
                if (mounted) setState(() {});
                if (_auth.estConnecte) _charger();
              },
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (_nom != null && _nom!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Dr $_nom',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Tabibi.texte)),
                  ),
                _tuile(Icons.event_note_outlined, 'Mes rendez-vous',
                    'Confirmer, honorer ou annuler', () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => MedecinRendezVousPage(auth: _auth)));
                }),
                _tuile(Icons.badge_outlined, 'Mon profil',
                    'Tarifs, paiement, téléconsultation, bio', () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => MedecinProfilPage(auth: _auth)));
                  _charger();
                }),
              ],
            ),
    );
  }

  Widget _tuile(IconData icone, String titre, String sous, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
          child: Icon(icone, color: Tabibi.vert, size: 20),
        ),
        title: Text(titre,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
        subtitle: Text(sous, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Tabibi.texte4),
        onTap: onTap,
      ),
    );
  }
}

/// Rendez-vous recus par le praticien, avec actions selon le statut.
class MedecinRendezVousPage extends StatefulWidget {
  const MedecinRendezVousPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinRendezVousPage> createState() => _MedecinRendezVousPageState();
}

class _MedecinRendezVousPageState extends State<MedecinRendezVousPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _rdvs = [];
  bool _charge = false;
  String? _enCours;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final rdvs = await widget.medecin.rdvRecus();
      if (mounted) setState(() => _rdvs = rdvs);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _action(String id, Future<void> Function() op, String ok) async {
    if (_enCours != null) return;
    setState(() => _enCours = id);
    try {
      await op();
      if (mounted) _message(ok);
    } on Exception catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
    if (mounted) await _charger();
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              onPressed: _charge ? null : _charger,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (!_auth.estConnecte) {
      return VueConnexion(
        icone: Icons.event_note_outlined,
        titre: 'Mes rendez-vous',
        message: 'Connectez-vous avec votre compte praticien.',
        onSeConnecter: () async {
          await _auth.seConnecter();
          if (mounted) setState(() {});
          if (_auth.estConnecte) _charger();
        },
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    if (_erreur != null) return VueErreur(message: _erreur!, onReessayer: _charger);
    if (_rdvs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Aucun rendez-vous pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Tabibi.texteDoux)),
        ),
      );
    }
    return RefreshIndicator(
      color: Tabibi.vert,
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [for (final r in _rdvs) _carte(r)],
      ),
    );
  }

  Widget _carte(Map<String, dynamic> rdv) {
    final id = identifiant(rdv['id']);
    final statut = '${rdv['statut'] ?? ''}';
    final nom = (rdv['patientNom'] as String?) ?? 'Patient ${abreger(identifiant(rdv['patientId']))}';
    final date = formaterDateIso(langueDe(context), '${rdv['debut']}');
    final motif = (rdv['motif'] as String?)?.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration:
                    const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
                child: const Icon(Icons.person_outline, color: Tabibi.vert, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Tabibi.texte, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(date, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 13)),
                    if (motif != null && motif.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(motif,
                            style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              _pile(statut),
            ],
          ),
          _actions(id, statut),
        ],
      ),
    );
  }

  Widget _actions(String id, String statut) {
    final s = statut.toUpperCase();
    final boutons = <Widget>[];
    if (s == 'EN_ATTENTE') {
      boutons.add(_btn('Confirmer', () => _action(id, () => widget.medecin.confirmer(id), 'Rendez-vous confirmé')));
      boutons.add(_btn('Refuser', () => _action(id, () => widget.medecin.annuler(id), 'Rendez-vous annulé'), doux: true));
    } else if (s == 'CONFIRME') {
      boutons.add(_btn('Honoré', () => _action(id, () => widget.medecin.terminer(id), 'Rendez-vous honoré')));
      boutons.add(_btn('Absent', () => _action(id, () => widget.medecin.marquerAbsent(id), 'Patient marqué absent'), doux: true));
      boutons.add(_btn('Annuler', () => _action(id, () => widget.medecin.annuler(id), 'Rendez-vous annulé'), doux: true));
    }
    if (boutons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(alignment: WrapAlignment.end, spacing: 8, children: boutons),
    );
  }

  Widget _btn(String texte, VoidCallback onTap, {bool doux = false}) {
    return doux
        ? TextButton(onPressed: _enCours != null ? null : onTap, child: Text(texte))
        : FilledButton(
            onPressed: _enCours != null ? null : onTap,
            style: FilledButton.styleFrom(
                backgroundColor: Tabibi.vert,
                visualDensity: VisualDensity.compact),
            child: Text(texte),
          );
  }

  Widget _pile(String statut) {
    final s = statut.toUpperCase();
    Color bg;
    Color fg;
    String texte;
    if (s.startsWith('ANNUL')) {
      bg = Tabibi.rougeClair;
      fg = Tabibi.rouge;
      texte = 'Annulé';
    } else if (s == 'HONORE') {
      bg = Tabibi.bg2;
      fg = Tabibi.texte3;
      texte = 'Honoré';
    } else if (s == 'ABSENT') {
      bg = Tabibi.bg2;
      fg = Tabibi.texte3;
      texte = 'Absent';
    } else if (s == 'EN_ATTENTE') {
      bg = Tabibi.orClair;
      fg = Tabibi.orTexte;
      texte = 'En attente';
    } else {
      bg = Tabibi.vertTresClair;
      fg = Tabibi.vert;
      texte = 'Confirmé';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(texte,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
