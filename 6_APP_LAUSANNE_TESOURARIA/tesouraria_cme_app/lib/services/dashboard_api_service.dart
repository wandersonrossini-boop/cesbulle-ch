import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardSummaryModel {
  final String periodLabel;
  final bool periodLocked;
  final double currentMonthInputs;
  final int pendingExpensesCount;
  final double pendingExpensesTotal;
  final int currentMonthClosingsCount;

  DashboardSummaryModel({
    required this.periodLabel,
    required this.periodLocked,
    required this.currentMonthInputs,
    required this.pendingExpensesCount,
    required this.pendingExpensesTotal,
    required this.currentMonthClosingsCount,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      periodLabel: json['periodLabel'] ?? '',
      periodLocked: json['periodLocked'] ?? false,
      currentMonthInputs: (json['currentMonthInputs'] as num?)?.toDouble() ?? 0.0,
      pendingExpensesCount: json['pendingExpensesCount'] ?? 0,
      pendingExpensesTotal: (json['pendingExpensesTotal'] as num?)?.toDouble() ?? 0.0,
      currentMonthClosingsCount: json['currentMonthClosingsCount'] ?? 0,
    );
  }
}

class DashboardApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

  Future<DashboardSummaryModel> fetchDashboardSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/dashboard/summary'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      return DashboardSummaryModel.fromJson(jsonDecode(decodedBody));
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao obter sumário do painel (${response.statusCode})');
    }
  }
}
