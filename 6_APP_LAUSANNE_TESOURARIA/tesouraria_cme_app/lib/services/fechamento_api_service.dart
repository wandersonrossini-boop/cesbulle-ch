import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/monetary_utils.dart';
import '../domain/service_closing_history_models.dart';
import '../presentation/blocs/service_closing_events_states.dart';
import '../domain/envelope.dart';

class FechamentoApiService {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

  Future<void> submitClosing(ServiceClosingState state) async {
    final Map<String, dynamic> payload = {
      "serviceDate": state.date != null ? "${state.date!.year.toString().padLeft(4, '0')}-${state.date!.month.toString().padLeft(2, '0')}-${state.date!.day.toString().padLeft(2, '0')}" : null,
      "mainTreasurer": state.mainTreasurer,
      "coTreasurer": state.coTreasurer,
      "verifierName": state.verifierName,
      "verifierType": state.verifierType,
      "physicalTotal": BigDecimalConverter.fromRappen(state.physicalTotal),
      "identifiedEntries": state.identifiedEntries.map((e) => {
        "memberName": e.memberName,
        "type": e.type.name.toUpperCase(),
        "amount": BigDecimalConverter.fromRappen(e.amount),
      }).toList(),
      "unidentifiedDizimoTotal": BigDecimalConverter.fromRappen(state.anonymousTotalBy(EnvelopeType.dizimo)),
      "unidentifiedOfertaTotal": BigDecimalConverter.fromRappen(state.anonymousTotalBy(EnvelopeType.oferta)),
      "unidentifiedVotoTotal": BigDecimalConverter.fromRappen(state.anonymousTotalBy(EnvelopeType.voto)),
    };

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/fechamento-culto'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao sincronizar o fechamento: ${response.body}');
    }
  }

  Future<List<ServiceClosingSummary>> fetchHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/fechamento-culto'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ServiceClosingSummary.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else if (response.statusCode == 403) {
      throw Exception('Acesso negado (403)');
    } else {
      throw Exception('Falha ao carregar historico (${response.statusCode})');
    }
  }

  Future<List<String>> fetchMembros() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse('$_baseUrl/membros'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((e) => e.toString()).toList();
      } else {
        throw Exception('Erro ao buscar membros: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Falha de rede: $e');
    }
  }

  Future<ServiceClosingDetail> fetchClosingDetail(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/fechamento-culto/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      return ServiceClosingDetail.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else if (response.statusCode == 403) {
      throw Exception('Acesso negado (403)');
    } else {
      throw Exception('Falha ao carregar detalhes do fechamento (${response.statusCode})');
    }
  }

  Future<void> deleteClosing(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.delete(
      Uri.parse('$_baseUrl/fechamento-culto/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
      throw Exception('Erro ao deletar fechamento: ${response.statusCode}');
    }
  }

  Future<void> saveDraftToServer(ServiceClosingState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      await http.post(
        Uri.parse('$_baseUrl/fechamento-culto/draft'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(state.toJson()),
      );
    } catch (_) {}
  }

  Future<ServiceClosingState?> getDraftFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$_baseUrl/fechamento-culto/draft'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return ServiceClosingState.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
      return null;
    } on Exception {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraftOnServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      await http.delete(
        Uri.parse('$_baseUrl/fechamento-culto/draft'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getOrCreateSession({
    required DateTime date,
    required String startTime,
    required String endTime,
    required String? type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/fechamento-culto/session'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'serviceDate': "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'serviceTime': startTime,
        'serviceEndTime': endTime,
        'serviceType': type,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    } else {
      throw Exception('Falha ao criar/obter sessão (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> saveSessionDraftToServer(int sessionId, ServiceClosingState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      await http.post(
        Uri.parse('$_baseUrl/fechamento-culto/session/$sessionId/draft'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(state.toJson()),
      );
    } catch (_) {}
  }

  Future<ServiceClosingState?> getSessionDraftFromServer(int sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$_baseUrl/fechamento-culto/session/$sessionId/draft'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return ServiceClosingState.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
      return null;
    } on Exception {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSessionDraftOnServer(int sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      await http.delete(
        Uri.parse('$_baseUrl/fechamento-culto/session/$sessionId/draft'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
  }
}
