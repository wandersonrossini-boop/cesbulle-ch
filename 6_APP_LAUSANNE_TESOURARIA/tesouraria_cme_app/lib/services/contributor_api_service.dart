import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ContributorModel {
  final String id;
  final String fullName;
  final String address;
  final String postalCode;
  final String city;
  final String email;
  final String phone;
  final String contributorNumber;
  final bool active;
  final bool hasMovements;

  ContributorModel({
    required this.id,
    required this.fullName,
    required this.address,
    required this.postalCode,
    required this.city,
    required this.email,
    required this.phone,
    required this.contributorNumber,
    required this.active,
    this.hasMovements = false,
  });

  factory ContributorModel.fromJson(Map<String, dynamic> json) {
    return ContributorModel(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName'] ?? '',
      address: json['address'] ?? '',
      postalCode: json['postalCode'] ?? '',
      city: json['city'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      contributorNumber: json['contributorNumber'] ?? '',
      active: json['active'] as bool? ?? true,
      hasMovements: json['hasMovements'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.isEmpty ? null : int.parse(id),
      'fullName': fullName,
      'address': address,
      'postalCode': postalCode,
      'city': city,
      'email': email,
      'phone': phone,
      'contributorNumber': contributorNumber.trim().isEmpty ? null : contributorNumber.trim(),
      'active': active,
    };
  }
}

class ContributorApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');
  final http.Client _client;

  ContributorApiService({http.Client? client}) : _client = client ?? http.Client();

  String _parseErrorMessage(http.Response response, String fallbackMessage) {
    if (response.statusCode == 401) {
      return 'UNAUTHORIZED';
    }
    if (response.statusCode == 403) {
      return 'Acesso negado. Apenas administradores ou tesoureiros têm permissão.';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('message') && decoded['message'] is String && (decoded['message'] as String).isNotEmpty) {
          return decoded['message'];
        }
        if (decoded.containsKey('error') && decoded['error'] is String && (decoded['error'] as String).isNotEmpty) {
          return decoded['error'];
        }
      } else if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded;
      }
    } catch (_) {}

    final raw = response.body.trim();
    if (raw.isNotEmpty && raw.length < 120 && !raw.contains('<html') && !raw.contains('Exception') && !raw.contains('at com.')) {
      return raw;
    }
    return fallbackMessage;
  }

  Future<List<ContributorModel>> fetchContributors({String? search}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final uri = Uri.parse('$_baseUrl/contributors').replace(
      queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
    );

    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body) as List;
      return list.map((item) => ContributorModel.fromJson(item)).toList();
    } else {
      throw Exception(_parseErrorMessage(response, 'Falha ao obter contribuintes (${response.statusCode})'));
    }
  }

  Future<ContributorModel> createContributor(ContributorModel contributor) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await _client.post(
      Uri.parse('$_baseUrl/contributors'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(contributor.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ContributorModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(response, 'Falha ao cadastrar contribuinte.'));
    }
  }

  Future<ContributorModel> updateContributor(String id, ContributorModel contributor) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await _client.put(
      Uri.parse('$_baseUrl/contributors/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(contributor.toJson()),
    );

    if (response.statusCode == 200) {
      return ContributorModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(response, 'Falha ao atualizar contribuinte.'));
    }
  }

  Future<Uint8List> downloadAttestationPdf(String id, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await _client.get(
      Uri.parse('$_baseUrl/contributors/$id/attestation/pdf?year=$year'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception(_parseErrorMessage(response, 'Falha ao baixar Attestation PDF (${response.statusCode})'));
    }
  }

  Future<void> deleteContributor(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await _client.delete(
      Uri.parse('$_baseUrl/contributors/$id'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_parseErrorMessage(response, 'Falha ao excluir contribuinte.'));
    }
  }
}
