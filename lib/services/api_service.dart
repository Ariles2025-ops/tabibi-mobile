import 'dart:convert';
import 'package:http/http.dart' as http;

/// Appels a l'API Tabibi, avec le JWT en en-tete.
class ApiService {
  // En dev : emulateur Android -> 10.0.2.2 ; iOS -> localhost.
  static const String _base = 'http://10.0.2.2:8080';

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
