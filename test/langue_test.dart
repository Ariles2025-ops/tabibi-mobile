import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabibi_mobile/config/referentiel.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/utils/dates.dart';

void main() {
  tearDown(() => Langue.courante.value = Langue.francais);

  test('parDefaut : arabe si le telephone est en arabe, sinon francais', () {
    expect(Langue.parDefaut('ar'), 'ar');
    expect(Langue.parDefaut('fr'), 'fr');
    expect(Langue.parDefaut('en'), 'fr');
    expect(Langue.parDefaut(null), 'fr');
  });

  test('t choisit le texte de la langue courante', () {
    expect(t('Bonjour', 'مرحبا'), 'Bonjour');
    Langue.courante.value = Langue.arabe;
    expect(t('Bonjour', 'مرحبا'), 'مرحبا');
    expect(Langue.estArabe, isTrue);
  });

  test('initialiser lit la langue memorisee, sinon celle du telephone', () async {
    SharedPreferences.setMockInitialValues({});
    await Langue.initialiser(langueTelephone: 'ar');
    expect(Langue.courante.value, 'ar');

    SharedPreferences.setMockInitialValues({Langue.cle: 'fr'});
    await Langue.initialiser(langueTelephone: 'ar');
    expect(Langue.courante.value, 'fr');
  });

  test('choisir change la langue et la memorise ; un code inconnu est ignore', () async {
    SharedPreferences.setMockInitialValues({});
    await Langue.choisir('ar');
    expect(Langue.courante.value, 'ar');
    expect((await SharedPreferences.getInstance()).getString(Langue.cle), 'ar');
    await Langue.choisir('xx');
    expect(Langue.courante.value, 'ar');
  });

  test('le referentiel porte les 69 wilayas et les specialites en arabe', () {
    expect(wilayas, hasLength(69));
    expect(wilayas.every((w) => w.nomAr.isNotEmpty), isTrue);
    expect(specialites.every((s) => s.nomAr.isNotEmpty), isTrue);
  });

  test('wilayaParCode, libelleWilaya et nomSpecialite suivent la langue', () {
    expect(wilayaParCode('016')?.nom, 'Alger');
    expect(wilayaParCode('99'), isNull);
    expect(libelleWilaya('16'), '16 - Alger');
    expect(libelleWilaya('99'), '99');
    Langue.courante.value = Langue.arabe;
    expect(libelleWilaya('16'), '16 - الجزائر');
    expect(nomSpecialite(specialiteParSlug('cardiologue')!), 'طبيب القلب');
  });

  test('les dates sont ecrites en arabe en langue arabe', () {
    final d = DateTime(2026, 12, 3, 9, 5);
    expect(formaterDateHeure(d), 'jeu. 3 déc. 09:05');
    Langue.courante.value = Langue.arabe;
    expect(formaterDateHeure(d), contains('ديسمبر'));
    expect(formaterDateHeure(d), contains('09:05'));
  });
}
