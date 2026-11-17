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
}
