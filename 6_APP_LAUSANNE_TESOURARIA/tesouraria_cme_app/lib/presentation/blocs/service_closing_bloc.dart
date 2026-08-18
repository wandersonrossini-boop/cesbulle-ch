import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'service_closing_events_states.dart';
import '../../services/fechamento_api_service.dart';
import '../../services/draft_service.dart';

class ServiceClosingBloc extends Bloc<ServiceClosingEvent, ServiceClosingState> {
  final DraftService _draftService = DraftService();
  Timer? _debounceTimer;

  ServiceClosingBloc() : super(const ServiceClosingState()) {
    on<InitializeClosingContextEvent>((event, emit) {
      emit(state.copyWith(date: event.date, mainTreasurer: event.mainTreasurer, coTreasurer: event.coTreasurer));
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
        await apiService.clearDraftOnServer();
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
    try {
      final apiService = FechamentoApiService();
      final serverDraft = await apiService.getDraftFromServer();
      // Só publica no servidor se não houver sessão ativa lá ou se formos o dono dela
      if (serverDraft == null || serverDraft.mainTreasurer == state.mainTreasurer) {
        await apiService.saveDraftToServer(state);
      }
    } catch (_) {}
  }
}
