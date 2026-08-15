import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppUser {
  final int id;
  final String username;
  final String name;
  final String role;
  final bool isAuthorized;
  final String? avatarBase64;

  AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.isAuthorized,
    this.avatarBase64,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      username: json['username'],
      name: json['name'],
      role: json['role'],
      isAuthorized: json['authorized'] ?? false,
      avatarBase64: json['avatarBase64'],
    );
  }
}

class UserApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<AppUser> getMyProfile() async {
    final response = await http.get(Uri.parse('$_baseUrl/users/me'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      return AppUser.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Falha ao carregar perfil.');
  }

  Future<void> updateMyProfile(String? name, String? newPassword, String? avatarBase64) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users/me'),
      headers: await _getHeaders(),
      body: jsonEncode({
        if (name != null && name.isNotEmpty) 'name': name,
        if (newPassword != null && newPassword.isNotEmpty) 'newPassword': newPassword,
        if (avatarBase64 != null) 'avatarBase64': avatarBase64,
      }),
    );
    if (response.statusCode != 200) throw Exception('Falha ao atualizar perfil.');
  }

  // --- ADMIN ENDPOINTS ---

  Future<List<AppUser>> getAllUsers() async {
    final response = await http.get(Uri.parse('$_baseUrl/users'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((u) => AppUser.fromJson(u)).toList();
    }
    throw Exception('Falha ao carregar usuários.');
  }

  Future<void> approveUser(int id) async {
    final response = await http.put(Uri.parse('$_baseUrl/users/$id/approve'), headers: await _getHeaders());
    if (response.statusCode != 200) throw Exception('Falha ao aprovar usuário.');
  }

  Future<void> revokeUser(int id) async {
    final response = await http.put(Uri.parse('$_baseUrl/users/$id/revoke'), headers: await _getHeaders());
    if (response.statusCode != 200) throw Exception('Falha ao revogar usuário.');
  }

  Future<void> deleteUser(int id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/users/$id'), headers: await _getHeaders());
    if (response.statusCode != 200) throw Exception('Falha ao remover usuário.');
  }

  Future<void> resetPassword(int id, String newPassword) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users/$id/reset-password'),
      headers: await _getHeaders(),
      body: jsonEncode({'newPassword': newPassword}),
    );
    if (response.statusCode != 200) throw Exception('Falha ao redefinir senha.');
  }
}
