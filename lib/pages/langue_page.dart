import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../i18n/traductions.dart';

/// Choix de la langue de l'interface : Français, العربية (arabe) ou English.
///
/// Le choix est memorise sur le telephone (`shared_preferences`) et s'applique aussitot a
/// toute l'application (titre, libelles, dates, et direction d'ecriture : l'arabe s'affiche
/// de droite a gauche). Sans choix, l'application suit la langue du telephone, puis celle du
/// profil enregistre sur le serveur.
class LanguePage extends StatelessWidget {
  const LanguePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controleur = LangueScope.de(context);
    final texte = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'langue.titre'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t(context, 'langue.explication'), style: texte.bodySmall),
          const SizedBox(height: 12),
          for (final code in languesInterface)
            ListTile(
              leading: Icon(code == controleur.langue
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(nomsLangues[code] ?? code),
              onTap: () => _choisir(context, controleur, code),
            ),
        ],
      ),
    );
  }

  /// Applique et memorise la langue choisie, puis confirme dans cette langue.
  Future<void> _choisir(BuildContext context, ControleurLangue controleur, String choisie) async {
    if (choisie == controleur.langue) return;
    // Le messager est retenu avant l'attente : le contexte ne sert plus apres.
    final messager = ScaffoldMessenger.of(context);
    await controleur.choisir(choisie);
    messager.showSnackBar(SnackBar(content: Text(traduire(choisie, 'langue.enregistree'))));
  }
}
