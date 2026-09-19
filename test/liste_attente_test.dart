import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/models/inscription_attente.dart';
import 'package:tabibi_mobile/utils/liste_attente.dart';

void main() {
  test("InscriptionAttente.fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final i = InscriptionAttente.fromJson({
      'id': 'aa77aa77-0000-4000-8000-000000000001',
      'patientId': 'a1a1a1a1-0000-4000-8000-000000000007',
      'medecinId': '00000000-0000-0000-0000-000000000001',
      'inscritLe': '2026-11-20T09:00:00',
    });
    expect(i.id, 'aa77aa77-0000-4000-8000-000000000001');
    expect(i.patientId, 'a1a1a1a1-0000-4000-8000-000000000007');
    expect(i.medecinId, '00000000-0000-0000-0000-000000000001');
    expect(i.inscritLe, DateTime(2026, 11, 20, 9));
  });

  test('InscriptionAttente.fromJson tolere les valeurs nulles ou absentes', () {
    final vide = InscriptionAttente.fromJson({});
    expect(vide.id, '');
    expect(vide.patientId, '');
    expect(vide.medecinId, '');
    expect(vide.inscritLe, isNull);

    final partielle = InscriptionAttente.fromJson({
      'id': 7,
      'medecinId': null,
      'inscritLe': 'n/a',
    });
    expect(partielle.id, '7');
    expect(partielle.medecinId, '');
    expect(partielle.inscritLe, isNull);
  });

  test("dateInscription affiche la date d'inscription ou son absence", () {
    expect(
      dateInscription(InscriptionAttente.fromJson({'inscritLe': '2026-11-20T09:00:00'})),
      'Inscription le ven. 20 nov. 09:00',
    );
    expect(dateInscription(InscriptionAttente.fromJson({})), "Date d'inscription inconnue");
  });

  test('trierParInscription place la plus ancienne en tete et les dates absentes en fin', () {
    final triees = trierParInscription([
      InscriptionAttente.fromJson({'id': '1', 'inscritLe': '2026-03-05T09:00:00'}),
      InscriptionAttente.fromJson({'id': '2'}),
      InscriptionAttente.fromJson({'id': '3', 'inscritLe': '2026-01-10T09:00:00'}),
    ]);
    expect(triees.map((i) => i.id).toList(), ['3', '1', '2']);
  });
}
