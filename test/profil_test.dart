import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/models/profil.dart';
import 'package:tabibi_mobile/utils/profil.dart';

void main() {
  test("Profil.fromJson lit tous les champs de la vue renvoyee par l'API", () {
    final p = Profil.fromJson({
      'utilisateurId': 'a1a1a1a1-0000-4000-8000-000000000007',
      'nomComplet': 'Karim Haddad',
      'telephone': '0550123456',
      'dateNaissance': '1990-05-14',
      'wilayaCode': '16',
      'langue': 'kab',
      'misAJourLe': '2026-11-20T09:00:00',
    });
    expect(p.utilisateurId, 'a1a1a1a1-0000-4000-8000-000000000007');
    expect(p.nomComplet, 'Karim Haddad');
    expect(p.telephone, '0550123456');
    expect(p.dateNaissance, DateTime(1990, 5, 14));
    expect(p.wilayaCode, '16');
    expect(p.langue, 'kab');
    expect(p.misAJourLe, DateTime(2026, 11, 20, 9));
  });

  test("Profil.toJson produit le corps de PUT /api/moi/profil (date au format yyyy-MM-dd)", () {
    final corps = Profil(
      nomComplet: 'Karim Haddad',
      telephone: '0550123456',
      dateNaissance: DateTime(1990, 5, 14),
      wilayaCode: '16',
      langue: 'kab',
    ).toJson();
    expect(corps, {
      'nomComplet': 'Karim Haddad',
      'telephone': '0550123456',
      'dateNaissance': '1990-05-14',
      'wilayaCode': '16',
      'langue': 'kab',
    });
    // Ni identifiant ni date de mise a jour : le serveur les fixe.
    expect(corps.containsKey('utilisateurId'), isFalse);
    expect(corps.containsKey('misAJourLe'), isFalse);
    // Mois et jour sur deux chiffres.
    expect(
      Profil(nomComplet: 'A', dateNaissance: DateTime(1985, 12, 3)).toJson()['dateNaissance'],
      '1985-12-03',
    );
  });

  test('Profil.fromJson tolere les valeurs nulles ou absentes et toJson garde une date nulle',
      () {
    final vide = Profil.fromJson({});
    expect(vide.utilisateurId, '');
    expect(vide.nomComplet, '');
    expect(vide.telephone, isNull);
    expect(vide.dateNaissance, isNull);
    expect(vide.wilayaCode, isNull);
    expect(vide.langue, 'fr');
    expect(vide.misAJourLe, isNull);
    expect(vide.toJson(), {
      'nomComplet': '',
      'telephone': null,
      'dateNaissance': null,
      'wilayaCode': null,
      'langue': 'fr',
    });

    final partiel = Profil.fromJson({
      'nomComplet': '  Amina Ait Ahmed  ',
      'telephone': '   ',
      'dateNaissance': 'n/a',
      'wilayaCode': 16,
      'langue': null,
      'misAJourLe': null,
    });
    expect(partiel.nomComplet, 'Amina Ait Ahmed');
    expect(partiel.telephone, isNull);
    expect(partiel.dateNaissance, isNull);
    expect(partiel.wilayaCode, '16');
    expect(partiel.langue, 'fr');
    expect(partiel.toJson()['dateNaissance'], isNull);
  });

  test('Profil.fromJson ramene une date de naissance horodatee au jour seul', () {
    final p = Profil.fromJson({'nomComplet': 'Karim', 'dateNaissance': '1990-05-14T10:30:00'});
    expect(p.dateNaissance, DateTime(1990, 5, 14));
    expect(p.toJson()['dateNaissance'], '1990-05-14');
  });

  test("les langues du modele sont celles de l'API, dans l'ordre du menu", () {
    expect(Profil.langues, ['fr', 'ar', 'kab', 'en']);
    expect(Profil.langueParDefaut, 'fr');
    expect(libellesLangues.keys.toList(), Profil.langues);
    expect(libelleLangue('fr'), 'Français');
    expect(libelleLangue('ar'), 'العربية');
    expect(libelleLangue('kab'), 'Taqbaylit');
    expect(libelleLangue('en'), 'English');
    expect(libelleLangue('xx'), 'xx');
  });

  test('telephoneValide accepte un numero algerien de 9 a 10 chiffres commencant par 0', () {
    expect(telephoneValide('0550123456'), isTrue); // mobile, 10 chiffres
    expect(telephoneValide('021123456'), isTrue); // fixe, 9 chiffres
    expect(telephoneValide('05 50 12 34 56'), isTrue); // espaces toleres
    expect(telephoneValide(''), isTrue); // facultatif
    expect(telephoneValide('   '), isTrue);
    expect(telephoneValide(null), isTrue);
    expect(telephoneValide('550123456'), isFalse); // ne commence pas par 0
    expect(telephoneValide('05501234'), isFalse); // 8 chiffres
    expect(telephoneValide('05501234567'), isFalse); // 11 chiffres
    expect(telephoneValide('0550abc456'), isFalse); // lettres
    expect(telephoneValide('+213550123456'), isFalse); // indicatif international refuse
  });

  test('normaliserTelephone retire les espaces et se tait sans numero', () {
    expect(normaliserTelephone('05 50 12 34 56'), '0550123456');
    expect(normaliserTelephone('0550123456'), '0550123456');
    expect(normaliserTelephone('   '), isNull);
    expect(normaliserTelephone(''), isNull);
    expect(normaliserTelephone(null), isNull);
  });

  test('libelleDateNaissance et libelleMiseAJour decrivent le profil', () {
    expect(libelleDateNaissance(DateTime(1990, 5, 14)), '14 mai 1990');
    expect(libelleDateNaissance(null), 'Non renseignée');
    expect(
      libelleMiseAJour(Profil.fromJson({'misAJourLe': '2026-11-20T09:00:00'})),
      'Mis à jour le ven. 20 nov. 09:00',
    );
    expect(libelleMiseAJour(const Profil(nomComplet: 'Karim')), 'Profil non enregistré');
  });
}
