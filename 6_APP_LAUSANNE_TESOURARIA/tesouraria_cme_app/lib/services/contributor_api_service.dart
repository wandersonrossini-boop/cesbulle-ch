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
      'contributorNumber': contributorNumber,
      'active': active,
    };
  }
}

class ContributorApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

  Future<List<ContributorModel>> fetchContributors({String? search}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final uri = Uri.parse('$_baseUrl/contributors').replace(
      queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body) as List;
      return list.map((item) => ContributorModel.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao obter contribuintes (${response.statusCode})');
    }
  }

  Future<ContributorModel> createContributor(ContributorModel contributor) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/contributors'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(contributor.toJson()),
    );

    if (response.statusCode == 200) {
      return ContributorModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao cadastrar contribuinte: ${response.body}');
    }
  }

  Future<ContributorModel> updateContributor(String id, ContributorModel contributor) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.put(
      Uri.parse('$_baseUrl/contributors/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(contributor.toJson()),
    );

    if (response.statusCode == 200) {
      return ContributorModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao atualizar contribuinte: ${response.body}');
    }
  }

  Future<Uint8List> downloadAttestationPdf(String id, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/contributors/$id/attestation/pdf?year=$year'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Falha ao baixar Attestation PDF (${response.statusCode})');
    }
  }

  Future<void> deleteContributor(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.delete(
      Uri.parse('$_baseUrl/contributors/$id'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
      throw Exception('Falha ao excluir contribuinte: ${response.body}');
    }
  }
}
