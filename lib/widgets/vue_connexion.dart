import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../theme/theme_tabibi.dart';

/// Ecran « connectez-vous » epure (facon Doctolib) : icone dans un cercle,
/// titre, message et bouton « Se connecter » pleine largeur.
class VueConnexion extends StatelessWidget {
  const VueConnexion({
    super.key,
    required this.message,
    required this.onSeConnecter,
    this.icone = Icons.lock_outline,
    this.titre,
  });

  final String message;
  final VoidCallback onSeConnecter;

  /// Icone illustrative (par onglet) ; cadenas par defaut.
  final IconData icone;

  /// Titre court au-dessus du message (optionnel).
  final String? titre;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: Tabibi.pastille, shape: BoxShape.circle),
              child: Icon(icone, size: 44, color: Tabibi.vert),
            ),
            const SizedBox(height: 20),
            if (titre != null) ...[
              Text(titre!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Tabibi.ink)),
              const SizedBox(height: 10),
            ],
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Tabibi.texteDoux, height: 1.45, fontSize: 15)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSeConnecter,
                child: Text(t(context, 'commun.seConnecter')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
