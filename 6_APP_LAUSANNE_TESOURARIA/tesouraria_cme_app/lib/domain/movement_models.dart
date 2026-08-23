class MovementResponse {
  final String reference;
  final double totalIncomes;
  final double totalOutcomes;
  final double balance;
  final List<MovementItem> items;

  MovementResponse({
    required this.reference,
    required this.totalIncomes,
    required this.totalOutcomes,
    required this.balance,
    required this.items,
  });

  factory MovementResponse.fromJson(Map<String, dynamic> json) {
    var itemsJson = json['items'] as List? ?? [];
    List<MovementItem> itemsList = itemsJson.map((i) => MovementItem.fromJson(i)).toList();

    return MovementResponse(
      reference: json['reference'] ?? '',
      totalIncomes: (json['totalIncomes'] ?? 0.0).toDouble(),
      totalOutcomes: (json['totalOutcomes'] ?? 0.0).toDouble(),
      balance: (json['balance'] ?? 0.0).toDouble(),
      items: itemsList,
    );
  }
}

class MovementItem {
  final String id;
  final String date;
  final String type;
  final String category;
  final String description;
  final double value;
  final String status;

  MovementItem({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.description,
    required this.value,
    required this.status,
  });

  factory MovementItem.fromJson(Map<String, dynamic> json) {
    return MovementItem(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      type: json['type'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      value: (json['value'] ?? 0.0).toDouble(),
      status: json['status'] ?? '',
    );
  }
}
