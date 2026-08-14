import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../presentation/blocs/service_closing_events_states.dart';

class DraftService {
  static const String _baseKey = 'draft_closing_';

  Future<String> _getDraftKey() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'unknown';
    return '$_baseKey$username';
  }

  Future<void> saveDraft(ServiceClosingState state) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(state.toJson());
    final key = await _getDraftKey();
    await prefs.setString(key, jsonStr);
  }

  Future<ServiceClosingState?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getDraftKey();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return null;

    try {
      final data = jsonDecode(jsonStr);
      return ServiceClosingState.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getDraftKey();
    await prefs.remove(key);
  }
}
