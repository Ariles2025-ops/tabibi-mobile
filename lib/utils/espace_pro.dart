// Espaces selon le role (GET /api/moi -> roles) : medecin, secretaire, pharmacie ; regles de
// l'agenda du cabinet et generation des creneaux en serie.

import '../i18n/langue.dart';
import '../services/api_service.dart';

/// Espaces professionnels proposes dans « Mon espace ».
enum Espace { medecin, secretaire, pharmacie }

/// Roles du compte connecte, en majuscules, lus dans la reponse de GET /api/moi
/// (`{"sujet", "nom", "roles": [...]}`) ; ensemble vide si absents.
Set<String> rolesDe(Map<String, dynamic> moi) {
  final Object? roles = moi['roles'];
  if (roles is! List) return {};
  return roles.map((r) => r.toString().toUpperCase()).toSet();
}

/// Roles metier affiches sur « Mon compte », comme le site (moi.component) : « Rôle : Médecin »,
/// « Rôles : Patient, Médecin ». Les roles techniques de Keycloak (default-roles-tabibi,
/// offline_access...) sont masques ; chaine vide si aucun role metier.
String libelleRoles(Set<String> roles) {
  const libelles = <String, (String, String)>{
    'PATIENT': ('Patient', 'مريض'),
    'MEDECIN': ('Médecin', 'طبيب'),
    'SECRETAIRE': ('Secrétaire', 'سكرتيرة'),
    'PHARMACIE': ('Pharmacie', 'صيدلية'),
    'ADMIN': ('Administrateur', 'مسؤول'),
  };
  final connus = [
    for (final role in libelles.keys)
      if (roles.contains(role)) t(libelles[role]!.$1, libelles[role]!.$2),
  ];
  if (connus.isEmpty) return '';
  final titre = connus.length > 1 ? t('Rôles', 'الأدوار') : t('Rôle', 'الدور');
  return '$titre : ${connus.join(t(', ', '، '))}';
}

/// Message de confirmation apres connexion : « Connecté : karim », ou « Connecté » seul si
/// l'identite n'a pas de nom (jamais « Connecté : null »).
String messageConnecte(Map<String, dynamic> moi) {
  final nom = (moi['nom']?.toString() ?? '').trim();
  if (nom.isEmpty) return t('Connecté', 'تم تسجيل الدخول');
  return t('Connecté : $nom', 'تم تسجيل الدخول: $nom');
}

/// Espaces ouverts par les roles, dans l'ordre d'affichage.
List<Espace> espacesPour(Set<String> roles) => [
      if (roles.contains('MEDECIN')) Espace.medecin,
      if (roles.contains('SECRETAIRE')) Espace.secretaire,
      if (roles.contains('PHARMACIE')) Espace.pharmacie,
    ];

/// Vrai pour un compte professionnel sans role PATIENT : « Mes rendez-vous » et
/// « Mes ordonnances » (reserves au patient) lui renverraient « Accès refusé ».
bool comptePro(Set<String> roles) => aUnEspacePro(roles) && !roles.contains('PATIENT');

/// Vrai si « Messagerie » est proposee, comme le site : l'API (GET /api/conversations) la reserve
/// aux roles PATIENT et MEDECIN ; un compte secretaire ou pharmacie sans l'un d'eux n'a pas
/// d'entree menant a un refus 403. Roles inconnus (hors connexion) : l'entree reste affichee.
bool peutUtiliserMessagerie(Set<String> roles) =>
    roles.contains('PATIENT') ||
    roles.contains('MEDECIN') ||
    !(roles.contains('SECRETAIRE') || roles.contains('PHARMACIE'));

/// Vrai si la fiche d'un praticien ne propose pas « Ouvrir une conversation », comme le site
/// (`messagerieReservee`) : un compte medecin, secretaire, pharmacie ou administrateur n'est pas
/// un patient. Roles inconnus (hors connexion) : le bouton reste affiche.
bool messagerieReserveeAuxPatients(Set<String> roles) =>
    roles.any(const {'MEDECIN', 'SECRETAIRE', 'PHARMACIE', 'ADMIN'}.contains);

