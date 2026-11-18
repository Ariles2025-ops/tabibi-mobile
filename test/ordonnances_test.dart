import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/utils/libelles.dart';
import 'package:tabibi_mobile/utils/ordonnances.dart';

void main() {
  test('libelleStatut met en forme un statut brut et tolere une valeur absente', () {
    expect(libelleStatut('EMISE'), 'Émise');
    expect(libelleStatut('EN_ATTENTE'), 'En attente');
    expect(libelleStatut(null), '');
    expect(libelleStatut(''), '');
  });

  test('libelleStatut : ordonnance délivrée en arabe, comme sur le site (مُسلَّمة)', () {
    Langue.courante.value = Langue.arabe;
    addTearDown(() => Langue.courante.value = Langue.francais);
    expect(libelleStatut('DELIVREE'), 'مُسلَّمة');
    expect(libelleStatut('EMISE'), 'صادرة');
    expect(libelleStatut('ANNULEE'), 'ملغاة');
    expect(libelleStatut('EXPIREE'), 'منتهية الصلاحية');
  });

  test('dateEmission formate emiseLe et signale une date absente', () {
    expect(dateEmission({'emiseLe': '2026-12-03T10:15:00'}), 'jeu. 3 déc. 10:15');
    expect(dateEmission({}), 'date inconnue');
    expect(dateEmission({'emiseLe': null}), 'date inconnue');
  });

  test('lignesOrdonnance renvoie les lignes et ignore un champ absent ou mal forme', () {
    final lignes = lignesOrdonnance({
      'lignes': [
        {'medicament': 'Paracetamol 1 g', 'posologie': '1 le matin', 'duree': '5 jours'},
        'pas une ligne',
      ],
    });
    expect(lignes.length, 1);
    expect(lignes.single['medicament'], 'Paracetamol 1 g');
    expect(lignesOrdonnance({}), isEmpty);
    expect(lignesOrdonnance({'lignes': 'n/a'}), isEmpty);
  });

  test('trierParEmission place la plus recente en tete et les dates illisibles en fin', () {
    final triees = trierParEmission([
      {'id': '1', 'emiseLe': '2026-01-10T09:00:00'},
      {'id': '2'},
      {'id': '3', 'emiseLe': '2026-03-05T09:00:00'},
    ]);
    expect(triees.map((o) => o['id']).toList(), ['3', '1', '2']);

    final illisible = trierParEmission([
      {'id': '4', 'emiseLe': 'n/a'},
      {'id': '5', 'emiseLe': '2026-03-05T09:00:00'},
    ]);
    expect(illisible.map((o) => o['id']).toList(), ['5', '4']);
  });

  test("avertissementVerification refuse une ordonnance deja delivree ou annulee (comme le site)", () {
    expect(avertissementVerification({'valide': true, 'statut': 'EMISE'}), isNull);
    expect(avertissementVerification({'valide': true}), isNull);
    expect(avertissementVerification({'statut': 'ANNULEE'}),
        'Annulée : cette ordonnance a été annulée par le médecin et ne doit pas être délivrée.');
    expect(
        avertissementVerification({'statut': 'DELIVREE', 'delivreeLe': '2026-12-03T10:15:00'}),
        'Déjà délivrée le jeu. 3 déc. 10:15 : cette ordonnance ne peut pas être délivrée une nouvelle fois.');
    expect(avertissementVerification({'statut': 'DELIVREE'}),
        'Déjà délivrée : cette ordonnance ne peut pas être délivrée une nouvelle fois.');
  });

  test('avertissementVerification refuse aussi une ordonnance expiree (comme le site)', () {
    expect(avertissementVerification({'valide': true, 'statut': 'EXPIREE'}),
        'Expirée : cette ordonnance n\'est plus valable et ne doit pas être délivrée.');
    expect(avertissementVerification({'statut': ' expiree '}), isNotNull);
  });

  test('infoStatutOrdonnance precise l\'annulation et la delivrance (comme le site)', () {
    expect(infoStatutOrdonnance({'statut': 'EMISE'}), isNull);
    expect(infoStatutOrdonnance({}), isNull);
    expect(infoStatutOrdonnance({'statut': 'ANNULEE', 'motifAnnulation': ' Erreur de dose '}),
        'Annulée par le médecin : Erreur de dose');
    expect(infoStatutOrdonnance({'statut': 'ANNULEE', 'motifAnnulation': null}),
        'Annulée par le médecin');
    expect(infoStatutOrdonnance({'statut': 'DELIVREE', 'delivreeLe': '2026-12-03T10:15:00'}),
        'Délivrée en pharmacie le jeu. 3 déc. 10:15');
    expect(infoStatutOrdonnance({'statut': 'DELIVREE'}), 'Délivrée en pharmacie');
  });

  test('corpsOrdonnance : patient et medicament obligatoires, rendez-vous facultatif', () {
    const ligne = {'medicament': ' Doliprane ', 'posologie': '', 'duree': ' 7 jours'};
    expect(corpsOrdonnance('p1', '', [ligne]), {
      'patientId': 'p1',
      'lignes': [
        {'medicament': 'Doliprane', 'posologie': '', 'duree': '7 jours'}
      ],
    });
    expect(corpsOrdonnance('p1', 'r1', [ligne])!['rendezVousId'], 'r1');
    expect(corpsOrdonnance('', '', [ligne]), isNull);
    expect(corpsOrdonnance('p1', '', []), isNull);
    expect(corpsOrdonnance('p1', '', [{'medicament': '  '}]), isNull);
  });

  test('rendezVousLiables : confirmes ou honores du patient, recents d\'abord', () {
    final liste = rendezVousLiables([
      {'id': 'a', 'patientId': 'p1', 'statut': 'CONFIRME', 'debut': '2026-11-01T08:00:00Z'},
      {'id': 'b', 'patientId': 'p1', 'statut': 'honore', 'debut': '2026-11-09T08:00:00Z'},
      {'id': 'c', 'patientId': 'p1', 'statut': 'ANNULE', 'debut': '2026-11-10T08:00:00Z'},
      {'id': 'd', 'patientId': 'p2', 'statut': 'CONFIRME', 'debut': '2026-11-11T08:00:00Z'},
    ], 'p1');
    expect(liste.map((r) => r['id']), ['b', 'a']);
  });
}
