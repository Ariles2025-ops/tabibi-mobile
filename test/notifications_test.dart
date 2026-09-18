import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/models/notification.dart';
import 'package:tabibi_mobile/utils/notifications.dart';

void main() {
  test("fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final n = NotificationUtilisateur.fromJson({
      'id': 'b7f1e2c4-0000-4000-8000-000000000001',
      'destinataireId': 'a1a1a1a1-0000-4000-8000-000000000007',
      'canal': 'INTERNE',
      'sujet': 'Rendez-vous confirme',
      'message': 'Votre rendez-vous du 3 dec. 2026 09:00 est confirme.',
      'lue': false,
      'creeLe': '2026-12-01T18:00:00',
    });
    expect(n.id, 'b7f1e2c4-0000-4000-8000-000000000001');
    expect(n.destinataireId, 'a1a1a1a1-0000-4000-8000-000000000007');
    expect(n.canal, 'INTERNE');
    expect(n.sujet, 'Rendez-vous confirme');
    expect(n.message, 'Votre rendez-vous du 3 dec. 2026 09:00 est confirme.');
    expect(n.lue, isFalse);
    expect(n.creeLe, DateTime(2026, 12, 1, 18));
  });

  test('fromJson tolere les valeurs nulles ou absentes et une date illisible', () {
    final vide = NotificationUtilisateur.fromJson({});
    expect(vide.id, '');
    expect(vide.destinataireId, '');
    expect(vide.canal, '');
    expect(vide.sujet, '');
    expect(vide.message, '');
    expect(vide.lue, isFalse);
    expect(vide.creeLe, isNull);

    final nulle = NotificationUtilisateur.fromJson({
      'id': null,
      'sujet': null,
      'message': null,
      'lue': null,
      'creeLe': 'n/a',
    });
    expect(nulle.id, '');
    expect(nulle.sujet, '');
    expect(nulle.lue, isFalse);
    expect(nulle.creeLe, isNull);
  });

  test("marquerLue produit une copie lue sans modifier l'original", () {
    final n = NotificationUtilisateur.fromJson({
      'id': 'n-1',
      'sujet': 'Sujet',
      'message': 'Message',
      'lue': false,
      'creeLe': '2026-12-01T18:00:00',
    });
    final lue = n.marquerLue();
    expect(lue.lue, isTrue);
    expect(lue.id, 'n-1');
    expect(lue.sujet, 'Sujet');
    expect(lue.message, 'Message');
    expect(lue.creeLe, n.creeLe);
    expect(n.lue, isFalse);
  });

  test('dateNotification formate creeLe et signale une date absente', () {
    expect(
      dateNotification(NotificationUtilisateur.fromJson({'creeLe': '2026-12-03T10:15:00'})),
      'jeu. 3 dec. 10:15',
    );
    expect(dateNotification(NotificationUtilisateur.fromJson({})), 'date inconnue');
  });

  test('trierParCreation place la plus recente en tete et les dates absentes en fin', () {
    final triees = trierParCreation([
      NotificationUtilisateur.fromJson({'id': '1', 'creeLe': '2026-01-10T09:00:00'}),
      NotificationUtilisateur.fromJson({'id': '2'}),
      NotificationUtilisateur.fromJson({'id': '3', 'creeLe': '2026-03-05T09:00:00'}),
    ]);
    expect(triees.map((n) => n.id).toList(), ['3', '1', '2']);
  });

  test('compterNonLues compte les notifications non lues', () {
    expect(compterNonLues(const []), 0);
    expect(
      compterNonLues([
        NotificationUtilisateur.fromJson({'id': '1', 'lue': false}),
        NotificationUtilisateur.fromJson({'id': '2', 'lue': true}),
        NotificationUtilisateur.fromJson({'id': '3'}),
      ]),
      2,
    );
  });

  test("libelleNotifications ajoute le nombre de non lues seulement s'il est connu et positif",
      () {
    expect(libelleNotifications(null), 'Notifications');
    expect(libelleNotifications(0), 'Notifications');
    expect(libelleNotifications(3), 'Notifications (3)');
  });
}
