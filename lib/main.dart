import 'package:flutter/material.dart';

import 'pages/fiche_medecin_page.dart';
import 'pages/mes_rendez_vous_page.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/session.dart';

void main() => runApp(const TabibiApp());

class TabibiApp extends StatelessWidget {
  const TabibiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tabibi',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0F7560), useMaterial3: true),
      home: const RecherchePage(),
    );
  }
}

/// Ecran d'accueil : recherche de praticiens, acces a la fiche et aux rendez-vous.
class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  late final AuthService _auth = widget.auth ?? session;
  final _nom = TextEditingController();
  String? _specialite;
  List<Map<String, dynamic>> _resultats = [];
  bool _charge = false;

  Future<void> _rechercher() async {
    setState(() => _charge = true);
    try {
      final r = await widget.api.rechercherMedecins(specialite: _specialite, q: _nom.text);
      if (mounted) setState(() => _resultats = r);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Connexion Keycloak si necessaire, puis confirmation « Connecte ».
  Future<void> _seConnecter() async {
    if (!_auth.estConnecte) {
      final ok = await _auth.seConnecter();
      if (!mounted) return;
      setState(() {}); // met a jour l'icone de l'AppBar
      if (!ok) {
        _message('Connexion annulee');
        return;
      }
    }
    final token = _auth.accessToken;
    if (token == null) return;
    var texte = 'Connecte';
    try {
      final moi = await widget.api.moi(token);
      texte = 'Connecte : ${moi['nom']}';
    } on Exception {
      // Identite indisponible : message generique.
    }
    _message(texte);
  }

  Future<void> _ouvrirFiche(int medecinId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FicheMedecinPage(medecinId: medecinId, api: widget.api, auth: _auth),
      ),
    );
    if (mounted) setState(() {}); // l'utilisateur a pu se connecter depuis la fiche
  }

  Future<void> _ouvrirMesRendezVous() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MesRendezVousPage(api: widget.api, auth: _auth),
      ),
    );
    if (mounted) setState(() {});
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  void initState() {
    super.initState();
    _rechercher();
  }

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connecte = _auth.estConnecte;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabibi'),
        actions: [
          IconButton(
            tooltip: 'Mes rendez-vous',
            onPressed: _ouvrirMesRendezVous,
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: connecte ? 'Connecte' : 'Se connecter',
            onPressed: _seConnecter,
            icon: Icon(connecte ? Icons.person : Icons.person_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _nom,
                  decoration: const InputDecoration(labelText: 'Nom du medecin'),
                  onSubmitted: (_) => _rechercher(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _specialite,
                hint: const Text('Specialite'),
                items: const [
                  DropdownMenuItem(value: 'generaliste', child: Text('Generaliste')),
                  DropdownMenuItem(value: 'cardiologue', child: Text('Cardiologue')),
                  DropdownMenuItem(value: 'dermatologue', child: Text('Dermatologue')),
                  DropdownMenuItem(value: 'pediatre', child: Text('Pediatre')),
                ],
                onChanged: (v) => setState(() => _specialite = v),
              ),
              IconButton(onPressed: _rechercher, icon: const Icon(Icons.search)),
            ]),
            const SizedBox(height: 12),
            if (_charge) const CircularProgressIndicator(),
            Expanded(
              child: ListView.separated(
                itemCount: _resultats.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final m = _resultats[i];
                  return ListTile(
                    title: Text(m['nomComplet'] as String),
                    subtitle: Text('${m['specialiteFr']} · ${m['ville']} (${m['wilayaFr']})'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _ouvrirFiche(m['id'] as int),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
