import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/utils/identifiants.dart';

void main() {
  const uuid = '00000000-0000-0000-0000-000000000001';
  const autre = 'b2b2b2b2-0000-4000-8000-000000000003';

  test('identifiant conserve un UUID en texte et tolere un nombre ou une valeur absente', () {
    expect(identifiant(uuid), uuid);
    expect(identifiant(autre), autre);
    expect(identifiant(7), '7');
    expect(identifiant(null), '');
  });

  test('abreger garde les 8 premiers caracteres (premier groupe de l UUID)', () {
    expect(abreger(uuid), '00000000');
    expect(abreger(autre), 'b2b2b2b2');
    expect(abreger('abc'), 'abc');
    expect(abreger('12345678'), '12345678');
    expect(abreger(''), '');
    expect(longueurAbregee, 8);
  });

  test('libelleMedecin nomme le praticien par son identifiant abrege, ou inconnu', () {
    expect(libelleMedecin('fr', uuid), 'Médecin 00000000');
    expect(libelleMedecin('fr', '7'), 'Médecin 7');
    expect(libelleMedecin('fr', ''), 'Médecin inconnu');
  });
}
