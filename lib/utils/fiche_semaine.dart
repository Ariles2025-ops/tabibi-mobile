// Semaine type, fiche du medecin et rendez-vous pris au telephone : corps JSON des routes
// (contrats des tickets tabibi-backend) et validations, sans dependance a Flutter.

/// Jours de la semaine type : (valeur API, libelle FR, libelle AR), du lundi au dimanche.
const List<(String, String, String)> joursSemaineType = [
  ('LUNDI', 'Lun', 'الإثنين'),
  ('MARDI', 'Mar', 'الثلاثاء'),
  ('MERCREDI', 'Mer', 'الأربعاء'),
  ('JEUDI', 'Jeu', 'الخميس'),
  ('VENDREDI', 'Ven', 'الجمعة'),
  ('SAMEDI', 'Sam', 'السبت'),
  ('DIMANCHE', 'Dim', 'الأحد'),
];

/// Semaine algerienne par defaut : dimanche a jeudi.
const Set<String> joursParDefaut = {'DIMANCHE', 'LUNDI', 'MARDI', 'MERCREDI', 'JEUDI'};

const int maxSemainesSemaineType = 8;

/// « 09:00 » a partir d'heures et minutes.
String heureApi(int heure, int minute) =>
    '${heure.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// « 2026-11-23 » (jour local, fuseau Africa/Algiers cote serveur).
String dateApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Corps de POST .../creneaux/semaine-type ; les jours sont envoyes dans l'ordre de la semaine.
Map<String, dynamic> corpsSemaineType({
  required Set<String> jours,
  required String debut,
  required String fin,
  required int dureeMinutes,
  required DateTime aPartirDu,
  required int nombreSemaines,
}) =>
    {
      'jours': [
        for (final j in joursSemaineType)
          if (jours.contains(j.$1)) j.$1,
      ],
      'debut': debut,
      'fin': fin,
      'dureeMinutes': dureeMinutes,
      'aPartirDu': dateApi(aPartirDu),
      'nombreSemaines': nombreSemaines,
    };

/// Resultat `{"crees": n, "ignores": m}` ; 0 pour un champ absent.
(int, int) resultatSemaineType(Map<String, dynamic> corps) {
  int n(Object? v) => v is num ? v.toInt() : 0;
  return (n(corps['crees']), n(corps['ignores']));
}

/// Erreur de saisie de la semaine type : cle stable (`jours`, `heures`, `semaines`) ou null.
String? erreurSemaineType({
  required Set<String> jours,
  required int debutMinutes,
  required int finMinutes,
  required int dureeMinutes,
  required int nombreSemaines,
}) {
  if (jours.isEmpty) return 'jours';
  if (finMinutes - debutMinutes < dureeMinutes) return 'heures';
  if (nombreSemaines < 1 || nombreSemaines > maxSemainesSemaineType) return 'semaines';
  return null;
}

// --- Fiche du medecin ---

const int maxAdresse = 200;
const int maxHoraires = 300;
const int maxPresentation = 600;

/// Langues de la fiche : (valeur API, libelle FR, libelle AR).
const List<(String, String, String)> languesFiche = [
  ('fr', 'Français', 'الفرنسية'),
  ('ar', 'Arabe', 'العربية'),
  ('en', 'Anglais', 'الإنجليزية'),
  ('tamazight', 'Tamazight', 'الأمازيغية'),
];

/// Telephone algerien : 0XX XX XX XX (9 ou 10 chiffres apres le 0) ou +213..., espaces,
/// points et tirets tolérés. Vide accepte (champ facultatif).
bool telephoneAlgerienValide(String texte) {
  final t = texte.trim();
  if (t.isEmpty) return true;
  final chiffres = t.replaceAll(RegExp(r'[\s.\-()]'), '');
  return RegExp(r'^(\+213|00213|0)[1-9]\d{7,8}$').hasMatch(chiffres);
}

/// Corps de PUT /api/medecin/fiche.
Map<String, dynamic> corpsFiche({
  required String adresse,
  required String telephoneCabinet,
  required String horaires,
  required String presentation,
  required Set<String> langues,
}) =>
    {
      'adresse': adresse.trim(),
      'telephoneCabinet': telephoneCabinet.trim(),
      'horaires': horaires.trim(),
      'presentation': presentation.trim(),
      'langues': [
        for (final l in languesFiche)
          if (langues.contains(l.$1)) l.$1,
      ],
    };

/// Langues connues lues dans la fiche (liste de chaines), sans doublon.
Set<String> languesDe(Object? brut) {
  if (brut is! List) return {};
  final connues = languesFiche.map((l) => l.$1).toSet();
  return brut.map((e) => '$e'.toLowerCase()).where(connues.contains).toSet();
}

// --- RDV pris au telephone ---

const int maxMotif = 300;

/// Corps de POST /api/secretaire/medecins/{id}/rendezvous ; le motif est omis s'il est vide.
Map<String, dynamic> corpsRdvTelephone({
  required String creneauId,
  required String nomPatient,
  required String telephonePatient,
  String motif = '',
}) =>
    {
      'creneauId': creneauId,
      'nomPatient': nomPatient.trim(),
      'telephonePatient': telephonePatient.trim(),
      if (motif.trim().isNotEmpty) 'motif': motif.trim(),
    };
