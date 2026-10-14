import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/envelope.dart';
import 'service_closing_events_states.dart';
import '../../services/fechamento_api_service.dart';
import '../../services/draft_service.dart';

class ServiceClosingBloc extends Bloc<ServiceClosingEvent, ServiceClosingState> {
  final DraftService _draftService = DraftService();
  Timer? _debounceTimer;

  ServiceClosingBloc() : super(const ServiceClosingState()) {
    on<InitializeClosingContextEvent>((event, emit) {
      emit(state.copyWith(
        date: event.date,
        mainTreasurer: event.mainTreasurer,
        coTreasurer: event.coTreasurer,
        sessionId: event.sessionId,
        serviceTime: event.serviceTime,
        serviceEndTime: event.serviceEndTime,
        serviceType: event.serviceType,
      ));
    });

    on<RestoreDraftEvent>((event, emit) {
      emit(event.draftState.copyWith(
        isSubmitting: false,
        isSuccess: false,
        error: null,
      ));
    });

    on<LoadMembersEvent>((event, emit) async {
      try {
        final apiService = FechamentoApiService();
        final members = await apiService.fetchMembros();
        emit(state.copyWith(knownMembers: members));
      } catch (e) {
        // Ignora erros de carregamento de membros (fallback para digitação manual)
      }
    });

    on<AddEnvelopeEvent>((event, emit) {
      final updatedEntries = List.of(state.identifiedEntries)..add(event.envelope);
      emit(state.copyWith(identifiedEntries: updatedEntries));
    });

    on<RemoveEnvelopeEvent>((event, emit) {
      final updatedEntries = List.of(state.identifiedEntries)..removeWhere((e) => e.id == event.id);
      emit(state.copyWith(identifiedEntries: updatedEntries));
    });

    on<UndoAddedEntryEvent>((event, emit) {
      final updatedEntries = List.of(state.identifiedEntries)..removeWhere((e) => e.id == event.entryId);
      emit(state.copyWith(identifiedEntries: updatedEntries));
    });

    on<AddAnonymousOfferingEvent>((event, emit) {
      final updatedEntries = List.of(state.anonymousEntries)..add(event.entry);
      emit(state.copyWith(anonymousEntries: updatedEntries));
    });

    on<UndoAnonymousOfferingEvent>((event, emit) {
      final updatedEntries = List.of(state.anonymousEntries)..removeWhere((e) => e.id == event.id);
      emit(state.copyWith(anonymousEntries: updatedEntries));
    });

    on<SetPhysicalTotalEvent>((event, emit) {
      emit(state.copyWith(
        physicalTotal: event.physicalTotal,
        error: null,
      ));
    });

    on<SubmitClosingEvent>((event, emit) async {
      final updatedState = state.copyWith(
        isSubmitting: true,
        error: null,
        isSuccess: false,
        coTreasurer: event.coTreasurer ?? state.coTreasurer,
        verifierName: event.verifierName ?? state.verifierName,
        verifierType: event.verifierType ?? state.verifierType,
      );
      emit(updatedState);

      try {
        final apiService = FechamentoApiService();
        await apiService.submitClosing(updatedState);
        await _draftService.clearDraft();
        final sessionId = state.sessionId;
        if (sessionId != null) {
          await apiService.clearSessionDraftOnServer(sessionId);
        } else {
          await apiService.clearDraftOnServer();
        }
        emit(updatedState.copyWith(isSubmitting: false, isSuccess: true));
      } catch (e) {
        emit(updatedState.copyWith(isSubmitting: false, error: e.toString()));
      }
    });

    on<AddLocalMemberEvent>((event, emit) {
      final updatedList = List<String>.from(state.knownMembers);
      if (!updatedList.any((m) => m.toLowerCase() == event.name.trim().toLowerCase())) {
        updatedList.add(event.name.trim());
        updatedList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
      emit(state.copyWith(knownMembers: updatedList));
    });

    on<MergeSessionDraftEvent>((event, emit) {
      final server = event.serverDraft;

      // Merge identified entries by id to avoid duplicating entries
      final Map<String, Envelope> idMap = {};
      for (final e in state.identifiedEntries) {
        idMap[e.id] = e;
      }
      for (final e in server.identifiedEntries) {
        idMap[e.id] = e;
      }

      // Merge anonymous entries by id
      final Map<String, AnonymousEntry> anonMap = {};
      for (final a in state.anonymousEntries) {
        anonMap[a.id] = a;
      }
      for (final a in server.anonymousEntries) {
        anonMap[a.id] = a;
      }

      emit(state.copyWith(
        identifiedEntries: idMap.values.toList(),
        anonymousEntries: anonMap.values.toList(),
        physicalTotal: server.physicalTotal > 0 ? server.physicalTotal : state.physicalTotal,
        coTreasurer: server.coTreasurer ?? state.coTreasurer,
        verifierName: server.verifierName ?? state.verifierName,
        verifierType: server.verifierType ?? state.verifierType,
        conferente2: server.conferente2 ?? state.conferente2,
        conferente1Ready: server.conferente1Ready,
        conferente2Ready: server.conferente2Ready,
      ));
    });

    on<SetConferenteReadyEvent>((event, emit) async {
      final sessionId = state.sessionId;
      if (sessionId == null) return;
      try {
        final apiService = FechamentoApiService();
        final updatedSession = await apiService.setSessionReady(sessionId, event.ready);
        emit(state.copyWith(
          conferente1Ready: updatedSession['conferente1Ready'] ?? false,
          conferente2Ready: updatedSession['conferente2Ready'] ?? false,
          conferente2: updatedSession['conferente2'] as String? ?? state.conferente2,
        ));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });
  }

  @override
  void onChange(Change<ServiceClosingState> change) {
    super.onChange(change);
    final nextState = change.nextState;
    // Só grava o rascunho se a data estiver preenchida (contexto iniciado), não for sucesso, erro ou submissão
    if (nextState.error == null && nextState.date != null && !nextState.isSuccess && !nextState.isSubmitting) {
      _draftService.saveDraft(nextState);
      
      // Cancela o timer anterior para aplicar o debounce de 1 segundo
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        if (!isClosed) {
          _syncDraftToServer(nextState);
        }
      });
    } else {
      // Cancela qualquer sync pendente se o estado mudar para erro, sucesso ou submissão
      _debounceTimer?.cancel();
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> _syncDraftToServer(ServiceClosingState state) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    try {
      final apiService = FechamentoApiService();
      await apiService.saveSessionDraftToServer(sessionId, state);
    } catch (_) {}
  }
}
