// Lecture des notifications de l'utilisateur (voir `NotificationUtilisateur`) :
// date, tri, compteur de non lues et libelle de l'entree d'accueil.

import '../i18n/langue.dart';
import '../models/notification.dart';
import 'dates.dart';
import 'liens_appli.dart';

/// Date de creation formatee (« jeu. 4 dec. 09:00 ») ; « date inconnue » si absente.
String dateNotification(NotificationUtilisateur notification) {
  final creeLe = notification.creeLe;
  return creeLe == null ? t('date inconnue', 'تاريخ غير معروف') : formaterDateHeure(creeLe);
}

/// Copie triee de la plus recente a la plus ancienne (`creeLe`) ;
/// les dates absentes sont placees en fin de liste.
List<NotificationUtilisateur> trierParCreation(List<NotificationUtilisateur> notifications) {
  final copie = List<NotificationUtilisateur>.of(notifications);
  copie.sort((a, b) {
    final da = a.creeLe;
    final db = b.creeLe;
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return copie;
}

/// Nombre de notifications non lues d'une liste.
int compterNonLues(Iterable<NotificationUtilisateur> notifications) =>
    notifications.where((n) => !n.lue).length;

/// Libelle de l'entree d'accueil : « Notifications (3) », ou simplement « Notifications »
/// sans non lue ou tant que le nombre est inconnu (hors connexion, echec).
String libelleNotifications(int? nonLues) {
  final libelle = t('Notifications', 'الإشعارات');
  return nonLues != null && nonLues > 0 ? '$libelle ($nonLues)' : libelle;
}

/// Ecrans de l'appli pouvant etre ouverts depuis le lien d'une notification.
enum TypeCible { rendezVous, ordonnances, ordonnance, medecin, conversations, conversation, dawini, besoin, avis, listeAttente, agenda, avisMedecin, secretaires, candidature, cabinets, invitations, teleconsultations }

/// Ecran cible d'un lien de notification ; [id] n'est renseigne que pour les ecrans de detail.
class CibleNotification {
  const CibleNotification(this.type, [this.id]);

  final TypeCible type;
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is CibleNotification && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Associe un lien d'API (`/mes-rendez-vous`, `/ordonnances/{id}`, `/medecins/{id}`,
/// `/messagerie/{id}`, `/dawini`...) a un ecran de l'appli ; null si le lien est vide
/// ou n'a pas d'ecran correspondant.
CibleNotification? cibleDuLien(String lien) {
  final brut = lien.trim();
  // Comme le site : seul un chemin interne (« /... ») est suivi, jamais un lien externe (« //hote »).
  if (!brut.startsWith('/') || brut.startsWith('//')) return null;
  final chemin = brut.split(RegExp('[?#]')).first;
  final segments = chemin.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty || segments.length > 2) return null;
  final id = segments.length == 2 ? decoderSegment(segments[1]) : null;
  // Identifiant mal encode : lien inutilisable, pas de « Voir » (au lieu d'un plantage).
  if (segments.length == 2 && id == null) return null;
  switch (segments[0]) {
    case 'mes-rendez-vous':
      return id == null ? const CibleNotification(TypeCible.rendezVous) : null;
    case 'ordonnances':
      return id == null
          ? const CibleNotification(TypeCible.ordonnances)
          : CibleNotification(TypeCible.ordonnance, id);
    case 'medecins':
      return id == null ? null : CibleNotification(TypeCible.medecin, id);
    case 'messagerie':
      return id == null
          ? const CibleNotification(TypeCible.conversations)
          : CibleNotification(TypeCible.conversation, id);
    case 'dawini':
      // `/dawini/{id}` : reponses de la demande, comme sur le site (`/dawini/:id`).
      return id == null
          ? const CibleNotification(TypeCible.dawini)
          : CibleNotification(TypeCible.besoin, id);
    case 'mes-avis':
      return id == null ? const CibleNotification(TypeCible.avis) : null;
    case 'liste-attente':
      return id == null ? const CibleNotification(TypeCible.listeAttente) : null;
    case 'medecin':
      // Liens envoyes aux medecins : `/medecin/agenda`, `/medecin/avis`, `/medecin/secretaires`, `/medecin/candidature`.
      if (segments.length != 2) return null;
      switch (segments[1]) {
        case 'agenda':
          return const CibleNotification(TypeCible.agenda);
        case 'avis':
          return const CibleNotification(TypeCible.avisMedecin);
        case 'secretaires':
          return const CibleNotification(TypeCible.secretaires);
        case 'candidature':
          return const CibleNotification(TypeCible.candidature);
        default:
          return null;
      }
    case 'secretaire':
      return id == null ? const CibleNotification(TypeCible.cabinets) : null;
    case 'invitations':
      return id == null ? const CibleNotification(TypeCible.invitations) : null;
    case 'teleconsultations':
      return id == null ? const CibleNotification(TypeCible.teleconsultations) : null;
    default:
      return null;
  }
}

/// Vrai si la notification ouvre un ecran (donc « Voir → », comme sur le site) : un lien sans
/// ecran n'est pas propose, et `/teleconsultations` n'ouvre rien tant que la visio est « Bientôt ».
bool ouvreUnEcran(String lien, {required bool visioActive}) {
  final cible = cibleDuLien(lien);
  if (cible == null) return false;
  return cible.type != TypeCible.teleconsultations || visioActive;
}
