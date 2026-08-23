import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuditLogModel {
  final int id;
  final String action;
  final String performedBy;
  final String? targetId;
  final String? details;
  final String timestamp;

  AuditLogModel({
    required this.id,
    required this.action,
    required this.performedBy,
    this.targetId,
    this.details,
    required this.timestamp,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'],
      action: json['action'] ?? '',
      performedBy: json['performedBy'] ?? '',
      targetId: json['targetId'],
      details: json['details'],
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class AuditLogPageModel {
  final List<AuditLogModel> content;
  final int totalPages;
  final int totalElements;
  final int number;
  final bool last;

  AuditLogPageModel({
    required this.content,
    required this.totalPages,
    required this.totalElements,
    required this.number,
    required this.last,
  });

  factory AuditLogPageModel.fromJson(Map<String, dynamic> json) {
    var list = json['content'] as List? ?? [];
    List<AuditLogModel> contentList = list.map((i) => AuditLogModel.fromJson(i)).toList();
    return AuditLogPageModel(
      content: contentList,
      totalPages: json['totalPages'] ?? 1,
      totalElements: json['totalElements'] ?? 0,
      number: json['number'] ?? 0,
      last: json['last'] ?? true,
    );
  }
}

class AuditLogApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

  Future<AuditLogPageModel> fetchAuditLogs({int page = 0, int size = 20}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/audit-logs?page=$page&size=$size'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      return AuditLogPageModel.fromJson(jsonDecode(decodedBody));
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao obter logs de auditoria (${response.statusCode})');
    }
  }
}
