import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';

void main() {
  test('rolesDe lit les roles de GET /api/moi en majuscules', () {
    expect(
        rolesDe({
          'roles': ['medecin', 'PATIENT']
        }),
        {'MEDECIN', 'PATIENT'});
    expect(rolesDe({}), isEmpty);
  });

  test('messageConnecte n\'affiche jamais « null »', () {
    expect(messageConnecte({'nom': 'karim'}), 'Connecté : karim');
    expect(messageConnecte({'nom': null}), 'Connecté');
    expect(messageConnecte({}), 'Connecté');
    expect(messageConnecte({'nom': '  '}), 'Connecté');
  });

  test('espacesPour et aUnEspacePro suivent les roles', () {
    expect(espacesPour({'PATIENT'}), isEmpty);
    expect(aUnEspacePro({'PATIENT'}), isFalse);
    expect(espacesPour({'PHARMACIE', 'MEDECIN', 'SECRETAIRE'}),
        [Espace.medecin, Espace.secretaire, Espace.pharmacie]);
    expect(aUnEspacePro({'SECRETAIRE'}), isTrue);
  });

  test('statutAgenda traite RESERVE comme CONFIRME ; actions seulement si confirme', () {
    expect(statutAgenda('RESERVE'), 'CONFIRME');
    expect(statutAgenda('honore'), 'HONORE');
    expect(actionsCabinetPossibles('RESERVE'), isTrue);
    expect(actionsCabinetPossibles('CONFIRME'), isTrue);
    expect(actionsCabinetPossibles('ANNULE'), isFalse);
    expect(actionsCabinetPossibles('HONORE'), isFalse);
  });

  test('deplacer : seulement un rendez-vous confirme qui n\'a pas commence', () {
    final maintenant = DateTime.utc(2026, 12, 3, 9);
    expect(peutDeplacerCabinet('CONFIRME', '2026-12-03T10:00:00Z', maintenant), isTrue);
    expect(peutDeplacerCabinet('RESERVE', '2026-12-03T10:00:00Z', maintenant), isTrue);
    expect(peutDeplacerCabinet('CONFIRME', '2026-12-03T08:00:00Z', maintenant), isFalse);
    expect(peutDeplacerCabinet('ANNULE', '2026-12-03T10:00:00Z', maintenant), isFalse);
    expect(peutDeplacerCabinet('HONORE', '2026-12-03T10:00:00Z', maintenant), isFalse);
    expect(peutDeplacerCabinet('CONFIRME', null, maintenant), isFalse);
  });

  test('peutRedigerOrdonnance : ni annule, ni absent, ni pris par telephone (comme le site)', () {
    expect(peutRedigerOrdonnance('CONFIRME', 'EN_LIGNE'), isTrue);
    expect(peutRedigerOrdonnance('RESERVE', null), isTrue);
    expect(peutRedigerOrdonnance('HONORE', null), isTrue);
    expect(peutRedigerOrdonnance('ANNULE', null), isFalse);
    expect(peutRedigerOrdonnance('ANNULEE', null), isFalse);
    expect(peutRedigerOrdonnance('ABSENT', null), isFalse);
    expect(peutRedigerOrdonnance('CONFIRME', 'TELEPHONE'), isFalse);
  });

  test('creneauxPourDeplacer : libres, a venir, autres que le creneau actuel, tries', () {
    final maintenant = DateTime.utc(2026, 12, 3, 9);
    final propositions = creneauxPourDeplacer([
      {'id': 'actuel', 'debut': '2026-12-03T10:00:00Z', 'disponible': true},
      {'id': 'pris', 'debut': '2026-12-03T11:00:00Z', 'disponible': false},
      {'id': 'passe', 'debut': '2026-12-03T08:00:00Z', 'disponible': true},
      {'id': 'tard', 'debut': '2026-12-05T10:00:00Z', 'disponible': true},
      {'id': 'tot', 'debut': '2026-12-04T10:00:00Z', 'disponible': true},
      {'id': 'sans-date', 'disponible': true},
    ], {'creneauId': 'actuel'}, maintenant);
    expect(propositions.map((c) => c['id']), ['tot', 'tard']);
  });

  test('trierParDebut range du plus proche au plus lointain, dates absentes a la fin', () {
    final tries = trierParDebut([
      {'id': 'b', 'debut': '2026-12-04T09:00:00Z'},
      {'id': 'x'},
      {'id': 'a', 'debut': '2026-12-03T09:00:00Z'},
    ]);
    expect(tries.map((e) => e['id']), ['a', 'b', 'x']);
  });

  test('creneauxSerie : jours retenus, plage horaire, duree, sans les debuts passes', () {
    // Lundi 7 decembre 2026 ; serie de 7 jours, lundi et mercredi, 9 h a 10 h, 30 min.
    final serie = creneauxSerie(
      premierJour: DateTime(2026, 12, 7),
      jours: {DateTime.monday, DateTime.wednesday},
      debutMinutes: 9 * 60,
      finMinutes: 10 * 60,
      dureeMinutes: 30,
      maintenant: DateTime(2026, 12, 7, 9, 10),
    );
    expect(serie, [
      DateTime(2026, 12, 7, 9, 30),
      DateTime(2026, 12, 9, 9, 0),
      DateTime(2026, 12, 9, 9, 30),
    ]);
    expect(
      creneauxSerie(
        premierJour: DateTime(2026, 12, 7),
        jours: {1},
        debutMinutes: 600,
        finMinutes: 600,
        dureeMinutes: 30,
        maintenant: DateTime(2026),
      ),
      isEmpty,
    );
  });

  test('heure d\'Alger : UTC+1 quel que soit le fuseau du telephone', () {
    expect(instantAlger(DateTime(2026, 12, 7, 9)), DateTime.utc(2026, 12, 7, 8));
    expect(instantAlger(DateTime(2026, 12, 7, 0, 30)), DateTime.utc(2026, 12, 6, 23, 30));
    expect(muraleAlger(DateTime.utc(2026, 12, 7, 23, 30)), DateTime(2026, 12, 8, 0, 30));
  });

  test('rdvCommence : actions « venu / absent » seulement apres l\'heure du rendez-vous', () {
    final maintenant = DateTime.utc(2026, 12, 3, 8);
    expect(rdvCommence('2026-12-03T08:30:00Z', maintenant), isFalse);
    expect(rdvCommence('2026-12-03T08:00:00Z', maintenant), isTrue);
    expect(rdvCommence('2026-12-03T07:00:00Z', maintenant), isTrue);
    expect(rdvCommence('illisible', maintenant), isTrue);
  });

  test('secretaires : e-mail valide, nom affiche, invitation en attente, tri', () {
    expect(emailValide(' s@exemple.dz '), isTrue);
    expect(emailValide('sans-arobase'), isFalse);
    expect(emailValide('a@b'), isFalse);
    expect(nomSecretaire({'secretaireNom': ' Samia ', 'secretaireEmail': 'x@y.dz'}), 'Samia');
    expect(nomSecretaire({'secretaireNom': null, 'secretaireEmail': 'x@y.dz'}), 'x@y.dz');
    expect(nomSecretaire({'secretaireId': 'bbbbbbbb-0000-4000'}), 'Secrétaire bbbbbbbb');
    expect(invitationEnAttente({'accepte': false}), isTrue);
    expect(invitationEnAttente({'accepte': true}), isFalse);
    expect(invitationEnAttente({}), isFalse);
    final tri = trierRattachements([
      {'id': 'c'},
      {'id': 'b', 'creeLe': '2026-11-02T00:00:00Z'},
      {'id': 'a', 'creeLe': '2026-11-01T00:00:00Z'},
    ]);
    expect(tri.map((r) => r['id']), ['a', 'b', 'c']);
  });
}
