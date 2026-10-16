import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../widgets/vue_erreur.dart';

/// Liste des conversations du praticien.
class MedecinMessageriePage extends StatefulWidget {
  const MedecinMessageriePage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinMessageriePage> createState() => _MedecinMessageriePageState();
}

class _MedecinMessageriePageState extends State<MedecinMessageriePage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _convos = [];
  bool _charge = false;
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
      final c = await widget.medecin.mesConversations();
      if (mounted) setState(() => _convos = c);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _ouvrir(Map<String, dynamic> c) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MedecinConversationPage(
        conversationId: '${c['id']}',
        titre: '${c['patientNom'] ?? 'Patient'}',
        medecin: widget.medecin,
        auth: _auth,
      ),
    ));
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messagerie')),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? VueErreur(message: _erreur!, onReessayer: _charger)
              : _convos.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aucune conversation.',
                            textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                      ),
                    )
                  : RefreshIndicator(
                      color: Tabibi.vert,
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: [for (final c in _convos) _carte(c)],
                      ),
                    ),
    );
  }

  Widget _carte(Map<String, dynamic> c) {
    final nom = '${c['patientNom'] ?? 'Patient'}';
    final initiale = nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase();
    return InkWell(
      onTap: () => _ouvrir(c),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
            child: Text(initiale, style: const TextStyle(color: Tabibi.vert, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(nom, style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
          ),
          if ('${c['dernierMessageLe'] ?? ''}'.isNotEmpty)
            Text(formaterDateIso(langueDe(context), '${c['dernierMessageLe']}'),
                style: const TextStyle(color: Tabibi.texte4, fontSize: 11)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Tabibi.texte4),
        ]),
      ),
    );
  }
}

/// Vue d'une conversation : fil de messages + saisie.
class MedecinConversationPage extends StatefulWidget {
  const MedecinConversationPage({
    super.key,
    required this.conversationId,
    required this.titre,
    this.medecin = const MedecinSupabase(),
    this.auth,
  });

  final String conversationId;
  final String titre;
  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinConversationPage> createState() => _MedecinConversationPageState();
}

class _MedecinConversationPageState extends State<MedecinConversationPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _saisie = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _charge = false;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _saisie.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final m = await widget.medecin.messages(widget.conversationId);
      if (mounted) {
        setState(() => _messages = m);
        _versLeBas();
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _envoyer() async {
    final texte = _saisie.text.trim();
    if (texte.isEmpty || _envoi) return;
    setState(() => _envoi = true);
    try {
      await widget.medecin.envoyerMessage(widget.conversationId, texte);
      _saisie.clear();
      await _charger();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moi = widget.medecin.moiId;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titre)),
      body: Column(children: [
        Expanded(
          child: _charge
              ? const Center(child: CircularProgressIndicator())
              : _erreur != null
                  ? VueErreur(message: _erreur!, onReessayer: _charger)
                  : _messages.isEmpty
                      ? const Center(
                          child: Text('Aucun message. Écrivez le premier.',
                              style: TextStyle(color: Tabibi.texteDoux)))
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _bulle(_messages[i], '${_messages[i]['auteurId']}' == moi),
                        ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Tabibi.bord)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _saisie,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Votre message…', isDense: true),
                  onSubmitted: (_) => _envoyer(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Tabibi.vert),
                onPressed: _envoi ? null : _envoyer,
                icon: _envoi
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bulle(Map<String, dynamic> m, bool moi) {
    return Align(
      alignment: moi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: moi ? Tabibi.vert : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(moi ? 16 : 4),
            bottomRight: Radius.circular(moi ? 4 : 16),
          ),
          boxShadow: Tabibi.ombreDouce,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m['contenu'] ?? ''}',
              style: TextStyle(color: moi ? Colors.white : Tabibi.texte)),
          const SizedBox(height: 2),
          Text(formaterDateIso(langueDe(context), '${m['envoyeLe']}'),
              style: TextStyle(color: moi ? Colors.white70 : Tabibi.texte4, fontSize: 10)),
        ]),
      ),
    );
  }
}
