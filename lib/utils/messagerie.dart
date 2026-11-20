// Lecture des conversations et des messages (voir `Conversation` et `Message`) : auteur
// et alignement des bulles, dates, tri des conversations et libelle des non lus.

import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../i18n/langue.dart';
import 'dates.dart';

/// Vrai si le message a ete ecrit par l'utilisateur connecte, [moi] etant son identifiant
/// (sujet du jeton) ; faux si cet identifiant est inconnu.
bool estDeMoi(Message message, String? moi) =>
    moi != null && moi.isNotEmpty && message.auteurId == moi;

/// Alignement de la bulle : en fin de ligne pour mes messages (a droite en francais, a gauche en
/// arabe), en debut de ligne pour ceux du praticien.
AlignmentDirectional alignementMessage(Message message, String? moi) =>
    estDeMoi(message, moi) ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart;

/// Date d'envoi formatee (« jeu. 4 dec. 09:00 ») ; « date inconnue » si absente.
String dateMessage(Message message) {
  final envoyeLe = message.envoyeLe;
  return envoyeLe == null ? t('date inconnue', 'تاريخ غير معروف') : formaterDateHeure(envoyeLe);
}

/// Activite d'une conversation : « Dernier message le jeu. 4 dec. 09:00 », sinon
/// « Ouverte le ... » (date d'ouverture), sinon « Aucun message ».
String libelleActivite(Conversation conversation) {
  final dernierMessageLe = conversation.dernierMessageLe;
  if (dernierMessageLe != null) {
    return t('Dernier message le ${formaterDateHeure(dernierMessageLe)}',
        'آخر رسالة في ${formaterDateHeure(dernierMessageLe)}');
  }
  final creeLe = conversation.creeLe;
  if (creeLe != null) {
    return t('Ouverte le ${formaterDateHeure(creeLe)}', 'فُتحت في ${formaterDateHeure(creeLe)}');
  }
  return t('Aucun message', 'لا توجد رسائل');
}

/// Pastille textuelle des non lus : « 1 non lu », « 3 non lus » ; chaine vide sans non lu.
String libelleNonLus(int nonLus) {
  if (nonLus <= 0) return '';
  return nonLus == 1
      ? t('1 non lu', 'رسالة واحدة غير مقروءة')
      : t('$nonLus non lus', '$nonLus غير مقروءة');
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

/// Texte de la liste vide, comme le site : la messagerie s'ouvre depuis la fiche d'un médecin
/// seulement une fois un rendez-vous pris (sinon l'API répond 403).
String texteAucuneConversation() => t(
    'Aucune conversation pour le moment. Vous pouvez écrire à un médecin depuis sa fiche, une fois un rendez-vous pris.',
    'لا توجد محادثات حاليًا. يمكنك مراسلة طبيب من صفحته بعد حجز موعد.');
