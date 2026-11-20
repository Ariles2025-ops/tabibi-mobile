import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';
import 'package:tabibi_mobile/utils/identifiants.dart';
import 'package:tabibi_mobile/utils/praticien.dart';

void main() {
  tearDown(() => Langue.courante.value = Langue.francais);

  test('409 de reservation : texte arabe en arabe, texte du serveur en français', () {
    const serveur = "Ce créneau n'est plus disponible.";
    expect(traduireErreurServeur(409, serveur), serveur);
    Langue.courante.value = Langue.arabe;
    expect(traduireErreurServeur(409, serveur), 'هذا الموعد لم يعد متاحًا.');
    expect(traduireErreurServeur(409, 'Ce rendez-vous est déjà passé.'),
        'هذا الموعد قد مضى بالفعل.');
  });

  test('409 en arabe : rendez-vous déjà à venir, chevauchement et créneau pris, comme le site', () {
    const avenir = 'Vous avez déjà un rendez-vous à venir avec ce médecin : annulez-le pour en choisir un autre.';
    expect(traduireErreurServeur(409, avenir), avenir); // français : texte du serveur
    Langue.courante.value = Langue.arabe;
    expect(traduireErreurServeur(409, avenir),
        'لديك بالفعل موعد قادم مع هذا الطبيب: ألغِه لاختيار موعد آخر.');
    expect(traduireErreurServeur(409, 'Ce rendez-vous chevauche un autre rendez-vous.'),
        'هذا الموعد يتداخل مع موعد آخر لديك.');
    expect(traduireErreurServeur(409, 'Ce créneau est déjà pris.'), 'هذا الموعد حُجز للتوّ.');
    expect(traduireErreurServeur(409, 'Autre chose'), 'تعذّر الإجراء: تغيّر الوضع في الأثناء');
  });

  test('liste vide : message FR/AR', () {
    expect(messageAucunMedecin(), 'Aucun médecin trouvé. Essayez un autre nom ou une autre wilaya.');
    Langue.courante.value = Langue.arabe;
    expect(messageAucunMedecin(), 'لم نعثر على أي طبيب. جرّب اسمًا آخر أو ولاية أخرى.');
  });

  test('fiche sans nomComplet ni debut : pas de plantage', () {
    final Map<String, dynamic> m = {'nomComplet': null};
    expect(identifiant(m['nomComplet']), '');
    expect(identifiant(m['debut']), '');
    expect(DateTime.tryParse(identifiant(m['debut'])), isNull);
  });

  test('compte médecin : Mes rendez-vous renvoie vers Mon espace', () {
    expect(comptePro({'MEDECIN'}), isTrue);
    expect(comptePro({'MEDECIN', 'PATIENT'}), isFalse);
    expect(comptePro({'PATIENT'}), isFalse);
    expect(comptePro({}), isFalse);
    expect(messagePageReservee(), contains('Mon espace'));
  });

  test('badge « Réservable en ligne » : seulement si reservable == true, FR/AR', () {
    expect(estReservable({'reservable': true}), isTrue);
    expect(estReservable({'reservable': false}), isFalse);
    expect(estReservable({'reservable': null}), isFalse);
    expect(estReservable({}), isFalse);
    expect(estReservable({'reservable': 'true'}), isFalse);
    expect(libelleReservable(), 'Réservable en ligne');
    Langue.courante.value = Langue.arabe;
    expect(libelleReservable(), 'الحجز متاح عبر الإنترنت');
  });
}
