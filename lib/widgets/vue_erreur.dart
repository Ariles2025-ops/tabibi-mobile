import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../i18n/langue.dart';

/// Etat d'erreur commun a tous les ecrans qui chargent des donnees : icone, message clair
/// (ex. « Pas de connexion. Vérifiez votre réseau. ») et bouton « Réessayer ».
///
/// Style de la charte ([Charte] : vert, pastille, texte doux). Le sens RTL suit la langue de l'appli.
class VueErreur extends StatelessWidget {
  const VueErreur(
      {super.key, required this.message, required this.onReessayer});

  final String message;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: Charte.pastille, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 32, color: Charte.vert),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Charte.texte,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReessayer,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t('Réessayer', 'إعادة المحاولة')),
            ),
          ],
        ),
      ),
    );
  }
}
