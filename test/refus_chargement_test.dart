import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/utils/libelles.dart';

void main() {
  tearDown(() => Langue.courante.value = Langue.francais);

  String message(int statut, [String api = 'Message de l\'API']) =>
      messageChargementRefuse(statut, api,
          refus: t('Cette conversation ne vous concerne pas.', 'هذه المحادثة لا تخصّك.'),
          introuvable: t('Conversation introuvable.', 'المحادثة غير موجودة.'));

  test('403 et 404 disent la meme chose que le site, en francais', () {
    expect(message(403), 'Cette conversation ne vous concerne pas.');
    expect(message(404), 'Conversation introuvable.');
  });

  test('403 et 404 en arabe : aucun francais', () {
    Langue.courante.value = Langue.arabe;
    expect(message(403), 'هذه المحادثة لا تخصّك.');
    expect(message(404), 'المحادثة غير موجودة.');
  });

  test("un autre statut garde le message de l'API", () {
    expect(message(409), "Message de l'API");
    expect(message(500, 'Panne'), 'Panne');
  });
}
