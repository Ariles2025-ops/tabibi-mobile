import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/utils/rendez_vous.dart';

void main() {
  final maintenant = DateTime(2026, 6, 15, 12);
  Map<String, dynamic> rdv(String statut, String debut) => {'statut': statut, 'debut': debut};
  const futur = '2026-06-20T09:00:00';
  const passe = '2026-06-10T09:00:00';

  tearDown(() => Langue.courante.value = Langue.francais);

  test('annulable seulement si a venir et ni annule, ni honore, ni absent', () {
    expect(estAnnulable(rdv('CONFIRME', futur), maintenant: maintenant), isTrue);
    expect(estAnnulable(rdv('RESERVE', futur), maintenant: maintenant), isTrue);
    expect(estAnnulable(rdv('CONFIRME', passe), maintenant: maintenant), isFalse);
    expect(estAnnulable(rdv('ABSENT', futur), maintenant: maintenant), isFalse);
    expect(estAnnulable(rdv('HONORE', futur), maintenant: maintenant), isFalse);
    expect(estAnnulable(rdv('ANNULEE', futur), maintenant: maintenant), isFalse);
  });

  test('un rendez-vous confirme passe est « Terminé »', () {
    expect(libelleStatutRendezVous(rdv('CONFIRME', passe), maintenant: maintenant), 'Terminé');
    expect(libelleStatutRendezVous(rdv('RESERVE', passe), maintenant: maintenant), 'Terminé');
    expect(libelleStatutRendezVous(rdv('CONFIRME', futur), maintenant: maintenant), 'Confirmé');
    expect(libelleStatutRendezVous(rdv('ABSENT', passe), maintenant: maintenant), 'Non honoré');
    expect(libelleStatutRendezVous(rdv('HONORE', passe), maintenant: maintenant), 'Terminé');
  });

  test('libelle arabe', () {
    Langue.courante.value = Langue.arabe;
    expect(libelleStatutRendezVous(rdv('CONFIRME', passe), maintenant: maintenant), 'منتهٍ');
    expect(libelleStatutRendezVous(rdv('HONORE', passe), maintenant: maintenant), 'منتهٍ');
    expect(libelleStatutRendezVous(rdv('ABSENT', passe), maintenant: maintenant), 'لم يتم الحضور');
  });

  test('classe les rendez-vous : a venir (proche -> lointain) puis passes (recent -> ancien)', () {
    final liste = [
      rdv('HONORE', '2025-12-04T09:00:00'),
      rdv('CONFIRME', '2026-07-01T09:00:00'),
      rdv('HONORE', passe),
      rdv('CONFIRME', futur),
      rdv('ANNULEE', futur),
    ];
    final c = classerRendezVous(liste, maintenant: maintenant);
    expect(c.aVenir.map((r) => r['debut']), [futur, '2026-07-01T09:00:00']);
    expect(c.passes.map((r) => r['debut']), [futur, passe, '2025-12-04T09:00:00']);
  });

  test('messageRendezVousDeplace donne la date du nouveau créneau, jamais « null »', () {
    final avecDate = messageRendezVousDeplace('2099-12-03T09:00:00');
    expect(avecDate, startsWith('Rendez-vous déplacé au '));
    expect(avecDate, endsWith('.'));
    expect(avecDate, isNot(contains('null')));
    expect(messageRendezVousDeplace(null), 'Rendez-vous déplacé.');
    expect(messageRendezVousDeplace(''), 'Rendez-vous déplacé.');
  });

  test('messageRendezVousDeplaceCabinet ne promet une alerte que pour un rendez-vous de la plateforme', () {
    final prevenu = messageRendezVousDeplaceCabinet('2099-12-03T09:00:00', patientPrevenu: true);
    expect(prevenu, startsWith('Rendez-vous déplacé au '));
    expect(prevenu, endsWith(' : le patient est prévenu.'));
    final tel = messageRendezVousDeplaceCabinet('2099-12-03T09:00:00', patientPrevenu: false);
    expect(tel, endsWith('.'));
    expect(tel, isNot(contains('prévenu')));
    expect(messageRendezVousDeplaceCabinet(null, patientPrevenu: true), isNot(contains('null')));
    expect(messageRendezVousDeplaceCabinet('', patientPrevenu: false), 'Rendez-vous déplacé.');
  });

  test('messageRendezVousAnnuleCabinet : comme le site, sans promesse pour un rendez-vous par téléphone', () {
    final prevenu = messageRendezVousAnnuleCabinet('2099-12-03T09:00:00', patientPrevenu: true);
    expect(prevenu, startsWith('Rendez-vous du '));
    expect(prevenu, endsWith(' annulé : le créneau est de nouveau proposé et le patient est prévenu.'));
    final tel = messageRendezVousAnnuleCabinet('2099-12-03T09:00:00', patientPrevenu: false);
    expect(tel, endsWith(' annulé : le créneau est de nouveau proposé.'));
    expect(messageRendezVousAnnuleCabinet(null, patientPrevenu: true), isNot(contains('null')));
    expect(messageRendezVousAnnuleCabinet('', patientPrevenu: false),
        'Rendez-vous annulé : le créneau est de nouveau proposé.');
    Langue.courante.value = Langue.arabe;
    expect(messageRendezVousAnnuleCabinet('', patientPrevenu: true),
        'تم إلغاء الموعد: الموعد متاح من جديد وتم إعلام المريض.');
  });

  test('déplacement refusé : créneau pris ou chevauchement, le vrai motif est montré', () {
    const chevauche = 'Ce créneau chevauche un autre de vos rendez-vous : annulez-le ou choisissez un autre horaire';
    expect(messageDeplacementRefuse("Ce créneau n'est plus disponible."), contains("vient d'être pris"));
    expect(messageDeplacementRefuse(chevauche), chevauche);
    Langue.courante.value = Langue.arabe;
    expect(messageDeplacementRefuse('هذا الموعد لم يعد متاحًا.'), contains('حُجز للتوّ'));
    expect(messageDeplacementRefuse('هذا الموعد يتداخل مع موعد آخر لديك.'),
        'هذا الموعد يتداخل مع موعد آخر لديك.');
  });
}
