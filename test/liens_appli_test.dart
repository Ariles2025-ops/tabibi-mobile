import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/utils/liens_appli.dart';
import 'package:tabibi_mobile/utils/notifications.dart';

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

  test('un lien mal encode n\'ouvre rien et ne plante pas', () {
    expect(medecinIdDepuisRoute('/medecins/%E0%A4%A'), isNull);
    expect(medecinIdDepuisRoute('/medecins/a%20b'), 'a b');
    expect(decoderSegment('%'), isNull);
    expect(cibleDuLien('/ordonnances/%E0%A4%A'), isNull);
    expect(cibleDuLien('/messagerie/%'), isNull);
    expect(cibleDuLien('/ordonnances/o%2D1'), const CibleNotification(TypeCible.ordonnance, 'o-1'));
  });

  test('le manifeste Android ouvre l\'appli pour les liens que le code sait lire', () {
    final manifeste = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final chemin in ['/medecins/', '/praticiens/', '/ar/praticiens/']) {
      expect(manifeste, contains('android:host="ndawik.com" android:pathPrefix="$chemin"'));
    }
  });
}
