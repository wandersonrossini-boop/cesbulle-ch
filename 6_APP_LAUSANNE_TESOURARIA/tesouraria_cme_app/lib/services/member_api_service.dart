import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MemberDetail {
  final int id;
  final String name;

  MemberDetail({required this.id, required this.name});

  factory MemberDetail.fromJson(Map<String, dynamic> json) {
    return MemberDetail(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}

class MemberApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tesouraria-cme-api.onrender.com/api',
  );

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<MemberDetail>> fetchMembersDetailed() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/membros/detalhado'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((e) => MemberDetail.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Erro ao buscar contribuintes: ${response.statusCode}');
    }
  }

  Future<MemberDetail> createMember(String name) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/membros'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) {
      return MemberDetail.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception(response.body.isNotEmpty ? response.body : 'Erro ao criar contribuinte.');
    }
  }

  Future<void> renameMember(int id, String newName) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/membros/$id'),
      headers: headers,
      body: jsonEncode({'name': newName}),
    );
    if (response.statusCode == 200) return;
    if (response.statusCode == 400) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Nome inválido.');
    }
    if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    }
    throw Exception('Erro ao renomear contribuinte: ${response.statusCode}');
  }

  Future<void> deleteMember(int id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/membros/$id'),
      headers: headers,
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    }
    throw Exception('Erro ao excluir contribuinte: ${response.statusCode}');
  }
}
