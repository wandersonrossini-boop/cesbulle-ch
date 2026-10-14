import 'package:equatable/equatable.dart';
import '../../domain/envelope.dart';

abstract class ServiceClosingEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class InitializeClosingContextEvent extends ServiceClosingEvent {
  final DateTime date;
  final String mainTreasurer;
  final String coTreasurer;
  final int? sessionId;
  final String? serviceTime;
  final String? serviceEndTime;
  final String? serviceType;

  InitializeClosingContextEvent(
    this.date,
    this.mainTreasurer,
    this.coTreasurer, {
    this.sessionId,
    this.serviceTime,
    this.serviceEndTime,
    this.serviceType,
  });
}

class LoadMembersEvent extends ServiceClosingEvent {}

class RestoreDraftEvent extends ServiceClosingEvent {
  final ServiceClosingState draftState;
  RestoreDraftEvent(this.draftState);
}

class AddEnvelopeEvent extends ServiceClosingEvent {
  final Envelope envelope;
  AddEnvelopeEvent(this.envelope);
}

class AnonymousEntry extends Equatable {
  final String id;
  final EnvelopeType type;
  final int amount;
  final String? enteredBy;

  const AnonymousEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.enteredBy,
  });

  @override
  List<Object?> get props => [id, type, amount, enteredBy];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      if (enteredBy != null) 'enteredBy': enteredBy,
    };
  }

  factory AnonymousEntry.fromJson(Map<String, dynamic> json) {
    return AnonymousEntry(
      id: json['id'],
      type: EnvelopeType.values.firstWhere((e) => e.name == json['type']),
      amount: json['amount'],
      enteredBy: json['enteredBy'] as String?,
    );
  }
}

class RemoveEnvelopeEvent extends ServiceClosingEvent {
  final String id;
  RemoveEnvelopeEvent(this.id);
}

class AddAnonymousOfferingEvent extends ServiceClosingEvent {
  final AnonymousEntry entry;
  AddAnonymousOfferingEvent(this.entry);
}

class UndoAnonymousOfferingEvent extends ServiceClosingEvent {
  final String id;
  UndoAnonymousOfferingEvent(this.id);
}

class SetPhysicalTotalEvent extends ServiceClosingEvent {
  final int physicalTotal;
  SetPhysicalTotalEvent(this.physicalTotal);
}

class SubmitClosingEvent extends ServiceClosingEvent {
  final String? coTreasurer;
  final String? verifierName;
  final String? verifierType;
  SubmitClosingEvent({this.coTreasurer, this.verifierName, this.verifierType});

  @override
  List<Object?> get props => [coTreasurer, verifierName, verifierType];
}

class AddLocalMemberEvent extends ServiceClosingEvent {
  final String name;
  AddLocalMemberEvent(this.name);

  @override
  List<Object?> get props => [name];
}

class UndoAddedEntryEvent extends ServiceClosingEvent {
  final String entryId;
  UndoAddedEntryEvent(this.entryId);

  @override
  List<Object?> get props => [entryId];
}

class MergeSessionDraftEvent extends ServiceClosingEvent {
  final ServiceClosingState serverDraft;
  MergeSessionDraftEvent(this.serverDraft);

  @override
  List<Object?> get props => [serverDraft];
}

class SetConferenteReadyEvent extends ServiceClosingEvent {
  final bool ready;
  SetConferenteReadyEvent(this.ready);

  @override
  List<Object?> get props => [ready];
}

class ServiceClosingState extends Equatable {
  final int? sessionId;
  final DateTime? date;
  final String? serviceTime;
  final String? serviceEndTime;
  final String? serviceType;
  final String mainTreasurer;
  final String? coTreasurer;
  final String? verifierName;
  final String? verifierType;
  final List<Envelope> identifiedEntries;
  final List<AnonymousEntry> anonymousEntries;
  final int physicalTotal;
  final String? error;
  final List<String> knownMembers;
  final bool isSubmitting;
  final bool isSuccess;
  final String? conferente2;
  final bool conferente1Ready;
  final bool conferente2Ready;

  int get identifiedTotal => identifiedEntries.fold(0, (sum, item) => sum + item.amount);
  int get anonymousTotal => anonymousEntries.fold(0, (sum, item) => sum + item.amount);
  int get registeredTotal => identifiedTotal + anonymousTotal;
  int get difference => physicalTotal - registeredTotal;

  int identifiedTotalBy(EnvelopeType type) => identifiedEntries.where((e) => e.type == type).fold(0, (sum, item) => sum + item.amount);
  int anonymousTotalBy(EnvelopeType type) => anonymousEntries.where((e) => e.type == type).fold(0, (sum, item) => sum + item.amount);

