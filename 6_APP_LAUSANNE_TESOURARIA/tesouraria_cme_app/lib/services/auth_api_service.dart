import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-db.onrender.com/api');

  Future<String?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('username', username);
        return null; // Success (no error)
      } else if (response.statusCode == 403) {
        return "Usuário aguardando aprovação do Admin.";
      } else {
        return "Credenciais inválidas.";
      }
    } catch (e) {
      return "Erro de conexão: ${e.toString()}";
    }
  }

  Future<String?> register(String name, String username, String password, String? avatarBase64) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'username': username,
          'password': password,
          'avatarBase64': avatarBase64,
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        return response.body;
      }
    } catch (e) {
      return "Erro de conexão: ${e.toString()}";
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('jwt_token');
  }
}
