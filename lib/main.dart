import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';

void main() => runApp(const TabibiApp());

class TabibiApp extends StatelessWidget {
  const TabibiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tabibi',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F7560),
        useMaterial3: true,
      ),
      home: const AccueilPage(),
    );
  }
}

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});
  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  final _auth = AuthService();
  final _api = ApiService();
  Map<String, dynamic>? _moi;
  bool _chargement = false;

  Future<void> _seConnecter() async {
    setState(() => _chargement = true);
    try {
      if (await _auth.seConnecter()) {
        final moi = await _api.moi(_auth.accessToken!);
        setState(() => _moi = moi);
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tabibi')),
      body: Center(
        child: _chargement
            ? const CircularProgressIndicator()
            : _moi == null
                ? ElevatedButton(
                    onPressed: _seConnecter,
                    child: const Text('Se connecter'),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Connecte : ${_moi!['nom']}'),
                      Text('Roles : ${(_moi!['roles'] as List).join(', ')}'),
                    ],
                  ),
      ),
    );
  }
}
