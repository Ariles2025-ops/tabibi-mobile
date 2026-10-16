import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/medecin_supabase.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../widgets/vue_erreur.dart';

/// Gestion des horaires d'ouverture du cabinet (disponibilites) : par jour,
/// ouvert/ferme + une ou plusieurs plages horaires (matin, apres-midi...).
/// Alimente les creneaux proposes aux patients (get_available_slots).
class MedecinDisponibilitesPage extends StatefulWidget {
  const MedecinDisponibilitesPage({super.key, this.medecin = const MedecinSupabase(), this.auth});

  final MedecinSupabase medecin;
  final AuthService? auth;

  @override
  State<MedecinDisponibilitesPage> createState() => _MedecinDisponibilitesPageState();
}

class _MedecinDisponibilitesPageState extends State<MedecinDisponibilitesPage> {
  late final AuthService _auth = widget.auth ?? session;

  static const _jours = [
    ['mon', 'Lundi'],
    ['tue', 'Mardi'],
    ['wed', 'Mercredi'],
    ['thu', 'Jeudi'],
    ['fri', 'Vendredi'],
    ['sat', 'Samedi'],
    ['sun', 'Dimanche'],
  ];

  final Map<String, bool> _ouvert = {};
  // Une ou plusieurs plages {open, close} par jour.
  final Map<String, List<Map<String, String>>> _plages = {};

  bool _charge = false;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    for (final j in _jours) {
      final k = j[0];
      _ouvert[k] = k != 'sat' && k != 'sun';
      _plages[k] = [
        {'open': '09:00', 'close': '17:00'}
      ];
    }
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final p = await widget.medecin.monProfil();
      final h = p?['horaires'];
      if (h is Map) {
        for (final j in _jours) {
          final k = j[0];
          final arr = h[k];
          if (arr is List && arr.isNotEmpty) {
            final plages = <Map<String, String>>[];
            for (final e in arr) {
              if (e is Map) {
                plages.add({
                  'open': '${e['open'] ?? '09:00'}',
                  'close': '${e['close'] ?? '17:00'}',
                });
              }
            }
            if (plages.isNotEmpty) {
              _ouvert[k] = true;
              _plages[k] = plages;
            } else {
              _ouvert[k] = false;
            }
          } else if (arr is List) {
            _ouvert[k] = false;
          }
        }
      }
      if (mounted) setState(() {});
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _choisirHeure(String k, int index, bool ouverture) async {
    final actuel = ouverture ? _plages[k]![index]['open']! : _plages[k]![index]['close']!;
    final parts = actuel.split(':');
    final res = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (res == null) return;
    final v = '${res.hour.toString().padLeft(2, '0')}:${res.minute.toString().padLeft(2, '0')}';
    setState(() {
      _plages[k]![index][ouverture ? 'open' : 'close'] = v;
    });
  }

  void _ajouterPlage(String k) {
    setState(() => _plages[k]!.add({'open': '14:00', 'close': '18:00'}));
  }

  void _retirerPlage(String k, int index) {
    setState(() {
      _plages[k]!.removeAt(index);
      if (_plages[k]!.isEmpty) {
        _plages[k]!.add({'open': '09:00', 'close': '17:00'});
        _ouvert[k] = false;
      }
    });
  }

  Future<void> _enregistrer() async {
    if (_envoi) return;
    setState(() => _envoi = true);
    try {
      final horaires = <String, dynamic>{};
      for (final j in _jours) {
        final k = j[0];
        horaires[k] = (_ouvert[k] ?? false)
            ? [
                for (final p in _plages[k]!) {'open': p['open'], 'close': p['close']}
              ]
            : <dynamic>[];
      }
      await widget.medecin.enregistrerHoraires(horaires);
      if (mounted) _msg('Disponibilités enregistrées');
    } on Exception catch (e) {
      if (mounted) _msg(e.toString());
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes disponibilités')),
      body: !_auth.estConnecte
          ? const Center(child: Text('Connectez-vous.', style: TextStyle(color: Tabibi.texteDoux)))
          : _charge
              ? const Center(child: CircularProgressIndicator())
              : _erreur != null
                  ? VueErreur(message: _erreur!, onReessayer: _charger)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        const Text(
                          'Définissez vos horaires d\'ouverture (plusieurs plages possibles : matin, après-midi…). Les patients ne pourront réserver que sur ces plages.',
                          style: TextStyle(color: Tabibi.texteDoux),
                        ),
                        const SizedBox(height: 12),
                        for (final j in _jours) _ligneJour(j[0], j[1]),
                      ],
                    ),
      floatingActionButton: !_auth.estConnecte || _charge
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Tabibi.vert,
              onPressed: _envoi ? null : _enregistrer,
              icon: _envoi
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
    );
  }

  Widget _ligneJour(String k, String label) {
    final ouvert = _ouvert[k] ?? false;
    final plages = _plages[k] ?? const <Map<String, String>>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
          ),
          Text(ouvert ? 'Ouvert' : 'Fermé',
              style: TextStyle(color: ouvert ? Tabibi.vert : Tabibi.texte4, fontSize: 12)),
          Switch(
            activeColor: Tabibi.vert,
            value: ouvert,
            onChanged: (v) => setState(() => _ouvert[k] = v),
          ),
        ]),
        if (ouvert) ...[
          for (int i = 0; i < plages.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Row(children: [
                Expanded(child: _boutonHeure('Ouverture', plages[i]['open']!, () => _choisirHeure(k, i, true))),
                const SizedBox(width: 12),
                Expanded(child: _boutonHeure('Fermeture', plages[i]['close']!, () => _choisirHeure(k, i, false))),
                if (plages.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Tabibi.texte4),
                    onPressed: () => _retirerPlage(k, i),
                  ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _ajouterPlage(k),
              icon: const Icon(Icons.add, size: 18, color: Tabibi.vert),
              label: const Text('Ajouter une plage', style: TextStyle(color: Tabibi.vert)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _boutonHeure(String label, String valeur, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Tabibi.bg2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 11)),
            Text(valeur, style: const TextStyle(color: Tabibi.texte, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const Icon(Icons.access_time, size: 18, color: Tabibi.vert),
        ]),
      ),
    );
  }
}
