import 'envelope.dart';

class ServiceClosingSummary {
  final int id;
  final String serviceDate;
  final String mainTreasurer;
  final String coTreasurer;
  final String? verifierName;
  final String? verifierType;
  final double physicalTotal;

  ServiceClosingSummary({
    required this.id,
    required this.serviceDate,
    required this.mainTreasurer,
    required this.coTreasurer,
    this.verifierName,
    this.verifierType,
    required this.physicalTotal,
  });

  factory ServiceClosingSummary.fromJson(Map<String, dynamic> json) {
    String parseDate(dynamic val) {
      if (val == null) return '-';
      if (val is String) {
        // e.g. "2026-08-09"
        final parts = val.split('-');
        if (parts.length == 3) {
          return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
        }
        return val;
      }
      if (val is List && val.length == 3) {
        // e.g. [2026, 8, 9]
        return '${val[2].toString().padLeft(2, '0')}/${val[1].toString().padLeft(2, '0')}/${val[0]}';
      }
      return '-';
    }

    return ServiceClosingSummary(
      id: json['id'],
      serviceDate: parseDate(json['serviceDate']),
      mainTreasurer: json['mainTreasurer'] ?? '-',
      coTreasurer: json['coTreasurer'] ?? '-',
      verifierName: json['verifierName'],
      verifierType: json['verifierType'],
      physicalTotal: (json['physicalTotal'] ?? 0).toDouble(),
    );
  }
}


class ServiceClosingDetail {
  final int id;
  final String serviceDate;
  final String mainTreasurer;
  final String coTreasurer;
  final String? verifierName;
  final String? verifierType;
  
  final List<Envelope> identifiedEntries;
  
  final double unidentifiedDizimoTotal;
  final double unidentifiedOfertaTotal;
  final double unidentifiedVotoTotal;
  
  final double identifiedTotal;
  final double unidentifiedTotal;
  final double registeredTotal;
  final double physicalTotal;

  ServiceClosingDetail({
    required this.id,
    required this.serviceDate,
    required this.mainTreasurer,
    required this.coTreasurer,
    this.verifierName,
    this.verifierType,
    required this.identifiedEntries,
    required this.unidentifiedDizimoTotal,
    required this.unidentifiedOfertaTotal,
    required this.unidentifiedVotoTotal,
    required this.identifiedTotal,
    required this.unidentifiedTotal,
    required this.registeredTotal,
    required this.physicalTotal,
  });

  factory ServiceClosingDetail.fromJson(Map<String, dynamic> json) {
    var list = json['identifiedEntries'] as List<dynamic>? ?? [];
    List<Envelope> entries = list.map((e) {
      EnvelopeType type;
      switch (e['type']?.toString().toUpperCase()) {
        case 'OFERTA': type = EnvelopeType.oferta; break;
        case 'VOTO': type = EnvelopeType.voto; break;
        case 'DIZIMO':
        default: type = EnvelopeType.dizimo; break;
      }
      return Envelope(
        id: '', // Not used for history viewing
        amount: ((e['amount'] ?? 0) * 100).toInt(), 
        type: type,
        memberName: e['memberName'] ?? '',
      );
    }).toList().cast<Envelope>();

    String parseDate(dynamic val) {
      if (val == null) return '-';
      if (val is String) {
        final parts = val.split('-');
        if (parts.length == 3) {
          return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
        }
        return val;
      }
      if (val is List && val.length == 3) {
        return '${val[2].toString().padLeft(2, '0')}/${val[1].toString().padLeft(2, '0')}/${val[0]}';
      }
      return '-';
    }

    return ServiceClosingDetail(
      id: json['id'],
      serviceDate: parseDate(json['serviceDate']),
      mainTreasurer: json['mainTreasurer'] ?? '-',
      coTreasurer: json['coTreasurer'] ?? '-',
      verifierName: json['verifierName'],
      verifierType: json['verifierType'],
      identifiedEntries: entries,
      unidentifiedDizimoTotal: (json['unidentifiedDizimoTotal'] ?? 0).toDouble(),
      unidentifiedOfertaTotal: (json['unidentifiedOfertaTotal'] ?? 0).toDouble(),
      unidentifiedVotoTotal: (json['unidentifiedVotoTotal'] ?? 0).toDouble(),
      identifiedTotal: (json['identifiedTotal'] ?? 0).toDouble(),
      unidentifiedTotal: (json['unidentifiedTotal'] ?? 0).toDouble(),
      registeredTotal: (json['registeredTotal'] ?? 0).toDouble(),
      physicalTotal: (json['physicalTotal'] ?? 0).toDouble(),
    );
  }
}
