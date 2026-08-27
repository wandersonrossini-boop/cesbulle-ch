import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MonthlyReportModel {
  final int month;
  final int year;
  final double totalIncomes;
  final double totalExpenses;
  final double totalCommitted;
  final double netBalance;
  final List<CategorySummaryModel> incomesByCategory;
  final List<CategorySummaryModel> expensesByCategory;
  final String status;

  MonthlyReportModel({
    required this.month,
    required this.year,
    required this.totalIncomes,
    required this.totalExpenses,
    required this.totalCommitted,
    required this.netBalance,
    required this.incomesByCategory,
    required this.expensesByCategory,
    required this.status,
  });

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    final period = json['period'] ?? {};
    final summary = json['summary'] ?? {};
    final meta = json['metadata'] ?? {};

    final incomes = (json['incomesByCategory'] as List? ?? [])
        .map((item) => CategorySummaryModel.fromJson(item))
        .toList();

    final expenses = (json['expensesByCategory'] as List? ?? [])
        .map((item) => CategorySummaryModel.fromJson(item))
        .toList();

    return MonthlyReportModel(
      month: period['month'] ?? 0,
      year: period['year'] ?? 0,
      totalIncomes: (summary['totalIncomes'] as num? ?? 0.0).toDouble(),
      totalExpenses: (summary['totalExpenses'] as num? ?? 0.0).toDouble(),
      totalCommitted: (summary['totalCommitted'] as num? ?? 0.0).toDouble(),
      netBalance: (summary['netBalance'] as num? ?? 0.0).toDouble(),
      incomesByCategory: incomes,
      expensesByCategory: expenses,
      status: meta['status'] ?? 'DRAFT',
    );
  }
}

class CategorySummaryModel {
  final String category;
  final double total;
  final int count;

  CategorySummaryModel({
    required this.category,
    required this.total,
    required this.count,
  });

  factory CategorySummaryModel.fromJson(Map<String, dynamic> json) {
    return CategorySummaryModel(
      category: json['category'] ?? '',
      total: (json['total'] as num? ?? 0.0).toDouble(),
      count: json['count'] ?? 0,
    );
  }
}

class FinancialReportApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

  Future<MonthlyReportModel> fetchMonthlyReport(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/reports/financial/monthly?month=$month&year=$year'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return MonthlyReportModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao obter relatório financeiro mensal (${response.statusCode})');
    }
  }

  Future<Uint8List> downloadMonthlyReportCsv(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/reports/financial/monthly/csv?month=$month&year=$year'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Falha ao baixar relatório CSV (${response.statusCode})');
    }
  }

  Future<Uint8List> downloadMonthlyReportPdf(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/reports/financial/monthly/pdf?month=$month&year=$year'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Falha ao baixar relatório PDF (${response.statusCode})');
    }
  }

  Future<String> fetchPeriodStatus(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/reports/financial/monthly/status?month=$month&year=$year'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] ?? 'OPEN';
    } else {
      throw Exception('Falha ao obter status do período (${response.statusCode})');
    }
  }

  Future<void> lockPeriod(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/reports/financial/monthly/lock?month=$month&year=$year'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Falha ao trancar o período.');
    }
  }

  Future<void> unlockPeriod(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/reports/financial/monthly/unlock?month=$month&year=$year'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Falha ao reabrir o período.');
    }
  }

  Future<String> createGoogleSheetsReport(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/relatorios/google-sheets?month=$month&year=$year'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['spreadsheetUrl'] ?? '';
    } else {
      throw Exception(response.body.isNotEmpty ? response.body : 'Falha ao gerar planilha no Google Sheets.');
    }
  }
}
