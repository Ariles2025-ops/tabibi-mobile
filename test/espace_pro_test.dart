import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/services/api_service.dart';
import 'package:tabibi_mobile/utils/espace_pro.dart';

void main() {
  group('telephonePatientRdv', () {
    test('préfère le numéro saisi sur le rendez-vous, sinon celui de la fiche patient', () {
      expect(telephonePatientRdv(' 0661000000 ', '0550123456'), '0661000000');
      expect(telephonePatientRdv(null, ' 0550123456 '), '0550123456');
      expect(telephonePatientRdv('  ', null), '');
    });
  });

  tearDown(() => Langue.courante.value = Langue.francais);

  test('libelleRoles : roles metier comme le site, roles techniques masques', () {
    expect(libelleRoles({'MEDECIN'}), 'Rôle : Médecin');
    expect(libelleRoles({'PATIENT', 'MEDECIN', 'DEFAULT-ROLES-TABIBI', 'OFFLINE_ACCESS'}),
        'Rôles : Patient, Médecin');
    expect(libelleRoles({'OFFLINE_ACCESS'}), '');
    expect(libelleRoles({}), '');
    Langue.courante.value = Langue.arabe;
    expect(libelleRoles({'PHARMACIE'}), 'الدور : صيدلية');
    expect(libelleRoles({'ADMIN', 'SECRETAIRE'}), 'الأدوار : سكرتيرة، مسؤول');
  });

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

  test('messageChargement : 403 = « Cette page est réservée... » comme le site, autres erreurs inchangées', () {
    final interdit = ApiException(403, 'Accès refusé');
    expect(messageChargement(interdit, PublicPage.patients), 'Cette page est réservée aux patients.');
    expect(messageChargement(interdit, PublicPage.patientsEtMedecins),
        'Cette page est réservée aux patients et aux médecins.');
    expect(messageChargement(interdit, PublicPage.medecins), 'Cette page est réservée aux médecins.');
    expect(messageChargement(ApiException(500, 'Panne'), PublicPage.patients), 'Panne');
    expect(messageChargement(interdit, PublicPage.secretaires), 'Cette page est réservée aux secrétaires.');
    Langue.courante.value = Langue.arabe;
    expect(messageChargement(interdit, PublicPage.patients), 'هذه الصفحة مخصّصة للمرضى.');
    expect(messageChargement(interdit, PublicPage.medecins), 'هذه الصفحة مخصّصة للأطباء.');
    expect(messageChargement(interdit, PublicPage.secretaires), 'هذه الصفحة مخصّصة للسكرتارية.');
    expect(messageChargement(interdit, PublicPage.patientsEtMedecins), 'هذه الصفحة مخصّصة للمرضى والأطباء.');
  });

  test('pharmacie : 403 « réservée aux pharmacies » et refus de réponse comme le site', () {
    Langue.courante.value = Langue.francais;
    expect(messageChargement(ApiException(403, 'Accès refusé'), PublicPage.pharmacies),
        'Cette page est réservée aux pharmacies.');
    expect(messageReponseBesoin(ApiException(403, 'Accès refusé : ce compte n\'a pas les droits nécessaires')),
        'Seul un compte pharmacie peut répondre à une demande.');
    expect(messageReponseBesoin(ApiException(409, 'Action impossible : la situation a changé entre-temps')),
        "Cette demande n'accepte plus de réponse.");
    expect(messageReponseBesoin(ApiException(400, 'Une erreur est survenue (code 400). Réessayez dans un instant.')),
        'La réponse est incomplète.');
    // Texte précis du serveur conservé.
    expect(messageReponseBesoin(ApiException(409, 'Besoin clôturé')), 'Besoin clôturé');
    Langue.courante.value = Langue.arabe;
    expect(messageChargement(ApiException(403, 'x'), PublicPage.pharmacies), 'هذه الصفحة مخصّصة للصيدليات.');
    expect(messageReponseBesoin(ApiException(409, 'تعذّر الإجراء: تغيّر الوضع في الأثناء')),
        'لم يعد هذا الطلب يقبل ردودًا.');
    expect(messageReponseBesoin(ApiException(403, 'تم رفض الوصول: هذا الحساب لا يملك الصلاحيات اللازمة')),
        'وحده حساب الصيدلية يمكنه الرد على طلب.');
  });

  test('Dawini : refus de publication 403/400 comme le site (FR et AR)', () {
    Langue.courante.value = Langue.francais;
    expect(messagePublicationBesoin(ApiException(403, 'Accès refusé : ce compte n\'a pas les droits nécessaires')),
        'Seul un compte patient peut publier une demande.');
    expect(messagePublicationBesoin(ApiException(400, 'Une erreur est survenue (code 400). Réessayez dans un instant.')),
        'La demande est incomplète.');
    // Texte précis du serveur conservé ; autre statut inchangé.
    expect(messagePublicationBesoin(ApiException(400, 'Médicament obligatoire')), 'Médicament obligatoire');
    expect(messagePublicationBesoin(ApiException(500, 'Panne')), 'Panne');
    Langue.courante.value = Langue.arabe;
    expect(messagePublicationBesoin(ApiException(403, 'تم رفض الوصول: هذا الحساب لا يملك الصلاحيات اللازمة')),
        'يمكن لحساب المريض فقط نشر طلب.');
    expect(messagePublicationBesoin(ApiException(400, 'حدث خطأ (الرمز 400). أعد المحاولة بعد قليل.')),
        'الطلب غير مكتمل.');
  });

  test('invitation de secrétaire et candidature : refus 409/400/403 comme le site (FR et AR)', () {
    Langue.courante.value = Langue.francais;
    expect(messageInvitationSecretaire(ApiException(409, 'Action impossible : la situation a changé entre-temps')),
        'Cette secrétaire est déjà rattachée à votre cabinet.');
    expect(messageInvitationSecretaire(ApiException(400, 'Une erreur est survenue (code 400). Réessayez dans un instant.')),
        "Aucun compte Ndawik n'utilise cette adresse e-mail.");
    expect(messageInvitationSecretaire(ApiException(403, 'Accès refusé : ce compte n\'a pas les droits nécessaires')),
        'Seul un compte médecin peut inviter une secrétaire.');
    expect(messageInvitationSecretaire(ApiException(409, 'Déjà invitée')), 'Déjà invitée');
    expect(messageDepotCandidature(ApiException(409, 'Action impossible : la situation a changé entre-temps')),
        'Une candidature est déjà en attente ou validée.');
    expect(messageDepotCandidature(ApiException(403, 'Accès refusé : ce compte n\'a pas les droits nécessaires')),
        "Accès refusé. Votre demande n'a pas pu être envoyée.");
    expect(messageDepotCandidature(ApiException(400, 'Une erreur est survenue (code 400). Réessayez dans un instant.')),
        'La candidature est incomplète.');
    Langue.courante.value = Langue.arabe;
    expect(messageInvitationSecretaire(ApiException(409, 'تعذّر الإجراء: تغيّر الوضع في الأثناء')),
        'هذه السكرتيرة مرتبطة بعيادتك بالفعل.');
    expect(messageInvitationSecretaire(ApiException(400, 'تعذّر تنفيذ الطلب: تحقق من المعلومات المدخلة ثم أعد المحاولة.')),
        'لا يوجد حساب على نداويك بهذا البريد الإلكتروني.');
    expect(messageInvitationSecretaire(ApiException(403, 'تم رفض الوصول: هذا الحساب لا يملك الصلاحيات اللازمة')),
        'يمكن لحساب طبيب فقط دعوة سكرتيرة.');
    expect(messageDepotCandidature(ApiException(409, 'تعذّر الإجراء: تغيّر الوضع في الأثناء')),
        'يوجد ترشح قيد الانتظار أو معتمد بالفعل.');
    expect(messageDepotCandidature(ApiException(403, 'x')), 'تم رفض الوصول. تعذّر إرسال طلبك.');
    expect(messageDepotCandidature(ApiException(400, 'تعذّر تنفيذ الطلب: تحقق من المعلومات المدخلة ثم أعد المحاولة.')),
        'الترشح غير مكتمل.');
    // Le 400 de la pharmacie, traduit en arabe par l'appli, reste reconnu comme générique.
    expect(messageReponseBesoin(ApiException(400, 'تعذّر تنفيذ الطلب: تحقق من المعلومات المدخلة ثم أعد المحاولة.')),
        'الرد غير مكتمل.');
  });

  test('messagerieReserveeAuxPatients : comme le site, seul un compte patient ecrit au medecin', () {
    expect(messagerieReserveeAuxPatients({'PATIENT'}), isFalse);
    expect(messagerieReserveeAuxPatients(<String>{}), isFalse);
    expect(messagerieReserveeAuxPatients({'MEDECIN'}), isTrue);
    expect(messagerieReserveeAuxPatients({'SECRETAIRE'}), isTrue);
    expect(messagerieReserveeAuxPatients({'PHARMACIE'}), isTrue);
    expect(messagerieReserveeAuxPatients({'PATIENT', 'ADMIN'}), isTrue);
    expect(messageMessagerieReservee(), 'La messagerie est réservée aux patients.');
    Langue.courante.value = Langue.arabe;
    expect(messageMessagerieReservee(), 'المراسلة مخصّصة للمرضى.');
  });
}
