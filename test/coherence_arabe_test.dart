// Libellés arabes alignés sur le site : « داويني » (Dawini), « صفحتي » (Ma fiche), accroche
// d'accueil ; « Mes ordonnances rédigées » distinct de « Mes ordonnances » (patient).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _lire(String chemin) => File(chemin).readAsStringSync();

void main() {
  final tous = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.readAsStringSync())
      .join('\n');

  test('Dawini s\'écrit « داويني » en arabe, comme sur le site', () {
    expect(tous.contains('دَويني'), isFalse);
    expect(tous.contains("'داويني'"), isTrue);
  });

  test('« Ma fiche » s\'écrit « صفحتي » en arabe, comme sur le site', () {
    expect(tous.contains('بطاقتي'), isFalse);
    expect(tous.contains('بطاقتك'), isFalse);
    expect(_lire('lib/pages/espace/fiche_semaine_pages.dart'), contains("'Ma fiche', 'صفحتي'"));
  });

  test('l\'accroche arabe d\'accueil est celle du site', () {
    expect(_lire('lib/main.dart'), contains('صحتك لا تحتمل الانتظار'));
  });

  test('« Mes ordonnances rédigées » n\'a pas le même titre arabe que « Mes ordonnances »', () {
    expect(_lire('lib/pages/espace/ordonnances_redigees_page.dart'),
        contains("'Mes ordonnances rédigées', 'وصفاتي التي حررتها'"));
    expect(_lire('lib/pages/mes_ordonnances_page.dart'), contains("'Mes ordonnances', 'وصفاتي الطبية'"));
  });

  test('« Présentation » et « RDV pris au téléphone » ont les mêmes mots arabes que le site', () {
    expect(tous.contains("'Présentation', 'التعريف'"), isFalse);
    expect(tous.contains("'Présentation', 'تقديم'"), isTrue);
    expect(tous.contains('موعد بالهاتف'), isFalse);
    expect(_lire('lib/pages/espace/fiche_semaine_pages.dart'), contains("'RDV pris au téléphone', 'موعد عبر الهاتف'"));
    expect(_lire('lib/pages/espace/creneaux_page.dart'), contains("'RDV pris au téléphone', 'موعد عبر الهاتف'"));
  });
}
