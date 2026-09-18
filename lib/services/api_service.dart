import 'dart:convert';
import 'package:http/http.dart' as http;

/// Appels a l'API Tabibi.
class ApiService {
  // Emulateur Android -> 10.0.2.2 ; iOS -> localhost.
  static const String _base = 'http://10.0.2.2:8080';

  /// Recherche publique de praticiens (sans jeton).
  Future<List<Map<String, dynamic>>> rechercherMedecins({
    String? specialite,
    String? wilaya,
    String? q,
  }) async {
    final params = <String, String>{};
    if (specialite != null && specialite.isNotEmpty) params['specialite'] = specialite;
    if (wilaya != null && wilaya.isNotEmpty) params['wilaya'] = wilaya;
    if (q != null && q.isNotEmpty) params['q'] = q;
    final uri = Uri.parse('$_base/api/medecins').replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Echec /api/medecins : ${res.statusCode}');
  }

  /// Identite de l'utilisateur connecte.
  Future<Map<String, dynamic>> moi(String token) async {
    final res = await http.get(
      Uri.parse('$_base/api/moi'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Echec /api/moi : ${res.statusCode}');
  }
}
