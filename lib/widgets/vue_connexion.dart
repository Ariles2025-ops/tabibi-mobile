import 'package:flutter/material.dart';

import '../i18n/langue.dart';

/// Invitation a se connecter : message centre et bouton « Se connecter ».
class VueConnexion extends StatelessWidget {
  const VueConnexion({super.key, required this.message, required this.onSeConnecter});

  final String message;
  final VoidCallback onSeConnecter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onSeConnecter,
              child: Text(t(context, 'commun.seConnecter')),
            ),
          ],
        ),
      ),
    );
  }
}
