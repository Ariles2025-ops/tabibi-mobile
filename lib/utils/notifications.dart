// Lecture des notifications de l'utilisateur (voir `NotificationUtilisateur`) :
// date, tri, compteur de non lues et libelle de l'entree d'accueil.

import '../models/notification.dart';
import 'dates.dart';

/// Date de creation formatee (« jeu. 4 dec. 09:00 ») ; « date inconnue » si absente.
String dateNotification(NotificationUtilisateur notification) {
  final creeLe = notification.creeLe;
  return creeLe == null ? 'date inconnue' : formaterDateHeure(creeLe);
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
String libelleNotifications(int? nonLues) =>
    nonLues != null && nonLues > 0 ? 'Notifications ($nonLues)' : 'Notifications';
