import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/models/conversation.dart';
import 'package:tabibi_mobile/models/message.dart';
import 'package:tabibi_mobile/utils/jetons.dart';
import 'package:tabibi_mobile/utils/messagerie.dart';

import 'outils.dart';

void main() {
  test("Conversation.fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final c = Conversation.fromJson({
      'id': 'c1c1c1c1-0000-4000-8000-000000000001',
      'patientId': 'a1a1a1a1-0000-4000-8000-000000000007',
      'medecinId': '00000000-0000-0000-0000-000000000001',
      'creeLe': '2026-11-20T09:00:00',
      'dernierMessageLe': '2026-12-01T09:05:00',
      'nonLus': 2,
    });
    expect(c.id, 'c1c1c1c1-0000-4000-8000-000000000001');
    expect(c.patientId, 'a1a1a1a1-0000-4000-8000-000000000007');
    expect(c.medecinId, '00000000-0000-0000-0000-000000000001');
    expect(c.creeLe, DateTime(2026, 11, 20, 9));
    expect(c.dernierMessageLe, DateTime(2026, 12, 1, 9, 5));
    expect(c.nonLus, 2);
    expect(c.derniereActivite, DateTime(2026, 12, 1, 9, 5));
  });

  test('Conversation.fromJson tolere les valeurs nulles ou absentes et un identifiant numerique',
      () {
    final vide = Conversation.fromJson({});
    expect(vide.id, '');
    expect(vide.patientId, '');
    expect(vide.medecinId, '');
    expect(vide.creeLe, isNull);
    expect(vide.dernierMessageLe, isNull);
    expect(vide.nonLus, 0);
    expect(vide.derniereActivite, isNull);

    final sansMessage = Conversation.fromJson({
      'id': 'conv-1',
      'medecinId': 1,
      'creeLe': '2026-11-20T09:00:00',
      'dernierMessageLe': null,
      'nonLus': null,
    });
    expect(sansMessage.medecinId, '1');
    expect(sansMessage.dernierMessageLe, isNull);
    expect(sansMessage.nonLus, 0);
    expect(sansMessage.derniereActivite, DateTime(2026, 11, 20, 9));
  });

  test("Message.fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final m = Message.fromJson({
      'id': 'm1m1m1m1-0000-4000-8000-000000000001',
      'conversationId': 'c1c1c1c1-0000-4000-8000-000000000001',
      'auteurId': 'a1a1a1a1-0000-4000-8000-000000000007',
      'contenu': 'Bonjour docteur',
      'envoyeLe': '2026-12-01T09:05:00',
      'luLe': '2026-12-01T10:00:00',
    });
    expect(m.id, 'm1m1m1m1-0000-4000-8000-000000000001');
    expect(m.conversationId, 'c1c1c1c1-0000-4000-8000-000000000001');
    expect(m.auteurId, 'a1a1a1a1-0000-4000-8000-000000000007');
    expect(m.contenu, 'Bonjour docteur');
    expect(m.envoyeLe, DateTime(2026, 12, 1, 9, 5));
    expect(m.luLe, DateTime(2026, 12, 1, 10));
    expect(m.estLu, isTrue);
  });

  test('Message.fromJson tolere les valeurs nulles ou absentes (message non lu)', () {
    final vide = Message.fromJson({});
    expect(vide.id, '');
    expect(vide.auteurId, '');
    expect(vide.contenu, '');
    expect(vide.envoyeLe, isNull);
    expect(vide.luLe, isNull);
    expect(vide.estLu, isFalse);

    final nonLu = Message.fromJson({'id': 'm-1', 'contenu': null, 'luLe': null, 'envoyeLe': 'n/a'});
    expect(nonLu.contenu, '');
    expect(nonLu.estLu, isFalse);
    expect(nonLu.envoyeLe, isNull);
  });

  test('estDeMoi et alignementMessage distinguent mes messages de ceux du medecin', () {
    final mien = Message.fromJson({'id': 'm-1', 'auteurId': 'patient-7', 'contenu': 'Bonjour'});
    final sien = Message.fromJson({'id': 'm-2', 'auteurId': 'medecin-1', 'contenu': 'Bonjour'});
    expect(estDeMoi(mien, 'patient-7'), isTrue);
    expect(estDeMoi(sien, 'patient-7'), isFalse);
    expect(alignementMessage(mien, 'patient-7'), Alignment.centerRight);
    expect(alignementMessage(sien, 'patient-7'), Alignment.centerLeft);
    // Identifiant inconnu : rien n'est attribue au patient.
    expect(estDeMoi(mien, null), isFalse);
    expect(estDeMoi(mien, ''), isFalse);
    expect(alignementMessage(mien, null), Alignment.centerLeft);
  });

  test('dateMessage formate envoyeLe et signale une date absente', () {
    expect(
      dateMessage(Message.fromJson({'envoyeLe': '2026-12-03T10:15:00'})),
      'jeu. 3 dec. 10:15',
    );
    expect(dateMessage(Message.fromJson({})), 'date inconnue');
  });

  test("libelleActivite prefere le dernier message, sinon l'ouverture", () {
    expect(
      libelleActivite(Conversation.fromJson({
        'creeLe': '2026-11-20T09:00:00',
        'dernierMessageLe': '2026-12-01T09:05:00',
      })),
      'Dernier message le mar. 1 dec. 09:05',
    );
    expect(
      libelleActivite(Conversation.fromJson({'creeLe': '2026-11-20T09:00:00'})),
      'Ouverte le ven. 20 nov. 09:00',
    );
    expect(libelleActivite(Conversation.fromJson({})), 'Aucun message');
  });

  test('libelleNonLus accorde le nombre et se tait sans non lu', () {
    expect(libelleNonLus(0), '');
    expect(libelleNonLus(1), '1 non lu');
    expect(libelleNonLus(3), '3 non lus');
  });

  test("trierParActivite place l'activite la plus recente en tete et les dates absentes en fin",
      () {
    final triees = trierParActivite([
      Conversation.fromJson({'id': '1', 'creeLe': '2026-01-10T09:00:00'}),
      Conversation.fromJson({'id': '2'}),
      Conversation.fromJson({
        'id': '3',
        'creeLe': '2026-01-01T09:00:00',
        'dernierMessageLe': '2026-03-05T09:00:00',
      }),
    ]);
    expect(triees.map((c) => c.id).toList(), ['3', '1', '2']);
  });

  test("sujetDuJeton lit le sujet d'un JWT et ignore un jeton opaque", () {
    expect(sujetDuJeton(jetonAvecSujet('a1a1a1a1-0000-4000-8000-000000000007')),
        'a1a1a1a1-0000-4000-8000-000000000007');
    expect(sujetDuJeton('jeton-test'), isNull);
    expect(sujetDuJeton(null), isNull);
    expect(sujetDuJeton('a.b.c'), isNull);
    // Charge utile lisible mais sans sujet.
    final sansSujet = base64Url.encode(utf8.encode('{"exp":1}'));
    expect(sujetDuJeton('entete.$sansSujet.signature'), isNull);
  });
}
