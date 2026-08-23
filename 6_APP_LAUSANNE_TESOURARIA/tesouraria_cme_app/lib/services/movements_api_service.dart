import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/movement_models.dart';

class MovementsApiService {
  static const String baseUrl = 'http://localhost:8080/api/movements';

  Future<MovementResponse> fetchMovements(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$baseUrl?year=$year&month=$month'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = utf8.decode(response.bodyBytes);
      return MovementResponse.fromJson(json.decode(decoded));
    } else {
      throw Exception('Falha ao carregar movimentos.');
    }
  }
}
