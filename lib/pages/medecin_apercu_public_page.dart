import 'package:flutter/material.dart';

import '../services/medecin_supabase.dart';
import '../theme/theme_tabibi.dart';

/// Aperçu de la fiche publique : ce que les patients voient réellement
/// (données issues de la vue RGPD `public_doctors`).
class MedecinApercuPublicPage extends StatefulWidget {
  const MedecinApercuPublicPage({super.key, this.medecin = const MedecinSupabase()});

  final MedecinSupabase medecin;

  @override
  State<MedecinApercuPublicPage> createState() => _MedecinApercuPublicPageState();
}

class _MedecinApercuPublicPageState extends State<MedecinApercuPublicPage> {
  bool _charge = true;
  Map<String, dynamic>? _fiche;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final f = await widget.medecin.apercuFichePublique();
      if (mounted) setState(() { _fiche = f; _charge = false; });
    } on Object {
      if (mounted) setState(() => _charge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _fiche;
    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu fiche publique')),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : f == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'Votre fiche n\'est pas encore visible publiquement.\n'
                        'Elle apparaîtra une fois votre compte réclamé et validé.',
                        textAlign: TextAlign.center, style: TextStyle(color: Tabibi.texteDoux)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Tabibi.pastille, borderRadius: BorderRadius.circular(12)),
                      child: const Row(children: [
                        Icon(Icons.visibility_outlined, color: Tabibi.vert, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text('Vue patient — informations publiques uniquement',
                            style: TextStyle(color: Tabibi.texte, fontSize: 12))),
                      ]),
                    ),
                    _carteEntete(f),
                    const SizedBox(height: 12),
                    if ('${f['bio'] ?? ''}'.isNotEmpty) _section('À propos', Text('${f['bio']}')),
                    _section('Localisation', Text(
                        [f['address'], f['city'], f['wilaya_fr']].where((x) => '$x'.isNotEmpty && x != null).join(', '))),
                    _section('Tarifs', _tarifs(f)),
                    _section('Paiement acceptés', _paiements(f)),
                  ],
                ),
    );
  }

  Widget _carteEntete(Map<String, dynamic> f) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Row(children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Tabibi.pastille,
          backgroundImage: ('${f['photo_url'] ?? ''}'.isNotEmpty) ? NetworkImage('${f['photo_url']}') : null,
          child: ('${f['photo_url'] ?? ''}'.isEmpty) ? const Icon(Icons.person, color: Tabibi.vert, size: 30) : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${f['full_name'] ?? ''}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Tabibi.texte))),
              if (f['is_verified'] == true)
                const Icon(Icons.verified, color: Tabibi.vert, size: 18),
            ]),
            const SizedBox(height: 2),
            Text('${f['specialty_fr'] ?? ''}', style: const TextStyle(color: Tabibi.texteDoux)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.star, color: Tabibi.or, size: 15),
              const SizedBox(width: 3),
              Text('${(f['rating'] as num?)?.toStringAsFixed(1) ?? '—'} (${f['review_count'] ?? 0} avis)',
                  style: const TextStyle(fontSize: 12, color: Tabibi.texteDoux)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _tarifs(Map<String, dynamic> f) {
    final consult = f['consultation_fee_dzd'];
    final teleActif = f['telehealth_enabled'] == true;
    final tele = f['telehealth_fee_dzd'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Consultation : ${consult == null ? '—' : '$consult DA'}'),
      if (teleActif) Text('Téléconsultation : ${tele == null ? '—' : '$tele DA'}'),
    ]);
  }

  Widget _paiements(Map<String, dynamic> f) {
    final chips = <String>[
      if (f['accepts_cash'] == true) 'Espèces',
      if (f['accepts_card'] == true) 'Carte',
      if (f['accepts_chifa'] == true) 'Chifa',
    ];
    if (chips.isEmpty) return const Text('—');
    return Wrap(spacing: 8, runSpacing: 6, children: [
      for (final c in chips)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Tabibi.pastille, borderRadius: BorderRadius.circular(999)),
          child: Text(c, style: const TextStyle(fontSize: 12, color: Tabibi.vert)),
        ),
    ]);
  }

  Widget _section(String titre, Widget contenu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, color: Tabibi.texte)),
        const SizedBox(height: 6),
        DefaultTextStyle(style: const TextStyle(color: Tabibi.texteDoux), child: contenu),
      ]),
    );
  }
}
