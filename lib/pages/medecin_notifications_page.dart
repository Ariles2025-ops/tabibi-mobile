import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dates.dart';
import '../widgets/vue_erreur.dart';

/// Notifications du praticien (nouveaux RDV, annulations, messages, avis…).
class MedecinNotificationsPage extends StatefulWidget {
  const MedecinNotificationsPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinNotificationsPage> createState() => _MedecinNotificationsPageState();
}

class _MedecinNotificationsPageState extends State<MedecinNotificationsPage> {
  late final AuthService _auth = widget.auth ?? session;
  List<Map<String, dynamic>> _notifs = [];
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
      final n = await widget.medecin.notifications();
      if (mounted) setState(() => _notifs = n);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _toutLire() async {
    try {
      await widget.medecin.toutMarquerLues();
      await _charger();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _lire(Map<String, dynamic> n) async {
    if ('${n['luLe'] ?? ''}'.isNotEmpty) return;
    try {
      await widget.medecin.marquerNotificationLue('${n['id']}');
      if (mounted) setState(() => n['luLe'] = DateTime.now().toIso8601String());
    } on Exception {
      // silencieux
    }
  }

  IconData _icone(String type) {
    switch (type) {
      case 'appointment_confirmed':
      case 'appointment_created':
      case 'new_appointment':
        return Icons.event_available;
      case 'appointment_cancelled':
        return Icons.event_busy;
      case 'message':
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'review':
      case 'new_review':
        return Icons.star_outline;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final aDesNonLues = _notifs.any((n) => '${n['luLe'] ?? ''}'.isEmpty);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (aDesNonLues)
            TextButton(onPressed: _toutLire, child: const Text('Tout lire')),
        ],
      ),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? VueErreur(message: _erreur!, onReessayer: _charger)
              : _notifs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aucune notification.',
                            textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                      ),
                    )
                  : RefreshIndicator(
                      color: Tabibi.vert,
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: [for (final n in _notifs) _carte(n)],
                      ),
                    ),
    );
  }

  Widget _carte(Map<String, dynamic> n) {
    final nonLue = '${n['luLe'] ?? ''}'.isEmpty;
    return InkWell(
      onTap: () => _lire(n),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: nonLue ? Tabibi.vertTresClair : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Tabibi.ombreDouce,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
            child: Icon(_icone('${n['type']}'), color: Tabibi.vert, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n['titre'] ?? 'Notification'}',
                  style: TextStyle(fontWeight: nonLue ? FontWeight.w800 : FontWeight.w600, color: Tabibi.texte)),
              if ('${n['message'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('${n['message']}', style: const TextStyle(color: Tabibi.texteDoux, fontSize: 13)),
              ],
              const SizedBox(height: 4),
              Text(formaterDateIso(langueDe(context), '${n['creeLe']}'),
                  style: const TextStyle(color: Tabibi.texte4, fontSize: 11)),
            ]),
          ),
          if (nonLue)
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 4, left: 6),
              decoration: const BoxDecoration(color: Tabibi.vert, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}
