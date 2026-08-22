import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ServiceSchedule {
  final int id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String serviceType;
  final bool active;

  ServiceSchedule({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.serviceType,
    required this.active,
  });

  factory ServiceSchedule.fromJson(Map<String, dynamic> json) {
    return ServiceSchedule(
      id: json['id'],
      dayOfWeek: json['dayOfWeek'],
      startTime: json['startTime'].toString().substring(0, 5),
      endTime: json['endTime'].toString().substring(0, 5),
      serviceType: json['serviceType'],
      active: json['active'] ?? true,
    );
  }
}

class ServiceScheduleApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<ServiceSchedule>> listAll() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/service-schedules'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => ServiceSchedule.fromJson(item)).toList();
    }
    throw Exception('Falha ao carregar agenda de cultos.');
  }

  Future<ServiceSchedule> create({
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    required String serviceType,
    required bool active,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/service-schedules'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'serviceType': serviceType,
        'active': active,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ServiceSchedule.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Falha ao cadastrar culto programado: ${response.body}');
  }

  Future<ServiceSchedule> update(
    int id, {
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    required String serviceType,
    required bool active,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/service-schedules/$id'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'serviceType': serviceType,
        'active': active,
      }),
    );
    if (response.statusCode == 200) {
      return ServiceSchedule.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Falha ao atualizar culto programado: ${response.body}');
  }

  Future<void> toggleActive(int id) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/service-schedules/$id/toggle-active'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Falha ao alterar status da agenda.');
    }
  }
}
