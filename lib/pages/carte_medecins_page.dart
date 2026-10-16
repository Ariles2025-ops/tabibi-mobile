import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/praticiens_supabase.dart';
import '../theme/theme_tabibi.dart';

/// Carte des medecins dans toute l'Algerie : une bulle par wilaya, dimensionnee
/// par le nombre de praticiens (donnees agregees, aucune adresse individuelle).
class CarteMedecinsPage extends StatefulWidget {
  final PraticiensSupabase prat;
  const CarteMedecinsPage({super.key, required this.prat});

  @override
  State<CarteMedecinsPage> createState() => _CarteMedecinsPageState();
}

class _CarteMedecinsPageState extends State<CarteMedecinsPage> {
  List<Map<String, dynamic>> _pts = [];
  bool _charge = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final r = await widget.prat.carteParWilaya();
      if (!mounted) return;
      setState(() {
        _pts = r;
        _charge = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _charge = false;
      });
    }
  }

  double _taille(num n) => (30 + n / 900).clamp(30, 66).toDouble();

  String _court(num n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte des médecins')),
      body: _charge
          ? const Center(child: CircularProgressIndicator(color: Tabibi.vert))
          : _err != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Carte indisponible : $_err',
                        textAlign: TextAlign.center),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: const LatLng(28.2, 2.9),
                    initialZoom: 5.0,
                    minZoom: 4.0,
                    maxZoom: 12.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'dz.tabibi.mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final p in _pts)
                          if (p['lat'] != null && p['lng'] != null)
                            Marker(
                              point: LatLng((p['lat'] as num).toDouble(),
                                  (p['lng'] as num).toDouble()),
                              width: _taille(p['n'] as num),
                              height: _taille(p['n'] as num),
                              child: GestureDetector(
                                onTap: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${p['wilaya_fr'] ?? 'Wilaya'} — ${p['n']} médecins'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Tabibi.vert.withOpacity(0.85),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _court(p['n'] as num),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
