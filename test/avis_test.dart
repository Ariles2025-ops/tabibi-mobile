import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/models/avis.dart';
import 'package:tabibi_mobile/models/synthese_avis.dart';
import 'package:tabibi_mobile/utils/avis.dart';

import 'outils.dart';

void main() {
  setUp(preparerTests);

  test("Avis.fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final a = Avis.fromJson({
      'id': 'a1a1a1a1-0000-4000-8000-000000000001',
      'rendezVousId': 'r1r1r1r1-0000-4000-8000-000000000002',
      'medecinId': '00000000-0000-0000-0000-000000000001',
      'note': 4,
      'commentaire': 'Tres bon accueil.',
      'statut': 'PUBLIE',
      'deposeLe': '2026-11-20T10:15:00',
    });
    expect(a.id, 'a1a1a1a1-0000-4000-8000-000000000001');
    expect(a.rendezVousId, 'r1r1r1r1-0000-4000-8000-000000000002');
    expect(a.medecinId, '00000000-0000-0000-0000-000000000001');
    expect(a.note, 4);
    expect(a.commentaire, 'Tres bon accueil.');
    expect(a.aCommentaire, isTrue);
    expect(a.statut, 'PUBLIE');
    expect(a.deposeLe, DateTime(2026, 11, 20, 10, 15));
  });

  test('Avis.fromJson tolere les valeurs nulles ou absentes (avis public sans commentaire)', () {
    final vide = Avis.fromJson({});
    expect(vide.id, '');
    expect(vide.rendezVousId, '');
    expect(vide.note, 0);
    expect(vide.commentaire, isNull);
    expect(vide.aCommentaire, isFalse);
    expect(vide.statut, '');
    expect(vide.deposeLe, isNull);

    final public = Avis.fromJson({
      'id': 'avis-1',
      'rendezVousId': 3,
      'note': 5,
      'commentaire': '   ',
      'deposeLe': 'n/a',
    });
    expect(public.rendezVousId, '3');
    expect(public.note, 5);
    expect(public.commentaire, isNull);
    expect(public.deposeLe, isNull);
  });

  test('SyntheseAvis.fromJson lit la moyenne, le nombre et les derniers avis', () {
    final s = SyntheseAvis.fromJson({
      'moyenne': 4.5,
      'nombre': 12,
      'avis': [
        {'id': 'avis-1', 'note': 5, 'commentaire': 'Parfait', 'deposeLe': '2026-11-20T10:15:00'},
        'pas un avis',
        {'id': 'avis-2', 'note': 4, 'commentaire': null, 'deposeLe': null},
      ],
    });
    expect(s.moyenne, 4.5);
    expect(s.nombre, 12);
    expect(s.aDesAvis, isTrue);
    expect(s.avis.length, 2);
    expect(s.avis.first.note, 5);
    expect(s.avis.first.commentaire, 'Parfait');
    expect(s.avis.last.commentaire, isNull);
  });

  test('SyntheseAvis.fromJson tolere une moyenne nulle, un entier et des champs absents', () {
    final sansAvis = SyntheseAvis.fromJson({'moyenne': null, 'nombre': 0, 'avis': []});
    expect(sansAvis.moyenne, isNull);
    expect(sansAvis.nombre, 0);
    expect(sansAvis.avis, isEmpty);
    expect(sansAvis.aDesAvis, isFalse);

    final entiere = SyntheseAvis.fromJson({'moyenne': 4, 'nombre': 1});
    expect(entiere.moyenne, 4.0);
    expect(entiere.aDesAvis, isTrue);
    expect(entiere.avis, isEmpty);

    final vide = SyntheseAvis.fromJson({});
    expect(vide.moyenne, isNull);
    expect(vide.nombre, 0);
    expect(vide.aDesAvis, isFalse);
  });

  test('formaterMoyenne utilise la virgule francaise et signale l absence d avis', () {
    expect(formaterMoyenne('fr', const SyntheseAvis(moyenne: 4.5, nombre: 12)),
        '4,5 / 5 (12 avis)');
    expect(formaterMoyenne('fr', const SyntheseAvis(moyenne: 4.0, nombre: 1)), '4,0 / 5 (1 avis)');
    expect(formaterMoyenne('fr', const SyntheseAvis(moyenne: 3.666, nombre: 3)),
        '3,7 / 5 (3 avis)');
    expect(formaterMoyenne('fr', const SyntheseAvis()), 'Aucun avis');
    expect(formaterMoyenne('fr', const SyntheseAvis(moyenne: null, nombre: 2)), 'Aucun avis');
    expect(formaterMoyenne('fr', const SyntheseAvis(moyenne: 4.5, nombre: 0)), 'Aucun avis');
    expect(formaterDecimal('fr', 4.26), '4,3');
    expect(formaterDecimal('fr', 5.0), '5,0');
    // En anglais, le separateur decimal est le point.
    expect(formaterDecimal('en', 4.26), '4.3');
  });

  test('formaterNote, libelleStatutAvis et dateAvis mettent en forme un avis', () {
    expect(formaterNote('fr', 4), '4 / 5');
    expect(libelleStatutAvis('fr', 'PUBLIE'), 'Publié');
    expect(libelleStatutAvis('fr', 'SIGNALE'), 'Signalé');
    expect(libelleStatutAvis('fr', 'MASQUE'), 'Masqué');
    expect(libelleStatutAvis('fr', 'masque'), 'Masqué');
    expect(libelleStatutAvis('fr', 'AUTRE_STATUT'), 'Autre statut');
    expect(libelleStatutAvis('fr', null), '');
    // Le meme statut, lu cette fois dans le dictionnaire arabe.
    expect(libelleStatutAvis('ar', 'PUBLIE'), 'منشور');
    expect(
      dateAvis('fr', Avis.fromJson({'deposeLe': '2026-11-20T10:15:00'})),
      'ven. 20 nov. 10:15',
    );
    expect(dateAvis('fr', Avis.fromJson({})), 'date inconnue');
  });

  test('noteValide et estHonore encadrent le depot d un avis', () {
    expect(noteValide(null), isFalse);
    expect(noteValide(0), isFalse);
    expect(noteValide(1), isTrue);
    expect(noteValide(5), isTrue);
    expect(noteValide(6), isFalse);
    expect(estHonore('HONORE'), isTrue);
    expect(estHonore('honore'), isTrue);
    expect(estHonore('CONFIRME'), isFalse);
    expect(estHonore(null), isFalse);
  });
}
