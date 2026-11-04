import 'package:equatable/equatable.dart';

enum EnvelopeType { dizimo, oferta, voto }

enum PaymentMethod { dinheiro, twint, transferencia }

extension PaymentMethodExtension on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.twint:
        return 'TWINT';
      case PaymentMethod.transferencia:
        return 'Transferência';
      case PaymentMethod.dinheiro:
      default:
        return 'Dinheiro';
    }
  }
}

class Envelope extends Equatable {
  final String id;
  final String memberName;
  final EnvelopeType type;
  final int amount;
  final int? contributorId;
  final String? enteredBy;
  final PaymentMethod paymentMethod;

  const Envelope({
    required this.id,
    required this.memberName,
    required this.type,
    required this.amount,
    this.contributorId,
    this.enteredBy,
    this.paymentMethod = PaymentMethod.dinheiro,
  });

  @override
  List<Object?> get props => [id, memberName, type, amount, contributorId, enteredBy, paymentMethod];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberName': memberName,
      'type': type.name.toUpperCase(),
      'amount': amount,
      'contributorId': contributorId,
      if (enteredBy != null) 'enteredBy': enteredBy,
      'paymentMethod': paymentMethod.name.toUpperCase(),
    };
  }

  factory Envelope.fromJson(Map<String, dynamic> json) {
    PaymentMethod method = PaymentMethod.dinheiro;
    final methodStr = json['paymentMethod']?.toString().toUpperCase();
    if (methodStr == 'TWINT') {
      method = PaymentMethod.twint;
    } else if (methodStr == 'TRANSFERENCIA' || methodStr == 'TRANSFERÊNCIA' || methodStr == 'BANK_TRANSFER') {
      method = PaymentMethod.transferencia;
    }

    return Envelope(
      id: json['id']?.toString() ?? '',
      memberName: json['memberName'] ?? '',
      type: EnvelopeType.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['type'] as String).toLowerCase(),
        orElse: () => EnvelopeType.dizimo,
      ),
      amount: json['amount'] ?? 0,
      contributorId: json['contributorId'] != null ? int.tryParse(json['contributorId'].toString()) : null,
      enteredBy: json['enteredBy'] as String?,
      paymentMethod: method,
    );
  }
}
