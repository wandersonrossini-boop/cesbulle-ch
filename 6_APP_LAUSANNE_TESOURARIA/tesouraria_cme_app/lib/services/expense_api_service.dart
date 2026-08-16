import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseModel {
  final String id;
  final String description;
  final String category;
  final String supplier;
  final double amount;
  final String date;
  final String paymentMethod;
  final String receiptReference;
  final String status; // PENDING, APPROVED, REJECTED, REVERSED
  final String? reversalJustification;
  final String createdBy;
  final String? approvedBy;
  final String? approvalDate;

  ExpenseModel({
    required this.id,
    required this.description,
    required this.category,
    required this.supplier,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    required this.receiptReference,
    required this.status,
    this.reversalJustification,
    required this.createdBy,
    this.approvedBy,
    this.approvalDate,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    String parseDate(dynamic val) {
      if (val == null) return '-';
      if (val is String) {
        final parts = val.split('-');
        if (parts.length == 3) {
          return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
        }
        return val;
      }
      return '-';
    }

    return ExpenseModel(
      id: json['id']?.toString() ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      supplier: json['supplier'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      date: parseDate(json['expenseDate']),
      paymentMethod: json['paymentMethod'] ?? 'Outro',
      receiptReference: json['receiptReference'] ?? '',
      status: json['status'] ?? 'PENDING',
      reversalJustification: json['reversalJustification'],
      createdBy: json['createdBy'] ?? '',
      approvedBy: json['approvedBy'],
      approvalDate: json['approvalDate'] != null ? parseDate(json['approvalDate']) : null,
    );
  }
}

class ExpenseApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

  Future<List<ExpenseModel>> fetchExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/despesas'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ExpenseModel.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao carregar despesas (${response.statusCode})');
    }
  }

  Future<ExpenseModel> createExpense({
    required String description,
    required String supplier,
    required String category,
    required double amount,
    required String localDateStr, // DD/MM/YYYY
    required String paymentMethod,
    required String receiptReference,
  }) async {
    final parts = localDateStr.split('/');
    String backendDate = localDateStr;
    if (parts.length == 3) {
      backendDate = '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }

    final payload = {
      'expenseDate': backendDate,
      'description': description,
      'supplier': supplier,
      'category': category,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'receiptReference': receiptReference,
    };

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/despesas'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ExpenseModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao registrar despesa (${response.statusCode})');
    }
  }

  Future<void> approveExpense(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.put(
      Uri.parse('$_baseUrl/despesas/$id/approve'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
      throw Exception('Erro ao aprovar despesa: ${response.body}');
    }
  }

  Future<void> rejectExpense(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.put(
      Uri.parse('$_baseUrl/despesas/$id/reject'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
      throw Exception('Erro ao rejeitar despesa: ${response.body}');
    }
  }

  Future<void> reverseExpense(int id, String justification) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.put(
      Uri.parse('$_baseUrl/despesas/$id/reverse'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'justification': justification}),
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
      throw Exception('Erro ao estornar despesa: ${response.body}');
    }
  }
}
