import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session.dart';
import '../services/supabase_service.dart';
import '../theme/theme_tabibi.dart';
import 'medecin_absences_page.dart';
import 'medecin_avis_page.dart';
import 'medecin_notifications_page.dart';
import 'medecin_stats_page.dart';
import 'medecin_verification_page.dart';
import 'medecin_disponibilites_page.dart';
import 'medecin_apercu_public_page.dart';
import 'medecin_cabinet_page.dart';
import 'medecin_modeles_ordonnance_page.dart';
import 'medecin_parametres_page.dart';
import 'medecin_ordonnances_page.dart';
import 'medecin_profil_page.dart';

/// Onglet « Compte » du praticien : accès à la fiche, aux disponibilités,
/// aux ordonnances émises, aux avis reçus, et déconnexion.
class MedecinComptePage extends StatelessWidget {
  const MedecinComptePage({super.key, this.auth});

  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    final a = auth ?? session;
    final email = sb.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(email, style: const TextStyle(color: Tabibi.texteDoux)),
            ),
          _tuile(context, Icons.insights_outlined, 'Statistiques', 'Revenus, présence, patients, activité',
              () => const MedecinStatsPage()),
          _tuile(context, Icons.notifications_none, 'Notifications', 'Rendez-vous, messages, avis',
              () => MedecinNotificationsPage(auth: a)),
          _tuile(context, Icons.badge_outlined, 'Ma fiche', 'Tarifs, paiement, téléconsultation, bio',
              () => MedecinProfilPage(auth: a)),
          _tuile(context, Icons.visibility_outlined, 'Aperçu fiche publique', 'Voir votre fiche comme les patients',
              () => const MedecinApercuPublicPage()),
          _tuile(context, Icons.verified_user_outlined, 'Vérification', 'Numéro d\'Ordre, documents, badge vérifié',
              () => MedecinVerificationPage(auth: a)),
          _tuile(context, Icons.schedule_outlined, 'Mes disponibilités', 'Horaires d\'ouverture par jour',
              () => MedecinDisponibilitesPage(auth: a)),
          _tuile(context, Icons.event_busy_outlined, 'Congés / absences', 'Bloquer des plages sans rendez-vous',
              () => MedecinAbsencesPage(auth: a)),
          _tuile(context, Icons.description_outlined, 'Mes ordonnances', 'Émettre et consulter les ordonnances',
              () => MedecinOrdonnancesPage(auth: a)),
          _tuile(context, Icons.article_outlined, 'Modèles d\'ordonnances', 'Listes de médicaments réutilisables',
              () => const MedecinModelesOrdonnancePage()),
          _tuile(context, Icons.star_outline, 'Avis reçus', 'Les avis de vos patients',
              () => MedecinAvisPage(auth: a)),
          _tuile(context, Icons.business_outlined, 'Mon cabinet', 'Équipe, médecins et secrétariat',
              () => MedecinCabinetPage(auth: a)),
          _tuile(context, Icons.settings_outlined, 'Paramètres', 'Sécurité, notifications, suppression du compte',
              () => MedecinParametresPage(auth: a)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => a.seDeconnecter(),
            icon: const Icon(Icons.logout, color: Tabibi.rouge),
            label: const Text('Se déconnecter', style: TextStyle(color: Tabibi.rouge)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Tabibi.rouge),
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }

  Widget _tuile(BuildContext context, IconData icone, String titre, String sous, Widget Function() page) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Tabibi.ombreDouce),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
          child: Icon(icone, color: Tabibi.vert, size: 20),
        ),
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
        subtitle: Text(sous, style: const TextStyle(color: Tabibi.texteDoux, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Tabibi.texte4),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page())),
      ),
    );
  }
}
