// Espaces selon le role (GET /api/moi -> roles) : medecin, secretaire, pharmacie ; regles de
// l'agenda du cabinet et generation des creneaux en serie.

/// Espaces professionnels proposes dans « Mon espace ».
enum Espace { medecin, secretaire, pharmacie }

/// Roles du compte connecte, en majuscules, lus dans la reponse de GET /api/moi
/// (`{"sujet", "nom", "roles": [...]}`) ; ensemble vide si absents.
Set<String> rolesDe(Map<String, dynamic> moi) {
  final Object? roles = moi['roles'];
  if (roles is! List) return {};
  return roles.map((r) => r.toString().toUpperCase()).toSet();
}

/// Espaces ouverts par les roles, dans l'ordre d'affichage.
List<Espace> espacesPour(Set<String> roles) => [
      if (roles.contains('MEDECIN')) Espace.medecin,
      if (roles.contains('SECRETAIRE')) Espace.secretaire,
      if (roles.contains('PHARMACIE')) Espace.pharmacie,
    ];

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
