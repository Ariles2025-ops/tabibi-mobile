import 'package:flutter/material.dart';

import '../i18n/langue.dart';

/// Choix de la langue (Français / العربية) : bouton de l'AppBar ouvrant un menu.
/// Le choix est memorise sur le telephone et l'appli bascule aussitot (RTL en arabe).
class SelecteurLangue extends StatelessWidget {
  const SelecteurLangue({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: t('Langue', 'اللغة'),
      icon: const Icon(Icons.translate),
      initialValue: Langue.courante.value,
      onSelected: Langue.choisir,
      itemBuilder: (_) => [
        for (final code in Langue.codes) PopupMenuItem(value: code, child: Text(Langue.nom(code))),
      ],
    );
  }
}

/// Meme choix sous forme de champ (Mon profil) : boutons segmentes Français | العربية.
class ChampLangue extends StatelessWidget {
  const ChampLangue({super.key});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: t("Langue de l'appli", 'لغة التطبيق'),
        prefixIcon: const Icon(Icons.translate),
      ),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          for (final code in Langue.codes)
            ButtonSegment(value: code, label: Text(Langue.nom(code))),
        ],
        selected: {Langue.courante.value},
        onSelectionChanged: (choix) => Langue.choisir(choix.first),
      ),
    );
  }
}
