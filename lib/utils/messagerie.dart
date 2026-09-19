// Lecture des conversations et des messages (voir `Conversation` et `Message`) : auteur
// et alignement des bulles, dates, tri des conversations et libelle des non lus.

import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import 'dates.dart';

/// Vrai si le message a ete ecrit par l'utilisateur connecte, [moi] etant son identifiant
/// (sujet du jeton) ; faux si cet identifiant est inconnu.
bool estDeMoi(Message message, String? moi) =>
    moi != null && moi.isNotEmpty && message.auteurId == moi;

/// Alignement de la bulle : a droite pour mes messages, a gauche pour ceux du praticien.
Alignment alignementMessage(Message message, String? moi) =>
    estDeMoi(message, moi) ? Alignment.centerRight : Alignment.centerLeft;

/// Date d'envoi formatee (« jeu. 4 dec. 09:00 ») ; « date inconnue » si absente.
String dateMessage(Message message) {
  final envoyeLe = message.envoyeLe;
  return envoyeLe == null ? 'date inconnue' : formaterDateHeure(envoyeLe);
}

/// Activite d'une conversation : « Dernier message le jeu. 4 dec. 09:00 », sinon
/// « Ouverte le ... » (date d'ouverture), sinon « Aucun message ».
String libelleActivite(Conversation conversation) {
  final dernierMessageLe = conversation.dernierMessageLe;
  if (dernierMessageLe != null) {
    return 'Dernier message le ${formaterDateHeure(dernierMessageLe)}';
  }
  final creeLe = conversation.creeLe;
  if (creeLe != null) return 'Ouverte le ${formaterDateHeure(creeLe)}';
  return 'Aucun message';
}

/// Pastille textuelle des non lus : « 1 non lu », « 3 non lus » ; chaine vide sans non lu.
String libelleNonLus(int nonLus) {
  if (nonLus <= 0) return '';
  return nonLus == 1 ? '1 non lu' : '$nonLus non lus';
}

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
