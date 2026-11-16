import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/utils/fiche_semaine.dart';

import 'api_espace_test.dart' show requetes;

void main() {
  test('corps de la semaine type : jours dans l\'ordre, heures et date', () {
    final c = corpsSemaineType(
      jours: {'MERCREDI', 'LUNDI'},
      debut: '09:00',
      fin: '12:30',
      dureeMinutes: 20,
      aPartirDu: DateTime(2026, 11, 23),
      nombreSemaines: 4,
    );
    expect(c, {
      'jours': ['LUNDI', 'MERCREDI'],
      'debut': '09:00',
      'fin': '12:30',
      'dureeMinutes': 20,
      'aPartirDu': '2026-11-23',
      'nombreSemaines': 4,
    });
    expect(resultatSemaineType({'crees': 5, 'ignores': 1}), (5, 1));
    expect(resultatSemaineType({}), (0, 0));
  });

  test('validation de la semaine type', () {
    String? e(Set<String> j, int d, int f, int du, int n) => erreurSemaineType(
        jours: j, debutMinutes: d, finMinutes: f, dureeMinutes: du, nombreSemaines: n);
    expect(e({}, 540, 720, 20, 4), 'jours');
    expect(e({'LUNDI'}, 540, 550, 20, 4), 'heures');
    expect(e({'LUNDI'}, 540, 720, 20, 9), 'semaines');
    expect(e({'LUNDI'}, 540, 720, 20, 8), isNull);
  });

  test('telephone algerien', () {
    expect(telephoneAlgerienValide(''), isTrue);
    expect(telephoneAlgerienValide('023 45 67 89'), isTrue);
    expect(telephoneAlgerienValide('0555 12 34 56'), isTrue);
    expect(telephoneAlgerienValide('+213 555 12 34 56'), isTrue);
    expect(telephoneAlgerienValide('12345'), isFalse);
  });

  test('fiche et RDV telephone : corps', () {
    expect(
        corpsFiche(
            adresse: ' Rue 1 ',
            telephoneCabinet: '023456789',
            horaires: 'Dim–Jeu 9h–16h',
            presentation: '',
            langues: {'ar', 'fr'}),
        {
          'adresse': 'Rue 1',
          'telephoneCabinet': '023456789',
          'horaires': 'Dim–Jeu 9h–16h',
          'presentation': '',
          'langues': ['fr', 'ar'],
        });
    expect(languesDe(['FR', 'klingon', 'ar']), {'fr', 'ar'});
    expect(
        corpsRdvTelephone(creneauId: 'c', nomPatient: ' K ', telephonePatient: '0555123456'),
        {'creneauId': 'c', 'nomPatient': 'K', 'telephonePatient': '0555123456'});
  });

  test('routes semaine type, fiche et RDV telephone', () async {
    final a = (await requetes((api) => api.semaineTypeMedecin({'jours': []}, 'j'))).single;
    expect('${a.method} ${a.url.path}', 'POST /api/medecin/creneaux/semaine-type');
    final b = (await requetes((api) => api.semaineTypeSecretaire('m1', {}, 'j'))).single;
    expect(b.url.path, '/api/secretaire/medecins/m1/creneaux/semaine-type');
    final c = (await requetes((api) => api.ficheMedecin('j'))).single;
    expect('${c.method} ${c.url.path}', 'GET /api/medecin/fiche');
    final d = (await requetes((api) => api.modifierFicheMedecin({'adresse': 'x'}, 'j'))).single;
    expect('${d.method} ${d.url.path}', 'PUT /api/medecin/fiche');
    final e = (await requetes((api) => api.rdvTelephoneSecretaire('m1', {}, 'j'))).single;
    expect('${e.method} ${e.url.path}', 'POST /api/secretaire/medecins/m1/rendezvous');
    expect(requetes((api) => api.ficheMedecin('j'), statut: 404),
        throwsA(isA<ApiException>().having((x) => x.introuvable, 'introuvable', isTrue)));
  });
}
