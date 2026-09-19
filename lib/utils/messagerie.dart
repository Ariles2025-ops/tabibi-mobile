// Lecture des conversations et des messages (voir `Conversation` et `Message`) : auteur
// et alignement des bulles, dates, tri des conversations et libelle des non lus.

import 'package:flutter/material.dart';

import '../i18n/traductions.dart' as i18n;
import '../models/conversation.dart';
import '../models/message.dart';
import 'dates.dart';

/// Vrai si le message a ete ecrit par l'utilisateur connecte, [moi] etant son identifiant
/// (sujet du jeton) ; faux si cet identifiant est inconnu.
bool estDeMoi(Message message, String? moi) =>
    moi != null && moi.isNotEmpty && message.auteurId == moi;

/// Alignement de la bulle : du cote de la fin de ligne pour mes messages, du cote du debut
/// pour ceux du praticien. L'alignement est directionnel : il suit la langue (a droite en
/// francais et en anglais, a gauche en arabe, qui s'ecrit de droite a gauche).
AlignmentDirectional alignementMessage(Message message, String? moi) =>
    estDeMoi(message, moi) ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart;

/// Date d'envoi formatee (« jeu. 4 déc. 09:00 ») ; « date inconnue » si absente.
String dateMessage(String langue, Message message) {
  final envoyeLe = message.envoyeLe;
  return envoyeLe == null
      ? i18n.traduire(langue, 'commun.dateInconnue')
      : formaterDateHeure(langue, envoyeLe);
}

/// Activite d'une conversation : « Dernier message le jeu. 4 déc. 09:00 », sinon
/// « Ouverte le ... » (date d'ouverture), sinon « Aucun message ».
String libelleActivite(String langue, Conversation conversation) {
  final dernierMessageLe = conversation.dernierMessageLe;
  if (dernierMessageLe != null) {
    return i18n.traduire(langue, 'messagerie.dernierMessageLe',
        params: {'date': formaterDateHeure(langue, dernierMessageLe)});
  }
  final creeLe = conversation.creeLe;
  if (creeLe != null) {
    return i18n.traduire(langue, 'messagerie.ouverteLe',
        params: {'date': formaterDateHeure(langue, creeLe)});
  }
  return i18n.traduire(langue, 'messagerie.aucunMessage');
}

/// Pastille textuelle des non lus : « 1 non lu », « 3 non lus » ; chaine vide sans non lu.
String libelleNonLus(String langue, int nonLus) =>
    nonLus <= 0 ? '' : i18n.traduirePluriel(langue, 'messagerie.nonLus', nonLus);

/// Copie triee de l'activite la plus recente a la plus ancienne ([Conversation.derniereActivite]) ;
/// les conversations sans date sont placees en fin de liste.
List<Conversation> trierParActivite(List<Conversation> conversations) {
  final copie = List<Conversation>.of(conversations);
  copie.sort((a, b) {
    final da = a.derniereActivite;
    final db = b.derniereActivite;
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return copie;
}
