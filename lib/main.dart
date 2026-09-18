import 'package:flutter/material.dart';
import 'services/api_service.dart';

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

class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key});
  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  final _api = ApiService();
  final _nom = TextEditingController();
  String? _specialite;
  List<Map<String, dynamic>> _resultats = [];
  bool _charge = false;

  Future<void> _rechercher() async {
    setState(() => _charge = true);
    try {
      final r = await _api.rechercherMedecins(specialite: _specialite, q: _nom.text);
      setState(() => _resultats = r);
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _rechercher();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tabibi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _nom,
                  decoration: const InputDecoration(labelText: 'Nom du medecin'),
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
