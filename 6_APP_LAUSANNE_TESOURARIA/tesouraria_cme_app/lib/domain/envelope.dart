import 'package:equatable/equatable.dart';

enum EnvelopeType { dizimo, oferta, voto }

class Envelope extends Equatable {
  final String id;
  final String memberName;
  final EnvelopeType type;
  final int amount;
  final int? contributorId;

  const Envelope({
    required this.id,
    required this.memberName,
    required this.type,
    required this.amount,
    this.contributorId,
  });

  @override
  List<Object?> get props => [id, memberName, type, amount, contributorId];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberName': memberName,
      'type': type.name.toUpperCase(), // Map type name to upper case as expected by Spring enum
      'amount': amount,
      'contributorId': contributorId,
    };
  }

  factory Envelope.fromJson(Map<String, dynamic> json) {
    return Envelope(
      id: json['id']?.toString() ?? '',
      memberName: json['memberName'] ?? '',
      type: EnvelopeType.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['type'] as String).toLowerCase(),
        orElse: () => EnvelopeType.dizimo,
      ),
      amount: json['amount'] ?? 0,
      contributorId: json['contributorId'] as int?,
    );
  }
}
