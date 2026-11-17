import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import 'liens_legaux.dart';

/// Invitation a se connecter : message centre, bouton « Se connecter » et liens confidentialite / conditions.
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
            FilledButton(onPressed: onSeConnecter, child: Text(t('Se connecter', 'تسجيل الدخول'))),
            const SizedBox(height: 16),
            const LiensLegaux(),
          ],
        ),
      ),
    );
  }
}
