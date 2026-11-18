// Espaces selon le role (GET /api/moi -> roles) : medecin, secretaire, pharmacie ; regles de
// l'agenda du cabinet et generation des creneaux en serie.

import '../i18n/langue.dart';

/// Espaces professionnels proposes dans « Mon espace ».
enum Espace { medecin, secretaire, pharmacie }

/// Roles du compte connecte, en majuscules, lus dans la reponse de GET /api/moi
/// (`{"sujet", "nom", "roles": [...]}`) ; ensemble vide si absents.
Set<String> rolesDe(Map<String, dynamic> moi) {
  final Object? roles = moi['roles'];
  if (roles is! List) return {};
  return roles.map((r) => r.toString().toUpperCase()).toSet();
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

/// Message affiche a la place de ces pages pour un compte professionnel.
String messagePageReservee() => t(
    'Cette page est réservée aux patients. Utilisez « Mon espace ».',
    'هذه الصفحة مخصصة للمرضى. استخدم «فضائي».');

/// Liste de recherche vide (sans erreur).
String messageAucunMedecin() =>
    t('Aucun médecin trouvé pour ces critères', 'لم يُعثر على أي طبيب لهذه المعايير');

/// Vrai si l'entree « Mon espace » doit apparaitre sur l'accueil.
bool aUnEspacePro(Set<String> roles) => espacesPour(roles).isNotEmpty;

/// Statut d'un rendez-vous dans l'agenda du cabinet : RESERVE est traite comme CONFIRME.
String statutAgenda(Object? statut) {
  final s = (statut?.toString() ?? '').toUpperCase();
  return s == 'RESERVE' ? 'CONFIRME' : s;
}

/// Honorer, marquer absent ou annuler : seulement pour un rendez-vous confirme (ou reserve).
bool actionsCabinetPossibles(Object? statut) => statutAgenda(statut) == 'CONFIRME';

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

/// Vrai si le rendez-vous commencant a [debut] (ISO 8601) a atteint son heure : « Patient venu »
/// et « Absent » ne sont proposes qu'ensuite (comme sur le site). Debut illisible : vrai.
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
