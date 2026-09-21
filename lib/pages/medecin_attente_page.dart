import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/session.dart';
import '../services/supabase_service.dart';
import '../theme/theme_tabibi.dart';

/// Ecran affiche a un praticien dont le compte est cree mais pas encore valide
/// par un administrateur : il n'a pas acces a l'app tant qu'il n'est pas valide.
class MedecinAttentePage extends StatelessWidget {
  const MedecinAttentePage({super.key, this.auth});

  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    final a = auth ?? session;
    final email = sb.auth.currentUser?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Tabibi.orClair, shape: BoxShape.circle),
                  child: const Icon(Icons.hourglass_top_rounded, size: 40, color: Tabibi.orTexte),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Compte en attente de validation',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Tabibi.ink),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Votre compte praticien a bien été créé et votre e-mail vérifié. '
                  'Un administrateur Tabibi doit maintenant valider vos informations '
                  '(inscription à l\'Ordre, spécialité). Vous accéderez à votre espace '
                  'médecin dès que votre compte sera validé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Tabibi.texteDoux, height: 1.5),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Tabibi.bg2, borderRadius: BorderRadius.circular(999)),
                    child: Text(email, style: const TextStyle(color: Tabibi.texte, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () async {
                    a.seDeconnecter();
                    await sb.auth.signOut();
                  },
                  icon: const Icon(Icons.logout, color: Tabibi.rouge),
                  label: const Text('Se déconnecter', style: TextStyle(color: Tabibi.rouge)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Tabibi.rouge)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
