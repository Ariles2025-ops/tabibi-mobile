import 'package:flutter/material.dart';

import '../config/referentiel.dart';
import '../i18n/langue.dart';

/// Liste deroulante des 69 wilayas du referentiel (« 16 - Alger ») ; la valeur est le code.
class ChampWilaya extends StatelessWidget {
  const ChampWilaya({
    super.key,
    required this.valeur,
    required this.onChanged,
    this.obligatoire = false,
    this.actif = true,
  });

  /// Code de la wilaya choisie (« 16 ») ; null si aucune.
  final String? valeur;
  final ValueChanged<String?> onChanged;

  /// Ajoute « * » au libelle et retire le choix « Aucune ».
  final bool obligatoire;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    final code = wilayaParCode(valeur)?.code;
    return DropdownButtonFormField<String>(
      key: ValueKey('wilaya-$code'),
      initialValue: code,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: obligatoire ? t('Wilaya *', 'الولاية *') : t('Wilaya', 'الولاية'),
        prefixIcon: const Icon(Icons.map_outlined),
      ),
      items: [
        if (!obligatoire) DropdownMenuItem<String>(value: null, child: Text(t('Aucune', 'بدون'))),
        for (final w in wilayas)
          DropdownMenuItem(
            value: w.code,
            child: Text('${w.code} - ${nomWilaya(w)}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: actif ? onChanged : null,
    );
  }
}
