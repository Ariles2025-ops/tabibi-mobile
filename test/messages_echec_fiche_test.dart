import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/pages/fiche_medecin_page.dart';
import 'package:tabibi_mobile/services/api_service.dart';

void main() {
  tearDown(() => Langue.courante.value = Langue.francais);

  test('un echec de reservation dit la meme chose que le site', () {
    expect(messageEchecReservation(const ApiException(403, 'Accès refusé')),
        'Seul un compte patient peut réserver un créneau.');
    expect(messageEchecReservation(const ApiException(404, 'Ressource introuvable')),
        "Ce créneau n'est plus disponible.");
    expect(messageEchecReservation(const ApiException(400, 'Créneau passé')), 'Créneau passé');
  });

  test("un echec d'inscription a la liste d'attente dit la meme chose que le site", () {
    expect(messageEchecInscription(const ApiException(403, 'Accès refusé')),
        "Seul un compte patient peut s'inscrire sur une liste d'attente.");
    expect(messageEchecInscription(const ApiException(404, 'Ressource introuvable')),
        'Praticien introuvable.');
    expect(messageEchecInscription(const ApiException(500, 'Panne')), 'Panne');
  });

  test('ces messages existent en arabe', () {
    Langue.courante.value = Langue.arabe;
    expect(messageEchecReservation(const ApiException(403, 'x')),
        'يمكن لحساب المريض فقط حجز موعد.');
    expect(messageEchecInscription(const ApiException(404, 'x')), 'الممارس غير موجود.');
  });
}
