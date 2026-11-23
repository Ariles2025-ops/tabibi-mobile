import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/utils/liens_appli.dart';

void main() {
  test('medecinIdDepuisRoute lit la fiche d\'un praticien', () {
    expect(medecinIdDepuisRoute('/medecins/abc-123'), 'abc-123');
    expect(medecinIdDepuisRoute('/medecins/abc-123/'), 'abc-123');
    expect(medecinIdDepuisRoute('/medecins/abc-123?x=1#y'), 'abc-123');
    expect(medecinIdDepuisRoute('/praticiens/abc/dr-karim'), 'abc');
    expect(medecinIdDepuisRoute('/ar/praticiens/abc'), 'abc');
  });

  test('medecinIdDepuisRoute ignore les autres routes', () {
    expect(medecinIdDepuisRoute('/'), isNull);
    expect(medecinIdDepuisRoute(null), isNull);
    expect(medecinIdDepuisRoute('/medecins'), isNull);
    expect(medecinIdDepuisRoute('/medecins/'), isNull);
    expect(medecinIdDepuisRoute('/mes-rendez-vous'), isNull);
    expect(medecinIdDepuisRoute('/medecins/a/b/c'), isNull);
  });
}