/// Message affiche a la place du bouton de messagerie sur la fiche d'un praticien (comme le site).
String messageMessagerieReservee() =>
    t('La messagerie est réservée aux patients.', 'المراسلة مخصّصة للمرضى.');

/// Message affiche a la place de ces pages pour un compte professionnel.
String messagePageReservee() => t(
    'Cette page est réservée aux patients. Utilisez « Mon espace ».',
    'هذه الصفحة مخصّصة للمرضى. استخدم «فضائي».');

/// Liste de recherche vide (sans erreur).
String messageAucunMedecin() =>
    t('Aucun médecin trouvé. Essayez un autre nom ou une autre wilaya.',
        'لم نعثر على أي طبيب. جرّب اسمًا آخر أو ولاية أخرى.');

/// Compteur de la recherche : « 50 sur 312 médecins » (le total vient de X-Total-Count).
String messageNombreMedecins(int affiches, int total) => t(
    '$affiches sur $total médecins', '$affiches من أصل $total طبيب');

/// Bouton qui charge la page suivante de résultats.
String messageAfficherPlus() => t('Afficher plus', 'عرض المزيد');

/// Vrai si l'entree « Mon espace » doit apparaitre sur l'accueil.
bool aUnEspacePro(Set<String> roles) => espacesPour(roles).isNotEmpty;

/// Statut d'un rendez-vous dans l'agenda du cabinet : RESERVE est traite comme CONFIRME.
String statutAgenda(Object? statut) {
  final s = (statut?.toString() ?? '').toUpperCase();
  return s == 'RESERVE' ? 'CONFIRME' : s;
}

/// Honorer, marquer absent ou annuler : seulement pour un rendez-vous confirme (ou reserve).
bool actionsCabinetPossibles(Object? statut) => statutAgenda(statut) == 'CONFIRME';

/// « Rédiger une ordonnance » depuis l'agenda du medecin (comme le site) : pas pour un rendez-vous
/// annule ou « absent », ni pour un rendez-vous pris par telephone (le patient n'a pas de compte).
bool peutRedigerOrdonnance(Object? statut, Object? source) {
  final s = (statut?.toString() ?? '').trim().toUpperCase();
  return !s.startsWith('ANNUL') &&
      s != 'ABSENT' &&
      (source?.toString() ?? '').trim().toUpperCase() != 'TELEPHONE';
}

/// « Déplacer » : seulement un rendez-vous confirme (ou reserve) qui n'a pas encore commence,
/// comme sur le site.
bool peutDeplacerCabinet(Object? statut, Object? debut, DateTime maintenant) =>
    actionsCabinetPossibles(statut) && !rdvCommence(debut, maintenant);

/// Creneaux proposes pour deplacer [rdv] : libres, a venir et differents du creneau actuel,
/// du plus proche au plus lointain.
List<Map<String, dynamic>> creneauxPourDeplacer(
    List<Map<String, dynamic>> creneaux, Map<String, dynamic> rdv, DateTime maintenant) {
  final actuel = '${rdv['creneauId'] ?? ''}';
  final libres = creneaux.where((c) {
    final debut = DateTime.tryParse('${c['debut']}');
    return c['disponible'] == true &&
        '${c['id']}' != actuel &&
        debut != null &&
        debut.isAfter(maintenant);
  }).toList();
  return trierParDebut(libres);
}

