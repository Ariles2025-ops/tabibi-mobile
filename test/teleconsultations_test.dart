import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/models/teleconsultation.dart';
import 'package:tabibi_mobile/utils/teleconsultations.dart';

void main() {
  test("fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final t = Teleconsultation.fromJson({
      'id': 'c3c3c3c3-0000-4000-8000-000000000001',
      'rendezVousId': 'r1r1r1r1-0000-4000-8000-000000000002',
      'patientId': 'a1a1a1a1-0000-4000-8000-000000000007',
      'medecinId': '00000000-0000-0000-0000-000000000001',
      'statut': 'EN_COURS',
      'consentementPatientLe': '2026-12-03T08:30:00',
      'lienSalle': 'https://meet.jit.si/tabibi-salle-test',
      'creeLe': '2026-12-03T08:00:00',
      'demarreeLe': '2026-12-03T09:00:00',
      'termineeLe': null,
    });
    expect(t.id, 'c3c3c3c3-0000-4000-8000-000000000001');
    expect(t.rendezVousId, 'r1r1r1r1-0000-4000-8000-000000000002');
    expect(t.patientId, 'a1a1a1a1-0000-4000-8000-000000000007');
    expect(t.medecinId, '00000000-0000-0000-0000-000000000001');
    expect(t.statut, 'EN_COURS');
    expect(t.consentementPatientLe, DateTime(2026, 12, 3, 8, 30));
    expect(t.aConsenti, isTrue);
    expect(t.lienSalle, 'https://meet.jit.si/tabibi-salle-test');
    expect(t.creeLe, DateTime(2026, 12, 3, 8));
    expect(t.demarreeLe, DateTime(2026, 12, 3, 9));
    expect(t.termineeLe, isNull);
  });

  test('fromJson tolere les valeurs nulles ou absentes (pas de consentement, pas de lien)', () {
    final vide = Teleconsultation.fromJson({});
    expect(vide.id, '');
    expect(vide.statut, '');
    expect(vide.consentementPatientLe, isNull);
    expect(vide.aConsenti, isFalse);
    expect(vide.lienSalle, isNull);
    expect(vide.creeLe, isNull);
    expect(vide.demarreeLe, isNull);
    expect(vide.termineeLe, isNull);

    final planifiee = Teleconsultation.fromJson({
      'id': 'tc-1',
      'statut': 'PLANIFIEE',
      'consentementPatientLe': null,
      'lienSalle': '',
      'creeLe': 'n/a',
    });
    expect(planifiee.aConsenti, isFalse);
    expect(planifiee.lienSalle, isNull);
    expect(planifiee.creeLe, isNull);
  });

  test('libelleStatutTeleconsultation traduit les quatre statuts et tolere le reste', () {
    expect(libelleStatutTeleconsultation('PLANIFIEE'), 'Planifiee');
    expect(libelleStatutTeleconsultation('EN_COURS'), 'En cours');
    expect(libelleStatutTeleconsultation('TERMINEE'), 'Terminee');
    expect(libelleStatutTeleconsultation('ANNULEE'), 'Annulee');
    expect(libelleStatutTeleconsultation('en_cours'), 'En cours');
    expect(libelleStatutTeleconsultation('AUTRE_STATUT'), 'Autre statut');
    expect(libelleStatutTeleconsultation(null), '');
  });

  test('peutRejoindre exige un lien de salle et une session planifiee ou en cours', () {
    Teleconsultation t(String statut, {String? lien}) => Teleconsultation.fromJson({
          'id': 'tc',
          'statut': statut,
          'lienSalle': lien,
        });
    const lien = 'https://meet.jit.si/tabibi-salle-test';
    expect(peutRejoindre(t('PLANIFIEE', lien: lien)), isTrue);
    expect(peutRejoindre(t('EN_COURS', lien: lien)), isTrue);
    expect(peutRejoindre(t('TERMINEE', lien: lien)), isFalse);
    expect(peutRejoindre(t('ANNULEE', lien: lien)), isFalse);
    expect(peutRejoindre(t('PLANIFIEE')), isFalse);
    expect(peutRejoindre(t('EN_COURS', lien: '')), isFalse);

    expect(estActive(t('PLANIFIEE')), isTrue);
    expect(estActive(t('EN_COURS')), isTrue);
    expect(estActive(t('TERMINEE')), isFalse);
    expect(estActive(t('ANNULEE')), isFalse);
  });

  test("dateTeleconsultation suit l'avancement de la session", () {
    expect(
      dateTeleconsultation(Teleconsultation.fromJson({'creeLe': '2026-12-03T08:00:00'})),
      'Proposee le jeu. 3 dec. 08:00',
    );
    expect(
      dateTeleconsultation(Teleconsultation.fromJson({
        'creeLe': '2026-12-03T08:00:00',
        'demarreeLe': '2026-12-03T09:00:00',
      })),
      'Demarree le jeu. 3 dec. 09:00',
    );
    expect(
      dateTeleconsultation(Teleconsultation.fromJson({
        'creeLe': '2026-11-20T09:00:00',
        'demarreeLe': '2026-11-20T09:05:00',
        'termineeLe': '2026-11-20T09:40:00',
      })),
      'Terminee le ven. 20 nov. 09:40',
    );
    expect(dateTeleconsultation(Teleconsultation.fromJson({})), 'Date inconnue');
  });
}
