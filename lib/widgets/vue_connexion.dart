import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../i18n/langue.dart';
import 'liens_legaux.dart';

/// Invitation a se connecter : pictogramme, message centre, bouton « Se connecter » et liens
/// confidentialite / conditions.
class VueConnexion extends StatelessWidget {
  const VueConnexion({super.key, required this.message, required this.onSeConnecter});

  final String message;
  final VoidCallback onSeConnecter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: Charte.pastille, shape: BoxShape.circle),
              child: const Icon(Icons.lock_person_outlined, size: 40, color: Charte.vert),
            ),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: onSeConnecter,
                child: Text(t('Se connecter', 'تسجيل الدخول')),
              ),
            ),
            const SizedBox(height: 32),
            const LiensLegaux(),
          ],
        ),
      ),
    );
  }
}
