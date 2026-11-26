import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/utils/avis.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';
import 'package:tabibi_mobile/utils/identifiants.dart';
import 'package:tabibi_mobile/utils/praticien.dart';
import 'package:tabibi_mobile/utils/profil.dart';

void main() {
  tearDown(() => Langue.courante.value = Langue.francais);

  test('messagerie : réservée aux patients et médecins, comme le site', () {
    expect(peutUtiliserMessagerie({'PATIENT'}), isTrue);
    expect(peutUtiliserMessagerie({'MEDECIN'}), isTrue);
    expect(peutUtiliserMessagerie({'SECRETAIRE', 'PATIENT'}), isTrue);
    expect(peutUtiliserMessagerie({'SECRETAIRE'}), isFalse);
    expect(peutUtiliserMessagerie({'PHARMACIE'}), isFalse);
    expect(peutUtiliserMessagerie({}), isTrue); // hors connexion
  });

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

  test('400, 403 et 404 en arabe : jamais de français, comme le site (messageRefusArabe)', () {
    const refus = "Seul le patient du rendez-vous peut donner son avis.";
    expect(traduireErreurServeur(403, refus), refus); // français : texte du serveur
    expect(traduireErreurServeur(404, 'Rendez-vous introuvable.'), 'Rendez-vous introuvable.');
    Langue.courante.value = Langue.arabe;
    expect(traduireErreurServeur(404, 'Rendez-vous introuvable.'), 'العنصر المطلوب غير موجود.');
    expect(traduireErreurServeur(403, refus), 'تم رفض الوصول: هذا الحساب لا يملك الصلاحيات اللازمة');
    expect(traduireErreurServeur(400, 'La note doit être comprise entre 1 et 5.'),
        'تعذّر تنفيذ الطلب: تحقق من المعلومات المدخلة ثم أعد المحاولة.');
    expect(traduireErreurServeur(400, 'Ce créneau chevauche un créneau existant.'),
        'هذا الموعد يتداخل مع موعد آخر لديك.');
    expect(traduireErreurServeur(404, 'الموعد غير موجود.'), 'الموعد غير موجود.'); // déjà arabe
  });

  test('liste vide : message FR/AR', () {
    expect(messageAucunMedecin(), 'Aucun médecin trouvé. Essayez un autre nom ou une autre wilaya.');
    Langue.courante.value = Langue.arabe;
    expect(messageAucunMedecin(), 'لم نعثر على أي طبيب. جرّب اسمًا آخر أو ولاية أخرى.');
  });

  test('échec de la page suivante de résultats : même phrase que le site (FR et AR)', () {
    expect(messageEchecSuiteMedecins(), 'Impossible de charger la suite. Réessayez.');
    Langue.courante.value = Langue.arabe;
    expect(messageEchecSuiteMedecins(), 'تعذّر تحميل المزيد. أعد المحاولة.');
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

  test('Fiche médecin : « Prochaine disponibilité » = premier créneau, comme le site', () {
    expect(texteProchaineDisponibilite([]), isNull);
    expect(texteProchaineDisponibilite([{'debut': 'illisible'}]), isNull);
    final creneaux = [
      {'debut': '2026-12-04T09:00:00'},
      {'debut': '2026-12-05T10:00:00'},
    ];
    expect(texteProchaineDisponibilite(creneaux),
        'Prochaine disponibilité : ven. 4 déc. 09:00');
    Langue.courante.value = Langue.arabe;
    expect(texteProchaineDisponibilite(creneaux), startsWith('أقرب موعد متاح:'));
  });

  test('Dépôt d\'un avis : refus 403 et 404 comme le site, FR et AR', () {
    expect(messageRefusDepotAvis(403), 'Seul le patient du rendez-vous peut donner son avis.');
    expect(messageRefusDepotAvis(404), 'Rendez-vous introuvable.');
    expect(messageRefusDepotAvis(500), isNull);
    Langue.courante.value = Langue.arabe;
    expect(messageRefusDepotAvis(403), 'يمكن لمريض هذا الموعد فقط إبداء رأيه.');
    expect(messageRefusDepotAvis(404), 'الموعد غير موجود.');
  });

  test('Téléphone invalide : même phrase que le site', () {
    expect(messageTelephoneInvalide,
        'Le téléphone doit être un numéro algérien de 9 à 10 chiffres commençant par 0 (ex. 0550123456).');
  });
}
