import 'package:flutter/material.dart';

/// Message d'erreur centre avec un bouton « Reessayer ».
class VueErreur extends StatelessWidget {
  const VueErreur({super.key, required this.message, required this.onReessayer});

  final String message;
  final VoidCallback onReessayer;

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
            OutlinedButton(onPressed: onReessayer, child: const Text('Reessayer')),
          ],
        ),
      ),
    );
  }
}
