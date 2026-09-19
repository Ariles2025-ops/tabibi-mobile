import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/models/besoin_medicament.dart';
import 'package:tabibi_mobile/models/reponse_pharmacie.dart';
import 'package:tabibi_mobile/utils/dawini.dart';

import 'outils.dart';

void main() {
  setUp(preparerTests);

  test("BesoinMedicament.fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final b = BesoinMedicament.fromJson({
      'id': 'b1b1b1b1-0000-4000-8000-000000000001',
      'patientId': 'a1a1a1a1-0000-4000-8000-000000000007',
      'medicament': 'Insuline rapide',
      'wilayaCode': '16',
      'commune': 'Alger-Centre',
      'precision': 'Stylo 100 UI/ml, urgent',
      'statut': 'CLOTURE',
      'publieLe': '2026-11-20T09:00:00',
      'clotureLe': '2026-11-21T18:30:00',
      'nombreReponses': 3,
    });
    expect(b.id, 'b1b1b1b1-0000-4000-8000-000000000001');
    expect(b.patientId, 'a1a1a1a1-0000-4000-8000-000000000007');
    expect(b.medicament, 'Insuline rapide');
    expect(b.wilayaCode, '16');
    expect(b.commune, 'Alger-Centre');
    expect(b.precision, 'Stylo 100 UI/ml, urgent');
    expect(b.statut, 'CLOTURE');
    expect(b.publieLe, DateTime(2026, 11, 20, 9));
    expect(b.clotureLe, DateTime(2026, 11, 21, 18, 30));
    expect(b.nombreReponses, 3);
  });

  test('BesoinMedicament.fromJson tolere les valeurs nulles ou absentes (demande ouverte)', () {
    final vide = BesoinMedicament.fromJson({});
    expect(vide.id, '');
    expect(vide.medicament, '');
    expect(vide.wilayaCode, '');
    expect(vide.commune, isNull);
    expect(vide.precision, isNull);
    expect(vide.statut, '');
    expect(vide.publieLe, isNull);
    expect(vide.clotureLe, isNull);
    expect(vide.nombreReponses, 0);

    final ouverte = BesoinMedicament.fromJson({
      'id': 'b-1',
      'medicament': 'Doliprane 1000',
      'wilayaCode': 16,
      'commune': '  ',
      'precision': null,
      'statut': 'OUVERT',
      'publieLe': 'n/a',
      'clotureLe': null,
      'nombreReponses': null,
    });
    expect(ouverte.wilayaCode, '16');
    expect(ouverte.commune, isNull);
    expect(ouverte.precision, isNull);
    expect(ouverte.publieLe, isNull);
    expect(ouverte.nombreReponses, 0);
    expect(estOuvert(ouverte), isTrue);
  });

  test("cloturer produit une copie cloturee sans modifier l'original", () {
    final ouverte = BesoinMedicament.fromJson({
      'id': 'b-1',
      'medicament': 'Doliprane 1000',
      'wilayaCode': '16',
      'statut': 'OUVERT',
      'publieLe': '2026-11-20T09:00:00',
      'nombreReponses': 2,
    });
    final cloturee = ouverte.cloturer(DateTime(2026, 11, 21, 18, 30));
    expect(cloturee.statut, 'CLOTURE');
    expect(cloturee.clotureLe, DateTime(2026, 11, 21, 18, 30));
    expect(cloturee.id, 'b-1');
    expect(cloturee.medicament, 'Doliprane 1000');
    expect(cloturee.publieLe, ouverte.publieLe);
    expect(cloturee.nombreReponses, 2);
    expect(estOuvert(cloturee), isFalse);
    expect(ouverte.statut, 'OUVERT');
    expect(ouverte.clotureLe, isNull);
  });

  test("ReponsePharmacie.fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final r = ReponsePharmacie.fromJson({
      'id': 'r1r1r1r1-0000-4000-8000-000000000001',
      'besoinId': 'b1b1b1b1-0000-4000-8000-000000000001',
      'pharmacieId': 'p1p1p1p1-0000-4000-8000-000000000009',
      'nomPharmacie': 'Pharmacie El Amel',
      'disponible': true,
      'prixDa': 850,
      'commentaire': 'En stock, boite de 8.',
      'repondueLe': '2026-11-20T10:15:00',
    });
    expect(r.id, 'r1r1r1r1-0000-4000-8000-000000000001');
    expect(r.besoinId, 'b1b1b1b1-0000-4000-8000-000000000001');
    expect(r.pharmacieId, 'p1p1p1p1-0000-4000-8000-000000000009');
    expect(r.nomPharmacie, 'Pharmacie El Amel');
    expect(r.disponible, isTrue);
    expect(r.prixDa, 850);
    expect(r.commentaire, 'En stock, boite de 8.');
    expect(r.repondueLe, DateTime(2026, 11, 20, 10, 15));
  });

  test('ReponsePharmacie.fromJson tolere les valeurs nulles ou absentes (indisponible)', () {
    final vide = ReponsePharmacie.fromJson({});
    expect(vide.id, '');
    expect(vide.nomPharmacie, '');
    expect(vide.disponible, isFalse);
    expect(vide.prixDa, isNull);
    expect(vide.commentaire, isNull);
    expect(vide.repondueLe, isNull);

    final indisponible = ReponsePharmacie.fromJson({
      'id': 'r-2',
      'nomPharmacie': 'Pharmacie Ibn Sina',
      'disponible': null,
      'prixDa': null,
      'commentaire': '',
      'repondueLe': 'n/a',
    });
    expect(indisponible.disponible, isFalse);
    expect(indisponible.prixDa, isNull);
    expect(indisponible.commentaire, isNull);
    expect(indisponible.repondueLe, isNull);
    expect(ReponsePharmacie.fromJson({'prixDa': 1250.0}).prixDa, 1250);
  });

  test('formaterPrix affiche les dinars et se tait sans prix', () {
    expect(formaterPrix('fr', 850), '850 DA');
    expect(formaterPrix('fr', 0), '0 DA');
    expect(formaterPrix('fr', null), isNull);
    expect(formaterPrix('fr', -1), isNull);
    expect(formaterPrix('ar', 850), '850 دج');
  });

  test('libelleStatutBesoin accorde le statut a la demande et tolere le reste', () {
    expect(libelleStatutBesoin('fr', 'OUVERT'), 'Ouverte');
    expect(libelleStatutBesoin('fr', 'CLOTURE'), 'Clôturée');
    expect(libelleStatutBesoin('fr', 'cloture'), 'Clôturée');
    expect(libelleStatutBesoin('fr', 'AUTRE_STATUT'), 'Autre statut');
    expect(libelleStatutBesoin('fr', null), '');
  });

  test('libelleReponses et libelleDisponibilite accordent les libelles', () {
    expect(libelleReponses('fr', 0), '0 réponse');
    expect(libelleReponses('fr', 1), '1 réponse');
    expect(libelleReponses('fr', 3), '3 réponses');
    // Arabe : duel pour deux, pluriel restreint de 3 a 10.
    expect(libelleReponses('ar', 1), 'رد واحد');
    expect(libelleReponses('ar', 2), 'ردان');
    expect(libelleReponses('ar', 3), '3 ردود');
    expect(libelleDisponibilite('fr', true), 'Disponible');
    expect(libelleDisponibilite('fr', false), 'Indisponible');
  });

  test('lieuBesoin et dateBesoin decrivent la demande', () {
    expect(
      lieuBesoin('fr', BesoinMedicament.fromJson({'wilayaCode': '16', 'commune': 'Alger-Centre'})),
      'Wilaya 16 · Alger-Centre',
    );
    expect(lieuBesoin('fr', BesoinMedicament.fromJson({'wilayaCode': '31'})), 'Wilaya 31');
    expect(
      dateBesoin('fr', BesoinMedicament.fromJson({'publieLe': '2026-11-20T09:00:00'})),
      'Publiée le ven. 20 nov. 09:00',
    );
    expect(
      dateBesoin('fr', BesoinMedicament.fromJson({
        'publieLe': '2026-11-20T09:00:00',
        'clotureLe': '2026-11-21T18:30:00',
      })),
      'Clôturée le sam. 21 nov. 18:30',
    );
    expect(dateBesoin('fr', BesoinMedicament.fromJson({})), 'Date inconnue');
    expect(
      dateReponse('fr', ReponsePharmacie.fromJson({'repondueLe': '2026-11-20T10:15:00'})),
      'ven. 20 nov. 10:15',
    );
    expect(dateReponse('fr', ReponsePharmacie.fromJson({})), 'date inconnue');
  });

  test('trierParPublication place la plus recente en tete et les dates absentes en fin', () {
    final triees = trierParPublication([
      BesoinMedicament.fromJson({'id': '1', 'publieLe': '2026-01-10T09:00:00'}),
      BesoinMedicament.fromJson({'id': '2'}),
      BesoinMedicament.fromJson({'id': '3', 'publieLe': '2026-03-05T09:00:00'}),
    ]);
    expect(triees.map((b) => b.id).toList(), ['3', '1', '2']);
  });
}