/// Rendez-vous tries du plus proche au plus lointain (champ `debut`, ISO 8601).
List<Map<String, dynamic>> trierParDebut(List<Map<String, dynamic>> elements) {
  final copie = List<Map<String, dynamic>>.of(elements);
  DateTime? d(Map<String, dynamic> e) => DateTime.tryParse('${e['debut']}');
  copie.sort((a, b) {
    final da = d(a);
    final db = d(b);
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return copie;
}

/// Agenda du cabinet en trois sections, jours pris a l'heure d'Alger : « Aujourd'hui » et
/// « À venir » du plus proche au plus lointain, « Passés » du plus recent au plus ancien.
/// Un rendez-vous sans date lisible ferme les « Passés ».
class AgendaClasse {
  const AgendaClasse(this.aujourdhui, this.aVenir, this.passes);

  final List<Map<String, dynamic>> aujourdhui;
  final List<Map<String, dynamic>> aVenir;
  final List<Map<String, dynamic>> passes;
}

AgendaClasse classerAgenda(List<Map<String, dynamic>> rdvs, DateTime maintenant) {
  final n = muraleAlger(maintenant);
  final jour = DateTime(n.year, n.month, n.day);
  final fin = DateTime.utc(275000);
  final debuts = <Map<String, dynamic>, DateTime?>{};
  for (final r in rdvs) {
    final d = DateTime.tryParse('${r['debut']}');
    // Avec fuseau : heure d'Alger ; sans fuseau : deja l'heure murale algerienne.
    debuts[r] = d == null ? null : (d.isUtc ? muraleAlger(d) : d);
  }
  final auj = <Map<String, dynamic>>[];
  final avenir = <Map<String, dynamic>>[];
  final passes = <Map<String, dynamic>>[];
  for (final r in rdvs) {
    final d = debuts[r];
    if (d == null) {
      passes.add(r);
      continue;
    }
    final j = DateTime(d.year, d.month, d.day);
    (j == jour ? auj : j.isAfter(jour) ? avenir : passes).add(r);
  }
  int croissant(Map<String, dynamic> a, Map<String, dynamic> b) =>
      (debuts[a] ?? fin).compareTo(debuts[b] ?? fin);
  auj.sort(croissant);
  avenir.sort(croissant);
  passes.sort((a, b) {
    final da = debuts[a];
    final db = debuts[b];
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return AgendaClasse(auj, avenir, passes);
}

/// Durees de creneau proposees (minutes).
const List<int> dureesCreneau = [10, 15, 20, 30, 45, 60];

/// Debuts des creneaux d'une serie sur une semaine : les 7 jours a partir de [premierJour],
/// pour chaque jour de la semaine retenu dans [jours] (1 = lundi ... 7 = dimanche), des
/// creneaux successifs de [dureeMinutes] entre [debutMinutes] et [finMinutes] (minutes depuis
/// minuit, le dernier creneau devant finir au plus tard a [finMinutes]). Les debuts deja passes
/// par rapport a [maintenant] sont ignores.
List<DateTime> creneauxSerie({
  required DateTime premierJour,
  required Set<int> jours,
  required int debutMinutes,
  required int finMinutes,
  required int dureeMinutes,
  required DateTime maintenant,
}) {
  if (dureeMinutes <= 0 || finMinutes <= debutMinutes) return [];
  final resultat = <DateTime>[];
  for (var i = 0; i < 7; i++) {
    final jour = DateTime(premierJour.year, premierJour.month, premierJour.day + i);
    if (!jours.contains(jour.weekday)) continue;
    for (var m = debutMinutes; m + dureeMinutes <= finMinutes; m += dureeMinutes) {
      final debut = DateTime(jour.year, jour.month, jour.day, m ~/ 60, m % 60);
      if (debut.isAfter(maintenant)) resultat.add(debut);
    }
  }
  return resultat;
}

/// Algerie : UTC+1 toute l'annee (pas d'heure d'ete), quel que soit le fuseau du telephone.
const Duration decalageAlger = Duration(hours: 1);

/// Heure murale d'Alger a l'instant [instant], sous forme de DateTime sans fuseau reel
/// (seuls les champs annee..minute comptent).
DateTime muraleAlger(DateTime instant) {
  final a = instant.toUtc().add(decalageAlger);
  return DateTime(a.year, a.month, a.day, a.hour, a.minute, a.second);
}

/// Instant (UTC) correspondant a l'heure murale [murale] a Alger : 9 h a Alger = 8 h UTC.
DateTime instantAlger(DateTime murale) => DateTime.utc(
      murale.year,
      murale.month,
      murale.day,
      murale.hour,
      murale.minute,
      murale.second,
    ).subtract(decalageAlger);

/// Vrai si le rendez-vous commencant a [debut] (ISO 8601) a atteint son heure : « Marquer honoré »
/// et « Patient absent » ne sont proposes qu'ensuite (comme sur le site). Debut illisible : vrai.
bool rdvCommence(Object? debut, DateTime maintenant) {
  final d = DateTime.tryParse('$debut');
  if (d == null) return true;
  return !d.isAfter(maintenant);
}

/// Forme minimale d'une adresse e-mail, comme sur le site (le serveur verifie qu'un compte l'utilise).
bool emailValide(String texte) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(texte.trim());

/// Nom affiche d'une secretaire rattachee, comme sur le site : son nom, a defaut son e-mail,
/// a defaut « Secrétaire » suivi de l'identifiant abrege.
String nomSecretaire(Map<String, dynamic> rattachement) {
  for (final cle in ['secretaireNom', 'secretaireEmail']) {
    final Object? v = rattachement[cle];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  final id = rattachement['secretaireId']?.toString() ?? '';
  final court = id.length <= 8 ? id : id.substring(0, 8);
  return '${t('Secrétaire', 'سكرتيرة')} $court'.trim();
}

/// Vrai tant que la secretaire n'a pas accepte l'invitation (`accepte` explicitement faux ;
/// absent = ancien rattachement, actif).
bool invitationEnAttente(Map<String, dynamic> rattachement) => rattachement['accepte'] == false;

/// Rattachements du plus ancien au plus recent (`creeLe`) ; dates illisibles en fin de liste.
List<Map<String, dynamic>> trierRattachements(List<Map<String, dynamic>> liste) {
  DateTime? date(Map<String, dynamic> r) {
    final Object? iso = r['creeLe'];
    return iso is String ? DateTime.tryParse(iso) : null;
  }

  final copie = List<Map<String, dynamic>>.of(liste);
  copie.sort((a, b) {
    final da = date(a);
    final db = date(b);
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return copie;
}

/// Public d'une page reservee a un role, pour le message « Cette page est reservee aux ... ».
enum PublicPage { patients, patientsEtMedecins, pharmacies, medecins }

/// Message d'une page de chargement en echec : un refus 403 (role insuffisant) dit a qui
/// la page est reservee, comme le site (« Cette page est réservée aux patients. ») au lieu du
/// libelle generique « Accès refusé » ; les autres erreurs gardent leur message.
String messageChargement(ApiException e, PublicPage public) {
  if (!e.interdit) return e.message;
  return switch (public) {
    PublicPage.patients => t('Cette page est réservée aux patients.', 'هذه الصفحة مخصّصة للمرضى.'),
    PublicPage.patientsEtMedecins => t('Cette page est réservée aux patients et aux médecins.',
        'هذه الصفحة مخصّصة للمرضى والأطباء.'),
    PublicPage.medecins =>
      t('Cette page est réservée aux médecins.', 'هذه الصفحة مخصّصة للأطباء.'),
    PublicPage.pharmacies =>
      t('Cette page est réservée aux pharmacies.', 'هذه الصفحة مخصّصة للصيدليات.'),
  };
}

/// Message d'un refus a la reponse d'une pharmacie a une demande de medicament, comme le site :
/// 403 « Seul un compte pharmacie peut répondre à une demande. », 409 « Cette demande n'accepte
/// plus de réponse. », 400 « La réponse est incomplète. ». Un texte precis envoye par le
/// serveur est conserve ; seuls les libelles generiques de l'appli sont remplaces.
String messageReponseBesoin(ApiException e) {
  if (!estMessageGenerique(e.message)) return e.message;
  return switch (e.statusCode) {
    403 => t('Seul un compte pharmacie peut répondre à une demande.',
        'وحده حساب الصيدلية يمكنه الرد على طلب.'),
    409 => t("Cette demande n'accepte plus de réponse.", 'لم يعد هذا الطلب يقبل ردودًا.'),
    400 => t('La réponse est incomplète.', 'الرد غير مكتمل.'),
    _ => e.message,
  };
}

/// Message d'un refus a la publication d'une demande de medicament (Dawini), comme le site :
/// 403 « Seul un compte patient peut publier une demande. », 400 « La demande est incomplète. ».
/// Un texte precis envoye par le serveur est conserve ; seuls les libelles generiques de l'appli
/// sont remplaces.
String messagePublicationBesoin(ApiException e) {
  if (!estMessageGenerique(e.message)) return e.message;
  return switch (e.statusCode) {
    403 => t('Seul un compte patient peut publier une demande.',
        'يمكن لحساب المريض فقط نشر طلب.'),
    400 => t('La demande est incomplète.', 'الطلب غير مكتمل.'),
    _ => e.message,
  };
}

/// Vrai pour un libelle par defaut de l'appli (ou sa traduction arabe d'un refus du serveur) :
/// un tel texte ne dit rien de precis, l'ecran le remplace par la phrase du site.
bool estMessageGenerique(String message) => const [
      'Une erreur est survenue',
      'حدث خطأ',
      'Action impossible',
      'تعذّر الإجراء',
      'تعذّر تنفيذ الطلب',
      'Accès refusé',
      'تم رفض الوصول',
      'Ressource introuvable',
      'العنصر غير موجود',
      'العنصر المطلوب غير موجود',
    ].any(message.startsWith);

/// Refus de l'invitation d'une secretaire, comme le site : 409 « Cette secrétaire est déjà
/// rattachée à votre cabinet. », 400 « Aucun compte Ndawik n'utilise cette adresse e-mail. »,
/// 403 « Seul un compte médecin peut inviter une secrétaire. » (le site garde toujours la phrase
/// du 403). Un texte precis du serveur est conserve pour 409 et 400.
String messageInvitationSecretaire(ApiException e) {
  if (e.statusCode == 403) {
    return t('Seul un compte médecin peut inviter une secrétaire.',
        'يمكن لحساب طبيب فقط دعوة سكرتيرة.');
  }
  if (!estMessageGenerique(e.message)) return e.message;
  return switch (e.statusCode) {
    409 => t('Cette secrétaire est déjà rattachée à votre cabinet.',
        'هذه السكرتيرة مرتبطة بعيادتك بالفعل.'),
    400 => t("Aucun compte Ndawik n'utilise cette adresse e-mail.",
        'لا يوجد حساب على نداويك بهذا البريد الإلكتروني.'),
    _ => e.message,
  };
}

/// Refus du depot d'une candidature de medecin, comme le site : 403 « Accès refusé. Votre
/// demande n'a pas pu être envoyée. », 409 « Une candidature est déjà en attente ou validée. »,
/// 400 « La candidature est incomplète. ». Un texte precis du serveur (409, 400) est conserve.
String messageDepotCandidature(ApiException e) {
  if (e.statusCode == 403) {
    return t("Accès refusé. Votre demande n'a pas pu être envoyée.",
        'تم رفض الوصول. تعذّر إرسال طلبك.');
  }
  if (!estMessageGenerique(e.message)) return e.message;
  return switch (e.statusCode) {
    409 => t('Une candidature est déjà en attente ou validée.',
        'يوجد ترشح قيد الانتظار أو معتمد بالفعل.'),
    400 => t('La candidature est incomplète.', 'الترشح غير مكتمل.'),
    _ => e.message,
  };
}

/// Longueurs maximales des champs de la candidature, les memes que le formulaire du site
/// (praticien.component.ts) : au-dela, l'API refuse avec « textes pas trop longs ».
const int maxNomCandidature = 160;
const int maxVilleCandidature = 80;
const int maxOrdreCandidature = 40;

/// Numero du patient d'un rendez-vous de l'agenda, comme le site : celui saisi sur le rendez-vous
/// (prise par telephone) sinon celui de sa fiche patient ; chaine vide si aucun n'est connu.
String telephonePatientRdv(Object? saisi, Object? repertoire) {
  for (final v in [saisi, repertoire]) {
    final n = v is String ? v.trim() : '';
    if (n.isNotEmpty) return n;
  }
  return '';
}
