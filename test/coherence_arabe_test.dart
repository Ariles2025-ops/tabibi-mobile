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

  test('« Signalé » s\'écrit pareil (« مُبلَّغ عنه ») dans libelles.dart et avis.dart, comme sur le site', () {
    expect(_lire('lib/utils/libelles.dart'), contains("'مُبلَّغ عنه'"));
    expect(_lire('lib/utils/avis.dart'), contains("'مُبلَّغ عنه'"));
    expect(tous.contains('مُبلّغ'), isFalse);
  });

  test('« à distance » s\'écrit « عن بُعد » partout (accueil, compte, téléconsultations), comme sur le site', () {
    expect(tous.contains('عن بعد'), isFalse);
    expect(_lire('lib/main.dart'), contains("'الاستشارات عن بُعد'"));
    expect(_lire('lib/pages/compte_page.dart'), contains("'الاستشارة عن بُعد'"));
  });

  test('créneau pris, réponse Dawini, prix et avis vides : mêmes phrases que le site (FR et AR)', () {
    // La phrase du déplacement patient vit dans utils/rendez_vous.dart (messageDeplacementRefuse).
    expect(_lire('lib/pages/mes_rendez_vous_page.dart'), contains('messageDeplacementRefuse('));
    for (final fichier in ['lib/utils/rendez_vous.dart', 'lib/pages/espace/agenda_page.dart']) {
      final src = _lire(fichier);
      expect(src, contains('هذا الموعد حُجز للتوّ.'));
      expect(src.contains('تم حجز هذا الموعد للتو'), isFalse);
    }
    final pharmacie = _lire('lib/pages/espace/pharmacie_pages.dart');
    expect(pharmacie, contains('le patient est prévenu.'));
    expect(pharmacie, contains('المريض مُبلَّغ.'));
    expect(pharmacie, contains('(nombre entier positif ou nul).'));
    expect(pharmacie, contains('عدد صحيح موجب أو صفر'));
    expect(pharmacie.contains('سعراً'), isFalse);
    expect(_lire('lib/utils/espace_pro.dart'), contains('هذه الصفحة مخصّصة للمرضى.'));
    final avis = _lire('lib/pages/mes_avis_page.dart');
    expect(avis, contains('Vous pouvez noter un rendez-vous honoré depuis'));
    expect(avis, contains('يمكنك تقييم موعد تم حضوره من'));
  });
}
