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
    expect(libelleStatutRendezVous(rdv('ABSENT', passe), maintenant: maintenant), 'Absent');
    expect(libelleStatutRendezVous(rdv('HONORE', passe), maintenant: maintenant), 'Honoré');
  });

  test('libelle arabe', () {
    Langue.courante.value = Langue.arabe;
    expect(libelleStatutRendezVous(rdv('CONFIRME', passe), maintenant: maintenant), 'منتهٍ');
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
}
