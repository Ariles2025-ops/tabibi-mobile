import '../../services/api_service.dart';

/// Cabinet sur lequel agit l'ecran : celui du medecin connecte, ou celui d'un medecin pour une
/// secretaire rattachee (memes actions, routes /api/medecin/... ou /api/secretaire/...).
class Cabinet {
  const Cabinet.duMedecin()
      : medecinId = null,
        nomMedecin = null;

  const Cabinet.pourSecretaire(String this.medecinId, {this.nomMedecin});

  /// Medecin dont la secretaire gere l'agenda ; null pour le medecin connecte.
  final String? medecinId;
  final String? nomMedecin;

  bool get parSecretaire => medecinId != null;

  Future<List<Map<String, dynamic>>> agenda(ApiService api, String jeton) =>
      parSecretaire ? api.agendaSecretaire(medecinId!, jeton) : api.agendaMedecin(jeton);

  Future<List<Map<String, dynamic>>> patients(ApiService api, String jeton) =>
      parSecretaire ? api.patientsCabinet(medecinId!, jeton) : api.patientsMedecin(jeton);

  Future<void> honorer(ApiService api, String rdvId, String jeton) =>
      parSecretaire ? api.honorerParSecretaire(rdvId, jeton) : api.honorerRendezVous(rdvId, jeton);

  Future<void> absent(ApiService api, String rdvId, String jeton) => parSecretaire
      ? api.absentParSecretaire(rdvId, jeton)
      : api.marquerAbsentMedecin(rdvId, jeton);

  Future<void> annuler(ApiService api, String rdvId, String jeton) =>
      parSecretaire ? api.annulerParSecretaire(rdvId, jeton) : api.annulerParMedecin(rdvId, jeton);

  Future<List<Map<String, dynamic>>> creneaux(ApiService api, String jeton) =>
      parSecretaire ? api.creneauxSecretaire(medecinId!, jeton) : api.creneauxMedecin(jeton);

  Future<Map<String, dynamic>> ouvrirCreneau(
          ApiService api, DateTime debut, int duree, String jeton) =>
      parSecretaire
          ? api.ouvrirCreneauSecretaire(medecinId!, debut, duree, jeton)
          : api.ouvrirCreneauMedecin(debut, duree, jeton);

  Future<Map<String, dynamic>> semaineType(
          ApiService api, Map<String, dynamic> corps, String jeton) =>
      parSecretaire
          ? api.semaineTypeSecretaire(medecinId!, corps, jeton)
          : api.semaineTypeMedecin(corps, jeton);

  Future<void> supprimerCreneau(ApiService api, String creneauId, String jeton) => parSecretaire
      ? api.supprimerCreneauSecretaire(medecinId!, creneauId, jeton)
      : api.supprimerCreneauMedecin(creneauId, jeton);
}
