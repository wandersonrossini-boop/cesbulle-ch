import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/fechamento_api_service.dart';
import '../../domain/service_closing_history_models.dart';
import '../../domain/envelope.dart';

abstract class HistoryEvent {}

class LoadHistoryEvent extends HistoryEvent {}

class LoadClosingDetailEvent extends HistoryEvent {
  final int id;
  LoadClosingDetailEvent(this.id);
}

class DeleteClosingEvent extends HistoryEvent {
  final int id;
  DeleteClosingEvent(this.id);
}

class RequestCorrectionEvent extends HistoryEvent {
  final int closingId;
  final String reason;
  final double physicalTotal;
  final double unidentifiedDizimoTotal;
  final double unidentifiedOfertaTotal;
  final double unidentifiedVotoTotal;
  final List<Envelope> identifiedEntries;
  final String? verifierName;
  final String? verifierType;

  RequestCorrectionEvent({
    required this.closingId,
    required this.reason,
    required this.physicalTotal,
    required this.unidentifiedDizimoTotal,
    required this.unidentifiedOfertaTotal,
    required this.unidentifiedVotoTotal,
    required this.identifiedEntries,
    this.verifierName,
    this.verifierType,
  });
}

abstract class HistoryState {}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<ServiceClosingSummary> history;
  HistoryLoaded(this.history);
}

class HistoryDeleting extends HistoryState {}

class HistoryDeleteSuccess extends HistoryState {}

class HistoryDetailLoading extends HistoryState {}

class HistoryDetailLoaded extends HistoryState {
  final ServiceClosingDetail detail;
  final List<ServiceClosingCorrectionItem> corrections;
  HistoryDetailLoaded(this.detail, {this.corrections = const []});
}

class HistoryCorrectionSubmitting extends HistoryState {}

class HistoryCorrectionSuccess extends HistoryState {
  final String message;
  HistoryCorrectionSuccess(this.message);
}

class HistoryError extends HistoryState {
  final String message;
  final bool isUnauthorized;
  HistoryError(this.message, {this.isUnauthorized = false});
}

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final FechamentoApiService _apiService;

  HistoryBloc(this._apiService) : super(HistoryInitial()) {
    on<LoadHistoryEvent>((event, emit) async {
      emit(HistoryLoading());
      try {
        final history = await _apiService.fetchHistorico();
        emit(HistoryLoaded(history));
      } catch (e) {
        if (e.toString().contains('UNAUTHORIZED')) {
          emit(HistoryError('Sessão expirada.', isUnauthorized: true));
        } else {
          emit(HistoryError('Falha ao carregar histórico: $e'));
        }
      }
    });

    on<LoadClosingDetailEvent>((event, emit) async {
      emit(HistoryDetailLoading());
      try {
        final detail = await _apiService.fetchClosingDetail(event.id);
        List<ServiceClosingCorrectionItem> corrections = [];
        try {
          corrections = await _apiService.fetchCorrections(event.id);
        } catch (_) {}
        emit(HistoryDetailLoaded(detail, corrections: corrections));
      } catch (e) {
        if (e.toString().contains('UNAUTHORIZED')) {
          emit(HistoryError('Sessão expirada.', isUnauthorized: true));
        } else {
          emit(HistoryError('Falha ao carregar detalhes: $e'));
        }
      }
    });

    on<RequestCorrectionEvent>((event, emit) async {
      emit(HistoryCorrectionSubmitting());
      try {
        await _apiService.submitCorrection(
          event.closingId,
          reason: event.reason,
          physicalTotal: event.physicalTotal,
          unidentifiedDizimoTotal: event.unidentifiedDizimoTotal,
          unidentifiedOfertaTotal: event.unidentifiedOfertaTotal,
          unidentifiedVotoTotal: event.unidentifiedVotoTotal,
          identifiedEntries: event.identifiedEntries,
          verifierName: event.verifierName,
          verifierType: event.verifierType,
        );
        emit(HistoryCorrectionSuccess("Correção registrada com sucesso no histórico de auditoria."));
        add(LoadClosingDetailEvent(event.closingId));
      } catch (e) {
        final msg = e.toString().replaceAll('Exception: ', '');
        emit(HistoryError(msg));
        add(LoadClosingDetailEvent(event.closingId));
      }
    });

    on<DeleteClosingEvent>((event, emit) async {
      emit(HistoryDeleting());
      try {
        await _apiService.deleteClosing(event.id);
        emit(HistoryDeleteSuccess());
      } catch (e) {
        if (e.toString().contains('UNAUTHORIZED')) {
          emit(HistoryError('Sessão expirada.', isUnauthorized: true));
        } else {
          emit(HistoryError('Falha ao excluir fechamento: $e'));
        }
      }
    });
  }
}