  const ServiceClosingState({
    this.sessionId,
    this.date,
    this.serviceTime,
    this.serviceEndTime,
    this.serviceType,
    this.mainTreasurer = "",
    this.coTreasurer,
    this.verifierName,
    this.verifierType,
    this.identifiedEntries = const [],
    this.anonymousEntries = const [],
    this.physicalTotal = 0,
    this.error,
    this.knownMembers = const [],
    this.isSubmitting = false,
    this.isSuccess = false,
    this.conferente2,
    this.conferente1Ready = false,
    this.conferente2Ready = false,
  });

  ServiceClosingState copyWith({
    int? sessionId,
    DateTime? date,
    String? serviceTime,
    String? serviceEndTime,
    String? serviceType,
    String? mainTreasurer,
    String? coTreasurer,
    String? verifierName,
    String? verifierType,
    List<Envelope>? identifiedEntries,
    List<AnonymousEntry>? anonymousEntries,
    int? physicalTotal,
    String? error,
    List<String>? knownMembers,
    bool? isSubmitting,
    bool? isSuccess,
    String? conferente2,
    bool? conferente1Ready,
    bool? conferente2Ready,
  }) {
    return ServiceClosingState(
      sessionId: sessionId ?? this.sessionId,
      date: date ?? this.date,
      serviceTime: serviceTime ?? this.serviceTime,
      serviceEndTime: serviceEndTime ?? this.serviceEndTime,
      serviceType: serviceType ?? this.serviceType,
      mainTreasurer: mainTreasurer ?? this.mainTreasurer,
      coTreasurer: coTreasurer ?? this.coTreasurer,
      verifierName: verifierName ?? this.verifierName,
      verifierType: verifierType ?? this.verifierType,
      identifiedEntries: identifiedEntries ?? this.identifiedEntries,
      anonymousEntries: anonymousEntries ?? this.anonymousEntries,
      physicalTotal: physicalTotal ?? this.physicalTotal,
      error: error,
      knownMembers: knownMembers ?? this.knownMembers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      conferente2: conferente2 ?? this.conferente2,
      conferente1Ready: conferente1Ready ?? this.conferente1Ready,
      conferente2Ready: conferente2Ready ?? this.conferente2Ready,
    );
  }

  @override
  List<Object?> get props => [
    sessionId, date, serviceTime, serviceEndTime, serviceType,
    mainTreasurer, coTreasurer, verifierName, verifierType,
    identifiedEntries, anonymousEntries, physicalTotal, error, knownMembers,
    isSubmitting, isSuccess, conferente2, conferente1Ready, conferente2Ready
  ];

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'date': date?.toIso8601String(),
      'serviceTime': serviceTime,
      'serviceEndTime': serviceEndTime,
      'serviceType': serviceType,
      'mainTreasurer': mainTreasurer,
      'coTreasurer': coTreasurer,
      'verifierName': verifierName,
      'verifierType': verifierType,
      'identifiedEntries': identifiedEntries.map((e) => e.toJson()).toList(),
      'anonymousEntries': anonymousEntries.map((e) => e.toJson()).toList(),
      'physicalTotal': physicalTotal,
      'error': error,
      'knownMembers': knownMembers,
      'isSubmitting': isSubmitting,
      'isSuccess': isSuccess,
      'conferente2': conferente2,
      'conferente1Ready': conferente1Ready,
      'conferente2Ready': conferente2Ready,
    };
  }

  factory ServiceClosingState.fromJson(Map<String, dynamic> json) {
    return ServiceClosingState(
      sessionId: json['sessionId'] as int?,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      serviceTime: json['serviceTime'] as String?,
      serviceEndTime: json['serviceEndTime'] as String?,
      serviceType: json['serviceType'] as String?,
      mainTreasurer: json['mainTreasurer'] ?? "",
      coTreasurer: json['coTreasurer'],
      verifierName: json['verifierName'],
      verifierType: json['verifierType'],
      identifiedEntries: (json['identifiedEntries'] as List<dynamic>?)
              ?.map((e) => Envelope.fromJson(e))
              .toList() ??
          const [],
      anonymousEntries: (json['anonymousEntries'] as List<dynamic>?)
              ?.map((e) => AnonymousEntry.fromJson(e))
              .toList() ??
          const [],
      physicalTotal: json['physicalTotal'] ?? 0,
      error: json['error'],
      knownMembers: (json['knownMembers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isSubmitting: json['isSubmitting'] ?? false,
      isSuccess: json['isSuccess'] ?? false,
      conferente2: json['conferente2'] as String?,
      conferente1Ready: json['conferente1Ready'] ?? false,
      conferente2Ready: json['conferente2Ready'] ?? false,
    );
  }
}
