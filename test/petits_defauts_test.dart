import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';
import 'package:tabibi_mobile/utils/identifiants.dart';

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

  test('liste vide : message FR/AR', () {
    expect(messageAucunMedecin(), 'Aucun médecin trouvé pour ces critères');
    Langue.courante.value = Langue.arabe;
    expect(messageAucunMedecin(), isNot(contains('Aucun')));
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
}
