import 'package:flutter_test/flutter_test.dart';
import 'package:tesouraria_cme_app/presentation/blocs/history_bloc.dart';
import 'package:tesouraria_cme_app/services/fechamento_api_service.dart';
import 'package:tesouraria_cme_app/domain/service_closing_history_models.dart';
import 'package:tesouraria_cme_app/presentation/blocs/service_closing_events_states.dart';

class FakeFechamentoApiService implements FechamentoApiService {
  @override
  Future<List<ServiceClosingSummary>> fetchHistorico() async {
    return [
      ServiceClosingSummary(id: 1, serviceDate: '2026-08-09', mainTreasurer: 'A', coTreasurer: 'B', physicalTotal: 100.0)
    ];
  }

  @override
  Future<List<String>> fetchMembros() async {
    return ['Admilson', 'João Silva'];
  }

  @override
  Future<ServiceClosingDetail> fetchClosingDetail(int id) async {
    return ServiceClosingDetail(
      id: id,
      serviceDate: '2026-08-09',
      mainTreasurer: 'A',
      coTreasurer: 'B',
      identifiedEntries: [],
      unidentifiedDizimoTotal: 0,
      unidentifiedOfertaTotal: 0,
      unidentifiedVotoTotal: 0,
      identifiedTotal: 0,
      unidentifiedTotal: 0,
      registeredTotal: 10000,
      physicalTotal: 10000,
    );
  }

  @override
  Future<void> deleteClosing(int id) async {
    return;
  }
  
  @override
  Future<void> submitClosing(dynamic state) async {}

  @override
  Future<void> saveDraftToServer(dynamic state) async {}

  @override
  Future<ServiceClosingState?> getDraftFromServer() async {
    return null;
  }

  @override
  Future<void> clearDraftOnServer() async {}

  @override
  Future<Map<String, dynamic>> getOrCreateSession({
    required DateTime date,
    required String startTime,
    required String endTime,
    required String? type,
  }) async {
    return {};
  }

  @override
  Future<void> saveSessionDraftToServer(int sessionId, ServiceClosingState state) async {}

  @override
  Future<ServiceClosingState?> getSessionDraftFromServer(int sessionId) async {
    return null;
  }

  @override
  Future<void> clearSessionDraftOnServer(int sessionId) async {}

  @override
  Future<Map<String, dynamic>> getCurrentSessionStatus() async {
    return {'hasSchedule': false};
  }

  @override
  Future<Map<String, dynamic>> resolveAutomaticSession() async {
    return {};
  }
}

void main() {
  group('HistoryBloc', () {
    test('emits HistoryLoaded when LoadHistoryEvent is added successfully', () async {
      final fakeService = FakeFechamentoApiService();
      final bloc = HistoryBloc(fakeService);
      
      final expectedStates = [
        isA<HistoryLoading>(),
        isA<HistoryLoaded>(),
      ];
      
      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(LoadHistoryEvent());
    });

    test('emits HistoryDetailLoaded when LoadClosingDetailEvent is added successfully', () async {
      final fakeService = FakeFechamentoApiService();
      final bloc = HistoryBloc(fakeService);
      
      final expectedStates = [
        isA<HistoryDetailLoading>(),
        isA<HistoryDetailLoaded>(),
      ];
      
      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(LoadClosingDetailEvent(1));
    });
  });
}
